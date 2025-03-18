#!/bin/bash
#
# EMERGENCY Ubuntu Disk Space Cleanup Script
# For use when disk is critically full and system is unresponsive
# CAUTION: This is aggressive and doesn't ask for confirmations
#
# IMPORTANT: Run this script as root (sudo)

echo "===== EMERGENCY Ubuntu Disk Cleanup ====="
echo "Current disk usage:"
df -h | grep -v "tmpfs\|loop\|udev"

# 1. Quick-win cleanups first to get system responsive
echo -e "\n===== PHASE 1: Emergency Space Creation ====="

# Clean all package caches immediately
echo "Cleaning package cache..."
apt-get clean
apt-get autoclean

# Clean journal logs aggressively
echo "Truncating journal logs..."
journalctl --vacuum-size=50M

# Remove all rotated logs
echo "Removing rotated logs..."
find /var/log -type f -regex ".*\.gz$" -delete
find /var/log -type f -regex ".*\.[0-9]$" -delete
find /var/log -type f -regex ".*\.[0-9]\.gz$" -delete

# Truncate active logs
echo "Truncating active logs..."
find /var/log -type f -size +10M | xargs truncate -s 0

# Clean temp files 
echo "Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*

# Emergency trash cleanup
echo "Emptying trash..."
rm -rf /home/*/.local/share/Trash/*/**
rm -rf /root/.local/share/Trash/*/**

# Clear old snap versions
if command -v snap > /dev/null; then
    echo "Cleaning snap packages..."
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        snap remove "$snapname" --revision="$revision"
    done
fi

# Clear thumbnails
echo "Cleaning thumbnails..."
rm -rf /home/*/.cache/thumbnails/*

# Check if we have more space now
echo -e "\nDisk usage after emergency cleanup:"
df -h | grep -v "tmpfs\|loop\|udev"

# 2. Deeper cleaning if still needed
echo -e "\n===== PHASE 2: Deeper Cleaning ====="

# Aggressively clean unused packages 
echo "Removing unused packages..."
apt-get autoremove -y

# Clean old kernels - more aggressive approach
echo "Removing old kernels..."
CURRENT_KERNEL=$(uname -r)
echo "Current kernel: $CURRENT_KERNEL (will be preserved)"
dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r)"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs apt-get -y purge || true

# Clean Docker if present (with no confirmation)
if command -v docker > /dev/null; then
    echo "Cleaning Docker..."
    docker system prune -af || true
fi

# Remove cached packages
echo "Removing package cache..."
apt-get clean

# Remove old crash reports
echo "Cleaning crash reports..."
rm -rf /var/crash/*

# Final disk usage check
echo -e "\nFinal disk usage after emergency cleanup:"
df -h | grep -v "tmpfs\|loop\|udev"

# Look for large files if system is responsive enough
echo -e "\nQuickly identifying very large files (>200MB)..."
find / -xdev -type f -size +200M -exec ls -lh {} \; 2>/dev/null | sort -rh | head -n 10

echo -e "\n===== EMERGENCY CLEANUP COMPLETE ====="
echo "If disk is still critically full, consider checking:"
echo "1. /var/lib/snapd/snaps directory"
echo "2. /var/lib/docker if using Docker"
echo "3. User home directories for large files"
echo "4. /var/lib/mysql or other database storage"
echo "5. /var/cache directories"
echo "6. /var/log for any remaining large logs"
echo "7. Core dumps: /var/lib/systemd/coredump/"
