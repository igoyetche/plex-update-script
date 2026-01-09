# Plex Auto-Update Script Specification

## Overview

Automate the update process of Plex Media Server on a Raspberry Pi running Ubuntu/Debian on ARMv7 architecture.

## Assumptions

- Plex Media Server is already installed on the Raspberry Pi
- Plex is currently running
- Default target: Ubuntu/Debian/ARMv7 version
- Architecture/distribution should be configurable

## Requirements

### Functional Requirements

1. **Version Detection**
   - Detect currently installed Plex version
   - Check for latest available version from Plex downloads

2. **Update Process**
   - Download the appropriate Plex package for the configured architecture
   - Verify download integrity (checksum validation)
   - Stop Plex service
   - Install the new version
   - Start Plex service
   - Verify successful update

3. **Configuration**
   - Support configurable target architecture/distribution
   - Configurable download location
   - Backup Plex configuration before update (required)
   - Auto-restart service after update

4. **Error Handling**
   - Handle network failures during download
   - Rollback capability if update fails
   - Ensure Plex service restarts even if update fails
   - Logging of all operations

5. **Safety Features**
   - Check available disk space before downloading
   - Backup current version information
   - Optional: create backup of Plex configuration

### Non-Functional Requirements

1. **Idempotency**: Script can be run multiple times safely (if already latest version, exit gracefully)
2. **Logging**: Detailed logs of all operations to file
3. **Notifications**: File-based logging only (future: email notifications)

## Technical Design

### Architecture Options

**Supported Plex Distributions:**
- Ubuntu/Debian ARMv7 (default)
- Ubuntu/Debian ARMv8
- Ubuntu/Debian x86_64
- Other Linux distributions (configurable)

### Configuration File

Simple configuration file (shell variables or JSON) with:
- Target architecture/distribution (default: armv7)
- Download directory (default: /tmp)
- Backup directory
- Log file location

### Script Flow

```
1. Load configuration
2. Check current Plex version
3. Fetch latest version from Plex downloads page
4. Compare versions
   - If current == latest: log "Already up to date" and exit
   - If update available: proceed
5. Check disk space (for download + backup)
6. Backup Plex configuration directory
7. Download new package
8. Verify checksum (if available)
9. Stop Plex service
10. Install package (dpkg -i)
11. Start Plex service
12. Verify service is running
13. Verify version updated
14. Log success/failure
15. Cleanup downloaded package
```

## Implementation

**Language:** Bash script

**Execution:** Manual (run on-demand)

## Future Enhancements

- Scheduled automatic updates (cron integration)
- Email notifications on update completion
- Automatic rollback on failure detection
- Update channel selection (public, Plex Pass beta, etc.)
- Support for multiple Plex servers
