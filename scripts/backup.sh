#!/bin/bash

# ===============================================
# BORG BACKUP SCRIPT
# Professional backup solution
# ===============================================

# Borg configuratie - EDIT THESE VALUES
STORAGE_USER="u123456"
STORAGE_HOST="u123456.your-storagebox.de"
STORAGE_PORT="23"
BORG_REPO="ssh://${STORAGE_USER}@${STORAGE_HOST}:${STORAGE_PORT}/./backup/main_repo"

# Wat wordt gebackupt - VOLLEDIGE MACHINE HERSTEL
PATHS_TO_BACKUP="/home /etc /root /var /opt /usr/local"

# Wat NIET - runtime/temporary + target machine protection
EXCLUDE_PATTERNS=(
    --exclude '/var/cache/*'
    --exclude '/var/tmp/*'
    --exclude '/var/run/*'
    --exclude '/var/lock/*'
    --exclude '/tmp/*'
    --exclude '/proc/*'
    --exclude '/sys/*'
    --exclude '/dev/*'
    --exclude '/etc/ssh/*'
    --exclude '/etc/ufw/*'
    --exclude '/etc/iptables/*'
    --exclude '/etc/netplan/*'
    --exclude '/etc/network/*'
    --exclude '/etc/hostname'
    --exclude '/etc/hosts'
)

# Bewaarbeleid: 1 maand
PRUNE_OPTIONS="--keep-daily 30"

# Wachtwoord en SSH setup - EDIT PASSWORD IN /etc/borg_storage.conf
STORAGE_PASS=$(grep STORAGE_PASS /etc/borg_storage.conf | cut -d'=' -f2)
export BORG_PASSPHRASE=$(cat /etc/borg_passphrase.txt)
export BORG_RSH="sshpass -p ${STORAGE_PASS} ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_PORT}"

echo "--- Backup Start: $(hostname) - $(date) ---"

# Backup maken - simpel en werkend
borg create --stats \
    --exclude '/var/cache' \
    --exclude '/var/tmp' \
    --exclude '/tmp' \
    ${BORG_REPO}::{hostname}-{now:%Y-%m-%d-%H%M} \
    ${PATHS_TO_BACKUP}

if [ $? -eq 0 ]; then
    echo "✅ Backup succesvol"
    
    # Oude backups opruimen
    borg prune --stats ${BORG_REPO} ${PRUNE_OPTIONS} --prefix {hostname}-
else
    echo "❌ Backup mislukt!"
    exit 1
fi

echo "--- Backup Klaar ---"