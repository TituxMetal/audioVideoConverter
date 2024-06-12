#!/bin/bash
#
# Author: TituxMetal <github[at]lgdweb[dot]fr>
# Description:
#   Rips a DVD to a H.264 MKV file, with chapters and tags. Ignores any
#   bad blocks or sectors on the DVD.
# Dependencies:
#  * ddrescue
#  * handbrake-cli
#  * mkvpropedit
#  * lsdvd
#
# Debian: sudo apt install gddrescue mkvtoolnix handbrake-cli lsdvd
# Archlinux: sudo pacman -S ddrescue handbrake-cli mkvtoolnix-cli lsdvd
#

# On debian mkvpropedit is here: /usr/bin/mkvpropedit
# On debian HandBrakeCLI is here: /usr/bin/HandBrakeCLI
# On debian lsdvd is here: /usr/bin/lsdvd
# On debian dvdxchap is here: /usr/bin/dvdxchap
# On debian ddrescue is here: /usr/bin/ddrescue
# On Archlinux mkvpropedit is here: /usr/bin/mkvpropedit
# On Archlinux HandBrakeCLI is here: /usr/bin/HandBrakeCLI
# On Archlinux lsdvd is here: /usr/bin/lsdvd
# On Archlinux dvdxchap is here: /usr/bin/dvdxchap
# On Archlinux ddrescue is here: /usr/bin/ddrescue

baseDir="$HOME/mediaSources/video"
workingDir="${baseDir}/tmp"
destinationDir="$HOME/Videos/originalDvd"
isoBackupDir="$HOME/isoBackups"

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
# Parameters:
#   None
# Returns:
#   None
handleError() {
  local exitCode=$?
  if [ $exitCode -ne 0 ]; then
    printMessage "An error occurred with status: $exitCode"
    printMessage "Cleaning up tmp directory"
    rm -rfv ${tmpPath}

    exit $exitCode
  fi
}

checkCommands() {
  local commands=("mkvpropedit" "HandBrakeCLI" "lsdvd" "dvdxchap" "ddrescue")
  local debian_packages=("gddrescue" "mkvtoolnix" "handbrake-cli" "lsdvd")
  local arch_packages=("ddrescue" "handbrake-cli" "mkvtoolnix-cli")
  local missing_commands=()
  for cmd in "${commands[@]}"; do
    if ! command -v $cmd &> /dev/null; then
      missing_commands+=($cmd)
    fi
  done
  if [ ${#missing_commands[@]} -ne 0 ]; then
    echo "The following commands could not be found: ${missing_commands[@]}"
    echo "You may need to install the missing packages. Here are the commands for Debian and Archlinux:"
    echo "Debian: sudo apt install ${debian_packages[@]}"
    echo "Archlinux: sudo pacman -S ${arch_packages[@]}"
    return 1
  fi
  echo "All commands are available"
  return 0
}

prepareDirectories() {
  if [ ! -d ${workingDir} ]; then
    mkdir -pv ${workingDir}
  fi
  if [ ! -d ${destinationDir} ]; then
    mkdir -pv ${destinationDir}
  fi
  if [ ! -d ${isoBackupDir} ]; then
    mkdir -pv ${isoBackupDir}
  fi
}

copyDvd() {
  local dvdBlocksize=2048
  local dvdDevice="/dev/sr0"
  local ddrescuePasses=0

  if [[ -f "${workingDir}/dvd.iso" ]]; then
    return
  fi

  ddrescue -b "$dvdBlocksize" -r 0 -n "$dvdDevice" "${workingDir}/dvd.iso.part" "${workingDir}/dvd.log"

  if (( ddrescuePasses > 1 )); then
    ddrescue -b "$dvdBlocksize" -d "$dvdDevice" -r 0 "${workingDir}/dvd.iso.part" "${workingDir}/dvd.log"
  fi

  if (( ddrescuePasses > 2 )); then
    ddrescue -b "$dvdBlocksize" -d -R "$dvdDevice" -r 0 "${workingDir}/dvd.iso.part" "${workingDir}/dvd.log"
  fi

  mv "${workingDir}/dvd.iso.part" "${workingDir}/dvd.iso"
  # cp -v "${workingDir}/dvd.iso" "${isoBackupDir}/dvd.iso"
}

main() {
  trap 'handleError' ERR

  printMessage "Checking for required commands..."
  checkCommands

  printMessage "Preparing directories..."
  prepareDirectories

  printMessage "Copying DVD..."
  copyDvd

  printMessage "All is done!"
}

time main

exit 0
