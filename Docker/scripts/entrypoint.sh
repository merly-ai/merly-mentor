#!/bin/sh

# Check if a registration key is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <REGISTRATION_KEY>"
  exit 1
fi

# Assign the provided argument to the REGISTRATION_KEY variable
REGISTRATION_KEY=$1

# Define the output directory and file
OUTPUT_DIR="./.mentor"
OUTPUT_FILE="$OUTPUT_DIR/keys.json"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create the JSON content
JSON_CONTENT="{ \"$REGISTRATION_KEY\": {} }"

# Check if the output file exists, if not, write the JSON content to it
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "$JSON_CONTENT" > "$OUTPUT_FILE"
  echo "Registration key saved to $OUTPUT_FILE"
else
  echo "$OUTPUT_FILE already exists. No changes made."
fi

# Trap SIGTERM and SIGINT for cleanup
trap 'kill $(jobs -p)' SIGTERM SIGINT

# Run Merly Mentor Daemon and prefix logs with "DAEMON"
./MerlyMentor -N daemon --stdout &

# Run Merly Mentor Bridge and prefix logs with "BRIDGE"
./MentorBridge &

# Run Merly Mentor UI and prefix logs with "UI"
cd UI
exec npm start
