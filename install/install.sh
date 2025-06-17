#!/bin/bash

# ===============================================
# BORG BACKUP AUTO-INSTALLER
# Dit script configureert automatisch borg backup
# ===============================================

# CONFIGURATIE - EDIT THESE VALUES
STORAGE_BOX_USER="u123456"
STORAGE_BOX_HOST="u123456.your-storagebox.de"
STORAGE_BOX_PORT="23"

# ===============================================
# HIERONDER NIKS AANPASSEN
# ===============================================

set -e  # Stop bij fouten

# Debug/test mode - zet op 'true' voor stap-voor-stap testing
DEBUG_MODE=true

pause_if_debug() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo ""
        echo "⏸️  DEBUG PAUSE - Automatisch doorgaan in 2 seconden..."
        sleep 2
    fi
}

echo "🚀 Borg Backup Auto-Installer gestart..."

# Vraag om wachtwoord
echo "🔑 Voer het Borg wachtwoord in (wordt niet getoond):"
read -s BORG_PASSWORD
echo ""
if [ -z "$BORG_PASSWORD" ]; then
    echo "❌ Geen wachtwoord ingevoerd. Script gestopt."
    exit 1
fi

echo "🔑 Voer het Storage Box SSH wachtwoord in:"
read -s STORAGE_PASS
echo ""
if [ -z "$STORAGE_PASS" ]; then
    echo "❌ Geen SSH wachtwoord ingevoerd. Script gestopt."
    exit 1
fi

# Valideer configuratie
if [[ ! "$STORAGE_BOX_USER" =~ ^u[0-9]+$ ]]; then
    echo "❌ STORAGE_BOX_USER moet format 'u12345' hebben"
    exit 1
fi

# Variabelen
BORG_REPO="ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:${STORAGE_BOX_PORT}/./backup/main_repo"
BACKUP_SCRIPT="/usr/local/bin/borg-backup.sh"
PASSPHRASE_FILE="/etc/borg_passphrase.txt"

pause_if_debug

# 1. Installeer borg als het nog niet geïnstalleerd is
echo "📋 STAP 1: Borg software installatie controleren..."
if ! command -v borg &> /dev/null; then
    echo "📦 Borg installeren..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y borgbackup
    elif command -v yum &> /dev/null; then
        yum install -y epel-release && yum install -y borgbackup
    else
        echo "❌ Kan borg niet automatisch installeren. Installeer handmatig."
        exit 1
    fi
fi

pause_if_debug

# 2. Maak benodigde mappen
echo "📋 STAP 2: Benodigde mappen aanmaken..."
echo "📁 Mappen aanmaken..."
mkdir -p /opt/borg-backup/scripts
mkdir -p /var/log

if [ "$DEBUG_MODE" = "true" ]; then
    echo "✅ STAP 2 VOLTOOID - Doorgaan naar stap 3..."
fi

pause_if_debug

# 3. Maak wachtwoordbestand
echo "📋 STAP 3: Wachtwoord configureren..."
echo "${BORG_PASSWORD}" > ${PASSPHRASE_FILE}
chmod 600 ${PASSPHRASE_FILE}

if [ "$DEBUG_MODE" = "true" ]; then
    echo "✅ STAP 3 VOLTOOID - Doorgaan naar stap 4..."
fi

pause_if_debug

# 4. Test SSH verbinding
echo "📋 STAP 4: SSH verbinding testen..."

echo "🔐 Testing SSH connection with timeout..."
export BORG_RSH="sshpass -p ${STORAGE_PASS} ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_BOX_PORT}"
if sshpass -p "${STORAGE_PASS}" ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_BOX_PORT} -o ConnectTimeout=10 ${STORAGE_BOX_USER}@${STORAGE_BOX_HOST} exit 2>/dev/null; then
    echo "✅ SSH connection successful!"
else
    echo "❌ SSH connection failed:"
    echo "   - Host: ${STORAGE_BOX_HOST}:${STORAGE_BOX_PORT}"
    echo "   - Check network connectivity and credentials"
    exit 1
fi

if [ "$DEBUG_MODE" = "true" ]; then
    echo "✅ STAP 4 VOLTOOID - Doorgaan naar stap 5..."
fi

pause_if_debug

# 5. Initialiseer repository (alleen als deze nog niet bestaat)
echo "📋 STAP 5: Repository controleren/aanmaken..."
export BORG_PASSPHRASE="${BORG_PASSWORD}"

# 5.1 Create remote directory structure if needed
echo "🗂️  Ensuring remote directory structure exists..."
sshpass -p "${STORAGE_PASS}" ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_BOX_PORT} ${STORAGE_BOX_USER}@${STORAGE_BOX_HOST} "mkdir -p backup" 2>/dev/null || true

# 5.2 Initialize repository
if ! borg list ${BORG_REPO} &> /dev/null; then
    echo "📦 Creating new borg repository..."
    borg init --encryption=repokey ${BORG_REPO}
    echo "✅ Repository created successfully"
else
    echo "ℹ️  Repository already exists, skipping creation"
fi

if [ "$DEBUG_MODE" = "true" ]; then
    echo "✅ STAP 5 VOLTOOID - Doorgaan naar stap 6..."
fi

pause_if_debug

# 6. Installeer backup scripts
echo "📋 STAP 6: Backup scripts installeren..."

if [ "$DEBUG_MODE" = "true" ]; then
    COPY_SCRIPTS="y"
    echo "🔧 DEBUG: Scripts automatisch gekopieerd"
else
    echo "❓ Copy backup scripts to system? (y/n):"
    read -r COPY_SCRIPTS
fi

if [[ "$COPY_SCRIPTS" =~ ^[Yy]$ ]]; then
    echo "📄 Copying backup scripts..."
    cp /opt/borg-backup/scripts/backup.sh ${BACKUP_SCRIPT}
    chmod +x ${BACKUP_SCRIPT}
    
    # Update script with current configuration
    sed -i "s/u123456/${STORAGE_BOX_USER}/g" ${BACKUP_SCRIPT}
    
    # Create storage config file
    echo "STORAGE_PASS=${STORAGE_PASS}" > /etc/borg_storage.conf
    chmod 600 /etc/borg_storage.conf
    
    echo "✅ Backup script installed and configured"
else
    echo "ℹ️  Backup scripts not copied - manual setup required"
fi

if [ "$DEBUG_MODE" = "true" ]; then
    echo "✅ STAP 6 VOLTOOID - Doorgaan naar stap 7..."
fi


pause_if_debug

# 7. Test backup
echo "📋 STAP 7: Test backup uitvoeren..."
${BACKUP_SCRIPT}

if [ $? -eq 0 ]; then
    echo "✅ Test backup succesvol!"
    
    # Clean up password from memory
    unset BORG_PASSWORD
    unset BORG_PASSPHRASE
    
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "✅ STAP 7 VOLTOOID - Test backup werkt!"
        exit 0
    fi
    
    pause_if_debug
    
    # 8. Cron job instellen
    echo "📋 STAP 8: Automatische backup instellen (dagelijks om 3:00)..."
    (crontab -l 2>/dev/null | grep -v borg-backup; echo "0 3 * * * ${BACKUP_SCRIPT} >> /var/log/borg_backup.log 2>&1") | crontab -
    
    echo ""
    echo "✅ INSTALLATIE VOLTOOID!"
    echo ""
    echo "📋 BELANGRIJKE INFORMATIE:"
    echo "- Repository: ${BORG_REPO}"
    echo "- Backup script: ${BACKUP_SCRIPT}"
    echo "- Log bestand: /var/log/borg_backup.log"
    echo "- Backup tijd: Dagelijks om 3:00"
    echo ""
    echo "📌 HERSTEL COMMANDO's:"
    echo "- Lijst backups: borg list ${BORG_REPO}"
    echo "- Herstel backup: borg extract ${BORG_REPO}::<backup-naam> --target /tmp/herstel"
    
    pause_if_debug
    
    # Log rotatie instellen
    echo "📋 STAP 9: Log rotatie configureren..."
    cat > /etc/logrotate.d/borgbackup << EOF
/var/log/borg_backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF
else
    echo "❌ Test backup mislukt. Controleer de instellingen."
    exit 1
fi
