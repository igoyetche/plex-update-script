#!/bin/bash

###############################################################################
# Plex Media Server Auto-Update Script
#
# This script automates the update process for Plex Media Server on
# Raspberry Pi (or other Linux systems)
#
# Usage: sudo ./update-plex.sh
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

###############################################################################
# Logging Functions
###############################################################################

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

###############################################################################
# Utility Functions
###############################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    local deps=("curl" "jq" "dpkg" "systemctl" "tar")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
}

create_directories() {
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
}

check_disk_space() {
    local required_mb=500  # Minimum 500MB free space
    local available=$(df "$DOWNLOAD_DIR" | awk 'NR==2 {print int($4/1024)}')

    if [[ $available -lt $required_mb ]]; then
        log_error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available}MB"
        exit 1
    fi

    log "Disk space check passed (${available}MB available)"
}

###############################################################################
# Plex Version Functions
###############################################################################

get_installed_version() {
    if ! dpkg -l | grep -q plexmediaserver; then
        log_error "Plex Media Server is not installed"
        exit 1
    fi

    local version=$(dpkg -l plexmediaserver | awk '/^ii/ {print $3}')
    echo "$version"
}

get_latest_version() {
    # Fetch the latest version from Plex downloads page
    local url="https://plex.tv/api/downloads/5.json"

    log "Fetching latest version information..."

    local response=$(curl -s "$url")
    if [[ -z "$response" ]]; then
        log_error "Failed to fetch version information from Plex"
        exit 1
    fi

    # Parse JSON based on architecture
    local distro_key="${DISTRO}"
    local arch_key="${ARCH}"

    # Extract the download URL and version
    local download_url=$(echo "$response" | jq -r ".computer.Linux.releases[] | select(.build==\"linux-${arch_key}\" and (.distro==\"${distro_key}\" or .distro==\"ubuntu\")) | .url" | head -1)
    local version=$(echo "$response" | jq -r ".computer.Linux.version")

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log_error "Could not find download URL for ${distro_key}/${arch_key}"
        exit 1
    fi

    echo "$version|$download_url"
}

###############################################################################
# Backup Functions
###############################################################################

backup_plex_config() {
    local backup_name="plex-backup-$(date '+%Y%m%d-%H%M%S').tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log "Creating backup of Plex configuration..."

    if [[ ! -d "$PLEX_DIR" ]]; then
        log_error "Plex directory not found: $PLEX_DIR"
        exit 1
    fi

    tar -czf "$backup_path" -C "$(dirname "$PLEX_DIR")" "$(basename "$PLEX_DIR")" 2>/dev/null || {
        log_error "Failed to create backup"
        exit 1
    }

    log "Backup created: $backup_path"

    # Keep only last 5 backups
    ls -t "${BACKUP_DIR}"/plex-backup-*.tar.gz | tail -n +6 | xargs -r rm
}

###############################################################################
# Update Functions
###############################################################################

download_package() {
    local url="$1"
    local filename=$(basename "$url")
    local output_path="${DOWNLOAD_DIR}/${filename}"

    log "Downloading Plex package from: $url"

    curl -L -o "$output_path" "$url" || {
        log_error "Failed to download package"
        exit 1
    }

    log "Download complete: $output_path"
    echo "$output_path"
}

stop_plex_service() {
    log "Stopping Plex Media Server service..."

    systemctl stop "$SERVICE_NAME" || {
        log_error "Failed to stop Plex service"
        exit 1
    }

    # Wait for service to fully stop
    sleep 3
    log "Plex service stopped"
}

start_plex_service() {
    log "Starting Plex Media Server service..."

    systemctl start "$SERVICE_NAME" || {
        log_error "Failed to start Plex service"
        exit 1
    }

    # Wait for service to fully start
    sleep 5
    log "Plex service started"
}

install_package() {
    local package_path="$1"

    log "Installing Plex package: $package_path"

    dpkg -i "$package_path" || {
        log_error "Failed to install package"
        # Try to restart service even if install failed
        start_plex_service
        exit 1
    }

    log "Package installed successfully"
}

verify_service() {
    log "Verifying Plex service is running..."

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Plex service is running"
        return 0
    else
        log_error "Plex service is not running"
        return 1
    fi
}

cleanup() {
    log "Cleaning up downloaded packages..."
    rm -f "${DOWNLOAD_DIR}"/*.deb
}

###############################################################################
# Main Script
###############################################################################

main() {
    log "========================================"
    log "Plex Media Server Update Script Started"
    log "========================================"

    # Pre-flight checks
    check_root
    check_dependencies
    create_directories
    check_disk_space

    # Get current and latest versions
    local current_version=$(get_installed_version)
    log "Current installed version: $current_version"

    local version_info=$(get_latest_version)
    local latest_version=$(echo "$version_info" | cut -d'|' -f1)
    local download_url=$(echo "$version_info" | cut -d'|' -f2)

    log "Latest available version: $latest_version"

    # Compare versions
    if [[ "$current_version" == "$latest_version" ]]; then
        log "Plex is already up to date. No update needed."
        log "========================================"
        exit 0
    fi

    log "Update available: $current_version -> $latest_version"

    # Perform backup
    backup_plex_config

    # Download new package
    local package_path=$(download_package "$download_url")

    # Stop Plex service
    stop_plex_service

    # Install package
    install_package "$package_path"

    # Start Plex service
    start_plex_service

    # Verify service is running
    if ! verify_service; then
        log_error "Update completed but service verification failed"
        exit 1
    fi

    # Verify version
    local new_version=$(get_installed_version)
    log "New installed version: $new_version"

    if [[ "$new_version" == "$latest_version" ]]; then
        log "SUCCESS: Plex updated successfully from $current_version to $new_version"
    else
        log_error "Version mismatch after update. Expected: $latest_version, Got: $new_version"
    fi

    # Cleanup
    cleanup

    log "========================================"
    log "Plex Media Server Update Script Completed"
    log "========================================"
}

# Run main function
main "$@"
