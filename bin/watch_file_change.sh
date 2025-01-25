#!/bin/bash

# Usage function to display script usage
usage() {
  echo "Usage: $0 <file_path> <command> [sleep_interval]"
  echo "  file_path      - Path to the file to monitor for changes."
  echo "  command        - Command to execute when the file changes."
  echo "  sleep_interval - (Optional) Time in seconds to wait between checks (default: 2)."
  exit 1
}

# Check if at least two arguments are provided
if [ "$#" -lt 2 ]; then
  usage
fi

FILE_PATH=$1
COMMAND=$2
SLEEP_INTERVAL=${3:-2}

# Ensure the file exists
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File $FILE_PATH does not exist."
  exit 1
fi

# Store the initial checksum of the file
LAST_CHECKSUM=$(md5sum "$FILE_PATH" | awk '{ print $1 }')

echo "Monitoring changes to $FILE_PATH with a check interval of $SLEEP_INTERVAL seconds..."
while true; do
  # Calculate the current checksum
  CURRENT_CHECKSUM=$(md5sum "$FILE_PATH" | awk '{ print $1 }')

  # Compare the current checksum with the last one
  if [ "$CURRENT_CHECKSUM" != "$LAST_CHECKSUM" ]; then
    echo "File has changed. Executing command..."
    eval "$COMMAND"

    # Update the last checksum
    LAST_CHECKSUM=$CURRENT_CHECKSUM
  fi

  # Wait for the specified interval before checking again
  sleep "$SLEEP_INTERVAL"
done
