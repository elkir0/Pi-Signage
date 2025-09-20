# 🎉 PiSignage v0.9.1 Release Notes

**Release Date:** September 20, 2025  
**Version:** 0.9.1  
**Type:** Bug Fix Release  

## 🔧 What's Fixed

This release addresses three critical bugs that were preventing core functionality from working properly:

### 1. YouTube Download Feature Restored ✅
**Problem:** YouTube downloads were failing silently with no error messages  
**Solution:** Installed and configured yt-dlp (latest version) with proper permissions  
**Impact:** Users can now download YouTube videos directly from the web interface  

### 2. Screenshot Capture Fixed ✅
**Problem:** Screenshot API was returning "Impossible de prendre une capture" error  
**Solution:** Installed scrot and imagemagick, implemented 6 fallback capture methods  
**Impact:** Live display preview now works correctly in the dashboard  

### 3. Large Video Upload Support ✅
**Problem:** Videos larger than 2MB resulted in "413 Request Entity Too Large" error  
**Solution:** Configured nginx and PHP to support uploads up to 500MB  
**Impact:** Users can now upload full-length, high-quality video content  

## 📦 Installation

### Fresh Installation
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
sudo ./install.sh
```

### Upgrade from v0.9.0
```bash
cd Pi-Signage
git pull
sudo ./upgrade.sh
```

### Manual Bug Fixes (if upgrading manually)

#### Fix YouTube Download:
```bash
sudo wget -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

#### Fix Screenshot:
```bash
sudo apt-get install -y scrot imagemagick
```

#### Fix Upload Limits:
Add to `/etc/nginx/sites-available/default`:
```nginx
client_max_body_size 500M;
client_body_buffer_size 128k;
client_body_timeout 300;
```

Create `/etc/php/8.2/fpm/conf.d/99-pisignage.ini`:
```ini
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
memory_limit = 256M
```

Then restart services:
```bash
sudo systemctl restart nginx php8.2-fpm
```

## 🧪 Testing

All fixes have been thoroughly tested:
- ✅ YouTube download tested with multiple videos
- ✅ Screenshot capture verified on Raspberry Pi 4
- ✅ Upload tested with 102MB video file

Test scripts included:
- `/opt/pisignage/scripts/test-all-fixes.sh`
- `/opt/pisignage/scripts/quick-test.sh`

## 📊 System Requirements

No changes from v0.9.0:
- Raspberry Pi 4 (2GB+ RAM)
- Raspberry Pi OS Lite (Bookworm)
- 16GB+ SD Card
- Network connection

## 🔄 Compatibility

This release maintains full compatibility with:
- Existing playlists and media files
- All API endpoints
- Web interface features
- Configuration files from v0.9.0

## 📝 Known Issues

- Screenshot image URL accessibility may require nginx configuration adjustment (non-critical)
- Large file uploads (>100MB) may take several minutes depending on network speed

## 🚀 What's Next

Version 1.0.0 (planned for Q4 2025) will include:
- Enhanced multi-display support
- Cloud synchronization
- Mobile app for remote control
- Advanced scheduling features
- Performance optimizations for 4K content

## 🙏 Acknowledgments

Thanks to all users who reported these issues and helped with testing the fixes.

## 📞 Support

Report issues: https://github.com/elkir0/Pi-Signage/issues  
Documentation: https://github.com/elkir0/Pi-Signage/wiki  

---

**PiSignage v0.9.1** - Digital Signage that just works! 📺✨