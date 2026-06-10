#!/bin/bash
# ============================================
# Script  : reset_password.sh
# Author  : Adrien Alfred
# GitHub  : https://github.com/adrienalfred
# Purpose : Reset user password with secure
#           random credentials and force
#           password change on next login
# Usage   : sudo ./reset_password.sh <username>
# Compat  : Ubuntu/Debian & CentOS/RHEL
# ============================================

set -euo pipefail

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------- Variables ----------
USERNAME=$1
LOG_FILE="/var/log/user_management.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ---------- Functions ----------

log() {
    echo "[$DATE] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] This script must be run as root.${NC}"
        exit 1
    fi
}

check_args() {
    if [[ $# -lt 1 ]]; then
        echo -e "${YELLOW}[USAGE] sudo ./reset_password.sh <username>${NC}"
        exit 1
    fi
}

user_exists() {
    if ! id "$USERNAME" &>/dev/null; then
        echo -e "${RED}[ERROR] User '$USERNAME' does not exist.${NC}"
        log "FAILED - User '$USERNAME' not found."
        exit 1
    fi
}

reset_password() {
    echo -e "${GREEN}[INFO] Resetting password for '$USERNAME'...${NC}"

    # Generate secure random password
    PASSWORD=$(openssl rand -base64 12)

    # Apply new password
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Force password change on next login
    chage -d 0 "$USERNAME"

    log "SUCCESS - Password reset for '$USERNAME'."
    echo -e "${GREEN}[SUCCESS] Password reset for '$USERNAME'.${NC}"
    echo -e "${YELLOW}[CREDENTIALS]${NC}"
    echo -e "  Username : $USERNAME"
    echo -e "  Password : $PASSWORD"
    echo -e "${YELLOW}[NOTE] User must change password on next login.${NC}"
}

# ---------- Main ----------
check_root
check_args "$@"
user_exists
reset_password
