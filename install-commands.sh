#!/bin/bash

#############################################
# PiSignage Installation Commands
# Run these commands on the Raspberry Pi
#############################################

cat << 'EOF'
==================================================
PISIGNAGE WEB SERVER INSTALLATION COMMANDS
==================================================

Copy and run these commands on your Raspberry Pi:

# Step 1: Update system and install web server
sudo apt-get update
sudo apt-get install -y nginx php-fpm php-json php-curl php-mbstring jq curl wget

# Step 2: Create directories
sudo mkdir -p /var/www/pisignage/{api,assets,templates,uploads}
sudo mkdir -p /opt/pisignage/{media,logs,config,scripts}
sudo chmod 755 /opt/pisignage
sudo chown -R www-data:www-data /var/www/pisignage
sudo chmod 775 /var/www/pisignage/uploads

# Step 3: Create VLC control script
cat > /tmp/vlc-control.sh << 'SCRIPT'
#!/bin/bash

ACTION=$1
VIDEO_PATH=$2

case $ACTION in
    play)
        pkill vlc 2>/dev/null
        DISPLAY=:0 cvlc --fullscreen --loop --no-video-title-show "${VIDEO_PATH:-/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4}" &
        echo "Video started: ${VIDEO_PATH}"
        ;;
    stop)
        pkill vlc
        echo "Video stopped"
        ;;
    status)
        if pgrep vlc > /dev/null; then
            echo "VLC is running"
            ps aux | grep vlc | grep -v grep
        else
            echo "VLC is not running"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 play "$VIDEO_PATH"
        ;;
    *)
        echo "Usage: $0 {play|stop|status|restart} [video_path]"
        exit 1
        ;;
esac
SCRIPT

sudo mv /tmp/vlc-control.sh /opt/pisignage/scripts/vlc-control.sh
sudo chmod +x /opt/pisignage/scripts/vlc-control.sh
sudo chown pi:pi /opt/pisignage/scripts/vlc-control.sh

# Step 4: Configure nginx
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;
    root /var/www/pisignage;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location /api {
        try_files $uri $uri/ /api/index.php?$query_string;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Step 5: Setup permissions for www-data
echo "www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/vlc-control.sh" | sudo tee /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill vlc" | sudo tee -a /etc/sudoers.d/pisignage  
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/cvlc" | sudo tee -a /etc/sudoers.d/pisignage
sudo chmod 440 /etc/sudoers.d/pisignage

# Step 6: Restart services
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
sudo systemctl enable nginx
sudo systemctl enable php*-fpm

# Step 7: Copy sample video to media directory
cp /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 /opt/pisignage/media/ 2>/dev/null || true

# Step 8: Test the control script
/opt/pisignage/scripts/vlc-control.sh status

echo "===================================================="
echo "Installation complete!"
echo "Access the web interface at: http://$(hostname -I | cut -d' ' -f1)/"
echo "===================================================="
EOF