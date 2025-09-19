# PiSignage Installation Guide

This comprehensive guide will walk you through the complete installation process for PiSignage on your Raspberry Pi.

## 📋 Prerequisites

### Hardware Requirements

- **Raspberry Pi 4** (2GB RAM minimum, 4GB+ recommended)
- **MicroSD Card** (16GB+ Class 10 or USB SSD for better performance)
- **Power Supply** (Official 5V/3A adapter recommended)
- **HDMI Cable** and compatible display
- **Network Connection** (Ethernet preferred, Wi-Fi supported)
- **Keyboard and Mouse** (for initial setup)

### Software Requirements

- **Raspberry Pi OS Desktop** (Bookworm or Bullseye)
- **SSH Access** (enabled during OS installation)
- **Internet Connection** (for package downloads)

## 🚀 Installation Methods

### Method 1: Quick Installation (Recommended)

This is the fastest way to get PiSignage running on your Raspberry Pi.

#### Step 1: Prepare Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
2. Flash **Raspberry Pi OS Desktop** to your SD card
3. **Before ejecting**, configure the following in the imager:
   - Enable SSH
   - Set username: `pi`
   - Set a secure password
   - Configure Wi-Fi (if using wireless)
   - Set locale settings

#### Step 2: First Boot and SSH Connection

1. Insert SD card and boot the Raspberry Pi
2. Find the Pi's IP address:
   ```bash
   # From your computer
   nmap -sn 192.168.1.0/24
   # Or check your router's admin panel
   ```

3. Connect via SSH:
   ```bash
   ssh pi@YOUR_PI_IP
   ```

#### Step 3: Install PiSignage

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clone PiSignage repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Run installation
sudo make install
```

The installer will:
- Install all required packages (VLC, nginx, PHP, etc.)
- Configure system services
- Set up the web interface
- Configure hardware acceleration
- Create systemd services
- Set up automatic startup

#### Step 4: Verify Installation

```bash
# Check service status
make status

# Test video playback
./src/scripts/player-control.sh start

# Access web interface
# Open browser: http://YOUR_PI_IP/
```

### Method 2: Manual Installation

For users who prefer step-by-step control or need custom configurations.

#### Step 1: System Preparation

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y git curl wget htop nano

# Configure GPU memory
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Enable hardware acceleration
echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/config.txt
echo "max_framebuffers=2" | sudo tee -a /boot/config.txt

# Reboot to apply changes
sudo reboot
```

#### Step 2: Install Media Player

```bash
# Install VLC with hardware acceleration support
sudo apt install -y vlc vlc-plugin-base

# Verify VLC installation
vlc --version
```

#### Step 3: Install Web Server

```bash
# Install nginx and PHP
sudo apt install -y nginx php8.2-fpm php8.2-cli php8.2-json php8.2-curl

# Start and enable services
sudo systemctl start nginx php8.2-fpm
sudo systemctl enable nginx php8.2-fpm
```

#### Step 4: Configure PiSignage

```bash
# Clone repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Copy web files
sudo cp -r web/* /var/www/html/

# Set permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Install systemd services
sudo cp src/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable vlc-signage
```

#### Step 5: Configure Nginx

```bash
# Backup default config
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Apply PiSignage nginx configuration
sudo cp src/config/nginx.conf /etc/nginx/sites-available/default

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

## 🔧 Post-Installation Configuration

### Display Configuration

#### For Standard HDMI Displays

```bash
# Edit boot configuration
sudo nano /boot/config.txt

# Add these lines for better compatibility:
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16  # 1080p 60Hz
```

#### For 4K Displays

```bash
# In /boot/config.txt
hdmi_enable_4kp60=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=3840 2160 60
```

### Network Configuration

#### Static IP Configuration

```bash
# Edit DHCP configuration
sudo nano /etc/dhcpcd.conf

# Add at the end:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

#### Wi-Fi Configuration

```bash
# Configure Wi-Fi
sudo raspi-config
# Navigate to: Network Options > Wi-Fi
# Or edit directly:
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

### Performance Optimization

#### GPU Optimization

```bash
# Edit /boot/config.txt
sudo nano /boot/config.txt

# Add GPU optimizations:
gpu_mem=128
gpu_freq=600
v3d_freq=600
over_voltage=2
arm_freq=1800
```

#### System Optimization

```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
sudo systemctl disable avahi-daemon

# Configure automatic login
sudo raspi-config
# System Options > Boot / Auto Login > Desktop Autologin
```

## 🎯 Testing Installation

### Basic Functionality Test

```bash
# Run comprehensive tests
make test

# Test video playback
./tests/test-video-playback.sh

# Check web interface
curl -s http://localhost/ | grep -i pisignage
```

### Performance Test

```bash
# Monitor system performance
./src/scripts/performance-monitor.sh

# Check GPU acceleration
glxinfo | grep "OpenGL renderer"

# Verify hardware decoding
./tests/test-hardware-acceleration.sh
```

### Service Status Check

```bash
# Check all PiSignage services
make status

# Individual service checks
sudo systemctl status vlc-signage
sudo systemctl status nginx
sudo systemctl status php8.2-fpm
```

## 🐛 Troubleshooting Installation

### Common Installation Issues

#### Package Installation Failures

```bash
# Fix broken packages
sudo apt --fix-broken install

# Clear package cache
sudo apt clean && sudo apt autoclean

# Update package lists
sudo apt update --fix-missing
```

#### Permission Issues

```bash
# Fix web directory permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Fix PiSignage directory permissions
sudo chown -R pi:pi /opt/pisignage/
chmod +x /opt/pisignage/src/scripts/*.sh
```

#### Service Start Failures

```bash
# Check service logs
sudo journalctl -u vlc-signage -n 50
sudo journalctl -u nginx -n 50

# Restart services
sudo systemctl restart vlc-signage nginx php8.2-fpm

# Reload systemd daemon
sudo systemctl daemon-reload
```

### GPU Acceleration Issues

#### Verify GPU Setup

```bash
# Check GPU memory
vcgencmd get_mem gpu

# Verify OpenGL
glxinfo | grep -E "(OpenGL vendor|OpenGL renderer)"

# Test hardware decoding
./tests/test-gpu-acceleration.sh
```

#### Fix GPU Issues

```bash
# Ensure GPU packages are installed
sudo apt install -y mesa-utils libgl1-mesa-dri

# Add user to video group
sudo usermod -a -G video pi

# Reboot to apply changes
sudo reboot
```

### Network Access Issues

#### Firewall Configuration

```bash
# Check if UFW is active
sudo ufw status

# Allow HTTP traffic
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp  # SSH

# Or disable firewall for testing
sudo ufw disable
```

#### Service Binding Issues

```bash
# Check what's listening on port 80
sudo netstat -tlnp | grep :80

# Restart nginx with proper configuration
sudo nginx -t && sudo systemctl restart nginx
```

## 🔄 Updating PiSignage

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update PiSignage
cd /opt/pisignage
git pull origin main
sudo make install  # Re-run installer for updates
```

### Version Migration

```bash
# Backup current configuration
./src/scripts/backup-config.sh

# Pull latest version
git fetch --all
git checkout main
git pull

# Run migration script
./deploy/migrate.sh
```

## 📋 Installation Checklist

Use this checklist to ensure complete installation:

- [ ] Raspberry Pi OS Desktop installed and updated
- [ ] SSH access configured and working
- [ ] PiSignage repository cloned
- [ ] Installation completed without errors
- [ ] Services running (vlc-signage, nginx, php8.2-fpm)
- [ ] Web interface accessible
- [ ] Video playback working
- [ ] GPU acceleration verified
- [ ] Performance benchmarks satisfactory
- [ ] Network configuration optimized
- [ ] Automatic startup configured
- [ ] Backup strategy implemented

## 📞 Getting Help

If you encounter issues during installation:

1. **Check the logs**: `sudo journalctl -u vlc-signage -f`
2. **Run diagnostics**: `./src/scripts/diagnostics.sh`
3. **Consult troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. **Community support**: [GitHub Issues](https://github.com/elkir0/Pi-Signage/issues)
5. **Documentation**: [Project Wiki](https://github.com/elkir0/Pi-Signage/wiki)

## 🎉 Next Steps

After successful installation:

1. **Configure your first playlist**: Access the web interface
2. **Upload media content**: Use the media manager
3. **Set up monitoring**: Configure system alerts
4. **Customize settings**: Adjust performance and display options
5. **Plan maintenance**: Set up regular updates and backups

---

**Installation complete! Your Raspberry Pi is now a professional digital signage display.**