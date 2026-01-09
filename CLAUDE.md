# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Automated update script for Plex Media Server on Raspberry Pi (Ubuntu/Debian ARMv7). The script checks for updates, creates backups, and safely updates Plex to the latest version.

**Key Features:**
- Version comparison (skips if already up to date)
- Automatic configuration backup before updates
- Service management (stop/update/start)
- Comprehensive logging
- Configurable architecture support (ARMv7, ARMv8, x86_64)

## Architecture

**Main Components:**

- [update-plex.sh](update-plex.sh) - Main bash script that orchestrates the update process
- [config.conf](config.conf) - Configuration file with architecture, paths, and settings
- [SPEC.md](SPEC.md) - Detailed specification document

**Update Flow:**
1. Check installed vs latest version (via Plex API)
2. If up to date → exit
3. If update available → backup config → download → stop service → install → start service → verify

**Key Functions in update-plex.sh:**
- `get_installed_version()` - Checks current Plex version via dpkg
- `get_latest_version()` - Fetches latest version from Plex API (https://plex.tv/api/downloads/5.json)
- `backup_plex_config()` - Creates timestamped tar.gz backup of /var/lib/plexmediaserver
- `install_package()` - Installs .deb package via dpkg

## Development Commands

**Run the update script:**
```bash
sudo ./update-plex.sh
```

**Test configuration:**
```bash
# Check if config file is valid
bash -n update-plex.sh
source config.conf && echo "Config loaded successfully"
```

**Check logs:**
```bash
tail -f /var/log/plex-update.log
```

**Manual Plex service management:**
```bash
sudo systemctl status plexmediaserver
sudo systemctl stop plexmediaserver
sudo systemctl start plexmediaserver
```

## Configuration

Edit [config.conf](config.conf) to customize:
- `ARCH` - Target architecture (armv7, armv8, amd64)
- `DISTRO` - Distribution (debian, ubuntu)
- `DOWNLOAD_DIR` - Where to download packages
- `BACKUP_DIR` - Where to store backups
- `LOG_FILE` - Log file location

## Important Notes

- Script must be run as root (uses `sudo`)
- Requires: curl, jq, dpkg, systemctl, tar
- Plex must already be installed
- Keeps last 5 backups automatically
- Downloads from official Plex API
