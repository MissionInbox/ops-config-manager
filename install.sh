#!/bin/bash

# Installation script for ops-config-manager
# Usage: ./install.sh [environment] [private_key]
# Example: ./install.sh staging "some_private_key"

set -e

# Check for required arguments
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 [environment] [private_key]"
  echo "Example: $0 staging \"some_private_key\""
  exit 1
fi

ENV="$1"
PRIVATE_KEY="$2"
API_DOMAIN="https://admin-api.missioninbox.com"
CONFIG_URL="${API_DOMAIN}/ops/${ENV}.config"
OUTPUT_FILE="/opt/missioninbox/environment.config"
SCRIPT_DESTINATION="/usr/bin/init_mi_config.sh"
CONFIG_PARAMS_FILE="/opt/missioninbox/config_params"

# Check if user has root permissions
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root or with sudo to install to system directories"
  echo "Try: sudo $0 $*"
  exit 1
fi

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

# Extract repo_private_key if present in config
REPO_KEY_PATH="/opt/missioninbox/repo.key"
echo "Checking for repository private key in config..."

if grep -q "repo_private_key" "$OUTPUT_FILE"; then
  echo "Found repo_private_key in config, extracting..."
  
  # Extract the base64 encoded private key
  REPO_KEY_BASE64=$(grep -o '"repo_private_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$OUTPUT_FILE" | cut -d'"' -f4)
  
  if [ -n "$REPO_KEY_BASE64" ]; then
    # Decode the base64 key
    echo "$REPO_KEY_BASE64" | base64 -d > "$REPO_KEY_PATH"
    
    # Set secure permissions for SSH key
    chmod 600 "$REPO_KEY_PATH"
    
    echo "✅ Repository private key saved to $REPO_KEY_PATH with secure permissions"
  else
    echo "⚠️ repo_private_key found but appears to be empty"
  fi
else
  echo "No repo_private_key found in config"
fi

# Install the parameterless updater script
echo "Installing updater script to $SCRIPT_DESTINATION..."

cat > "$SCRIPT_DESTINATION" << 'EOF'
#!/bin/bash

# MissionInbox Configuration Refresh Script
# This script refreshes the configuration file using stored parameters

set -e

CONFIG_PARAMS_FILE="/opt/missioninbox/config_params"
OUTPUT_FILE="/opt/missioninbox/environment.config"

# Check if we have stored parameters
if [ ! -f "$CONFIG_PARAMS_FILE" ]; then
  echo "Error: No stored parameters found at $CONFIG_PARAMS_FILE"
  echo "Please run the initial setup first with environment and private key"
  exit 1
fi

# Load stored parameters
source "$CONFIG_PARAMS_FILE"

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Error: Missing required parameters in $CONFIG_PARAMS_FILE"
  exit 1
fi

echo "Refreshing configuration for environment: $ENVIRONMENT"

API_DOMAIN="https://admin-api.missioninbox.com"
CONFIG_URL="${API_DOMAIN}/ops/${ENVIRONMENT}.config"

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

echo "✅ Configuration refreshed successfully at $OUTPUT_FILE"

# Extract repo_private_key if present in config
REPO_KEY_PATH="/opt/missioninbox/repo.key"
echo "Checking for repository private key in config..."

if grep -q "repo_private_key" "$OUTPUT_FILE"; then
  echo "Found repo_private_key in config, extracting..."
  
  # Extract the base64 encoded private key
  REPO_KEY_BASE64=$(grep -o '"repo_private_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$OUTPUT_FILE" | cut -d'"' -f4)
  
  if [ -n "$REPO_KEY_BASE64" ]; then
    # Decode the base64 key
    echo "$REPO_KEY_BASE64" | base64 -d > "$REPO_KEY_PATH"
    
    # Set secure permissions for SSH key
    chmod 600 "$REPO_KEY_PATH"
    
    echo "✅ Repository private key saved to $REPO_KEY_PATH with secure permissions"
  else
    echo "⚠️ repo_private_key found but appears to be empty"
  fi
else
  echo "No repo_private_key found in config"
fi
EOF

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