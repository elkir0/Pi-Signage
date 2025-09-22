#!/bin/bash
# PiSignage v0.8.0 - Screenshot Script
# Takes screenshots of the current display

SCREENSHOT_DIR="/opt/pisignage/screenshots"
LOG_FILE="/opt/pisignage/logs/screenshot.log"
MAX_SCREENSHOTS=50  # Keep only the last 50 screenshots

# Create directories if they don't exist
mkdir -p "$SCREENSHOT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

take_screenshot() {
    local filename="$1"
    local method="$2"

    if [[ -z "$filename" ]]; then
        filename="screenshot-$(date '+%Y%m%d-%H%M%S').png"
    fi

    local filepath="$SCREENSHOT_DIR/$filename"

    log_message "Taking screenshot: $filename (method: $method)"

    case "$method" in
        "scrot")
            if command -v scrot >/dev/null 2>&1; then
                scrot -z "$filepath" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_message "Screenshot taken successfully with scrot: $filepath"
                    echo "$filepath"
                    return 0
                else
                    log_message "Failed to take screenshot with scrot"
                    return 1
                fi
            fi
            ;;
        "import")
            if command -v import >/dev/null 2>&1; then
                DISPLAY=:0 import -window root "$filepath" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_message "Screenshot taken successfully with ImageMagick: $filepath"
                    echo "$filepath"
                    return 0
                else
                    log_message "Failed to take screenshot with ImageMagick"
                    return 1
                fi
            fi
            ;;
        "gnome-screenshot")
            if command -v gnome-screenshot >/dev/null 2>&1; then
                DISPLAY=:0 gnome-screenshot -f "$filepath" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_message "Screenshot taken successfully with gnome-screenshot: $filepath"
                    echo "$filepath"
                    return 0
                else
                    log_message "Failed to take screenshot with gnome-screenshot"
                    return 1
                fi
            fi
            ;;
        "xwd")
            if command -v xwd >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
                DISPLAY=:0 xwd -root | convert xwd:- "$filepath" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_message "Screenshot taken successfully with xwd: $filepath"
                    echo "$filepath"
                    return 0
                else
                    log_message "Failed to take screenshot with xwd"
                    return 1
                fi
            fi
            ;;
        "fbgrab")
            if command -v fbgrab >/dev/null 2>&1; then
                fbgrab "$filepath" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_message "Screenshot taken successfully with fbgrab: $filepath"
                    echo "$filepath"
                    return 0
                else
                    log_message "Failed to take screenshot with fbgrab"
                    return 1
                fi
            fi
            ;;
    esac

    return 1
}

auto_detect_method() {
    local methods=("scrot" "import" "gnome-screenshot" "xwd" "fbgrab")

    for method in "${methods[@]}"; do
        case "$method" in
            "scrot")
                command -v scrot >/dev/null 2>&1 && echo "scrot" && return
                ;;
            "import")
                command -v import >/dev/null 2>&1 && echo "import" && return
                ;;
            "gnome-screenshot")
                command -v gnome-screenshot >/dev/null 2>&1 && echo "gnome-screenshot" && return
                ;;
            "xwd")
                command -v xwd >/dev/null 2>&1 && command -v convert >/dev/null 2>&1 && echo "xwd" && return
                ;;
            "fbgrab")
                command -v fbgrab >/dev/null 2>&1 && echo "fbgrab" && return
                ;;
        esac
    done

    echo "none"
}

take_screenshot_auto() {
    local filename="$1"
    local method=$(auto_detect_method)

    if [[ "$method" == "none" ]]; then
        log_message "No screenshot method available"
        echo "Error: No screenshot tool found"
        return 1
    fi

    log_message "Auto-detected screenshot method: $method"
    take_screenshot "$filename" "$method"
}

cleanup_old_screenshots() {
    local count=$(ls -1 "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | wc -l)

    if [[ $count -gt $MAX_SCREENSHOTS ]]; then
        local to_remove=$((count - MAX_SCREENSHOTS))
        log_message "Removing $to_remove old screenshots (keeping last $MAX_SCREENSHOTS)"

        # Remove oldest files
        ls -1t "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | tail -n "+$((MAX_SCREENSHOTS + 1))" | xargs rm -f

        log_message "Cleanup completed"
    fi
}

list_screenshots() {
    if [[ ! -d "$SCREENSHOT_DIR" ]]; then
        echo "No screenshots directory found"
        return 1
    fi

    echo "Available screenshots:"
    ls -lht "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | head -20
}

get_latest_screenshot() {
    local latest=$(ls -1t "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | head -1)

    if [[ -n "$latest" ]]; then
        echo "$latest"
        return 0
    else
        echo "No screenshots found"
        return 1
    fi
}

show_status() {
    echo "Screenshot Tool Status:"
    echo "======================="
    echo "Screenshot directory: $SCREENSHOT_DIR"
    echo "Log file: $LOG_FILE"
    echo "Max screenshots kept: $MAX_SCREENSHOTS"
    echo ""

    echo "Available screenshot methods:"
    command -v scrot >/dev/null 2>&1 && echo "  ✓ scrot" || echo "  ✗ scrot"
    command -v import >/dev/null 2>&1 && echo "  ✓ ImageMagick (import)" || echo "  ✗ ImageMagick (import)"
    command -v gnome-screenshot >/dev/null 2>&1 && echo "  ✓ gnome-screenshot" || echo "  ✗ gnome-screenshot"
    command -v xwd >/dev/null 2>&1 && command -v convert >/dev/null 2>&1 && echo "  ✓ xwd + convert" || echo "  ✗ xwd + convert"
    command -v fbgrab >/dev/null 2>&1 && echo "  ✓ fbgrab" || echo "  ✗ fbgrab"

    echo ""
    echo "Auto-detected method: $(auto_detect_method)"

    echo ""
    local count=$(ls -1 "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | wc -l)
    echo "Current screenshots: $count"

    if [[ $count -gt 0 ]]; then
        echo "Latest screenshot: $(basename "$(get_latest_screenshot)")"
    fi
}

# Main script logic
case "$1" in
    take|capture)
        filename="$2"
        method="$3"

        if [[ -n "$method" ]]; then
            take_screenshot "$filename" "$method"
        else
            take_screenshot_auto "$filename"
        fi

        if [[ $? -eq 0 ]]; then
            cleanup_old_screenshots
        fi
        ;;
    auto)
        take_screenshot_auto "$2"
        if [[ $? -eq 0 ]]; then
            cleanup_old_screenshots
        fi
        ;;
    list)
        list_screenshots
        ;;
    latest)
        get_latest_screenshot
        ;;
    cleanup)
        cleanup_old_screenshots
        ;;
    status)
        show_status
        ;;
    install-deps)
        echo "Installing screenshot dependencies..."
        sudo apt-get update
        sudo apt-get install -y scrot imagemagick
        echo "Dependencies installed"
        ;;
    *)
        echo "Usage: $0 {take|auto|list|latest|cleanup|status|install-deps} [filename] [method]"
        echo ""
        echo "Commands:"
        echo "  take [filename] [method]  - Take a screenshot with optional filename and method"
        echo "  auto [filename]           - Take a screenshot using auto-detected method"
        echo "  list                      - List available screenshots"
        echo "  latest                    - Show path to latest screenshot"
        echo "  cleanup                   - Remove old screenshots (keep last $MAX_SCREENSHOTS)"
        echo "  status                    - Show screenshot tool status"
        echo "  install-deps              - Install screenshot dependencies"
        echo ""
        echo "Available methods: scrot, import, gnome-screenshot, xwd, fbgrab"
        echo "If no method is specified, auto-detection will be used"
        exit 1
        ;;
esac

exit $?