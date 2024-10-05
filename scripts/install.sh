#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect the Linux distribution
get_linux_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Install Docker and Docker Compose on macOS using Homebrew
install_docker_mac() {
    echo "Docker is not installed. Installing Docker for macOS using Homebrew..."
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        echo "Homebrew is not installed. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install Docker and Docker Compose
    brew install --cask docker
    echo "Docker has been installed. Please launch Docker Desktop manually from your Applications folder."

    # Docker Compose is included in Docker Desktop, so no need for a separate install.
}

# Install Docker on Debian-based systems (Ubuntu, Debian)
install_docker_debian() {
    echo "Docker is not installed. Installing Docker for Debian-based Linux..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "Docker installation completed. Please log out and log back in to apply the docker group."
}

# Install Docker on RedHat-based systems (RHEL, CentOS)
install_docker_redhat() {
    echo "Docker is not installed. Installing Docker for RedHat-based Linux..."
    sudo dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker installation completed. Please log out and log back in to apply the docker group."
}

# Install Docker on Fedora
install_docker_fedora() {
    echo "Docker is not installed. Installing Docker for Fedora Linux..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker installation completed. Please log out and log back in to apply the docker group."
}

# Install Docker Compose on Linux (same method for all distributions)
install_docker_compose_linux() {
    echo "Docker Compose is not installed. Installing Docker Compose for Linux..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installation completed."
}

# Check for Docker and Docker Compose
check_docker_and_compose() {
    if command_exists docker; then
        echo "Docker is already installed."
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            install_docker_mac
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            DISTRO=$(get_linux_distribution)
            case "$DISTRO" in
                ubuntu|debian)
                    install_docker_debian
                    ;;
                rhel|centos)
                    install_docker_redhat
                    ;;
                fedora)
                    install_docker_fedora
                    ;;
                *)
                    echo "Unsupported Linux distribution: $DISTRO"
                    exit 1
                    ;;
            esac
        else
            echo "Unsupported OS: $OSTYPE"
            exit 1
        fi
    fi

    if command_exists docker-compose; then
        echo "Docker Compose is already installed."
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Docker Compose is included with Docker Desktop on macOS."
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            install_docker_compose_linux
        fi
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
  echo "Usage: $0 -K <REGISTRATION_KEY>"
  exit 1
}

# Parse command line arguments
while getopts "K:" opt; do
  case ${opt} in
    K )
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

# Run docker-compose up with the registration key
docker-compose up -d