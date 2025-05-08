#!/bin/bash

# Configuration initialization script
# Usage: ./init_config.sh [environment] [private_key]
# Example: ./init_config.sh staging "some_private_key"

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