#!/bin/bash
# ============================================
# Script  : monitor_backup.sh
# Author  : Adrien Alfred
# GitHub  : https://github.com/adrienalfred
# Purpose : Run rsync backup and monitor
#           return code and logs
# Usage   : sudo ./monitor_backup.sh <source> <destination>
# Compat  : Ubuntu/Debian & CentOS/RHEL
# ============================================

set -euo pipefail

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------- Variables ----------
SOURCE=$1
DESTINATION=$2
DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/backup_monitor.log"
RSYNC_LOG="/var/log/rsync_$(date '+%Y%m%d_%H%M%S').log"

# ---------- Functions ----------

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] This script must be run as root.${NC}"
        exit 1
    fi
}

check_args() {
    if [[ $# -lt 2 ]]; then
        echo -e "${YELLOW}[USAGE] sudo ./monitor_backup.sh <source> <destination>${NC}"
        exit 1
    fi
}

check_source() {
    if [[ ! -d "$SOURCE" ]]; then
        echo -e "${RED}[ERROR] Source directory '$SOURCE' does not exist.${NC}"
        log "FAILED - Source '$SOURCE' not found."
        exit 1
    fi
}

run_backup() {
    echo -e "${GREEN}[INFO] Starting backup...${NC}"
    echo -e "  Source      : $SOURCE"
    echo -e "  Destination : $DESTINATION"
    echo -e "  Log         : $RSYNC_LOG"
    echo ""

    # Run rsync and capture return code
    rsync -avz --progress --log-file="$RSYNC_LOG" "$SOURCE" "$DESTINATION"
    RETURN_CODE=$?

    check_return_code
}

check_return_code() {
    case $RETURN_CODE in
        0)
            echo -e "${GREEN}[SUCCESS] Backup completed successfully.${NC}"
            log "SUCCESS - Backup from '$SOURCE' to '$DESTINATION' completed. RC=0"
            ;;
        23)
            echo -e "${YELLOW}[WARNING] Backup completed with some files not transferred.${NC}"
            log "WARNING - Backup completed with errors. RC=23"
            ;;
        24)
            echo -e "${YELLOW}[WARNING] Some files vanished during transfer.${NC}"
            log "WARNING - Some files vanished. RC=24"
            ;;
        *)
            echo -e "${RED}[ERROR] Backup failed with return code $RETURN_CODE.${NC}"
            log "FAILED - Backup failed. RC=$RETURN_CODE"
            echo -e "${YELLOW}[INFO] Check rsync log : $RSYNC_LOG${NC}"
            exit 1
            ;;
    esac
}

show_summary() {
    echo ""
    echo -e "${YELLOW}[SUMMARY]${NC}"
    echo -e "  Date        : $DATE"
    echo -e "  Source      : $SOURCE"
    echo -e "  Destination : $DESTINATION"
    echo -e "  Return Code : $RETURN_CODE"
    echo -e "  Rsync Log   : $RSYNC_LOG"
    echo -e "  Monitor Log : $LOG_FILE"
}

# ---------- Main ----------
check_root
check_args "$@"
check_source
run_backup
show_summary
