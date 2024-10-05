#!/bin/bash

# Default values for the tags and files
MODELS_TAG="v2.0.0"
ASSETS_TAG="v1.0.0"
MENTOR_TAG="v0.4.19"
BRIDGE_TAG="v0.1.0"
UI_TAG="v0.1.0"
TEMPLATE_FILE=""
OUTPUT_FILE=""

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --models-tag TAG         Set merly-models image tag (default: v2.0.0)"
    echo "  --assets-tag TAG         Set merly-assets image tag (default: v1.0.0)"
    echo "  --mentor-tag TAG         Set merly-mentor image tag (default: v0.4.19)"
    echo "  --bridge-tag TAG         Set merly-bridge image tag (default: v0.1.0)"
    echo "  --ui-tag TAG             Set merly-ui image tag (default: v0.1.0)"
    echo "  --template-file FILE, -i FILE    Set the template file (default: docker-compose.template.yml)"
    echo "  --output-file FILE, -o FILE      Set the output file (default: docker-compose.yml)"
    echo
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --models-tag) MODELS_TAG="$2"; shift ;;
        --assets-tag) ASSETS_TAG="$2"; shift ;;
        --mentor-tag) MENTOR_TAG="$2"; shift ;;
        --bridge-tag) BRIDGE_TAG="$2"; shift ;;
        --ui-tag) UI_TAG="$2"; shift ;;
        --template-file|-i) TEMPLATE_FILE="$2"; shift ;;
        --output-file|-o) OUTPUT_FILE="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check if the template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Template file '$TEMPLATE_FILE' does not exist."
    exit 1
fi

# Replace the placeholders in the template file and output to the new file
sed -e "s/\${MODELS_TAG}/${MODELS_TAG}/g" \
    -e "s/\${ASSETS_TAG}/${ASSETS_TAG}/g" \
    -e "s/\${MENTOR_TAG}/${MENTOR_TAG}/g" \
    -e "s/\${BRIDGE_TAG}/${BRIDGE_TAG}/g" \
    -e "s/\${UI_TAG}/${UI_TAG}/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Create Docker Compose file for ubi9
UBI9_OUTPUT_FILE=$(echo $OUTPUT_FILE | sed 's/\.yml/-ubi9.yml/' | sed 's/\.yaml/-ubi9.yaml/')
sed -e "s/\${MODELS_TAG}/${MODELS_TAG}-ubi9/g" \
    -e "s/\${ASSETS_TAG}/${ASSETS_TAG}-ubi9/g" \
    -e "s/\${MENTOR_TAG}/${MENTOR_TAG}-ubi9/g" \
    -e "s/\${BRIDGE_TAG}/${BRIDGE_TAG}-ubi9/g" \
    -e "s/\${UI_TAG}/${UI_TAG}-ubi9/g" \
    "$TEMPLATE_FILE" > "$UBI9_OUTPUT_FILE"


echo "Generated $OUTPUT_FILE from $TEMPLATE_FILE with the following:"
echo "  merly-models: ${MODELS_TAG}"
echo "  merly-assets: ${ASSETS_TAG}"
echo "  merly-mentor: ${MENTOR_TAG}"
echo "  merly-bridge: ${BRIDGE_TAG}"
echo "  merly-ui: ${UI_TAG}"
