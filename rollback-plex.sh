#!/bin/bash

###############################################################################
# Plex Media Server Rollback Script
#
# This script restores Plex Media Server configuration from a backup
#
# Usage:
#   sudo ./rollback-plex.sh                  # Rollback to most recent backup
#   sudo ./rollback-plex.sh <backup-file>    # Rollback to specific backup
#   sudo ./rollback-plex.sh --list           # List available backups
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
    local deps=("systemctl" "tar" "dpkg")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
}

###############################################################################
# Backup Management Functions
###############################################################################

list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backup directory found: $BACKUP_DIR"
        exit 0
    fi

    local backups=($(ls -t "${BACKUP_DIR}"/plex-backup-*.tar.gz 2>/dev/null))

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No backups found in $BACKUP_DIR"
        exit 0
    fi

    echo "Available Plex backups:"
    echo "========================================"

    local count=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" 2>/dev/null || stat -f "%Sm" "$backup")

        echo "$count. $filename"
        echo "   Size: $size"
        echo "   Date: $date"
        echo ""
        ((count++))
    done
}

get_latest_backup() {
    local latest=$(ls -t "${BACKUP_DIR}"/plex-backup-*.tar.gz 2>/dev/null | head -1)

    if [[ -z "$latest" ]]; then
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    fi

    echo "$latest"
}

validate_backup() {
    local backup_path="$1"

    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        exit 1
    fi

    # Test if tar file is valid
    if ! tar -tzf "$backup_path" &>/dev/null; then
        log_error "Invalid or corrupted backup file: $backup_path"
        exit 1
    fi

    log "Backup file validated: $backup_path"
}

###############################################################################
# Plex Service Functions
###############################################################################

get_installed_version() {
    if ! dpkg -l | grep -q plexmediaserver; then
        echo "Not installed"
        return
    fi

    local version=$(dpkg -l plexmediaserver | awk '/^ii/ {print $3}')
    echo "$version"
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

###############################################################################
# Rollback Functions
###############################################################################

create_pre_rollback_backup() {
    local backup_name="plex-backup-pre-rollback-$(date '+%Y%m%d-%H%M%S').tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log "Creating safety backup before rollback..."

    if [[ ! -d "$PLEX_DIR" ]]; then
        log "Plex directory not found: $PLEX_DIR (skipping safety backup)"
        return
    fi

    tar -czf "$backup_path" -C "$(dirname "$PLEX_DIR")" "$(basename "$PLEX_DIR")" 2>/dev/null || {
        log_error "Failed to create safety backup"
        exit 1
    }

    log "Safety backup created: $backup_path"
}

restore_backup() {
    local backup_path="$1"

    log "Restoring Plex configuration from: $(basename "$backup_path")"

    # Remove existing Plex directory
    if [[ -d "$PLEX_DIR" ]]; then
        log "Removing current Plex directory..."
        rm -rf "$PLEX_DIR"
    fi

    # Extract backup
    log "Extracting backup..."
    tar -xzf "$backup_path" -C "$(dirname "$PLEX_DIR")" || {
        log_error "Failed to extract backup"
        exit 1
    }

    # Restore ownership (Plex typically runs as 'plex' user)
    if id -u plex &>/dev/null; then
        log "Restoring ownership to plex user..."
        chown -R plex:plex "$PLEX_DIR"
    fi

    log "Backup restored successfully"
}

###############################################################################
# Main Script
###############################################################################

show_usage() {
    echo "Usage:"
    echo "  sudo $0                 # Rollback to most recent backup"
    echo "  sudo $0 <backup-file>   # Rollback to specific backup"
    echo "  sudo $0 --list          # List available backups"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --list"
    echo "  sudo $0 /var/backups/plex/plex-backup-20260109-120000.tar.gz"
}

main() {
    # Handle arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --list|-l)
                list_backups
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                BACKUP_FILE="$1"
                ;;
        esac
    fi

    log "========================================"
    log "Plex Media Server Rollback Script Started"
    log "========================================"

    # Pre-flight checks
    check_root
    check_dependencies

    # Get current version
    local current_version=$(get_installed_version)
    log "Current installed version: $current_version"

    # Determine which backup to use
    if [[ -z "${BACKUP_FILE:-}" ]]; then
        log "No backup file specified, using most recent backup"
        BACKUP_FILE=$(get_latest_backup)
    else
        # If relative path or just filename, look in BACKUP_DIR
        if [[ ! -f "$BACKUP_FILE" && -f "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
            BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
        fi
    fi

    log "Selected backup: $(basename "$BACKUP_FILE")"

    # Validate backup file
    validate_backup "$BACKUP_FILE"

    # Confirm rollback
    echo ""
    echo "WARNING: This will replace your current Plex configuration with the backup."
    echo "Backup file: $(basename "$BACKUP_FILE")"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Rollback cancelled by user"
        exit 0
    fi

    # Create safety backup of current state
    create_pre_rollback_backup

    # Stop Plex service
    stop_plex_service

    # Restore backup
    restore_backup "$BACKUP_FILE"

    # Start Plex service
    start_plex_service

    # Verify service is running
    if ! verify_service; then
        log_error "Rollback completed but service verification failed"
        log_error "You may need to manually start Plex or restore from the safety backup"
        exit 1
    fi

    # Verify version
    local restored_version=$(get_installed_version)
    log "Restored version: $restored_version"

    log "SUCCESS: Plex configuration rolled back successfully"
    log "Previous version: $current_version"
    log "Current version: $restored_version"

    log "========================================"
    log "Plex Media Server Rollback Script Completed"
    log "========================================"
}

# Run main function
main "$@"