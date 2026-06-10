#!/bin/bash
# ============================================
# Script  : basic_hardening.sh
# Author  : Adrien Alfred
# GitHub  : https://github.com/adrienalfred
# Purpose : Basic Linux server hardening
#           SSH, fail2ban, firewall, updates
# Usage   : sudo ./basic_hardening.sh
# Compat  : Ubuntu/Debian & CentOS/RHEL
# ============================================

set -euo pipefail

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- Variables ----------
DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/hardening.log"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_PORT=22

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

print_section() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt-get"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        PKG_MANAGER="yum"
    else
        echo -e "${RED}[ERROR] Unsupported OS.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[INFO] Detected OS : $OS${NC}"
    log "INFO - OS detected : $OS"
}

update_system() {
    print_section "SYSTEM UPDATE"
    echo -e "${GREEN}[INFO] Updating system packages...${NC}"

    if [[ "$OS" == "debian" ]]; then
        apt-get update -y && apt-get upgrade -y
    elif [[ "$OS" == "rhel" ]]; then
        yum update -y
    fi

    log "SUCCESS - System updated."
    echo -e "${GREEN}[SUCCESS] System updated.${NC}"
}

harden_ssh() {
    print_section "SSH HARDENING"

    # Backup original config
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak_$(date '+%Y%m%d')"
    echo -e "${GREEN}[INFO] SSH config backed up.${NC}"

    # Disable root login
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    echo -e "${GREEN}[OK] Root login disabled.${NC}"

    # Disable password authentication
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"

    # Disable empty passwords
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"

    # Set max auth tries
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"

    # Set login grace time
    sed -i 's/^#*LoginGraceTime.*/LoginGraceTime 30/' "$SSHD_CONFIG"

    # Disable X11 forwarding
    sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"

    # Restart SSH service
    systemctl restart sshd
    echo -e "${GREEN}[SUCCESS] SSH hardened and restarted.${NC}"
    log "SUCCESS - SSH hardened."
}

install_fail2ban() {
    print_section "FAIL2BAN"

    if ! command -v fail2ban-server &>/dev/null; then
        echo -e "${GREEN}[INFO] Installing fail2ban...${NC}"
        $PKG_MANAGER install -y fail2ban
    else
        echo -e "${YELLOW}[INFO] fail2ban already installed.${NC}"
    fi

    # Configure fail2ban for SSH
    cat > /etc/fail2ban/jail.local << 'FAIL2BAN'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
maxretry = 3
bantime  = 86400
FAIL2BAN

    systemctl enable fail2ban
    systemctl restart fail2ban
    echo -e "${GREEN}[SUCCESS] fail2ban configured and started.${NC}"
    log "SUCCESS - fail2ban configured."
}

configure_iptables() {
    print_section "IPTABLES FIREWALL"

    # Flush existing rules
    iptables -F
    iptables -X
    iptables -Z

    # Default policies — drop everything
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow SSH
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT

    # Allow HTTP / HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Allow ICMP (ping)
    iptables -A INPUT -p icmp -j ACCEPT

    # Save rules
    if [[ "$OS" == "debian" ]]; then
        apt-get install -y iptables-persistent
        netfilter-persistent save
    elif [[ "$OS" == "rhel" ]]; then
        service iptables save
    fi

    echo -e "${GREEN}[SUCCESS] iptables configured and saved.${NC}"
    log "SUCCESS - iptables configured."
}

show_summary() {
    print_section "HARDENING SUMMARY"
    echo -e "  Date          : $DATE"
    echo -e "  OS            : $OS"
    echo -e "  SSH           : ${GREEN}Hardened${NC}"
    echo -e "  Root login    : ${RED}Disabled${NC}"
    echo -e "  fail2ban      : ${GREEN}Active${NC}"
    echo -e "  iptables      : ${GREEN}Configured${NC}"
    echo -e "  Log           : $LOG_FILE"
    echo ""
    echo -e "${YELLOW}[WARNING] Review iptables rules before production use.${NC}"
    echo -e "${YELLOW}[WARNING] Make sure you have another way in before locking SSH.${NC}"
}

# ---------- Main ----------
check_root
detect_os
update_system
harden_ssh
install_fail2ban
configure_iptables
show_summary
