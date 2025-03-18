#!/bin/bash
#
# Ubuntu Disk Space Cleanup Script
# This script helps clean up disk space on Ubuntu systems by removing various cached
# and temporary files, old kernels, and other expendable items.
#
# IMPORTANT: Run this script as root (sudo)

set -e  # Exit on error
echo "===== Ubuntu Disk Space Cleanup Script ====="

# Function to ask for confirmation
confirm() {
    read -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Show current disk usage
echo -e "\n===== Current Disk Usage ====="
df -h | grep -v "tmpfs\|loop\|udev"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Clean APT cache
echo -e "\n===== Cleaning APT cache ====="
echo "Cache size before cleanup:"
du -sh /var/cache/apt/archives
apt-get clean
apt-get autoclean
echo "Cache size after cleanup:"
du -sh /var/cache/apt/archives

# Remove unused packages
echo -e "\n===== Removing unused packages ====="
apt-get autoremove -y

# Clean logs safely
echo -e "\n===== Cleaning logs ====="
if confirm "Do you want to clean old log files? (Keeps recent logs)"; then
    # Clean rotated logs
    find /var/log -type f -regex ".*\.gz$" -delete
    find /var/log -type f -regex ".*\.[0-9]$" -delete
    find /var/log -type f -regex ".*\.[0-9]\.gz$" -delete
    
    # Truncate large active logs greater than 50MB
    find /var/log -type f -size +50M | while read log_file; do
        echo "Truncating large log file: $log_file"
        cp /dev/null "$log_file"
    done
    
    # Clean journal logs
    echo "Cleaning systemd journal logs (keeping last 7 days)..."
    journalctl --vacuum-time=7d
fi

# Clean Snap packages
echo -e "\n===== Cleaning Snap packages ====="
if command -v snap > /dev/null; then
    echo "Current snap disk usage:"
    du -sh /var/lib/snapd/snaps
    
    if confirm "Do you want to remove old snap versions?"; then
        # Count of old snap revisions
        SNAP_COUNT=$(snap list --all | grep disabled | wc -l)
        echo "Found $SNAP_COUNT old snap revisions to clean up"
        
        # Clean up old snap versions
        snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
            echo "Removing old snap: $snapname (revision $revision)"
            snap remove "$snapname" --revision="$revision"
        done
        
        echo "Snap disk usage after cleanup:"
        du -sh /var/lib/snapd/snaps
    fi
else
    echo "Snap not installed, skipping..."
fi

# Clean user trash
echo -e "\n===== Cleaning user trash ====="
if confirm "Do you want to empty all user trash folders?"; then
    rm -rf /home/*/.local/share/Trash/*/**
    rm -rf /root/.local/share/Trash/*/**
    echo "Trash folders emptied"
fi

# Clean temporary files
echo -e "\n===== Cleaning temporary files ====="
if confirm "Do you want to clean temporary files?"; then
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    echo "Temporary files cleaned"
fi

# Check for Docker and clean if present
echo -e "\n===== Checking for Docker ====="
if command -v docker > /dev/null; then
    echo "Docker found on system"
    if confirm "Do you want to clean unused Docker data?"; then
        docker system prune -af
        echo "Docker cleaned"
    fi
else
    echo "Docker not installed, skipping..."
fi

# Clean old kernels
echo -e "\n===== Cleaning old kernels ====="
if confirm "Do you want to remove old kernels? (Keeps the current and one previous version)"; then
    # Count the number of installed kernels
    KERNEL_COUNT=$(dpkg --list | grep -E 'linux-image-[0-9]+' | grep -v "$(uname -r)" | wc -l)
    echo "Found $KERNEL_COUNT older kernel packages that can be removed"
    
    if [ "$KERNEL_COUNT" -gt 1 ]; then
        echo "Current kernel: $(uname -r)"
        echo "Removing old kernels (keeping current and one previous version)..."
        
        # This keeps the current kernel and one previous version
        dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | head -n -1 | xargs apt-get -y purge
    else
        echo "Not enough old kernels to safely remove"
    fi
fi

# Remove non-English man pages (optional)
echo -e "\n===== Non-English documentation ====="
if confirm "Do you want to remove non-English man pages to save space?"; then
    rm -rf /usr/share/man/?? 
    rm -rf /usr/share/man/??_*
    echo "Non-English man pages removed"
fi

# Find large files
echo -e "\n===== Finding large files ====="
if confirm "Do you want to search for large files (>100MB)?"; then
    echo "Searching for files larger than 100MB (this may take a while)..."
    find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -rh | head -n 20
    echo "These are the 20 largest files on your system. Review them manually to decide if any can be deleted."
fi

# Summary
echo -e "\n===== Cleanup Complete ====="
echo "Final disk usage:"
df -h | grep -v "tmpfs\|loop\|udev"

echo -e "\nAdditional space-saving tips:"
echo "1. Use 'ncdu' for interactive disk usage analysis: sudo apt install ncdu && sudo ncdu /"
echo "2. Check browser download folders and clear them if needed"
echo "3. Move large files to external storage"
echo "4. Uninstall unused applications: dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 20"

echo -e "\nCleanup completed successfully!"
