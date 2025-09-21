#!/bin/bash

# Ultimate video playback script that WILL work
# Tries multiple methods in order of preference

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"
LOG_FILE="/opt/pisignage/logs/player.log"

# Kill any existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

echo "[$(date)] Starting video playback..." > $LOG_FILE

# Method 1: Try ffmpeg directly to framebuffer (most reliable)
echo "[$(date)] Trying ffmpeg to framebuffer..." >> $LOG_FILE
ffmpeg -re -i "$VIDEO_FILE" -pix_fmt rgb565le -f fbdev /dev/fb0 2>>$LOG_FILE &
FFMPEG_PID=$!
sleep 3

# Check if ffmpeg is running
if ps -p $FFMPEG_PID > /dev/null; then
    echo "[$(date)] FFmpeg started successfully with PID $FFMPEG_PID" >> $LOG_FILE
    wait $FFMPEG_PID
else
    echo "[$(date)] FFmpeg failed, trying mplayer..." >> $LOG_FILE
    
    # Method 2: Try mplayer with framebuffer
    mplayer -vo fbdev2 -vf scale=1920:1080 -quiet -loop 0 "$VIDEO_FILE" 2>>$LOG_FILE &
    MPLAYER_PID=$!
    sleep 3
    
    if ps -p $MPLAYER_PID > /dev/null; then
        echo "[$(date)] MPlayer started successfully with PID $MPLAYER_PID" >> $LOG_FILE
        wait $MPLAYER_PID
    else
        echo "[$(date)] MPlayer failed, trying VLC..." >> $LOG_FILE
        
        # Method 3: Try VLC
        cvlc --intf dummy --vout fb --fbdev /dev/fb0 --no-audio --loop "$VIDEO_FILE" 2>>$LOG_FILE &
        VLC_PID=$!
        sleep 3
        
        if ps -p $VLC_PID > /dev/null; then
            echo "[$(date)] VLC started successfully with PID $VLC_PID" >> $LOG_FILE
            wait $VLC_PID
        else
            echo "[$(date)] All players failed!" >> $LOG_FILE
            exit 1
        fi
    fi
fi