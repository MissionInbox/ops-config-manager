# Operations Configuration Manager

A secure system for managing sensitive configuration files for different environments.

## Overview

This tool allows you to:

1. Encrypt sensitive configuration files with a private key
2. Upload the encrypted configurations to a server
3. Securely retrieve and decrypt configurations when needed

## Setup for Configuration Management

Copy the example environment file to create your own:

```bash
cp .env.example .env
```

Edit the `.env` file and set the following variables:

- `PRIVATE_KEY`: A secure key used for encryption
- `SERVER_IP`: The SSH connection string (user@hostname) for your server
- `SSH_KEY_PATH`: Path to your SSH private key for authentication

## Usage

### Updating Configuration Files

To encrypt a configuration file and upload it to the server:

```bash
./update.sh staging
```

This will:
1. Read the `staging.config` file
2. Encrypt it using your private key
3. Convert to base64 format
4. Upload to your server at `/var/www/ops/staging.config`

The script automatically detects which environment's configuration to update based on the command line argument, so you can easily update any environment:

```bash
./update.sh production
```

### Initializing Configuration

The system uses two scripts for configuration management:

1. `curl_install.sh` - For downloading and running the installation remotely
2. `init_mi_config.sh` - The main script for both initial setup and updates

#### First-Time Setup

To perform the initial configuration on a new server, use the `init_mi_config.sh` script:

```bash
sudo ./init_mi_config.sh staging "your_private_key"
```

This will:
1. Fetch the encrypted configuration from `https://admin-api.missioninbox.com/ops/staging.config`
2. Decrypt it using the provided private key
3. Store the decrypted configuration at `/opt/missioninbox/environment.config`
4. Extract any `repo_private_key` field and save it to `/opt/missioninbox/repo.key`
5. Install itself to `/usr/bin/init_mi_config.sh` for future use
6. Store the environment and private key securely for automatic updates

#### Quick Setup for New Developers

For new developers who have received the private key, you can quickly set up your environment with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/MissionInbox/ops-config-manager/refs/heads/master/curl_install.sh | sudo bash -s -- staging "your_private_key"
```

Replace `staging` with the environment you need (`production`, etc.) and `"your_private_key"` with the actual private key you've received through secure channels.

This single command downloads and runs the installation script to perform the complete setup process.

### Integration with Other Repositories

Once the initial setup is complete, other repositories can refresh the configuration by simply running:

```bash
/usr/bin/init_mi_config.sh
```

This script will automatically:
1. Read the stored environment and private key
2. Download the latest configuration
3. Update `/opt/missioninbox/environment.config` with the latest values

No additional arguments are needed as the script uses the stored parameters from the initial setup.

#### Example Integration

Add this to the beginning of your scripts in other repositories:

```bash
#!/bin/bash
# Check if the configuration updater is available
if [ -x "/usr/bin/init_mi_config.sh" ]; then
  echo "Refreshing configuration..."
  /usr/bin/init_mi_config.sh
else
  echo "Warning: Configuration updater not installed"
  echo "Run the ops-config-manager setup first"
fi

# Continue with your script...
```

## Configuration Files

Create environment-specific configuration files in the `configs` directory:

- `configs/staging.config` - Configuration for staging environment
- `configs/production.config` - Configuration for production environment

These files can contain any sensitive data that needs to be securely managed, including:

### Special Configuration Fields

The configuration files support some special fields that receive special handling:

- `repo_private_key`: A base64-encoded SSH private key that will be:
  - Extracted from the configuration file
  - Decoded and saved to `/opt/missioninbox/repo.key`
  - Given proper permissions (600) for use as an SSH key
  - This allows secure storage of deployment keys for accessing repositories

## Security Notes

- Never commit your `.env` file or your private keys to version control
- Keep your private keys secure and limit access to authorized personnel
- Use strong, unique keys for each project
- Rotate keys periodically for enhanced security