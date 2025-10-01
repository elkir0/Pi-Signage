# BUG-012: YouTube Download Format Selection Error

**Date**: 2025-10-01
**Severity**: Critical
**Status**: ✅ FIXED
**Component**: YouTube Download (youtube.php)

## Problem Description

YouTube video downloads were failing with error:
```
ERROR: [youtube] Requested format is not available
```

### Root Causes

1. **Obsolete yt-dlp version** (2025.09.05)
2. **Missing cache directory** `/var/www/.cache` for www-data user
3. **Overly restrictive format selector** - didn't handle modern YouTube format variations
4. **nsig extraction failures** - signature verification issues

## Technical Details

### Error Symptoms
- Downloads failed with "format not available" even when formats existed
- yt-dlp couldn't write to cache directory (Permission denied)
- Format selector: `bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/best[height<=360]`
- This selector was too specific and failed when exact combinations weren't available

### Actual Available Formats
Analysis showed available formats for test video:
- **134**: 640x360 mp4 video-only
- **140**: m4a audio-only
- **18**: 640x360 mp4 with integrated audio ✅
- **696**: 640x360 60fps HDR mp4 video-only
- **243**: 640x360 webm video-only

## Solution Implemented

### 1. Cache Directory Creation
```bash
sudo mkdir -p /var/www/.cache
sudo chown -R www-data:www-data /var/www/.cache
sudo chmod 755 /var/www/.cache
```

### 2. Updated Format Selection Logic

**File**: `/opt/pisignage/web/api/youtube.php:353-367`

**Before**:
```php
if ($quality === 'best') {
    $command .= " -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'";
} else {
    $qualityNum = intval(str_replace('p', '', $quality));
    $command .= " -f 'bestvideo[height<=$qualityNum][ext=mp4]+bestaudio[ext=m4a]/best[height<=$qualityNum]'";
}
```

**After**:
```php
if ($quality === 'best') {
    // Try best video+audio merge, fallback to best single file with audio
    $command .= " -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best'";
} else {
    $qualityNum = intval(str_replace('p', '', $quality));
    // Try merge at quality, fallback to single file with audio at quality, then any format at quality
    $command .= " -f 'bestvideo[height<=$qualityNum][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$qualityNum]+bestaudio/best[height<=$qualityNum]/best'";
}
// Merge output container
$command .= " --merge-output-format mp4";
```

### 3. Format Selection Chain

The new selector implements a **fallback chain**:

#### For Best Quality:
1. `bestvideo[ext=mp4]+bestaudio[ext=m4a]` - Prefer MP4/M4A merge
2. `bestvideo+bestaudio` - Any video+audio merge
3. `best` - Best single file with audio

#### For Specific Quality (e.g., 360p):
1. `bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]` - MP4/M4A at quality
2. `bestvideo[height<=360]+bestaudio` - Any video+audio at quality
3. `best[height<=360]` - Best single file at quality
4. `best` - Final fallback

#### Merge Output:
- `--merge-output-format mp4` - Ensures final output is always MP4

## Testing Results

### Test Command
```bash
sudo -u www-data yt-dlp \
  -f 'bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=360]+bestaudio/best[height<=360]/best' \
  --merge-output-format mp4 \
  -o '/opt/pisignage/media/%(title)s.%(ext)s' \
  'https://www.youtube.com/watch?v=LXb3EKWsInQ'
```

### Result
```
✅ SUCCESS
[info] LXb3EKWsInQ: Downloading 1 format(s): 696+140
[Merger] Merging formats into "COSTA RICA IN 4K 60fps HDR (ULTRA HD).mp4"

File: 25MB MP4 video downloaded successfully
```

## System Verification

### yt-dlp Version
```bash
$ yt-dlp --version
2025.09.26  ✅ (up to date)
```

### Cache Directory
```bash
$ ls -la /var/www/.cache
drwxr-xr-x 3 www-data www-data 4096 Oct  1 15:51 .
```

## Files Modified

1. `/opt/pisignage/web/api/youtube.php` - Format selection logic
2. System: Created `/var/www/.cache` with proper permissions

## Impact

- ✅ Downloads now work with modern YouTube format variations
- ✅ Proper fallback handling for unavailable formats
- ✅ Cache directory prevents permission errors
- ✅ MP4 output guaranteed for compatibility

## Prevention

1. **Regular yt-dlp updates** - Keep updated for signature handling
2. **Flexible format selectors** - Always provide fallback options
3. **Cache directory** - Ensure created during installation
4. **Test with various videos** - Different YouTube videos have different format availability

## Related Issues

- BUG-011: yt-dlp installation
- BUG-010: YouTube download 404 error

## Deployment Notes

1. System must have yt-dlp version 2025.09.26 or later
2. Cache directory `/var/www/.cache` must exist with www-data ownership
3. Updated youtube.php includes backward-compatible format selection

---

**Fix verified**: 2025-10-01 15:54 UTC
**Test video**: COSTA RICA IN 4K 60fps HDR (LXb3EKWsInQ)
**Download time**: ~2 seconds for 25MB file
