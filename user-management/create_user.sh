#!/bin/bash
# ============================================
# Script  : create_user.sh
# Author  : Adrien Alfred
# GitHub  : https://github.com/adrienalfred
# Purpose : Create system user with secure
#           credentials and proper permissions
# Usage   : sudo ./create_user.sh <username>
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
        echo -e "${YELLOW}[USAGE] sudo ./create_user.sh <username>${NC}"
        exit 1
    fi
}

user_exists() {
    if id "$USERNAME" &>/dev/null; then
        echo -e "${RED}[ERROR] User '$USERNAME' already exists.${NC}"
        log "FAILED - User '$USERNAME' already exists."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        echo -e "${RED}[ERROR] Unsupported OS.${NC}"
        exit 1
    fi
}

create_user() {
    echo -e "${GREEN}[INFO] Creating user '$USERNAME'...${NC}"

    if [[ "$OS" == "debian" ]]; then
        useradd -m -s /bin/bash "$USERNAME"
    elif [[ "$OS" == "rhel" ]]; then
        useradd -m -s /bin/bash "$USERNAME"
    fi

    # Generate secure random password
    PASSWORD=$(openssl rand -base64 12)

    # Set password
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Force password change on first login
    chage -d 0 "$USERNAME"

    log "SUCCESS - User '$USERNAME' created."
    echo -e "${GREEN}[SUCCESS] User '$USERNAME' created.${NC}"
    echo -e "${YELLOW}[CREDENTIALS]${NC}"
    echo -e "  Username : $USERNAME"
    echo -e "  Password : $PASSWORD"
    echo -e "${YELLOW}[NOTE] User must change password on first login.${NC}"
}

# ---------- Main ----------
check_root
check_args "$@"
detect_os
user_exists
create_user
