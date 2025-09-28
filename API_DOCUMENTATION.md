# PiSignage API Documentation

## Base URL
```
http://{raspberry_pi_ip}/api/
```

## Response Format
All API responses follow a standard JSON structure:
```json
{
  "success": boolean,
  "data": mixed,
  "message": string,
  "timestamp": "Y-m-d H:i:s"
}
```

---

## System API (`/api/system.php`)

### GET /api/system.php?action=stats
Returns system statistics including CPU, memory, disk usage.

**Response:**
```json
{
  "success": true,
  "data": {
    "cpu": {
      "usage": 45,
      "load_1min": 1.2,
      "load_5min": 1.1,
      "load_15min": 0.9
    },
    "memory": {
      "total": 4096,
      "used": 2048,
      "free": 2048,
      "percent": 50
    },
    "disk": {
      "total_formatted": "100GB",
      "used_formatted": "20GB",
      "percent": 20
    },
    "temperature": 55.5,
    "uptime": "2 days, 3 hours",
    "network": "192.168.1.100",
    "media_count": 25
  }
}
```

### POST /api/system.php?action=reboot
Reboots the system.

**Response:**
```json
{
  "success": true,
  "message": "System reboot initiated"
}
```

### POST /api/system.php?action=shutdown
Shuts down the system.

---

## Media API (`/api/media.php`)

### GET /api/media.php
Lists all media files.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "video1.mp4",
      "size": 10485760,
      "type": "video/mp4",
      "duration": 120,
      "thumbnail": "/thumbnails/video1.jpg"
    }
  ]
}
```

### DELETE /api/media.php
Deletes a media file.

**Request Body:**
```json
{
  "filename": "video1.mp4"
}
```

---

## Playlist API (`/api/playlist-simple.php`)

### GET /api/playlist-simple.php
Returns all playlists.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "Morning Playlist",
      "items": [
        {"file": "video1.mp4", "duration": 30},
        {"file": "image1.jpg", "duration": 10}
      ],
      "created_at": "2025-01-01 10:00:00"
    }
  ]
}
```

### POST /api/playlist-simple.php
Creates a new playlist.

**Request Body:**
```json
{
  "name": "Evening Playlist",
  "items": [
    {"file": "video2.mp4", "duration": 60}
  ],
  "description": "Content for evening display"
}
```

### DELETE /api/playlist-simple.php
Deletes a playlist.

**Request Body:**
```json
{
  "name": "Morning Playlist"
}
```

---

## Player API (`/api/player.php`)

### GET /api/player.php?action=status
Returns current player status.

**Response:**
```json
{
  "success": true,
  "data": {
    "player": "vlc",
    "status": "playing",
    "current_file": "video1.mp4",
    "position": 45,
    "duration": 120,
    "volume": 80
  }
}
```

### POST /api/player.php
Controls the player.

**Request Body:**
```json
{
  "action": "play|pause|stop|next|previous",
  "player": "vlc|mpv"
}
```

### GET /api/player.php?action=current
Returns the current player configuration.

---

## Upload API (`/api/upload.php`)

### POST /api/upload.php
Uploads a media file.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Field: file (max 500MB)

**Response:**
```json
{
  "success": true,
  "data": {
    "filename": "video3.mp4",
    "size": 52428800,
    "path": "/opt/pisignage/media/video3.mp4"
  }
}
```

---

## Screenshot API (`/api/screenshot.php`)

### GET /api/screenshot.php
Takes a screenshot of the current display.

**Response:**
```json
{
  "success": true,
  "data": {
    "path": "/screenshots/2025-01-01_120000.png",
    "url": "/screenshots/2025-01-01_120000.png",
    "size": 204800
  }
}
```

---

## Logs API (`/api/logs.php`)

### GET /api/logs.php?type=system
Returns system logs.

**Parameters:**
- type: system|player|web|all
- lines: number (default 100)

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [
      "[2025-01-01 12:00:00] System started",
      "[2025-01-01 12:00:05] VLC player initialized"
    ]
  }
}
```

---

## Performance API (`/api/performance.php`)

### GET /api/performance.php
Returns performance metrics.

**Response:**
```json
{
  "success": true,
  "data": {
    "fps": 30,
    "dropped_frames": 0,
    "network_latency": 5,
    "rendering_time": 16
  }
}
```

---

## Scheduler API (`/api/scheduler.php`)

### GET /api/scheduler.php
Returns scheduled playlists.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "playlist": "Morning Playlist",
      "start_time": "08:00",
      "end_time": "12:00",
      "days": ["mon", "tue", "wed", "thu", "fri"],
      "active": true
    }
  ]
}
```

### POST /api/scheduler.php
Creates or updates a schedule.

**Request Body:**
```json
{
  "playlist": "Evening Playlist",
  "start_time": "18:00",
  "end_time": "22:00",
  "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
}
```

---

## Configuration API (`/api/config.php`)

### GET /api/config.php
Returns system configuration.

**Response:**
```json
{
  "success": true,
  "data": {
    "display": {
      "resolution": "1920x1080",
      "orientation": "landscape",
      "brightness": 80
    },
    "network": {
      "wifi_enabled": true,
      "ethernet_connected": false
    },
    "player": {
      "default": "vlc",
      "autostart": true
    }
  }
}
```

### POST /api/config.php
Updates configuration settings.

---

## YouTube API (`/api/youtube.php`)

### POST /api/youtube.php
Downloads a YouTube video.

**Request Body:**
```json
{
  "url": "https://youtube.com/watch?v=...",
  "quality": "720p"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "filename": "youtube_video.mp4",
    "title": "Video Title",
    "duration": 180
  }
}
```

---

## Error Codes

- `200` - Success
- `400` - Bad Request
- `404` - Not Found
- `500` - Internal Server Error
- `507` - Insufficient Storage

## Rate Limiting

- Maximum 100 requests per minute per IP
- Upload limit: 500MB per file
- Batch operations limited to 50 items

## Authentication

Currently no authentication required (local network only).
For production deployment, consider implementing API keys or JWT tokens.