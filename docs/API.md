# API Documentation - PiSignage v0.8.0

## Base URL
```
http://192.168.1.103/api/
```

## Endpoints

### System API
**GET** `/api/system.php`
- Returns system information (CPU, memory, disk usage)

### Media API
**GET** `/api/media.php`
- List all media files

**DELETE** `/api/media.php`
- Body: `{ "filename": "file.mp4", "action": "delete" }`

### Playlist API
**GET** `/api/playlist.php?action=info`
- Get all playlists

**POST** `/api/playlist.php`
- Create/Update playlist
- Body: `{ "name": "playlist1", "files": ["file1.mp4", "file2.jpg"] }`

**DELETE** `/api/playlist.php`
- Body: `{ "name": "playlist1" }`

### YouTube API
**POST** `/api/youtube-simple.php`
- Download YouTube video
- Body: `{ "url": "https://youtube.com/watch?v=...", "quality": "720p" }`

**GET** `/api/youtube-simple.php?action=status`
- Check download status

### Upload API
**POST** `/api/upload.php`
- Upload media files
- Form data with file field

### Screenshot API
**GET** `/api/screenshot.php`
- Capture current display screenshot