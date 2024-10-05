# Variables
INPUT_TEMPLATE=docker-compose-templates/docker-compose.template.yml
OUTPUT_FILE=docker-compose.yaml

# Targets
generate-docker-compose:
	chmod +x scripts/generate-docker-compose.sh
	@/bin/bash -c 'scripts/generate-docker-compose.sh -i $(INPUT_TEMPLATE) -o $(OUTPUT_FILE)'

.PHONY: generate-docker-compose
