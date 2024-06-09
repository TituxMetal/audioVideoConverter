#!/bin/bash

basePath="$HOME"
mainMediaSources="${basePath}/mediaSources/audio"
destinationPath="${basePath}/Musique"
tmpPath="${mainMediaSources}/tmp"
wavMedia="${destinationPath}/copieWav"
mp3Media="${destinationPath}/voitureMp3"
flacMedia="${destinationPath}/originalFlac"

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

convertToFormat() {
  local format="$1"
  local destination="$2"

  printMessage "Convert sounds to ${format}"
  soundconverter -b ${mainMediaSources} -r -f ${format} -o ${tmpPath} -p "{artist}/{album}/{Track}-{title}" -e skip

  printMessage "Move to musique ${destination} directory"
  rsync -rltv --progress --stats --human-readable ${tmpPath}/* ${destination}

  printMessage "Cleanup tmp directory"
  rm -rfv ${tmpPath}
}

cleanUp() {
  printMessage "All conversions completed successfully. Cleaning up..."
  rm -rfv ${mainMediaSources}/*
  rm -rfv ${mainMediaSources}_backup
}


main() {
  trap 'handleError' ERR

  printMessage "Starting the conversion process..."
  printMessage "Creating directory structure: ${mainMediaSources}"
  mkdir -pv ${mainMediaSources}
  cd $mainMediaSources

  printMessage "Creating backup of mainMediaSources directory: ${mainMediaSources}_backup"
  cp -rv ${mainMediaSources} ${mainMediaSources}_backup

  printMessage "Creating temporary directory: ${tmpPath}"
  mkdir -pv ${tmpPath}

  printMessage "Creating destination directory structure: ${mp3Media}, ${flacMedia}, ${wavMedia}"
  mkdir -pv ${mp3Media}
  mkdir -pv ${flacMedia}
  mkdir -pv ${wavMedia}

  printMessage "Starting the conversion process..."
  convertToFormat "mp3" ${mp3Media}
  convertToFormat "flac" ${flacMedia}
  convertToFormat "wav" ${wavMedia}

  cleanUp

  printMessage "All is done!"
}

time main

exit 0
