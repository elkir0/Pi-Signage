#!/bin/bash

# Fix PHP upload limits for PiSignage
echo "🔧 Configuration des limites PHP pour uploads vidéos..."

# Backup current config
sudo cp /etc/php/8.2/fpm/php.ini /etc/php/8.2/fpm/php.ini.backup.$(date +%s)

# Update PHP-FPM configuration
sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^max_input_time = .*/max_input_time = 300/' /etc/php/8.2/fpm/php.ini

# Also update CLI config for consistency
sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/cli/php.ini
sudo sed -i 's/^post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/cli/php.ini

# Update Nginx config for client body size
sudo bash -c 'echo "client_max_body_size 100M;" > /etc/nginx/conf.d/upload_size.conf'

# Restart services
echo "📦 Redémarrage des services..."
sudo systemctl restart php8.2-fpm
sudo systemctl restart nginx

# Verify changes
echo "✅ Vérification des nouvelles limites:"
echo -n "  upload_max_filesize: "
grep "^upload_max_filesize" /etc/php/8.2/fpm/php.ini | cut -d= -f2
echo -n "  post_max_size: "
grep "^post_max_size" /etc/php/8.2/fpm/php.ini | cut -d= -f2
echo -n "  max_execution_time: "
grep "^max_execution_time" /etc/php/8.2/fpm/php.ini | cut -d= -f2

echo "✅ Configuration terminée - Upload jusqu'à 100MB maintenant possible!"