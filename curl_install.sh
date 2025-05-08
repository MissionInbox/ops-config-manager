#!/bin/bash

# This script is used to install init_mi_config.sh from GitHub to the local system
# Usage: ./curl_install.sh [environment] [private_key]

set -e

# Check for required arguments
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 [environment] [private_key]"
  echo "Example: $0 staging \"some_private_key\""
  exit 1
fi

ENV="$1"
PRIVATE_KEY="$2"

# Directory for temporary files
TEMP_DIR=$(mktemp -d)
SCRIPT_TEMP="$TEMP_DIR/init_mi_config.sh"

# Function to cleanup temporary files
cleanup() {
  rm -rf "$TEMP_DIR"
}

# Set trap to ensure cleanup on exit
trap cleanup EXIT

echo "Downloading the configuration script..."

# Download the script from GitHub
curl -s -o "$SCRIPT_TEMP" "https://raw.githubusercontent.com/MissionInbox/ops-config-manager/refs/heads/master/init_mi_config.sh"

if [ $? -ne 0 ] || [ ! -s "$SCRIPT_TEMP" ]; then
  echo "Error: Failed to download the script"
  exit 1
fi

# Make the script executable
chmod +x "$SCRIPT_TEMP"

echo "Installing and running the configuration script..."

# Run the script to set up the configuration
"$SCRIPT_TEMP" "$ENV" "$PRIVATE_KEY"
cp "$SCRIPT_TEMP" /usr/bin/init_mi_config.sh
chmod +x /usr/bin/init_mi_config.sh
echo "Configuration script installed successfully."