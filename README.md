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

To fetch and decrypt a configuration file on a new server:

```bash
./init_config.sh staging "your_private_key"
```

This will:
1. Fetch the encrypted configuration from `https://admin-api.missioninbox.com/ops/staging.config`
2. Decrypt it using the provided private key
3. Store the decrypted configuration at `/opt/missioninbox/environment.config`

### Quick Setup for New Developers

For new developers who have received the private key, you can quickly set up your environment with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/missioninbox/ops-config-manager/main/init_config.sh | bash -s -- staging "your_private_key"
```

Replace `staging` with the environment you need (`production`, etc.) and `"your_private_key"` with the actual private key you've received through secure channels.

This command will:
1. Download the initialization script directly from GitHub
2. Execute it with your environment and private key
3. Set up your environment configuration at `/opt/missioninbox/environment.config`

Note: You may need to use `sudo` if you don't have write access to the `/opt/missioninbox` directory.

## Configuration Files

Create environment-specific configuration files:

- `staging.config` - Configuration for staging environment
- `production.config` - Configuration for production environment

These files can contain any sensitive data that needs to be securely managed.

## Security Notes

- Never commit your `.env` file or your private keys to version control
- Keep your private keys secure and limit access to authorized personnel
- Use strong, unique keys for each project
- Rotate keys periodically for enhanced security