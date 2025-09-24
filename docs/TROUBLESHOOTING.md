# Troubleshooting Guide - PiSignage v0.8.0

## Common Issues

### 1. Upload fails with large files
**Solution**: Increase PHP limits
```bash
sudo ./fix-php-limits.sh
sudo systemctl restart php8.2-fpm nginx
```

### 2. YouTube download not working
**Solution**: Update yt-dlp
```bash
sudo yt-dlp -U
```

### 3. VLC not playing videos
**Solution**: Check VLC service
```bash
sudo systemctl status vlc
sudo systemctl restart vlc
```

### 4. Permission denied errors
**Solution**: Fix permissions
```bash
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
```

### 5. Interface not loading
**Solution**: Check nginx and PHP
```bash
sudo systemctl status nginx php8.2-fpm
sudo systemctl restart nginx php8.2-fpm
```

### 6. No sound from VLC
**Solution**: Set audio output
```bash
amixer cset numid=3 1  # HDMI audio
amixer cset numid=3 2  # Headphone jack
```

## Log Files
- Application: `/opt/pisignage/logs/pisignage.log`
- Nginx: `/var/log/nginx/error.log`
- PHP: `/var/log/php8.2-fpm.log`

## Debug Mode
Enable debug in `/opt/pisignage/web/config.php`:
```php
define('DEBUG', true);
```

## Support
Report issues: https://github.com/elkir0/Pi-Signage/issues