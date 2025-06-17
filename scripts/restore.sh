#!/bin/bash

# ===============================================
# BORG RESTORE WIZARD
# Professional disaster recovery tool
# ===============================================

set -e

# Configuration - EDIT THESE VALUES
STORAGE_USER="u123456"
STORAGE_HOST="u123456.your-storagebox.de"
STORAGE_PORT="23"
STORAGE_PASS=$(grep STORAGE_PASS /etc/borg_storage.conf | cut -d'=' -f2 2>/dev/null || echo "PASSWORD_NOT_SET")
BORG_REPO="ssh://${STORAGE_USER}@${STORAGE_HOST}:${STORAGE_PORT}/./backup/main_repo"
RESTORE_TARGET="/tmp/restore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "🗄️  BORG RESTORE WIZARD"
    echo "Professional disaster recovery"
    echo -e "${NC}"
}

print_usage() {
    echo "Usage:"
    echo "  $0                           # Interactive wizard"
    echo "  $0 <hostname>                # List backups for hostname"
    echo "  $0 <hostname> last           # Restore latest backup"
    echo "  $0 <hostname> <archive>      # Restore specific archive"
    echo ""
    echo "Examples:"
    echo "  $0 ubuntu-server-01 last"
    echo "  $0 web-server-prod"
    echo "  $0 db-server-01 2025-06-17-1503"
}

setup_borg() {
    echo "🔧 Setting up borg environment..."
    
    # Install borg if not present
    if ! command -v borg &> /dev/null; then
        echo "📦 Installing borgbackup..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y borgbackup sshpass
        elif command -v yum &> /dev/null; then
            yum install -y epel-release && yum install -y borgbackup sshpass
        else
            echo -e "${RED}❌ Cannot install borg automatically${NC}"
            exit 1
        fi
    fi
    
    # Setup environment
    export BORG_RSH="sshpass -p ${STORAGE_PASS} ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_PORT}"
    export BORG_PASSPHRASE="${STORAGE_PASS}"
    
    # Test connection
    echo "🔐 Testing connection..."
    if ! sshpass -p "${STORAGE_PASS}" ssh -4 -o StrictHostKeyChecking=no -p ${STORAGE_PORT} -o ConnectTimeout=10 ${STORAGE_USER}@${STORAGE_HOST} exit 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to storage${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Connection OK${NC}"
}

list_machines() {
    echo "📋 Available machines:"
    borg list --short ${BORG_REPO} | cut -d'-' -f1-3 | sort -u | nl -w2 -s'. '
}

list_archives() {
    local hostname=$1
    echo "📅 Backups for ${hostname}:"
    borg list --short ${BORG_REPO} | grep "^${hostname}-" | sort -r | nl -w2 -s'. '
}

get_latest_archive() {
    local hostname=$1
    borg list --short ${BORG_REPO} | grep "^${hostname}-" | sort -r | head -n1
}

interactive_wizard() {
    echo -e "${YELLOW}🧙 Interactive Restore Wizard${NC}"
    echo ""
    
    # List and select machine
    list_machines
    echo ""
    read -p "Select machine number: " machine_num
    
    local hostname=$(borg list --short ${BORG_REPO} | cut -d'-' -f1-3 | sort -u | sed -n "${machine_num}p")
    if [ -z "$hostname" ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Selected: ${hostname}${NC}"
    echo ""
    
    # List and select backup
    list_archives "$hostname"
    echo ""
    read -p "Select backup number (or press ENTER for latest): " backup_num
    
    local archive
    if [ -z "$backup_num" ]; then
        archive=$(get_latest_archive "$hostname")
        echo -e "${GREEN}Using latest: ${archive}${NC}"
    else
        archive=$(borg list --short ${BORG_REPO} | grep "^${hostname}-" | sort -r | sed -n "${backup_num}p")
        if [ -z "$archive" ]; then
            echo -e "${RED}❌ Invalid backup selection${NC}"
            exit 1
        fi
    fi
    
    restore_archive "$archive"
}

restore_archive() {
    local archive=$1
    
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will restore system files!${NC}"
    echo -e "${YELLOW}⚠️  SSH config, firewall, and network settings will be preserved${NC}"
    echo ""
    echo "Archive: $archive"
    echo "Target:  $RESTORE_TARGET"
    echo ""
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    echo ""
    echo "🔄 Starting restore..."
    
    # Create restore directory
    mkdir -p "$RESTORE_TARGET"
    
    # Restore archive
    echo "📦 Extracting archive..."
    borg extract --progress ${BORG_REPO}::${archive} --target "$RESTORE_TARGET"
    
    echo ""
    echo -e "${GREEN}✅ Archive extracted to: $RESTORE_TARGET${NC}"
    echo ""
    echo "🛡️  Protected files (not restored):"
    echo "   - SSH configuration (/etc/ssh/)"
    echo "   - Firewall rules (/etc/ufw/, /etc/iptables/)"
    echo "   - Network config (/etc/netplan/, /etc/network/)"
    echo "   - Hostname and hosts file"
    echo ""
    echo "📁 Review files in: $RESTORE_TARGET"
    echo "📋 Copy needed files manually to preserve current system settings"
}

# Main logic
main() {
    print_banner
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Please run as root${NC}"
        exit 1
    fi
    
    # Setup environment
    setup_borg
    
    case $# in
        0)
            # Interactive wizard
            interactive_wizard
            ;;
        1)
            # List backups for hostname
            local hostname=$1
            if [ "$hostname" = "-h" ] || [ "$hostname" = "--help" ]; then
                print_usage
                exit 0
            fi
            echo "📅 Backups for ${hostname}:"
            list_archives "$hostname"
            ;;
        2)
            # Restore specific backup
            local hostname=$1
            local archive_spec=$2
            
            if [ "$archive_spec" = "last" ]; then
                local archive=$(get_latest_archive "$hostname")
                if [ -z "$archive" ]; then
                    echo -e "${RED}❌ No backups found for ${hostname}${NC}"
                    exit 1
                fi
                echo -e "${GREEN}Found latest backup: ${archive}${NC}"
                restore_archive "$archive"
            else
                # Specific archive name
                local archive="${hostname}-${archive_spec}"
                # Verify archive exists
                if ! borg list --short ${BORG_REPO} | grep -q "^${archive}$"; then
                    echo -e "${RED}❌ Archive not found: ${archive}${NC}"
                    exit 1
                fi
                restore_archive "$archive"
            fi
            ;;
        *)
            echo -e "${RED}❌ Invalid arguments${NC}"
            print_usage
            exit 1
            ;;
    esac
}

main "$@"