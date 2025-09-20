# Changelog

All notable changes to PiSignage will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.1] - 2025-09-20

### Fixed
- **YouTube Download**: Fixed yt-dlp not installed causing downloads to fail silently
- **Screenshot Capture**: Fixed missing scrot and imagemagick packages causing screenshot API to fail
- **Upload Limitation**: Fixed nginx/PHP 413 error for uploads > 2MB, now supports up to 500MB

### Added
- Multiple screenshot capture methods with automatic fallback (raspi2png, scrot, import, gnome-screenshot, xwd, ffmpeg)
- Enhanced upload API with better error handling and debug information
- Nginx and PHP configuration files for optimal performance

### Changed
- Updated nginx configuration with 500MB upload limit and optimized buffer settings
- Enhanced YouTube API with proper error handling and yt-dlp integration
- Improved screenshot script with 6 different capture methods for better compatibility

### Technical Details
- nginx: `client_max_body_size 500M`, `client_body_buffer_size 128k`
- PHP: `upload_max_filesize = 500M`, `post_max_size = 500M`, `memory_limit = 256M`
- New dependency: yt-dlp (YouTube downloader)
- New dependencies: scrot, imagemagick (screenshot tools)

## [0.9.0] - 2025-09-20

### Added
- Complete 7-tab web interface for digital signage management
- VLC-based video playback with GPU acceleration (30+ FPS, 7% CPU usage)
- YouTube video download capability
- Playlist management with drag-and-drop interface
- Scheduling system with weekly calendar
- Multi-zone display configuration
- Real-time system monitoring dashboard
- Screenshot capture at interface load
- 3 test videos pre-loaded (Big Buck Bunny, Sintel, Tears of Steel)

### Changed
- Complete refactoring from v3.x architecture to v0.9.x
- Migrated from FFmpeg to VLC for better performance
- Simplified deployment with no GPU modifications required

### Security
- Default Raspberry Pi credentials maintained for development
- nginx and PHP-FPM secured configurations

## [0.1.0] - 2025-09-17

### Added
- Initial project structure
- Basic video loop functionality
- Simple web interface

---

*This project follows semantic versioning. Version 1.0.0 will be released when all features are production-ready and thoroughly tested in real-world deployments.*