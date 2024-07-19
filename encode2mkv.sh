#!/bin/bash
#
# Author: TituxMetal <github[at]lgdweb[dot]fr>
# Description:
#   
# Dependencies:
#   HandBrakeCLI

AVC_CONVERTER_PATH="${AVC_CONVERTER_PATH:-$HOME}"

baseDir="$AVC_CONVERTER_PATH/mediaSources/video"
workingDir="${baseDir}/tmp"
destinationDir="$AVC_CONVERTER_PATH/Videos/originalDvdMkv"
isoFiles=()
# Define log file name with date and time
logFile="$AVC_CONVERTER_PATH/encode2mkv_$(date +%Y-%m-%d_%H-%M-%S).log"

# Redirect all output to log file
exec > >(tee -a "$logFile") 2>&1

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
  local commands=("HandBrakeCLI")
  local debianPackages=("handbrake-cli")
  local archPackages=("handbrake-cli")
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

prepareDirectories() {
  if [ ! -d ${workingDir} ]; then
    mkdir -pv ${workingDir}
  fi
  if [ ! -d ${destinationDir} ]; then
    mkdir -pv ${destinationDir}
  fi
}

# Function to scan the working directory for Iso files
scanIsoFiles() {
  # Use find command with -exec to directly process each found file
  while IFS= read -r -d $'\0' iso; do
    isoFiles+=("$iso")
    printMessage "Found ISO file: $iso"
  done < <(find "${baseDir}" -type f -name "*.iso" -print0)
}

# Encode DVD Iso to MKV file
encodeIsoToMkv() {
  local isoFile="$1"
  local dvdName=$(basename "$isoFile" .iso)
  local mkvPath="${workingDir}"

  # Get the scan output to extract the number of titles
  scanOutput=$(HandBrakeCLI --input "$isoFile" --scan 2>&1)
  numTitles=$(echo "$scanOutput" | grep -E "scan: DVD has" | awk '{print $5}')

  if [ -z "$numTitles" ]; then
    echo "No titles found in the DVD scan output"
    exit 1
  fi

  # Initialize the longest title to the first title
  longestTitle=0
  maxChapters=0

  # Loop through each title to find the one with the most chapters
  for ((titleNumber=1; titleNumber<=numTitles; titleNumber++)); do
    titleInfo=$(HandBrakeCLI --input "$isoFile" --scan --title $titleNumber 2>&1)
    numChapters=$(echo "$titleInfo" | grep -E "scan: title $titleNumber has" | awk '{print $6}')
    
    if [ $numChapters -gt $maxChapters ]; then
      maxChapters=$numChapters
      longestTitle=$titleNumber
    fi
  done

  if [ $longestTitle -eq 0 ]; then
    echo "No valid title found for encoding"
    exit 1
  fi

  # Define the HandBrakeCLI options with the longest title
  local handbrakeOptions="--no-dvdnav --encoder x264 --quality 20 --optimize --encopts vbv-maxrate=2000:vbv-bufsize=2000 --x264-preset veryfast --x264-tune film --audio-lang-list \"fr\" --first-audio --aencoder copy --mixdown stereo --ab 160 --arate auto --format mkv --title $longestTitle"

  printMessage "Encoding $isoFile (Title $longestTitle) to MKV file..."
  HandBrakeCLI --input "$isoFile" --output "${mkvPath}/${dvdName}.mkv" ${handbrakeOptions}
}

copyMkvToDestination() {
  printMessage "Copying mkv file to ${destinationDir}..."
  rsync -rltv --progress --stats --human-readable ${workingDir}/*.mkv ${destinationDir}/
}

cleanup() {
  if [ -d ${workingDir} ]; then
    printMessage "Cleaning up tmp directory"
    rm -rfv ${workingDir}
  fi

  if ls ${baseDir}/*.iso 1> /dev/null 2>&1; then
    printMessage "Cleaning up iso files"
    rm -rfv ${baseDir}/*.iso
  fi
}

main() {
  trap 'handleError' ERR

  printMessage "Checking for required commands..."
  checkCommands

  printMessage "Preparing directories..."
  prepareDirectories

  printMessage "Scanning ${baseDir} for Iso files..."
  scanIsoFiles

  if [ -z "$isoFiles" ]; then  # Check if the variable is empty
    echo "No ISO files found in ${baseDir}"
    exit 1
  fi

  for isoFile in "${isoFiles[@]}"; do
    echo "Encode ${isoFile} to MKV file... be patient for about 30 minutes."
    encodeIsoToMkv "$isoFile"
  done

  copyMkvToDestination

  printMessage "Cleaning up..."
  cleanup

  printMessage "All is done!"
}

time main

exit 0
