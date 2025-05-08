#!/bin/bash

# Configuration initialization script
# Usage: ./init_mi_config.sh [environment] [private_key]
# Example: ./init_mi_config.sh staging "some_private_key"

set -e

# If we have parameters, use them 
if [ "$#" -eq 2 ]; then
  ENV="$1"
  PRIVATE_KEY="$2"
else
  # Check if we have stored parameters
  CONFIG_PARAMS_FILE="/opt/missioninbox/config_params"
  if [ -f "$CONFIG_PARAMS_FILE" ]; then
    echo "Loading stored configuration parameters..."
    source "$CONFIG_PARAMS_FILE"
    ENV="$ENVIRONMENT"
  else
    echo "Error: No stored parameters found."
    echo "Usage: $0 [environment] [private_key]"
    echo "Example: $0 staging \"some_private_key\""
    exit 1
  fi
fi

API_DOMAIN="https://admin-api.missioninbox.com"
CONFIG_URL="${API_DOMAIN}/ops/${ENV}.config"
OUTPUT_FILE="/opt/missioninbox/environment.config"
SCRIPT_DESTINATION="/usr/bin/init_mi_config.sh"
CONFIG_PARAMS_FILE="/opt/missioninbox/config_params"

# Function to check if script is run with sudo/root
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root or with sudo to install to system directories"
    echo "Try: sudo $0 $@"
    exit 1
  fi
}

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")" 2>/dev/null || true

# Directory for temporary files
TEMP_DIR=$(mktemp -d)
ENCODED_FILE="$TEMP_DIR/encoded.txt"
JSON_FILE="$TEMP_DIR/json.txt"
ENCRYPTED_FILE="$TEMP_DIR/encrypted.bin"

# Function to cleanup temporary files
cleanup() {
  rm -rf "$TEMP_DIR"
}

# Set trap to ensure cleanup on exit
trap cleanup EXIT

echo "Downloading encrypted config from $CONFIG_URL..."

# Download the encoded file
curl -s -o "$ENCODED_FILE" "$CONFIG_URL"

if [ $? -ne 0 ] || [ ! -s "$ENCODED_FILE" ]; then
  echo "Error: Failed to download encrypted config"
  exit 1
fi

echo "Decoding base64..."

# Decode the base64 string to get the JSON
cat "$ENCODED_FILE" | base64 -d > "$JSON_FILE"

if [ $? -ne 0 ] || [ ! -s "$JSON_FILE" ]; then
  echo "Error: Failed to decode base64"
  exit 1
fi

# Extract the IV and encrypted data from JSON
IV=$(grep -o '"iv":"[^"]*"' "$JSON_FILE" | cut -d'"' -f4)
DATA=$(grep -o '"data":"[^"]*"' "$JSON_FILE" | cut -d'"' -f4)

if [ -z "$IV" ] || [ -z "$DATA" ]; then
  echo "Error: Failed to extract IV or encrypted data from JSON"
  exit 1
fi

# Decode the encrypted data
echo "$DATA" | base64 -d > "$ENCRYPTED_FILE"

echo "Decrypting..."

# Decrypt the data using the private key and IV
openssl enc -aes-256-cbc -d -in "$ENCRYPTED_FILE" -out "$OUTPUT_FILE" \
  -K $(echo -n "$PRIVATE_KEY" | xxd -p -c 32) \
  -iv "$IV" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Decryption failed"
  exit 1
fi

echo "✅ Configuration initialized successfully at $OUTPUT_FILE"

# Only store the script if this is the initial installation
if [ "$#" -eq 2 ]; then
  # Get the actual script location - handle both direct execution and curl piping
  SCRIPT_PATH="$0"
  if [ "$SCRIPT_PATH" = "bash" ] || [ "$(basename $SCRIPT_PATH)" = "bash" ]; then
    # We're being piped via curl, create a temporary copy of ourselves
    SELF_CONTENT=$(cat)
    TEMP_SCRIPT="$TEMP_DIR/temp_script.sh"
    echo "$SELF_CONTENT" > "$TEMP_SCRIPT"
    chmod +x "$TEMP_SCRIPT"
    SCRIPT_PATH="$TEMP_SCRIPT"
  fi

  echo "Installing script to $SCRIPT_DESTINATION for future use..."
  
  # Check if we need root permissions
  if [[ "$SCRIPT_DESTINATION" =~ ^/usr/bin/ ]]; then
    # We're already running as root if we got here via curl | sudo bash
    true
  fi
  
  # Copy this script to the destination
  cp "$SCRIPT_PATH" "$SCRIPT_DESTINATION"
  chmod +x "$SCRIPT_DESTINATION"
  
  # Store environment and private key for future use
  echo "Storing configuration parameters..."
  mkdir -p "$(dirname "$CONFIG_PARAMS_FILE")" 2>/dev/null || true
  cat > "$CONFIG_PARAMS_FILE" << EOF
ENVIRONMENT=$ENV
PRIVATE_KEY=$PRIVATE_KEY
EOF
  chmod 600 "$CONFIG_PARAMS_FILE"  # Restrict permissions - only owner can read/write
  
  echo "✅ Script installed at $SCRIPT_DESTINATION"
  echo "✅ Configuration parameters stored at $CONFIG_PARAMS_FILE"
  echo ""
  echo "Other repositories can now run this command to update configuration:"
  echo "  $SCRIPT_DESTINATION"
fi