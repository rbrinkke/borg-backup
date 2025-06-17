#!/bin/bash

# ===============================================
# BORG BACKUP SCRIPT
# Professional backup solution
# ===============================================

# Borg configuratie
BORG_REPO="ssh://u465138@u465138.your-storagebox.de:23/./backup/main_repo"

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

# Wachtwoord en SSH setup
export BORG_PASSPHRASE=$(cat /etc/borg_passphrase.txt)
export BORG_RSH="sshpass -p W8Rj8MWeLSmPPcKM ssh -4 -o StrictHostKeyChecking=no -p 23"

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