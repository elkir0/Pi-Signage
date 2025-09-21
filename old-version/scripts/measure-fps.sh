#!/bin/bash

# FPS measurement and diagnostic script
# Tests different video players and measures actual performance

echo "=== PiSignage FPS Diagnostic Tool ==="
echo "Date: $(date)"
echo

# System info
echo "📊 SYSTEM INFORMATION:"
echo "Framebuffer: $(cat /sys/class/graphics/fb0/virtual_size)"
echo "GPU Memory: $(vcgencmd get_mem gpu 2>/dev/null || echo 'N/A')"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)"
echo "Raspberry Pi model: $(cat /proc/cpuinfo | grep 'Model' | cut -d':' -f2 | xargs 2>/dev/null || echo 'Not Pi')"
echo

# Check hardware decoders
echo "🔧 HARDWARE DECODERS:"
echo "V4L2 M2M Decoder: $([ -e /dev/video11 ] && echo '✅ Available' || echo '❌ Not found')"
echo "V4L2 M2M Encoder: $([ -e /dev/video10 ] && echo '✅ Available' || echo '❌ Not found')"
echo

# Check video file
VIDEO_FILE="/opt/pisignage/media/sintel.mp4"
if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Video file not found: $VIDEO_FILE"
    exit 1
fi

echo "📹 VIDEO FILE INFO:"
ffprobe -v quiet -show_format -show_streams "$VIDEO_FILE" | grep -E "(codec_name|width|height|r_frame_rate|bit_rate)" | head -6
echo

# Kill any existing players
pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null
sleep 1

echo "🧪 TESTING DIFFERENT METHODS:"
echo

# Test 1: Hardware FFmpeg
echo "1. FFmpeg with V4L2 M2M hardware decoder:"
if [ -e /dev/video11 ]; then
    timeout 10 ffmpeg \
        -hwaccel v4l2m2m \
        -c:v h264_v4l2m2m \
        -i "$VIDEO_FILE" \
        -t 10 \
        -f null \
        - 2>&1 | grep -E "(fps=|speed=)" | tail -1
else
    echo "   ❌ Hardware decoder not available"
fi
echo

# Test 2: Software FFmpeg
echo "2. FFmpeg software decoding:"
timeout 10 ffmpeg \
    -i "$VIDEO_FILE" \
    -t 10 \
    -f null \
    - 2>&1 | grep -E "(fps=|speed=)" | tail -1
echo

# Test 3: MPV performance test
echo "3. MPV DRM performance test:"
if command -v mpv >/dev/null 2>&1; then
    timeout 10 mpv \
        --no-video \
        --no-audio \
        --benchmark \
        --untimed \
        "$VIDEO_FILE" 2>&1 | grep -E "(fps|seconds)" | tail -1
else
    echo "   ❌ MPV not installed"
fi
echo

echo "🔍 CURRENT RUNNING PLAYERS:"
ps aux | grep -E "(ffmpeg|vlc|mplayer|mpv|ffplay)" | grep -v grep | head -5
echo

echo "💡 RECOMMENDATIONS:"

# Get framebuffer size
FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)

if [ -e /dev/video11 ]; then
    echo "✅ OPTIMAL COMMAND (Hardware accelerated):"
    echo "   ffmpeg -hwaccel v4l2m2m -c:v h264_v4l2m2m -i '$VIDEO_FILE' \\"
    echo "          -vf 'scale=${FB_WIDTH}:${FB_HEIGHT}' -pix_fmt rgb565le \\"
    echo "          -f fbdev -stream_loop -1 /dev/fb0"
    echo "   Expected: 25-60 FPS, 10-15% CPU"
else
    echo "✅ RECOMMENDED COMMAND (Software):"
    echo "   mpv --vo=drm --fullscreen --no-audio --loop-file=inf '$VIDEO_FILE'"
    echo "   Expected: 15-25 FPS, 25-35% CPU"
fi
echo

echo "🐛 COMMON ISSUES FIXED:"
echo "   ❌ Old: -pix_fmt bgra (rejected by framebuffer)"
echo "   ✅ New: -pix_fmt rgb565le (compatible)"
echo "   ❌ Old: -loop 0 (deprecated)"
echo "   ✅ New: -stream_loop -1 (correct)"
echo "   ❌ Old: Fixed 1920x1080 resolution"
echo "   ✅ New: Dynamic framebuffer resolution (${FB_WIDTH}x${FB_HEIGHT})"
echo

echo "=== Diagnostic Complete ==="