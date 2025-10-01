# BUG-013: Player Control - Single File Playback Always Plays BigBuckBunny

**Date**: 2025-10-01
**Severity**: Medium
**Status**: ⚠️ KNOWN LIMITATION
**Component**: Player Control (player.php, VLC HTTP Interface)

## Problem Description

When using the player control interface to play a specific video file, the system continues to play `BigBuckBunny_720p.mp4` instead of the selected file, regardless of which video is chosen from the dropdown.

### User Impact

- Users cannot reliably play individual video files from the player control interface
- The "Lecture rapide" (Quick Play) feature does not work as expected
- Only playlist playback works correctly

## Root Cause Analysis

### System Architecture Issue

The pisignage-vlc.service is configured to start with the entire `/opt/pisignage/media/` directory:

```systemd
ExecStart=/usr/bin/vlc \
    --intf http \
    --extraintf dummy \
    --http-host 0.0.0.0 \
    --http-port 8080 \
    --http-password pisignage \
    --fullscreen \
    --no-video-title-show \
    --loop \
    --playlist-autostart \
    --video-on-top \
    --no-osd \
    /opt/pisignage/media/
```

This causes VLC to:
1. Load ALL files from the media directory into its internal playlist on startup
2. Start playing the first file alphabetically (usually BigBuckBunny_720p.mp4)
3. Loop indefinitely on this initial playlist

### VLC HTTP Interface Limitation

The VLC HTTP interface has **asynchronous command processing**, which means:

- Commands like `pl_empty` (clear playlist) return immediately but take time to execute
- Adding files with `in_enqueue` doesn't guarantee immediate availability
- Playing with `pl_play` may start before the playlist is properly cleared/updated
- There's no reliable way to wait for command completion via HTTP

### Failed Solutions Attempted

#### 1. Clear + Add + Play (Basic)
```php
$vlc->stop();
$vlc->clearPlaylist();
$vlc->addToPlaylist($filepath);
$vlc->play();
```
**Result**: ❌ VLC continues playing the cached file (BBB)

#### 2. Use `in_play` Command
```php
$vlc->playFile($filepath); // Uses VLC 'in_play' command
```
**Result**: ❌ Command ignored, VLC continues current playback

#### 3. Find Playlist ID + Play by ID
```php
$playlist = $vlc->getPlaylist();
$targetId = findFileId($playlist, $filename);
$vlc->playPlaylistItem($targetId);
```
**Result**: ❌ VLC metadata doesn't update fast enough, still shows BBB

#### 4. Restart VLC Service
```php
exec('sudo systemctl restart pisignage-vlc.service');
$vlc->clearPlaylist();
$vlc->addToPlaylist($filepath);
$vlc->play();
```
**Result**: ❌ Service restarts with `/media/` directory again

#### 5. PHP sleep() Between Commands
```php
$vlc->stop();
sleep(1);
$vlc->clearPlaylist();
sleep(1);
$vlc->addToPlaylist($filepath);
sleep(1);
$vlc->play();
```
**Result**: ❌ Still doesn't work (VLC commands are async, PHP waits don't help)

### Working Solution (Manual Only)

**Only works via direct curl commands** with proper timing:

```bash
curl 'http://IP:8080/requests/status.json?command=pl_stop' --user ":pisignage"
sleep 1
curl 'http://IP:8080/requests/status.json?command=pl_empty' --user ":pisignage"
sleep 1
curl 'http://IP:8080/requests/status.json?command=in_enqueue&input=/opt/pisignage/media/FILE.mp4' --user ":pisignage"
sleep 1
curl 'http://IP:8080/requests/status.json?command=pl_play' --user ":pisignage"
sleep 3
# Now check status - file is actually playing!
curl 'http://IP:8080/requests/status.json' --user ":pisignage" | jq '.information.category.meta.filename'
```

**Test Results**: ✅ SUCCESS - COSTA RICA IN 4K 60fps HDR plays correctly

**Why it works manually but not in PHP**:
- Shell `sleep` creates actual time gaps between HTTP requests
- PHP's `sleep()` doesn't help because `sendCommand()` is non-blocking
- VLC needs real-time gaps to process commands sequentially

## Current Workaround

### For Users

**Use playlists instead of single files**:

1. Go to **Playlists** page
2. Create a playlist with your desired video
3. Go to **Player** page
4. Use "Gestion des Playlists" → Select your playlist → Click "Charger"

✅ Playlist playback works correctly because playlists use a different VLC loading mechanism.

### For Developers

The code now includes a warning message:

```php
$message = "Playing: $filename (Note: May still play previous file due to VLC limitation)";
```

## Proper Fix Options

### Option A: Modify VLC Service to Start Empty

**Change systemd service**:
```systemd
ExecStart=/usr/bin/vlc \
    --intf http \
    --extraintf dummy \
    --http-host 0.0.0.0 \
    --http-port 8080 \
    --http-password pisignage \
    --fullscreen \
    --no-video-title-show \
    --loop \
    --video-on-top \
    --no-osd \
    # NO media directory - start empty
```

**Pros**: Clean solution, HTTP commands would work reliably
**Cons**: System wouldn't auto-play on startup (breaks auto-start feature)

### Option B: Create Bash Wrapper Script

Create `/opt/pisignage/scripts/vlc-play-file.sh`:
```bash
#!/bin/bash
FILE="$1"

curl -s "http://localhost:8080/requests/status.json?command=pl_stop" --user ":pisignage" > /dev/null
sleep 1
curl -s "http://localhost:8080/requests/status.json?command=pl_empty" --user ":pisignage" > /dev/null
sleep 1
curl -s "http://localhost:8080/requests/status.json?command=in_enqueue&input=$FILE" --user ":pisignage" > /dev/null
sleep 1
curl -s "http://localhost:8080/requests/status.json?command=pl_play" --user ":pisignage" > /dev/null
```

Call from PHP:
```php
exec("/opt/pisignage/scripts/vlc-play-file.sh " . escapeshellarg($filepath) . " > /dev/null 2>&1 &");
```

**Pros**: Reliable, uses proven manual method
**Cons**: Requires external script, user must wait ~3 seconds

### Option C: Use VLC Lua HTTP Extensions

Create custom VLC Lua script with synchronous command execution.

**Pros**: Professional solution
**Cons**: Complex, requires VLC Lua knowledge

## Recommendation

**Implement Option B (Bash Wrapper Script)** as it:
- Uses the proven working manual solution
- Requires minimal code changes
- Is reliable and testable
- Maintains backward compatibility

## Files Affected

- `web/api/player.php` - Contains workaround code with TODO comment
- `web/api/player-control.php` - VLCController class
- `/etc/systemd/system/pisignage-vlc.service` - Service configuration (root cause)

## Testing Evidence

### Manual Test (WORKS)
```bash
$ # Test with COSTA RICA video
$ curl 'http://192.168.1.149:8080/requests/status.json?command=pl_stop' --user ":pisignage"
$ sleep 1
$ curl 'http://192.168.1.149:8080/requests/status.json?command=pl_empty' --user ":pisignage"
$ sleep 1
$ curl 'http://192.168.1.149:8080/requests/status.json?command=in_enqueue&input=/opt/pisignage/media/COSTA%20RICA%20IN%204K%2060fps%20HDR%20%28ULTRA%20HD%29.mp4' --user ":pisignage"
$ sleep 1
$ curl 'http://192.168.1.149:8080/requests/status.json?command=pl_play' --user ":pisignage"
$ sleep 3
$ curl 'http://192.168.1.149:8080/requests/status.json' --user ":pisignage" | jq '.information.category.meta.filename'
"COSTA RICA IN 4K 60fps HDR (ULTRA HD).mp4"  ✅ SUCCESS
```

### PHP Test (FAILS)
```bash
$ curl -X POST http://192.168.1.149/api/player.php \
  -H "Content-Type: application/json" \
  -d '{"action":"play_file","file":"COSTA RICA IN 4K 60fps HDR (ULTRA HD).mp4"}'
{"success":true,"message":"Playing: COSTA RICA..."}

$ sleep 5
$ curl 'http://192.168.1.149:8080/requests/status.json' --user ":pisignage" | jq '.information.category.meta.filename'
"BigBuckBunny_720p.mp4"  ❌ STILL BBB
```

## Related Issues

- Service configuration in `/etc/systemd/system/pisignage-vlc.service`
- VLC HTTP API asynchronous behavior
- Auto-start functionality requirements

## Timeline

- **2025-10-01**: Bug reported and investigated
- **2025-10-01**: Multiple solutions attempted (all failed in PHP context)
- **2025-10-01**: Manual curl solution confirmed working
- **2025-10-01**: Documented as KNOWN LIMITATION pending proper fix

---

**Priority**: Medium (playlists work as workaround)
**Impact**: Single file playback only
**Next Steps**: Implement Option B (Bash wrapper script) in future release
