# Ubuntu Disk Cleanup Scripts

This repository contains scripts to help manage disk space on Ubuntu systems, from regular maintenance to emergency situations when your disk is critically full.

## Contents

- [Regular Cleanup Script](#regular-cleanup-script)
- [Emergency Cleanup Script](#emergency-cleanup-script)
- [Recovery Using Live USB](#recovery-using-live-usb)
- [Understanding Disk Usage in Ubuntu](#understanding-disk-usage-in-ubuntu)
- [Common Disk Space Issues](#common-disk-space-issues)
- [Preventative Measures](#preventative-measures)

## Regular Cleanup Script

The `ubuntu-cleanup.sh` script provides a comprehensive, safe approach to freeing up disk space during normal system operation. It includes:

- APT cache cleaning
- Log rotation and cleanup
- Removal of unused packages
- Old kernel cleanup
- Snap package version management
- Trash emptying
- Docker cleanup (if installed)
- Temporary file cleanup

### Usage

```bash
chmod +x ubuntu-cleanup.sh
sudo ./ubuntu-cleanup.sh
```

This script asks for confirmation before each major step, making it safe for regular use. It preserves essential system files and current kernels.

## Emergency Cleanup Script

The `emergency-disk-cleanup.sh` script is designed for critical situations when your disk is completely full and the system is unresponsive or barely functioning. This script:

- Takes immediate action without confirmations
- Focuses on high-impact cleanups first
- Is more aggressive with log files and caches
- Removes all but the current running kernel
- Cleans temporary files, crash reports, and thumbnails

### Usage

```bash
chmod +x emergency-disk-cleanup.sh
sudo ./emergency-disk-cleanup.sh
```

**⚠️ Warning:** This script is more aggressive and should only be used in emergency situations when regular cleanup methods aren't possible due to severe disk space constraints.

## Recovery Using Live USB

When your system won't boot or is completely unresponsive due to disk space issues, you may need to use a live USB approach:

### 1. Create a Live USB

1. On another computer, download Ubuntu Desktop ISO from [ubuntu.com](https://ubuntu.com/download/desktop)
2. Create a bootable USB using tools like:
   - Rufus (Windows)
   - Etcher (Cross-platform)
   - dd command (Linux/Mac)

### 2. Boot from Live USB

1. Insert the USB into the affected computer
2. Restart the computer and enter BIOS/boot menu (typically by pressing F2, F12, Del, or Esc during startup)
3. Select the USB device as the boot option
4. Select "Try Ubuntu" when the Ubuntu live environment loads

### 3. Mount Your System's Drive

```bash
# Create a mount point
sudo mkdir -p /mnt/system

# List available drives to identify your system drive
sudo fdisk -l

# Mount your main system partition (adjust /dev/sdXY as needed)
sudo mount /dev/sdXY /mnt/system

# If you have a separate /home partition
sudo mount /dev/sdZY /mnt/system/home
```

### 4. Clean Up Disk Space

Now you can free up space by targeting known large locations:

```bash
# Clear APT cache
sudo rm -rf /mnt/system/var/cache/apt/archives/*.deb

# Clear logs
sudo find /mnt/system/var/log -type f -name "*.gz" -delete
sudo find /mnt/system/var/log -type f -name "*.1" -delete
sudo find /mnt/system/var/log -type f -size +50M -exec truncate -s 0 {} \;

# Clear temporary files
sudo rm -rf /mnt/system/tmp/*

# Clear user trash if needed
sudo rm -rf /mnt/system/home/*/.local/share/Trash/*

# Clear snap cache if needed (be careful)
sudo rm -rf /mnt/system/var/lib/snapd/snaps/*.snap
```

### 5. Unmount and Reboot

```bash
sudo umount /mnt/system/home  # If mounted separately
sudo umount /mnt/system
sudo reboot
```

## Understanding Disk Usage in Ubuntu

### LVM and Disk Structure

Ubuntu typically uses Logical Volume Management (LVM), which appears as `/dev/mapper/ubuntu--vg-ubuntu--lv` for the main partition. LVM provides flexibility for managing disk space, but can be confusing when troubleshooting space issues.

### Key Directories That Consume Space

- **/var/log** - System logs, especially after crashes or errors
- **/var/cache/apt** - Package management cache
- **/var/lib/snapd/snaps** - Snap package storage
- **/var/lib/docker** - Docker images and containers
- **/home** - User files and application data
- **/var/lib/systemd/coredump** - System crash dumps
- **/boot** - Kernel and bootloader files

### Analyzing Disk Usage

Tools to analyze disk usage:

```bash
# Simple disk usage by directory
du -h --max-depth=1 /path | sort -rh

# Interactive disk usage analyzer
sudo apt install ncdu
sudo ncdu /

# Graphical disk analyzer
sudo apt install baobab
baobab
```

## Common Disk Space Issues

### Large Log Files

Log files can grow extremely large, especially after system errors:

```bash
# Find and examine large log files
sudo find /var/log -type f -size +50M -exec ls -lh {} \;
```

### Snap Package Bloat

Snap retains old versions, consuming significant space:

```bash
# See snap disk usage
du -h /var/lib/snapd/snaps

# List all snap versions
snap list --all
```

### Docker Storage Growth

Docker images and containers can consume gigabytes:

```bash
# Check Docker disk usage
docker system df
```

### Journal Logs

Systemd's journal can grow quite large:

```bash
# Check journal size
journalctl --disk-usage
```

## Preventative Measures

### Configure Log Rotation

Edit `/etc/logrotate.conf` to configure more aggressive log rotation:

```
# Example configuration
rotate 7          # Keep 7 rotations
compress          # Compress logs
size 50M          # Rotate at 50MB
```

### Set Journal Size Limits

Edit `/etc/systemd/journald.conf`:

```
[Journal]
SystemMaxUse=500M
```

### Monitor Disk Space

Set up automated monitoring:

```bash
# Create a simple disk space check script
cat > /usr/local/bin/check-disk.sh << 'EOF'
#!/bin/bash
THRESHOLD=90
USAGE=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
if [ $USAGE -gt $THRESHOLD ]; then
    echo "Disk usage is at $USAGE%" | mail -s "Disk Space Alert" your@email.com
fi
EOF
chmod +x /usr/local/bin/check-disk.sh

# Add to crontab to run daily
echo "0 8 * * * /usr/local/bin/check-disk.sh" | sudo tee -a /etc/cron.d/disk-check
```

### Schedule Regular Maintenance

Set up a monthly cleanup:

```bash
# Add to crontab (adjust path to your script)
echo "0 2 1 * * /path/to/ubuntu-cleanup.sh" | sudo tee -a /etc/cron.d/monthly-cleanup
```

## License

These scripts are released under the [MIT License](LICENSE).

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.
