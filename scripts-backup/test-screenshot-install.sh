#!/bin/bash
# PiSignage v0.8.0 - Screenshot Installation Test Script
# Tests the screenshot installation without making system changes

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}$1${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_check() {
    local name="$1"
    local status="$2"
    local details="$3"

    if [[ "$status" == "pass" ]]; then
        echo -e "${GREEN}✓${NC} $name${details:+ - $details}"
    elif [[ "$status" == "warn" ]]; then
        echo -e "${YELLOW}⚠${NC} $name${details:+ - $details}"
    else
        echo -e "${RED}✗${NC} $name${details:+ - $details}"
    fi
}

test_prerequisites() {
    print_header "Testing Prerequisites"

    # Check if running on Raspberry Pi
    if [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        local model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' | tail -1)
        print_check "Raspberry Pi Detection" "pass" "$model"
    else
        print_check "Raspberry Pi Detection" "fail" "Not running on Raspberry Pi"
    fi

    # Check PiSignage directory
    if [[ -d /opt/pisignage ]]; then
        print_check "PiSignage Directory" "pass" "/opt/pisignage exists"
    else
        print_check "PiSignage Directory" "fail" "/opt/pisignage not found"
    fi

    # Check write permissions
    if [[ -w /opt/pisignage ]]; then
        print_check "Write Permissions" "pass" "Can write to /opt/pisignage"
    else
        print_check "Write Permissions" "fail" "Cannot write to /opt/pisignage"
    fi

    # Check if script exists
    if [[ -f /opt/pisignage/scripts/install-screenshot.sh ]]; then
        print_check "Install Script" "pass" "Installation script ready"
    else
        print_check "Install Script" "fail" "Installation script not found"
    fi
}

test_system_tools() {
    print_header "Testing System Tools"

    # Package manager
    if command -v apt-get >/dev/null 2>&1; then
        print_check "Package Manager" "pass" "apt-get available"
    else
        print_check "Package Manager" "fail" "apt-get not found"
    fi

    # Build tools
    local build_tools=("gcc" "make" "git" "cmake")
    for tool in "${build_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$($tool --version 2>/dev/null | head -1 || echo "Unknown")
            print_check "Build Tool: $tool" "pass" "$version"
        else
            print_check "Build Tool: $tool" "warn" "Not installed (will be installed)"
        fi
    done

    # System access
    if [[ -r /boot/config.txt ]]; then
        print_check "Boot Config Access" "pass" "Can read /boot/config.txt"
    else
        print_check "Boot Config Access" "warn" "Cannot read /boot/config.txt"
    fi

    if command -v vcgencmd >/dev/null 2>&1; then
        local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | cut -d= -f2 || echo "unknown")
        print_check "GPU Tools" "pass" "vcgencmd available, GPU memory: $gpu_mem"
    else
        print_check "GPU Tools" "warn" "vcgencmd not available"
    fi
}

test_existing_screenshot_tools() {
    print_header "Testing Existing Screenshot Tools"

    local tools=(
        "raspi2png:Hardware acceleration"
        "scrot:X11 screenshot"
        "import:ImageMagick"
        "fbgrab:Framebuffer capture"
        "gnome-screenshot:GNOME screenshot"
    )

    for tool_info in "${tools[@]}"; do
        local tool="${tool_info%%:*}"
        local desc="${tool_info##*:}"

        if command -v "$tool" >/dev/null 2>&1; then
            print_check "$tool" "pass" "$desc - Already installed"
        else
            print_check "$tool" "warn" "$desc - Will be installed"
        fi
    done
}

test_display_environment() {
    print_header "Testing Display Environment"

    # X11 display
    if [[ -n "${DISPLAY:-}" ]]; then
        print_check "X11 Display" "pass" "DISPLAY=$DISPLAY"
    else
        print_check "X11 Display" "warn" "No DISPLAY set (normal for headless)"
    fi

    # Framebuffer
    if [[ -c /dev/fb0 ]]; then
        print_check "Framebuffer" "pass" "/dev/fb0 available"
    else
        print_check "Framebuffer" "warn" "/dev/fb0 not found"
    fi

    # Graphics memory
    if [[ -f /boot/config.txt ]]; then
        local gpu_mem=$(grep "^gpu_mem=" /boot/config.txt | cut -d= -f2 || echo "default")
        if [[ "$gpu_mem" == "default" ]]; then
            print_check "GPU Memory" "warn" "Not configured (will be set to 256MB)"
        else
            if [[ ${gpu_mem%M} -ge 128 ]]; then
                print_check "GPU Memory" "pass" "${gpu_mem}MB configured"
            else
                print_check "GPU Memory" "warn" "${gpu_mem}MB (will be increased to 256MB)"
            fi
        fi
    fi
}

test_network_access() {
    print_header "Testing Network Access"

    # GitHub access for raspi2png
    if timeout 5s wget -q --spider https://github.com 2>/dev/null; then
        print_check "GitHub Access" "pass" "Can reach github.com"
    else
        print_check "GitHub Access" "fail" "Cannot reach github.com"
    fi

    # Package repositories
    if timeout 5s wget -q --spider http://raspbian.raspberrypi.org 2>/dev/null; then
        print_check "Raspbian Repository" "pass" "Can reach package repository"
    else
        print_check "Raspbian Repository" "warn" "Cannot reach raspbian repository"
    fi
}

test_current_screenshot_setup() {
    print_header "Testing Current Screenshot Setup"

    # Current screenshot script
    if [[ -f /opt/pisignage/scripts/screenshot.sh ]]; then
        if [[ -x /opt/pisignage/scripts/screenshot.sh ]]; then
            print_check "Current Script" "pass" "Executable screenshot script exists"

            # Test status command
            if /opt/pisignage/scripts/screenshot.sh status >/dev/null 2>&1; then
                print_check "Script Functionality" "pass" "Status command works"
            else
                print_check "Script Functionality" "warn" "Status command failed"
            fi
        else
            print_check "Current Script" "warn" "Script exists but not executable"
        fi
    else
        print_check "Current Script" "warn" "No existing screenshot script"
    fi

    # Screenshot directory
    if [[ -d /opt/pisignage/screenshots ]]; then
        local count=$(ls -1 /opt/pisignage/screenshots/*.png 2>/dev/null | wc -l)
        print_check "Screenshot Directory" "pass" "$count existing screenshots"
    else
        print_check "Screenshot Directory" "warn" "Directory will be created"
    fi
}

estimate_installation_impact() {
    print_header "Installation Impact Estimation"

    # Disk space
    local available_space=$(df /opt/pisignage | tail -1 | awk '{print $4}')
    local available_mb=$((available_space / 1024))

    if [[ $available_mb -gt 500 ]]; then
        print_check "Disk Space" "pass" "${available_mb}MB available (>500MB required)"
    elif [[ $available_mb -gt 200 ]]; then
        print_check "Disk Space" "warn" "${available_mb}MB available (marginal)"
    else
        print_check "Disk Space" "fail" "${available_mb}MB available (<200MB required)"
    fi

    # Reboot requirement
    print_check "Reboot Required" "warn" "System reboot needed after installation"

    # Service impact
    if systemctl is-active --quiet nginx 2>/dev/null; then
        print_check "Web Server Impact" "pass" "nginx running (no impact expected)"
    else
        print_check "Web Server Impact" "warn" "nginx not running"
    fi

    if pgrep vlc >/dev/null 2>&1; then
        print_check "VLC Impact" "warn" "VLC running (no impact expected)"
    else
        print_check "VLC Impact" "pass" "VLC not running"
    fi
}

show_installation_summary() {
    print_header "Installation Summary"

    echo -e "${BLUE}What will be installed:${NC}"
    echo "• raspi2png (compiled from source)"
    echo "• Screenshot tools: scrot, imagemagick, fbgrab"
    echo "• Build dependencies: gcc, make, cmake, git"
    echo "• PNG libraries: libpng-dev"
    echo ""

    echo -e "${BLUE}What will be configured:${NC}"
    echo "• /boot/config.txt: GPU memory, display driver"
    echo "• Shared memory cache in /dev/shm"
    echo "• systemd service for automatic screenshots"
    echo "• Enhanced screenshot script with hardware acceleration"
    echo ""

    echo -e "${BLUE}What will be backed up:${NC}"
    echo "• Current /boot/config.txt"
    echo "• Existing screenshot script"
    echo "• Restore script for rollback"
    echo ""

    echo -e "${YELLOW}To proceed with installation:${NC}"
    echo "sudo /opt/pisignage/scripts/install-screenshot.sh"
    echo ""

    echo -e "${YELLOW}To test without installation:${NC}"
    echo "/opt/pisignage/scripts/install-screenshot.sh --dry-run"
}

main() {
    print_header "PiSignage Screenshot Installation Readiness Test"

    test_prerequisites
    test_system_tools
    test_existing_screenshot_tools
    test_display_environment
    test_network_access
    test_current_screenshot_setup
    estimate_installation_impact
    show_installation_summary

    echo -e "\n${GREEN}Pre-installation testing completed.${NC}"
    echo -e "Review the results above before proceeding with installation.\n"
}

main "$@"