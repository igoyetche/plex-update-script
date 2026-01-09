# Plex Auto-Update Script

Automated update script for Plex Media Server on Raspberry Pi (or other Linux systems).

## Features

- Automatically checks for the latest Plex version
- Compares with installed version (exits if already up to date)
- Creates backup of Plex configuration before updating
- Downloads and installs the latest version
- Manages Plex service (stop/start)
- Comprehensive logging
- Configurable for different architectures (ARMv7, ARMv8, x86_64)

## Prerequisites

- Plex Media Server already installed
- Root/sudo access
- Required packages: `curl`, `jq`, `dpkg`, `systemctl`, `tar`

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x update-plex.sh
   ```

3. (Optional) Edit `config.conf` to customize settings:
   ```bash
   nano config.conf
   ```

## Usage

Run the script with sudo:

```bash
sudo ./update-plex.sh
```

The script will:
1. Check if an update is available
2. If yes, create a backup and update
3. If no, exit with "already up to date" message

## Configuration

Edit `config.conf` to customize:

- **ARCH**: Target architecture (`armv7`, `armv8`, `amd64`)
- **DISTRO**: Distribution (`debian`, `ubuntu`)
- **DOWNLOAD_DIR**: Temporary download location (default: `/tmp/plex-updates`)
- **BACKUP_DIR**: Backup storage location (default: `/var/backups/plex`)
- **LOG_FILE**: Log file path (default: `/var/log/plex-update.log`)

## Logs

Check the log file for detailed information:

```bash
tail -f /var/log/plex-update.log
```

## Backups

- Backups are stored in `/var/backups/plex` by default
- Format: `plex-backup-YYYYMMDD-HHMMSS.tar.gz`
- Only the last 5 backups are kept (older ones are automatically deleted)

## Future Enhancements

- Cron job integration for automatic updates
- Email notifications
- Automatic rollback on failure
- Plex Pass beta channel support

## License

MIT

## Contributing

Feel free to submit issues or pull requests!
