#!/bin/bash
# PiSignage - Advanced screenshot capture with Wayland/X11 support
# Supports: grim (Wayland), gnome-screenshot (GNOME), scrot (X11), import (X11)

SCREENSHOT_DIR="/tmp"
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
OUTPUT_PATH="$SCREENSHOT_DIR/$FILENAME"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Detect display server
detect_display_server() {
    if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        echo "wayland"
    elif [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "unknown"
    fi
}

# Try capture with grim (Wayland)
capture_with_grim() {
    if command -v grim >/dev/null 2>&1; then
        log_message "Attempting capture with grim..."
        if grim "$1" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Try capture with GNOME Screenshot via D-Bus
capture_with_gnome() {
    if command -v gdbus >/dev/null 2>&1; then
        log_message "Attempting capture with GNOME D-Bus..."
        # Check if GNOME Screenshot service is available
        if gdbus introspect --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot 2>/dev/null | grep -q Screenshot; then
            if gdbus call --session \
                --dest org.gnome.Shell.Screenshot \
                --object-path /org/gnome/Shell/Screenshot \
                --method org.gnome.Shell.Screenshot.Screenshot \
                true false "$1" 2>/dev/null | grep -q true; then
                return 0
            fi
        fi
    fi
    return 1
}

# Try capture with scrot (X11)
capture_with_scrot() {
    if command -v scrot >/dev/null 2>&1; then
        log_message "Attempting capture with scrot..."
        if DISPLAY=${DISPLAY:-:0} scrot -q 90 "$1" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Try capture with import/ImageMagick (X11)
capture_with_import() {
    if command -v import >/dev/null 2>&1; then
        log_message "Attempting capture with ImageMagick import..."
        if DISPLAY=${DISPLAY:-:0} import -window root -quality 90 "$1" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Try capture with fbgrab (framebuffer)
capture_with_fbgrab() {
    if command -v fbgrab >/dev/null 2>&1; then
        log_message "Attempting capture with fbgrab..."
        if fbgrab "$1" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Try capture with raspi2png (Raspberry Pi)
capture_with_raspi2png() {
    if command -v raspi2png >/dev/null 2>&1; then
        log_message "Attempting capture with raspi2png..."
        if raspi2png -p "$1" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Main capture logic
main() {
    local display_server=$(detect_display_server)
    log_message "Detected display server: $display_server"

    # Try methods based on display server
    if [ "$display_server" = "wayland" ]; then
        # Wayland priority: grim > gnome > fallbacks
        capture_with_grim "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_gnome "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_fbgrab "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_raspi2png "$OUTPUT_PATH" && success=1
    else
        # X11 priority: scrot > import > raspi2png > fbgrab
        capture_with_scrot "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_import "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_raspi2png "$OUTPUT_PATH" && success=1
        [ -z "$success" ] && capture_with_fbgrab "$OUTPUT_PATH" && success=1
    fi

    # Check if capture was successful
    if [ -f "$OUTPUT_PATH" ] && [ -s "$OUTPUT_PATH" ]; then
        # Output the path for the calling script
        echo "$OUTPUT_PATH"
        log_message "Screenshot captured successfully: $OUTPUT_PATH"
        exit 0
    else
        log_message "Error: All screenshot methods failed"
        echo "Error: Screenshot failed" >&2
        exit 1
    fi
}

# Handle arguments
case "$1" in
    --test)
        # Test mode: show available methods
        echo "Testing screenshot methods..."
        echo "Display server: $(detect_display_server)"
        echo ""
        echo "Available methods:"
        command -v grim >/dev/null 2>&1 && echo "  ✓ grim (Wayland)"
        command -v gdbus >/dev/null 2>&1 && gdbus introspect --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot 2>/dev/null | grep -q Screenshot && echo "  ✓ GNOME D-Bus (Wayland/X11)"
        command -v scrot >/dev/null 2>&1 && echo "  ✓ scrot (X11)"
        command -v import >/dev/null 2>&1 && echo "  ✓ import/ImageMagick (X11)"
        command -v fbgrab >/dev/null 2>&1 && echo "  ✓ fbgrab (Framebuffer)"
        command -v raspi2png >/dev/null 2>&1 && echo "  ✓ raspi2png (Raspberry Pi)"
        ;;
    --help)
        echo "Usage: $0 [OPTIONS]"
        echo "Capture a screenshot with automatic method detection"
        echo ""
        echo "Options:"
        echo "  --test    Test and show available capture methods"
        echo "  --help    Show this help message"
        echo ""
        echo "Without options, captures a screenshot and outputs the file path"
        ;;
    *)
        main
        ;;
esac