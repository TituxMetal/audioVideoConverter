#!/bin/bash
#
# Author: TituxMetal <github[at]lgdweb[dot]fr>
# Description:
#   This script will rip a DVD to the disk, create an ISO file from the DVD and copy the ISO file to a destination directory.
# Dependencies:
#   dvdbackup
#   dvdauthor
#   mkisofs

set -e

baseDirectory="$HOME/mediaSources/video"
workingDirectory="${baseDirectory}/tmp"
destinationDirectory="$HOME/Videos/originalDvdIso"
dvdName=""

# Function to print a message with formatting
# Usage: printMessage <message>
# Arguments:
#   - message: The message to be printed
printMessage() {
  local message="$1"
  if [ -t 1 ]; then  # Check if output is a terminal
    tput setaf 2
    echo -en "-------------------------------------------\n"
    echo -en "${message}\n"
    echo -en "-------------------------------------------\n"
    tput sgr0
  else
    echo -en "-------------------------------------------\n"
    echo -en "${message}\n"
    echo -en "-------------------------------------------\n"
  fi
}

# Function to handle errors and exit the script if an error occurs.
handleError() {
  local exitCode=$?
  if [ $exitCode -ne 0 ]; then
    printMessage "An error occurred with status: $exitCode"
    printMessage "Cleaning up tmp directory"
    rm -rfv ${tmpPath}

    exit $exitCode
  fi
}

# Function to check if the required commands are available
checkCommands() {
  local commands=("dvdbackup" "dvdauthor" "mkisofs")
  local debianPackages=("dvdbackup" "dvdauthor" "genisoimage")
  local archPackages=("dvdbackup" "dvdauthor" "cdrtools")
  local missingCommands=()

  for cmd in "${commands[@]}"; do
    if ! command -v $cmd &> /dev/null; then
      missingCommands+=($cmd)
    fi
  done

  if [ ${#missingCommands[@]} -ne 0 ]; then
    echo "The following commands could not be found: ${missingCommands[@]}"
    echo "You may need to install the missing packages. Here are the commands for Debian and Archlinux:"
    echo "Debian: sudo apt install ${debianPackages[@]}"
    echo "Archlinux: sudo pacman -S ${archPackages[@]}"
    return 1
  fi

  echo "All commands are available"

  return 0
}

# Function to check if a DVD is inserted in the drive and wait for a DVD to be inserted
checkDvdDevice() {
  local dvdPath="/dev/sr0"

  while true; do
    dvdName=$(dvdbackup -I -i ${dvdPath} 2>&1 | grep "DVD-Video " | awk -F'"' '{print $2}')
    
    if [ -n "${dvdName}" ]; then
      break
    fi

    printMessage "No DVD found in the drive. Please insert a DVD..."
    sleep 10 # Wait for 10 seconds before checking again
  done
}

checkDvdDirectory() {
  local dvdPath="/dev/sr0"
  local dvdDirectory="${workingDirectory}/${dvdName}/"

  # While a DVD directory with the same name as the dvd in the drive exists there is no need to copy the DVD again then we eject the DVD and wait for a new one by calling checkDvdDevice function again
  while true; do
    if [ -d "${dvdDirectory}" ]; then
      printMessage "The DVD directory already exists: ${dvdDirectory}"

      printMessage "Ejecting DVD..."
      eject "${dvdPath}"

      checkDvdDevice
    fi
    break
  done
}

# Function to create the working and destination directories
prepareDirectories() {
  if [ ! -d ${workingDirectory} ]; then
    mkdir -pv ${workingDirectory}
  fi

  if [ ! -d ${destinationDirectory} ]; then
    mkdir -pv ${destinationDirectory}
  fi
}

# Copy the DVD to the working directory
copyDvd() {
  # Set the path of the DVD based on the name of the DVD
  local tmpPath="${workingDirectory}"
  local dvdPath="/dev/sr0"
  
  printMessage "Copying DVD to ${tmpPath}... be patient for about 30 minutes."
  dvdbackup --input "${dvdPath}" --output "${tmpPath}" --mirror --progress --verbose

  eject "${dvdPath}"
}

# Create an ISO file from the DVD directory
createIsoFromDvd() {
  local tmpPath="${workingDirectory}/${dvdName}"
  local isoPath="${baseDirectory}/${dvdName}.iso"

  printMessage "Creating ISO file from DVD... be patient for about 5 minutes."
  mkisofs -dvd-video -input-charset utf8 -udf -o "${isoPath}" "${tmpPath}"
}

# Copy the ISO file to the destination directory
copyIsoToDestination() {
  local isoPath="${baseDirectory}"

  printMessage "Copying ISO file to ${destinationDirectory}..."
  rsync -rltv --progress --stats --human-readable ${isoPath}/*.iso ${destinationDirectory}/
}

# Function to clean up the working directory
cleanup() {
  printMessage "Cleaning up tmp directory"
  rm -rfv ${workingDirectory}
}

main() {
  trap 'handleError' ERR

  printMessage "Checking for required commands..."
  checkCommands

  printMessage "Preparing directories..."
  prepareDirectories

  printMessage "Checking for DVD..."
  checkDvdDevice

  printMessage "Checking for DVD directory..."
  checkDvdDirectory

  printMessage "Copying DVD..."
  copyDvd

  printMessage "Creating ISO file..."
  createIsoFromDvd

  printMessage "Copying ISO file..."
  copyIsoToDestination

  printMessage "Cleaning up..."
  cleanup

  printMessage "All is done!"
}

time main

exit 0
