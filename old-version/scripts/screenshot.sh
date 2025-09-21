#!/bin/bash

# PiSignage Screenshot Script - FIXED VERSION
# Returns ONLY the path on stdout

set -e

# CONSISTENT PATH with API
SCREENSHOT_DIR='/opt/pisignage/web/assets/screenshots'
DEFAULT_FILENAME='current.png'
OUTPUT_FILE="${1:-$SCREENSHOT_DIR/$DEFAULT_FILENAME}"
TEMP_FILE="/tmp/pisignage_screenshot_$$.png"

# Create directory
mkdir -p "$SCREENSHOT_DIR"

# Log function (to stderr)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Cleanup
cleanup() {
    [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
}
trap cleanup EXIT

log "Starting screenshot capture to: $OUTPUT_FILE"

# Method 1: scrot (most reliable)
if command -v scrot >/dev/null 2>&1; then
    log "Trying scrot"
    if env DISPLAY=:0 scrot "$TEMP_FILE" -q 80 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "SUCCESS with scrot"
        echo "$OUTPUT_FILE"  # ONLY this on stdout
        exit 0
    fi
fi

# Method 2: ffmpeg framebuffer
if command -v ffmpeg >/dev/null 2>&1; then
    log "Trying ffmpeg framebuffer"
    if ffmpeg -f fbdev -i /dev/fb0 -vframes 1 -y "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "SUCCESS with ffmpeg"
        echo "$OUTPUT_FILE"
        exit 0
    fi
fi

# Method 3: ImageMagick
if command -v import >/dev/null 2>&1; then
    log "Trying ImageMagick import"
    if env DISPLAY=:0 import -window root "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "SUCCESS with import"
        echo "$OUTPUT_FILE"
        exit 0
    fi
fi

# Fallback: placeholder
log "All methods failed, creating placeholder"
if command -v convert >/dev/null 2>&1; then
    convert -size 800x600 xc:lightblue -gravity center -pointsize 24 -fill darkblue -annotate 0 "PiSignage\n\nScreenshot\nnot available\n\n$(date)" "$OUTPUT_FILE"
    log "Placeholder created"
    echo "$OUTPUT_FILE"
    exit 0
fi

log "ERROR: All methods failed"
exit 1
