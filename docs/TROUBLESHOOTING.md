# PiSignage Troubleshooting Guide

This guide covers common issues and their solutions for PiSignage installations.

## 🔍 Quick Diagnosis

Before diving into specific issues, run our diagnostic tools:

```bash
# Comprehensive system check
./src/scripts/diagnostics.sh

# Check service status
make status

# Monitor system performance
./src/scripts/performance-monitor.sh

# View recent logs
make logs
```

## 📺 Display Issues

### Black Screen

**Symptoms:** No display output, screen remains black

**Causes & Solutions:**

1. **HDMI Connection Issues**
   ```bash
   # Force HDMI output
   sudo nano /boot/config.txt
   # Add: hdmi_force_hotplug=1
   sudo reboot
   ```

2. **Display Mode Problems**
   ```bash
   # Set specific resolution
   sudo nano /boot/config.txt
   # Add:
   hdmi_group=1
   hdmi_mode=16  # 1080p 60Hz
   sudo reboot
   ```

3. **GPU Memory Insufficient**
   ```bash
   # Check GPU memory
   vcgencmd get_mem gpu
   
   # If less than 128MB, increase it
   sudo nano /boot/config.txt
   # Change to: gpu_mem=128
   sudo reboot
   ```

4. **Service Not Running**
   ```bash
   # Check VLC service
   sudo systemctl status vlc-signage
   
   # Restart if needed
   sudo systemctl restart vlc-signage
   ```

### Incorrect Resolution or Aspect Ratio

**Symptoms:** Display appears stretched, wrong size, or poor quality

**Solutions:**

1. **Auto-detect Display**
   ```bash
   # Get display information
   tvservice -s
   
   # Apply detected settings
   sudo nano /boot/config.txt
   # Remove custom hdmi_mode and hdmi_group lines
   sudo reboot
   ```

2. **Manual Resolution Setting**
   ```bash
   # For 1080p displays
   sudo nano /boot/config.txt
   hdmi_group=1
   hdmi_mode=16
   
   # For 720p displays
   hdmi_group=1
   hdmi_mode=4
   
   # For custom resolution
   hdmi_group=2
   hdmi_mode=87
   hdmi_cvt=1920 1080 60
   ```

3. **Overscan Issues**
   ```bash
   # Disable overscan
   sudo nano /boot/config.txt
   disable_overscan=1
   sudo reboot
   ```

## 🎬 Video Playback Issues

### Low Frame Rate (< 25 FPS)

**Symptoms:** Choppy video, stuttering, low FPS

**Diagnosis:**
```bash
# Check CPU usage during playback
top -p $(pgrep vlc)

# Verify GPU acceleration
glxinfo | grep "OpenGL renderer"

# Monitor video statistics
./src/scripts/video-stats.sh
```

**Solutions:**

1. **Enable Hardware Acceleration**
   ```bash
   # Verify GPU configuration
   sudo nano /boot/config.txt
   # Ensure these lines exist:
   dtoverlay=vc4-kms-v3d
   gpu_mem=128
   max_framebuffers=2
   sudo reboot
   ```

2. **VLC Configuration**
   ```bash
   # Check VLC hardware acceleration
   vlc --list | grep -i hardware
   
   # Restart VLC with GPU flags
   ./src/scripts/player-control.sh restart
   ```

3. **Video Format Issues**
   ```bash
   # Check video codec
   ffprobe your_video.mp4 2>&1 | grep Stream
   
   # Convert to H.264 if needed
   ffmpeg -i input.mp4 -c:v h264_omx -b:v 2M output.mp4
   ```

### Video Not Playing

**Symptoms:** No video content appears, audio might work

**Solutions:**

1. **Check Media File**
   ```bash
   # Verify file exists and permissions
   ls -la /path/to/video.mp4
   
   # Test file integrity
   ffprobe /path/to/video.mp4
   ```

2. **Test VLC Manually**
   ```bash
   # Try playing directly
   DISPLAY=:0 vlc --intf dummy /path/to/video.mp4
   
   # Check for error messages
   sudo journalctl -u vlc-signage -f
   ```

3. **Check File Permissions**
   ```bash
   # Fix ownership
   sudo chown -R pi:pi /opt/pisignage/media/
   chmod 644 /opt/pisignage/media/*.mp4
   ```

### Audio Issues

**Symptoms:** No sound output or distorted audio

**Solutions:**

1. **Enable Audio Output**
   ```bash
   # Check audio configuration
   sudo nano /boot/config.txt
   # Add: dtparam=audio=on
   
   # Set audio output
   sudo raspi-config
   # Advanced Options > Audio > Force 3.5mm jack
   ```

2. **HDMI Audio**
   ```bash
   # Force HDMI audio
   sudo nano /boot/config.txt
   # Add: hdmi_drive=2
   sudo reboot
   ```

3. **Test Audio**
   ```bash
   # Check audio devices
   aplay -l
   
   # Test audio output
   speaker-test -t wav
   ```

## 🌐 Web Interface Issues

### Cannot Access Web Interface

**Symptoms:** Browser shows connection timeout or error

**Diagnosis:**
```bash
# Check nginx status
sudo systemctl status nginx

# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Test local access
curl -I http://localhost/
```

**Solutions:**

1. **Restart Web Services**
   ```bash
   sudo systemctl restart nginx php8.2-fpm
   
   # Check for errors
   sudo journalctl -u nginx -f
   sudo journalctl -u php8.2-fpm -f
   ```

2. **Check Firewall**
   ```bash
   # Check UFW status
   sudo ufw status
   
   # Allow HTTP traffic
   sudo ufw allow 80/tcp
   
   # Or disable for testing
   sudo ufw disable
   ```

3. **Verify Network Configuration**
   ```bash
   # Check IP address
   ip addr show
   
   # Test from another device
   ping YOUR_PI_IP
   telnet YOUR_PI_IP 80
   ```

### PHP Errors

**Symptoms:** Web pages show PHP errors or don't load properly

**Solutions:**

1. **Check PHP Configuration**
   ```bash
   # Test PHP
   php -v
   
   # Check PHP-FPM
   sudo systemctl status php8.2-fpm
   
   # Test PHP files
   php -l /var/www/html/index.php
   ```

2. **Fix Permissions**
   ```bash
   sudo chown -R www-data:www-data /var/www/html/
   sudo chmod -R 755 /var/www/html/
   sudo chmod -R 777 /var/www/html/uploads/
   ```

3. **Check PHP Logs**
   ```bash
   sudo tail -f /var/log/php8.2-fpm.log
   sudo tail -f /var/log/nginx/error.log
   ```

## ⚡ Performance Issues

### High CPU Usage

**Symptoms:** System sluggish, high CPU temperature

**Diagnosis:**
```bash
# Monitor CPU usage
htop

# Check temperature
vcgencmd measure_temp

# Monitor processes
./src/scripts/performance-monitor.sh
```

**Solutions:**

1. **Verify GPU Acceleration**
   ```bash
   # Check if GPU is being used
   sudo rpi-update  # Update firmware
   
   # Verify OpenGL
   glxinfo | grep renderer
   
   # Should show: "V3D" not "Software"
   ```

2. **Optimize Video Settings**
   ```bash
   # Lower video quality
   ffmpeg -i input.mp4 -c:v h264_omx -b:v 1M output.mp4
   
   # Use 720p instead of 1080p
   # Reduce frame rate to 25 FPS
   ```

3. **System Optimization**
   ```bash
   # Disable unnecessary services
   sudo systemctl disable bluetooth
   sudo systemctl disable avahi-daemon
   
   # Increase GPU frequency
   sudo nano /boot/config.txt
   # Add: gpu_freq=500
   ```

### Memory Issues

**Symptoms:** System runs out of memory, applications crash

**Solutions:**

1. **Increase GPU Memory**
   ```bash
   sudo nano /boot/config.txt
   # Increase: gpu_mem=256
   sudo reboot
   ```

2. **Add Swap Space**
   ```bash
   # Create swap file
   sudo fallocate -l 1G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   
   # Make permanent
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

3. **Monitor Memory Usage**
   ```bash
   # Check memory usage
   free -h
   
   # Monitor in real-time
   watch -n 1 'free -h && echo && ps aux --sort=-%mem | head -10'
   ```

## 🔧 System Issues

### Service Startup Failures

**Symptoms:** Services don't start automatically after reboot

**Solutions:**

1. **Check Service Status**
   ```bash
   sudo systemctl status vlc-signage
   sudo systemctl status nginx
   sudo systemctl status php8.2-fpm
   ```

2. **Enable Services**
   ```bash
   sudo systemctl enable vlc-signage
   sudo systemctl enable nginx
   sudo systemctl enable php8.2-fpm
   ```

3. **Fix Service Dependencies**
   ```bash
   # Edit service file if needed
   sudo nano /etc/systemd/system/vlc-signage.service
   
   # Reload daemon
   sudo systemctl daemon-reload
   ```

### Boot Issues

**Symptoms:** Pi doesn't boot properly or gets stuck

**Solutions:**

1. **Safe Mode Boot**
   ```bash
   # Mount SD card on another computer
   # Edit /boot/config.txt
   # Comment out custom settings:
   # #gpu_mem=128
   # #dtoverlay=vc4-kms-v3d
   ```

2. **Check Boot Logs**
   ```bash
   # After successful boot
   sudo journalctl -b
   
   # Check for errors
   dmesg | grep -i error
   ```

3. **File System Check**
   ```bash
   # From another computer or recovery mode
   sudo fsck /dev/mmcblk0p2
   ```

## 🌡️ Temperature Issues

### Overheating

**Symptoms:** Thermal throttling, system instability

**Solutions:**

1. **Monitor Temperature**
   ```bash
   # Check current temperature
   vcgencmd measure_temp
   
   # Monitor throttling
   vcgencmd get_throttled
   ```

2. **Improve Cooling**
   - Add heatsinks to CPU and RAM
   - Install case fan
   - Ensure proper ventilation
   - Consider active cooling case

3. **Reduce Heat Generation**
   ```bash
   # Lower CPU frequency
   sudo nano /boot/config.txt
   # Add: arm_freq=1400  # Default is 1500
   
   # Reduce GPU frequency
   # Add: gpu_freq=400  # Default is 500
   ```

## 📊 Diagnostic Commands

### System Information

```bash
# Hardware information
cat /proc/cpuinfo
vcgencmd version
vcgencmd get_mem arm && vcgencmd get_mem gpu

# Software versions
uname -a
lsb_release -a
vlc --version
nginx -v
php --version

# GPU information
glxinfo | head -20
vcgencmd measure_clock arm
vcgencmd measure_clock gpu
```

### Performance Monitoring

```bash
# CPU and memory usage
htop

# Disk usage
df -h
iostat 1

# Network status
ifconfig
netstat -i

# Temperature monitoring
watch -n 1 vcgencmd measure_temp
```

### Log Analysis

```bash
# System logs
sudo journalctl --since "1 hour ago"

# Service-specific logs
sudo journalctl -u vlc-signage --since "10 minutes ago"
sudo journalctl -u nginx --since "10 minutes ago"

# Web server logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Application logs
tail -f /opt/pisignage/logs/*.log
```

## 🚨 Emergency Recovery

### Complete System Reset

If PiSignage becomes completely unusable:

1. **Backup Important Data**
   ```bash
   # Copy media files
   cp -r /opt/pisignage/media/ /backup/
   
   # Export configuration
   ./src/scripts/export-config.sh
   ```

2. **Clean Reinstall**
   ```bash
   # Uninstall PiSignage
   sudo make uninstall
   
   # Clean system
   sudo apt autoremove -y
   sudo apt autoclean
   
   # Reinstall
   sudo make install
   ```

3. **Factory Reset (Last Resort)**
   - Re-flash Raspberry Pi OS
   - Start fresh installation
   - Restore backup data

## 📞 Getting Additional Help

If these solutions don't resolve your issue:

1. **Collect Diagnostic Information**
   ```bash
   ./src/scripts/collect-logs.sh
   ```

2. **Create GitHub Issue**
   - Include diagnostic output
   - Describe exact symptoms
   - List steps taken
   - Provide system information

3. **Community Resources**
   - [GitHub Discussions](https://github.com/elkir0/Pi-Signage/discussions)
   - [Project Wiki](https://github.com/elkir0/Pi-Signage/wiki)
   - [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

---

**Remember:** Most issues can be resolved by ensuring proper GPU configuration and hardware acceleration. When in doubt, check the logs first!