#!/bin/bash
# PiSignage - Simple screenshot capture

# Take screenshot with scrot and save to /tmp
DISPLAY=:0 scrot -q 75 /tmp/screenshot.jpg 2>/dev/null

# Return the path if successful
if [ -f /tmp/screenshot.jpg ]; then
    echo "/tmp/screenshot.jpg"
else
    echo "Error: Screenshot failed"
    exit 1
fi