#!/bin/bash

# Default values
os="Redhat"
channel="Test"

# Check if arguments are passed and override the default values
if [ ! -z "$1" ]; then
  os=$1
fi

if [ ! -z "$2" ]; then
  channel=$2
fi

# Base URL for the API with dynamic or default os and channel
BASE_URL="https://merlyserviceadmin.azurewebsites.net/api/VersionInfo?stable=true&os=${os}&channel=${channel}&artifactUrl=true"


# Create directories for components
mkdir -p .models .assets UI

# Fetch the JSON response from the URL
response=$(curl -s $BASE_URL)

# Function to download and show percentage progress based on known size with proper signal handling
download_file() {
    local name=$1
    local url=$2
    local dir=$3
    local size=$4  # Expected file size in bytes

    # Create an empty file to store the download progress
    temp_file="$dir/$name.tmp"

    echo "Downloading $name... (Size: $((size / 1024)) KB)"
    
    # Start curl in the background
    curl -s -L "$url" -o "$temp_file" &
    curl_pid=$!

    # Trap the SIGINT (Ctrl + C) to ensure curl process is killed
    trap "echo 'Download interrupted. Cleaning up...'; kill $curl_pid 2>/dev/null; rm -f $temp_file; exit 1" SIGINT

    # Track the download progress manually
    while kill -0 $curl_pid 2>/dev/null; do
        # Get the size of the partially downloaded file
        downloaded_size=$(stat -c%s "$temp_file" 2>/dev/null || echo 0)
        
        # Calculate the download percentage
        if [[ "$size" -gt 0 ]]; then
            percentage=$(( 100 * downloaded_size / size ))
            echo -ne "\rDownloading $name: $percentage% completed"
        fi
        
        sleep 1
    done

    wait $curl_pid

    # Reset the trap for future downloads
    trap - SIGINT

    # Move the file to the final location after download is complete
    mv "$temp_file" "$dir/$name"
    echo -e "\n$name downloaded to $dir."
}



# Prepare MerlyMentor
prepare_merlymentor() {
    echo "Preparing MerlyMentor..."
    mentor_url=$(echo $response | jq -r '.[] | select(.Name=="MerlyMentor") | .Url')
    size=$(echo $response | jq -r '.[] | select(.Name=="MerlyMentor") | .Size')
    download_file "MerlyMentor" "$mentor_url" "." $size
}

# Prepare models
prepare_models() {
    echo "Preparing models..."

    # Get all model names that end with _model and store them in an array
    models=$(echo "$response" | jq -r '.[] | select(.Name | endswith("_model")) | .Name')

    # Loop through each model name and download it
    for model_name in $models; do
        model_url=$(echo "$response" | jq -r --arg model_name "$model_name" '.[] | select(.Name==$model_name) | .Url')
        size=$(echo "$response" | jq -r --arg model_name "$model_name" '.[] | select(.Name==$model_name) | .Size')
        download_file "$model_name" "$model_url" ".models" $size
    done
}

# Prepare assets
prepare_assets() {
    echo "Preparing assets..."
    assets_url=$(echo $response | jq -r '.[] | select(.Name=="assets.zip") | .Url')
    size=$(echo $response | jq -r '.[] | select(.Name=="assets.zip") | .Size')
    download_file "assets.zip" "$assets_url" ".assets" $size
    unzip -q .assets/assets.zip -d .assets
    rm -f .assets/assets.zip
}

# Prepare MentorUI
prepare_mentorui() {
    echo "Preparing MentorUI..."
    ui_url=$(echo $response | jq -r '.[] | select(.Name=="MentorUI") | .Url')
    size=$(echo $response | jq -r '.[] | select(.Name=="MentorUI") | .Size')
    download_file "ui.zip" "$ui_url" "UI" $size
    unzip -q UI/ui.zip -d UI
    rm -f UI/ui.zip
}

# Prepare MentorBridge
prepare_mentorbridge() {
    echo "Preparing MentorBridge..."
    bridge_url=$(echo $response | jq -r '.[] | select(.Name=="MentorBridge") | .Url')
    size=$(echo $response | jq -r '.[] | select(.Name=="MentorBridge") | .Size')
    download_file "MentorBridge" "$bridge_url" "." $size
}

# Run all preparation steps
prepare_merlymentor
prepare_models
prepare_assets
prepare_mentorui
prepare_mentorbridge

echo "All components prepared successfully."
