#!/bin/bash
# ============================================
# Script  : vmware_disk_extend.sh
# Author  : Adrien Alfred
# GitHub  : https://github.com/adrienalfred
# Purpose : Add and configure a new disk on
#           a VMware VM — SCSI rescan, LVM
#           setup and ext4 filesystem
# Usage   : sudo ./vmware_disk_extend.sh
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
LOG_FILE="/var/log/vmware_disk_extend.log"

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

check_dependencies() {
    print_section "CHECKING DEPENDENCIES"
    for cmd in fdisk pvcreate vgcreate lvcreate mkfs.ext4 lsblk; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${RED}[ERROR] '$cmd' not found. Install lvm2 and e2fsprogs.${NC}"
            exit 1
        fi
        echo -e "${GREEN}[OK] $cmd found.${NC}"
    done
}

scsi_rescan() {
    print_section "SCSI BUS RESCAN"
    echo -e "${GREEN}[INFO] Rescanning SCSI hosts...${NC}"

    for host in /sys/class/scsi_host/host*/scan; do
        echo "- - -" > "$host"
        echo -e "${GREEN}[OK] Rescanned : $host${NC}"
    done

    sleep 2
    log "SUCCESS - SCSI rescan completed."
    echo -e "${GREEN}[SUCCESS] SCSI rescan done.${NC}"
}

detect_new_disk() {
    print_section "DISK DETECTION"
    echo -e "${YELLOW}[INFO] Available disks :${NC}"
    echo ""
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
    echo ""
    read -rp "Enter the new disk name (e.g. sdb, sdc) : " DISK
    DISK_PATH="/dev/$DISK"

    if [[ ! -b "$DISK_PATH" ]]; then
        echo -e "${RED}[ERROR] Disk '$DISK_PATH' not found.${NC}"
        log "FAILED - Disk '$DISK_PATH' not found."
        exit 1
    fi

    echo -e "${GREEN}[OK] Disk '$DISK_PATH' detected.${NC}"
    log "INFO - Disk selected : $DISK_PATH"
}

create_partition() {
    print_section "PARTITION CREATION"
    echo -e "${GREEN}[INFO] Creating LVM partition on $DISK_PATH...${NC}"

    fdisk "$DISK_PATH" << FDISK_CMDS
n
p
1


t
8e
w
FDISK_CMDS

    PARTITION="${DISK_PATH}1"
    sleep 1
    partprobe "$DISK_PATH"

    echo -e "${GREEN}[SUCCESS] Partition $PARTITION created.${NC}"
    log "SUCCESS - Partition $PARTITION created."
}

setup_lvm() {
    print_section "LVM SETUP"

    # PV
    echo -e "${GREEN}[INFO] Creating Physical Volume...${NC}"
    pvcreate "$PARTITION"
    echo -e "${GREEN}[OK] PV created : $PARTITION${NC}"

    # VG
    read -rp "Enter Volume Group name (e.g. vg_data) : " VG_NAME
    vgcreate "$VG_NAME" "$PARTITION"
    echo -e "${GREEN}[OK] VG created : $VG_NAME${NC}"

    # LV
    read -rp "Enter Logical Volume name (e.g. lv_data) : " LV_NAME
    read -rp "Enter size (e.g. 10G, 50G or 100%FREE) : " LV_SIZE

    if [[ "$LV_SIZE" == "100%FREE" ]]; then
        lvcreate -l 100%FREE -n "$LV_NAME" "$VG_NAME"
    else
        lvcreate -L "$LV_SIZE" -n "$LV_NAME" "$VG_NAME"
    fi

    LV_PATH="/dev/$VG_NAME/$LV_NAME"
    echo -e "${GREEN}[OK] LV created : $LV_PATH${NC}"
    log "SUCCESS - LVM setup : PV=$PARTITION VG=$VG_NAME LV=$LV_PATH"
}

format_and_mount() {
    print_section "FORMAT & MOUNT"

    # Format ext4
    echo -e "${GREEN}[INFO] Formatting $LV_PATH as ext4...${NC}"
    mkfs.ext4 "$LV_PATH"
    echo -e "${GREEN}[OK] Filesystem created.${NC}"

    # Mount point
    read -rp "Enter mount point (e.g. /data, /mnt/storage) : " MOUNT_POINT
    mkdir -p "$MOUNT_POINT"
    mount "$LV_PATH" "$MOUNT_POINT"
    echo -e "${GREEN}[OK] Mounted at $MOUNT_POINT${NC}"

    # Persist in fstab
    UUID=$(blkid -s UUID -o value "$LV_PATH")
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
    echo -e "${GREEN}[OK] Added to /etc/fstab for persistence.${NC}"

    log "SUCCESS - $LV_PATH formatted and mounted at $MOUNT_POINT. UUID=$UUID"
}

show_summary() {
    print_section "SUMMARY"
    echo -e "  Date        : $DATE"
    echo -e "  Disk        : $DISK_PATH"
    echo -e "  Partition   : $PARTITION"
    echo -e "  VG          : $VG_NAME"
    echo -e "  LV          : $LV_PATH"
    echo -e "  Mount point : $MOUNT_POINT"
    echo -e "  Filesystem  : ext4"
    echo -e "  fstab       : ${GREEN}Updated${NC}"
    echo -e "  Log         : $LOG_FILE"
    echo ""
    echo -e "${GREEN}[DONE] Disk successfully configured. 🎉${NC}"
}

# ---------- Main ----------
check_root
check_dependencies
scsi_rescan
detect_new_disk
create_partition
setup_lvm
format_and_mount
show_summary
