# PiSignage Migration Guide

Guide for upgrading from previous versions to v0.11.0.

## Table of Contents

- [Overview](#overview)
- [What's New in v0.11.0](#whats-new-in-v0110)
- [Breaking Changes](#breaking-changes)
- [Migration Paths](#migration-paths)
- [Post-Migration Steps](#post-migration-steps)
- [Rollback Procedure](#rollback-procedure)

---

## Overview

PiSignage v0.11.0 introduces significant improvements while maintaining backward compatibility with existing API clients and configurations.

### Key Changes

- **Display Mode Switcher** - Toggle between VLC and Chromium kiosk
- **BUG-013 Fix** - Single file playback now 100% reliable
- **Legacy Code Cleanup** - Removed unused files (index-pi.php, youtube-simple.php)
- **HDMI Audio Default** - System-wide configuration
- **Enhanced Documentation** - API, Architecture, and Migration guides

---

## What's New in v0.11.0

### 1. Display Mode Switcher

**Feature**: Toggle between VLC (stable) and Chromium kiosk (HTML5) modes via web UI or API.

**New Files:**
- `/opt/pisignage/config/display-mode.json` - Mode configuration
- `/opt/pisignage/scripts/switch-display-mode.sh` - Switching script
- `/opt/pisignage/web/api/display-mode.php` - API endpoint
- `/opt/pisignage/web/display-mode.php` - UI page
- `/etc/sudoers.d/pisignage-display-mode` - Permissions

**New Services:**
- `greetd.service` - Chromium kiosk session manager
- `pisignage-vlc.service` - VLC player (if not already present)

### 2. BUG-013 Fix - Single File Playback

**Problem**: Files wouldn't start playing consistently when using `playFile()` API.

**Solution**: 4-step reliable playback process in `player-control.php`:
1. Clear existing playlist
2. Enqueue file
3. Explicit play command
4. Verify playback with retry

**Impact**: API calls to `play_file` action now work 100% reliably.

### 3. Legacy Code Cleanup

**Removed Files:**
- `/opt/pisignage/web/index-pi.php` (2,620 lines, unused legacy SPA)
- `/opt/pisignage/web/api/youtube-simple.php` (symlink duplicate)

**Impact**: Cleaner codebase, no functional changes.

### 4. HDMI Audio Default

**New File**: `/etc/asound.conf` - Forces HDMI audio output system-wide

**Impact**: Audio always outputs to HDMI by default.

---

## Breaking Changes

### ⚠️ None

v0.11.0 maintains 100% backward compatibility with:
- All API endpoints
- Existing playlists
- Configuration files
- Media files
- Systemd services (VLC mode)

**Exception**: If you were using `index-pi.php` or `youtube-simple.php` directly (unlikely), these files no longer exist.

---

## Migration Paths

### Path A: Fresh Installation (Recommended for new systems)

**Requirements:**
- Raspberry Pi OS Trixie (Debian 13) Desktop edition
- Raspberry Pi 4 or 5
- Fresh SD card or clean system

**Steps:**
```bash
# 1. Clone repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# 2. Run installer
chmod +x install.sh
./install.sh --auto

# 3. Verify installation
systemctl status pisignage-vlc
curl http://localhost/api/system.php?action=stats

# 4. Access web interface
# Navigate to http://<raspberry-pi-ip>/dashboard.php
```

**Duration**: ~20 minutes (depends on internet speed for package downloads)

### Path B: In-Place Upgrade from v0.8.x/v0.9.x/v0.10.x

**⚠️ Backup First:**
```bash
# Backup configuration
sudo cp -r /opt/pisignage/config /opt/pisignage/config.backup

# Backup playlists
sudo cp -r /opt/pisignage/playlists /opt/pisignage/playlists.backup

# Backup media (optional, can be large)
# sudo cp -r /opt/pisignage/media /opt/pisignage/media.backup
```

**Upgrade Steps:**
```bash
# 1. Navigate to installation directory
cd /path/to/Pi-Signage

# 2. Pull latest changes
git fetch origin
git pull origin main

# 3. Stop services
sudo systemctl stop pisignage-vlc

# 4. Run upgrade script (or re-run installer)
./install.sh --auto

# 5. Restart services
sudo systemctl start pisignage-vlc
sudo systemctl status pisignage-vlc

# 6. Verify web interface
curl http://localhost/dashboard.php
```

**Duration**: ~10 minutes

**Verify Upgrade:**
```bash
# Check version in web UI
# Dashboard should show: PiSignage v0.11.0

# Verify new Display Mode page exists
curl http://localhost/display-mode.php

# Test BUG-013 fix
curl -X POST -H "Content-Type: application/json" \
  -d '{"file":"Big_Buck_Bunny.mp4"}' \
  http://localhost/api/player-control.php?action=play_file
```

### Path C: Migration from Raspberry Pi OS Bullseye to Trixie

**⚠️ Major OS Upgrade Required**

If you're running older Raspberry Pi OS (Bullseye or earlier), Chromium kiosk mode requires Trixie (Debian 13).

**Options:**

**Option 1: Keep VLC Only (No OS Upgrade)**
- Continue using v0.11.0 in VLC-only mode
- Chromium kiosk features unavailable
- No OS upgrade needed

**Option 2: Fresh Trixie Installation**
1. Backup all media and configurations
2. Flash new SD card with Raspberry Pi OS Trixie Desktop
3. Follow Path A (Fresh Installation)
4. Restore media and configurations

**Option 3: In-Place OS Upgrade (Advanced, not recommended)**
```bash
# Update sources.list
sudo sed -i 's/bullseye/trixie/g' /etc/apt/sources.list
sudo sed -i 's/bullseye/trixie/g' /etc/apt/sources.list.d/*.list

# Full system upgrade
sudo apt update
sudo apt full-upgrade -y
sudo reboot

# After reboot, reinstall PiSignage
cd Pi-Signage
./install.sh --auto
```

**Duration**: 1-2 hours (depends on upgrade path)

---

## Post-Migration Steps

### 1. Verify VLC Player

```bash
# Check VLC service
sudo systemctl status pisignage-vlc

# Test VLC HTTP API
curl http://localhost:8080/requests/status.json \
  --user ":pisignage"

# Test single file playback (BUG-013 fix)
curl -X POST -H "Content-Type: application/json" \
  -d '{"file":"Big_Buck_Bunny.mp4"}' \
  http://localhost/api/player-control.php?action=play_file
```

### 2. Configure Display Mode

```bash
# Check current mode
curl http://localhost/api/display-mode.php?action=status

# Default should be VLC
# Output: {"success":true,"current_mode":"vlc",...}
```

**To Enable Chromium Kiosk (Optional):**

1. Access web interface: http://<pi-ip>/display-mode.php
2. Click "Switch to Chromium Kiosk" button
3. Wait 10-15 seconds for mode switch
4. Verify Chromium is running: `ps aux | grep chromium`

**Or via API:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"mode":"chromium"}' \
  http://localhost/api/display-mode.php?action=switch
```

### 3. Verify HDMI Audio

```bash
# Check audio configuration
cat /etc/asound.conf

# Should output:
# pcm.!default {
#     type hw
#     card 0
#     device 0
# }
```

**Test Audio:**
```bash
# Play test sound
speaker-test -t wav -c 2 -l 1

# Verify VLC volume control
curl -X POST -H "Content-Type: application/json" \
  -d '{"volume":200}' \
  http://localhost/api/player-control.php?action=volume
```

### 4. Restore Backups (if applicable)

```bash
# Restore playlists
sudo cp -r /opt/pisignage/playlists.backup/* /opt/pisignage/playlists/

# Restore specific configs
sudo cp /opt/pisignage/config.backup/specific-file.json /opt/pisignage/config/

# Set permissions
sudo chown -R www-data:www-data /opt/pisignage/playlists
sudo chown -R www-data:www-data /opt/pisignage/config
```

### 5. Test All Features

**Checklist:**
- [ ] Login to web interface
- [ ] Upload a test video file
- [ ] Create a playlist
- [ ] Deploy playlist to VLC
- [ ] Verify video playback
- [ ] Test single file playback (BUG-013 fix)
- [ ] Check Display Mode page
- [ ] Switch to Chromium mode (optional)
- [ ] Switch back to VLC mode
- [ ] Verify HDMI audio output
- [ ] Check system stats on dashboard

---

## Rollback Procedure

If you encounter issues and need to rollback:

### Option 1: Rollback Code Only

```bash
# Navigate to installation directory
cd /path/to/Pi-Signage

# Checkout previous version (replace v0.10.0 with your version)
git checkout v0.10.0

# Stop services
sudo systemctl stop pisignage-vlc
sudo systemctl stop greetd

# Restore backups
sudo cp -r /opt/pisignage/config.backup /opt/pisignage/config
sudo cp -r /opt/pisignage/playlists.backup /opt/pisignage/playlists

# Restart VLC service
sudo systemctl start pisignage-vlc
```

### Option 2: Full System Restore

If you made a complete backup before migration:

```bash
# Restore from backup image
sudo dd if=/path/to/backup.img of=/dev/mmcblk0 bs=4M status=progress
```

### Option 3: Fresh Installation of Previous Version

```bash
# Clone specific version
git clone --branch v0.10.0 https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
./install.sh --auto
```

---

## Troubleshooting

### Issue 1: Display Mode Switch Fails

**Symptoms:**
- "Switch failed" error in UI
- Services not starting after switch

**Solutions:**
```bash
# Check sudo permissions
sudo -l -U www-data

# Should include:
# /opt/pisignage/scripts/switch-display-mode.sh

# Manually restart services
sudo systemctl restart pisignage-vlc
# OR
sudo systemctl restart greetd

# Check service status
sudo systemctl status pisignage-vlc
sudo systemctl status greetd

# Check logs
journalctl -u pisignage-vlc -n 50
journalctl -u greetd -n 50
```

### Issue 2: BUG-013 Fix Not Working

**Symptoms:**
- Single file playback still unreliable
- Files don't start playing

**Solutions:**
```bash
# Verify VLC HTTP API is responding
curl http://localhost:8080/requests/status.json --user ":pisignage"

# Check VLC service
sudo systemctl status pisignage-vlc

# Restart VLC
sudo systemctl restart pisignage-vlc

# Test with curl (verbose)
curl -v -X POST -H "Content-Type: application/json" \
  -d '{"file":"Big_Buck_Bunny.mp4"}' \
  http://localhost/api/player-control.php?action=play_file

# Check PHP error logs
sudo tail -f /var/log/apache2/error.log
```

### Issue 3: Chromium Kiosk Not Starting

**Symptoms:**
- Black screen after switching to Chromium mode
- greetd service failed

**Solutions:**
```bash
# Check greetd service
sudo systemctl status greetd
journalctl -u greetd -n 100

# Verify labwc is installed
which labwc

# Check autostart script
cat /home/pi/.config/labwc/autostart

# Manually test labwc
sudo -u pi WAYLAND_DISPLAY=wayland-0 labwc

# Check seatd (required for Wayland)
sudo systemctl status seatd
sudo systemctl start seatd

# Verify pi user in video group
groups pi | grep video
```

### Issue 4: HDMI Audio Not Working

**Symptoms:**
- No audio output
- Audio coming from wrong output

**Solutions:**
```bash
# Check ALSA config
cat /etc/asound.conf

# List audio devices
aplay -l

# Force HDMI audio
sudo amixer cset numid=3 2

# Test audio output
speaker-test -t wav -c 2 -l 1

# Check VLC audio output
curl http://localhost:8080/requests/status.json --user ":pisignage" | jq '.audiodelay'
```

### Issue 5: Media Files Missing After Migration

**Symptoms:**
- Media library empty
- Uploaded files not visible

**Solutions:**
```bash
# Check media directory
ls -la /opt/pisignage/media/

# Verify permissions
sudo chown -R www-data:www-data /opt/pisignage/media
sudo chmod -R 755 /opt/pisignage/media

# Restore from backup
sudo cp -r /opt/pisignage/media.backup/* /opt/pisignage/media/

# Check disk space
df -h /opt/pisignage
```

---

## Data Migration

### Playlists

Playlist files are JSON and fully compatible across versions.

**Location**: `/opt/pisignage/playlists/*.json`

**Format**:
```json
{
  "name": "Morning Playlist",
  "items": [
    {"file": "video1.mp4", "duration": 120},
    {"file": "video2.mp4", "duration": 90}
  ],
  "created_at": "2025-01-09 10:00:00"
}
```

**Migration**: No changes required, copy files as-is.

### Media Files

Media files are stored directly in filesystem.

**Location**: `/opt/pisignage/media/`

**Migration**: Copy files directly, no conversion needed.

```bash
# Copy media from old system
rsync -avz /old/system/opt/pisignage/media/ /opt/pisignage/media/
```

### Configuration Files

**v0.11.0 New Configs:**
- `display-mode.json` - Display mode settings (created automatically)

**Existing Configs (compatible):**
- Playlist configs
- Schedule configs
- System settings

---

## Performance Impact

### VLC Mode (No Change)

- CPU usage: Same as previous versions
- Memory usage: Same as previous versions
- Startup time: Same as previous versions

### Chromium Kiosk Mode (New Feature)

- CPU usage: +10-15% vs VLC mode
- Memory usage: +150MB vs VLC mode
- Startup time: +5-10 seconds vs VLC mode

**Recommendation**: Use VLC mode (default) for production displays. Use Chromium mode for web content or testing.

---

## Security Considerations

### New Security Features

1. **Display Mode Switching**: Requires sudo permissions via specific script only
2. **Input Validation**: Enhanced in BUG-013 fix (file path validation)

### Security Best Practices

```bash
# Change default VLC password
# Edit: /etc/systemd/system/pisignage-vlc.service
# Change: --http-password pisignage
sudo systemctl daemon-reload
sudo systemctl restart pisignage-vlc

# Firewall rules (optional)
sudo ufw allow 80/tcp     # Web interface
sudo ufw allow 22/tcp     # SSH
sudo ufw enable
```

---

## Support and Resources

### Documentation

- **API Documentation**: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- **Architecture Guide**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **README**: [README.md](README.md)

### Getting Help

- **GitHub Issues**: https://github.com/elkir0/Pi-Signage/issues
- **Repository**: https://github.com/elkir0/Pi-Signage

### Reporting Migration Issues

When reporting migration issues, please include:

1. **Source version**: e.g., v0.10.0
2. **Target version**: v0.11.0
3. **Migration path used**: A, B, or C
4. **Error messages**: Full logs from journalctl or apache logs
5. **System info**:
```bash
cat /etc/os-release
uname -a
systemctl status pisignage-vlc
df -h
free -h
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-09  
**PiSignage Version**: v0.11.0
