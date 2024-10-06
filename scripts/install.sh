#!/bin/bash

# Fancy progress spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Docker and Docker Compose
check_docker_and_compose() {
    if command_exists docker; then
        echo -e "\033[1;32mDocker is already installed.\033[0m"
    else
        echo -e "\033[1;33mDocker is not installed. Installing Docker...\033[0m"
        curl -fsSL https://get.docker.com -o get-docker.sh &
        spinner
        sudo sh get-docker.sh > /dev/null 2>&1 &
        spinner
        if command -v apt > /dev/null; then
          echo -e "\033[1;34mInstalling uidmap...\033[0m"
          sudo apt install -y uidmap > /dev/null 2>&1 &
          spinner
        fi
        echo -e "\033[1;32mDocker installation completed.\033[0m"
    fi
}

# Main script execution
echo -e "\033[1;34mChecking for Docker and Docker Compose installation...\033[0m"
check_docker_and_compose

# Default values
REGISTRATION_KEY=""
DOCKER_COMPOSE_URL="https://github.com/merly-ai/merly-mentor/releases/download/${RELEASE_TAG_VERSION}/docker-compose.yaml"
DOCKER_COMPOSE_FILE="docker-compose.yaml"

# Download docker-compose.yaml if it doesn't exist
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
  echo -e "\033[1;33mDownloading docker-compose.yaml...\033[0m"
  curl -L -o $DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_URL &
  spinner
  if [ $? -ne 0 ]; then
    echo -e "\033[1;31mError: Failed to download the docker-compose.yaml file.\033[0m"
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
  echo -e "\033[1;31mError: Registration key is required.\033[0m"
  usage
fi

# Export the registration key to the environment
export REGISTRATION_KEY=$REGISTRATION_KEY

# Create mentor data dir and assign permissions
echo -e "\033[1;34mSetting up mentor data directory...\033[0m"
mkdir -p mentor-data
chmod 777 mentor-data
echo -e "\033[1;32mMentor data directory set up successfully.\033[0m"

# Run docker-compose up with the registration key
echo -e "\033[1;34mStarting Docker Compose services...\033[0m"
docker compose up -d &
spinner

# Sucessful Installation
echo -e "\033[1;32m"
echo "======================================="
echo "  Installation of Merly Mentor SUCCESSFUL!"
echo "======================================="
echo -e "\033[0m"

# Display the visit link in a highlighted format
echo -e "\033[1;34mPlease visit \033[4;34mhttp://localhost:3000/\033[0m"
