# Installation Guide - PiSignage v0.8.0

## Prerequisites
- Raspberry Pi 3/4/5
- Raspberry Pi OS (Bullseye or newer)
- 8GB+ SD Card
- Network connection

## Quick Install

```bash
# Clone repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Run installation script
chmod +x scripts/install/install-pisignage-bullseye.sh
sudo ./scripts/install/install-pisignage-bullseye.sh
```

## Manual Installation

### 1. System Update
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Dependencies
```bash
sudo apt install -y nginx php8.2-fpm php8.2-cli php8.2-json php8.2-curl \
    vlc git curl python3-pip
```

### 3. Install yt-dlp
```bash
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

### 4. Configure Nginx
```bash
sudo cp config/nginx-site.conf /etc/nginx/sites-available/pisignage
sudo ln -s /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

### 5. Fix PHP Limits
```bash
sudo ./fix-php-limits.sh
```

### 6. Set Permissions
```bash
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
```

## Access
Open browser: `http://[raspberry-pi-ip]/`

## Default Directories
- Media files: `/opt/pisignage/media/`
- Logs: `/opt/pisignage/logs/`
- Config: `/opt/pisignage/config/`