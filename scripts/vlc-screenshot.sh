#!/bin/bash
# PiSignage - VLC Screenshot via streaming capture
# Solution pour capturer VLC en mode DRM/KMS

OUTPUT_FILE="${1:-/tmp/vlc-screenshot.png}"

# Method 1: Try to capture from VLC HTTP stream if available
if curl -s http://localhost:8080/snapshot &>/dev/null; then
    curl -s http://localhost:8080/snapshot -o "$OUTPUT_FILE"
    if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        echo "$OUTPUT_FILE"
        exit 0
    fi
fi

# Method 2: Capture a frame from VLC using ffmpeg
VLC_PID=$(pgrep -x vlc)
if [ -n "$VLC_PID" ]; then
    # Get the video file being played
    VIDEO_FILE=$(ps aux | grep vlc | grep -o '/[^[:space:]]*\.mp4' | head -1)

    if [ -n "$VIDEO_FILE" ] && [ -f "$VIDEO_FILE" ]; then
        # Get current playback position (approximate)
        # For simplicity, capture a frame at 10 seconds
        ffmpeg -ss 10 -i "$VIDEO_FILE" -vframes 1 -q:v 2 "$OUTPUT_FILE" -y &>/dev/null

        if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
            echo "$OUTPUT_FILE"
            exit 0
        fi
    fi
fi

# Method 3: Fallback to fbgrab
if command -v fbgrab >/dev/null 2>&1; then
    fbgrab "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        echo "$OUTPUT_FILE"
        exit 0
    fi
fi

echo "Error: Screenshot failed"
exit 1