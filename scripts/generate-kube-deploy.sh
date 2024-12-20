#!/bin/bash

# Define input and output files
VERSIONS_FILE="scripts/versions.conf"
TEMPLATE_FILE="kubernetes/deploy-template.yaml"
OUTPUT_FILE="kubernetes/deploy.yaml"

# Check if the required files exist
if [[ ! -f $VERSIONS_FILE ]]; then
  echo "Error: $VERSIONS_FILE does not exist."
  exit 1
fi

if [[ ! -f $TEMPLATE_FILE ]]; then
  echo "Error: $TEMPLATE_FILE does not exist."
  exit 1
fi

# Source the versions.conf file to load the variables
source $VERSIONS_FILE

# Replace placeholders in the template file and create the deploy.yaml
sed \
  -e "s|\${MODELS_TAG}|$MODELS_TAG|g" \
  -e "s|\${ASSETS_TAG}|$ASSETS_TAG|g" \
  -e "s|\${MENTOR_TAG}|$MENTOR_TAG|g" \
  -e "s|\${BRIDGE_TAG}|$BRIDGE_TAG|g" \
  -e "s|\${UI_TAG}|$UI_TAG|g" \
  "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Print success message
echo "Successfully created $OUTPUT_FILE with populated versions."