#!/bin/bash

# Simple update script for configuration files
# Usage: ./update.sh [environment]
# Example: ./update.sh staging

set -e

# Check for required argument
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 [environment]"
  echo "Example: $0 staging"
  exit 1
fi

ENV="$1"
CONFIG_FILE="configs/${ENV}.config"
REMOTE_PATH="/var/www/ops/${ENV}.config"

# Load variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found"
  exit 1
fi

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: PRIVATE_KEY not set in .env file"
  exit 1
fi

if [ -z "$SERVER_IP" ]; then
  echo "Error: SERVER_IP not set in .env file"
  exit 1
fi

if [ -z "$SSH_KEY_PATH" ]; then
  echo "Error: SSH_KEY_PATH not set in .env file"
  exit 1
fi

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file $CONFIG_FILE not found"
  exit 1
fi

# Directory for temporary files
TEMP_DIR=$(mktemp -d)
ENCRYPTED_FILE="$TEMP_DIR/encrypted.bin"

# Function to cleanup temporary files
cleanup() {
  rm -rf "$TEMP_DIR"
}

# Set trap to ensure cleanup on exit
trap cleanup EXIT

echo "Encrypting $CONFIG_FILE..."

# Generate a random Initialization Vector (IV)
IV=$(openssl rand -hex 16)

# Encrypt the config file with AES-256-CBC using the private key and IV
openssl enc -aes-256-cbc -in "$CONFIG_FILE" -out "$ENCRYPTED_FILE" \
  -K $(echo -n "$PRIVATE_KEY" | xxd -p -c 32) \
  -iv "$IV" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Encryption failed"
  exit 1
fi

# Combine the IV and encrypted data, then convert to base64
ENCODED=$(
  echo -n "{\"iv\":\"$IV\",\"data\":\"" > "$TEMP_DIR/json.txt"
  cat "$ENCRYPTED_FILE" | base64 -w 0 >> "$TEMP_DIR/json.txt"
  echo -n "\"}" >> "$TEMP_DIR/json.txt"
  cat "$TEMP_DIR/json.txt" | base64 -w 0
)

# Save the base64 encoded string to a file for uploading
echo "$ENCODED" > "$TEMP_DIR/encoded.txt"

echo "Uploading to $SERVER_IP:$REMOTE_PATH..."

# Upload the encoded file to the server using scp
scp -i "$SSH_KEY_PATH" "$TEMP_DIR/encoded.txt" "$SERVER_IP:$REMOTE_PATH"

if [ $? -eq 0 ]; then
  echo "✅ Successfully updated $ENV configuration on server"
else
  echo "❌ Failed to upload configuration"
  exit 1
fi