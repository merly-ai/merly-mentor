#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Docker and Docker Compose
check_docker_and_compose() {
    if command_exists docker; then
        echo "Docker is already installed."
    else
        echo "Docker is not installed. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh > /dev/null 2>&1
        # Check if apt exists
        if command -v apt > /dev/null; then
          echo "apt found, proceeding with the installation of uidmap..."
          sudo apt install -y uidmap > /dev/null 2>&1
        fi
        dockerd-rootless-setuptool.sh install
        echo "Docker installation completed."
    fi
}

# Main script execution
echo "Checking for Docker and Docker Compose installation..."
check_docker_and_compose

# Default values
REGISTRATION_KEY=""
DOCKER_COMPOSE_URL="https://github.com/merly-ai/merly-mentor/releases/download/${RELEASE_TAG_VERSION}/docker-compose.yaml"
DOCKER_COMPOSE_FILE="docker-compose.yaml"

# Download docker-compose.yaml if it doesn't exist
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
  echo "Downloading docker-compose.yaml..."
  curl -L -o $DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_URL
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download the docker-compose.yaml file."
    exit 1
  fi
fi

# Function to display help message
usage() {
  echo "Usage: $0 -k <REGISTRATION_KEY>"
  exit 1
}

# Parse command line arguments
while getopts "k:" opt; do
  case ${opt} in
    k )
      REGISTRATION_KEY=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

# Check if registration key is provided
if [ -z "$REGISTRATION_KEY" ]; then
  echo "Error: Registration key is required."
  usage
fi

# Export the registration key to the environment
export REGISTRATION_KEY=$REGISTRATION_KEY

# # Write the variables to the .env file
# echo "REGISTRATION_KEY=$REGISTRATION_KEY" > .env
# echo "PWD=$PWD" >> .env

# Create mentor data dir and assign permissions
mkdir mentor-data
chmod 777 mentor-data

# Run docker-compose up with the registration key
docker compose up -d

# Sucessful Installation
echo -e "\033[1;32m"
echo "======================================="
echo "  Installation of Merly Mentor SUCCESSFUL!"
echo "======================================="
echo -e "\033[0m"

# Display the visit link in a highlighted format
echo -e "\033[1;34mPlease visit \033[4;34mhttp://localhost:3000/\033[0m"
