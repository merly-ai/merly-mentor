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

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (reset)

# Trap SIGINT (CTRL + C) and forward to all background processes
trap "kill 0" SIGINT

# Run Merly Mentor Daemon and stream live logs with "DAEMON" in blue
./MerlyMentor -N daemon --stdout 2>&1 | sed "s/^/${BLUE}[MENTOR DAEMON] ${NC}/" &

# Run Merly Mentor Bridge and stream live logs with "BRIDGE" in green
./MentorBridge 2>&1 | sed "s/^/${GREEN}[MENTOR BRIDGE] ${NC}/" &

# Run Merly Mentor UI and stream live logs with "UI" in yellow
cd UI
npm start 2>&1 | sed "s/^/${YELLOW}[MENTOR UI] ${NC}/" &

# Wait for all background processes to finish, while streaming live logs
wait


