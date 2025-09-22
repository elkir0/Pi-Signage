#!/bin/bash
# PiSignage v0.8.0 - Screenshot Hardware Installation Script
# Installs and configures optimized screenshot functionality for Raspberry Pi
# Supports Pi 3/4/5 with multiple fallback methods

set -euo pipefail

# Configuration
SCRIPT_NAME="install-screenshot.sh"
LOG_FILE="/opt/pisignage/logs/screenshot-install.log"
BACKUP_DIR="/opt/pisignage/backup/screenshot-install-$(date +%Y%m%d-%H%M%S)"
BUILD_DIR="/tmp/pisignage-screenshot-build"
RASPI2PNG_URL="https://github.com/AndrewFromMelbourne/raspi2png.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
PI_MODEL=""
OS_VERSION=""
GPU_MEM_CURRENT=""
DISPLAY_DRIVER=""
INSTALL_ERRORS=()

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Colored output functions
print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}$1${NC} ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}➤${NC} $1"
    log_message "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log_message "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log_message "ERROR" "$1"
    INSTALL_ERRORS+=("$1")
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
    log_message "INFO" "$1"
}

# System detection functions
detect_pi_model() {
    print_step "Detecting Raspberry Pi model..."

    if [[ -f /proc/cpuinfo ]]; then
        local revision=$(grep "Revision" /proc/cpuinfo | awk '{print $3}' | tail -1)
        local model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' | tail -1)

        if [[ -n "$model" ]]; then
            PI_MODEL="$model"
            print_success "Detected: $PI_MODEL (Revision: $revision)"
        else
            PI_MODEL="Unknown"
            print_warning "Could not detect Pi model, assuming generic"
        fi
    else
        PI_MODEL="Unknown"
        print_error "Cannot read /proc/cpuinfo"
        return 1
    fi
}

detect_os_version() {
    print_step "Detecting OS version..."

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_VERSION="$PRETTY_NAME"
        print_success "OS: $OS_VERSION"
    else
        OS_VERSION="Unknown"
        print_warning "Could not detect OS version"
    fi
}

detect_display_config() {
    print_step "Analyzing display configuration..."

    # Check GPU memory
    if command -v vcgencmd >/dev/null 2>&1; then
        GPU_MEM_CURRENT=$(vcgencmd get_mem gpu | cut -d= -f2)
        print_info "Current GPU memory: $GPU_MEM_CURRENT"
    else
        print_warning "vcgencmd not available, cannot check GPU memory"
    fi

    # Check display driver
    if [[ -f /boot/config.txt ]]; then
        if grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
            DISPLAY_DRIVER="KMS (vc4-kms-v3d)"
        elif grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
            DISPLAY_DRIVER="FKMS (vc4-fkms-v3d)"
        else
            DISPLAY_DRIVER="Legacy"
        fi
        print_info "Display driver: $DISPLAY_DRIVER"
    else
        print_warning "Cannot access /boot/config.txt"
    fi
}

# Backup functions
create_backup() {
    print_step "Creating backup of current configuration..."

    mkdir -p "$BACKUP_DIR"

    # Backup boot config
    if [[ -f /boot/config.txt ]]; then
        cp /boot/config.txt "$BACKUP_DIR/config.txt.backup"
        print_success "Backed up /boot/config.txt"
    fi

    # Backup existing screenshot script
    if [[ -f /opt/pisignage/scripts/screenshot.sh ]]; then
        cp /opt/pisignage/scripts/screenshot.sh "$BACKUP_DIR/screenshot.sh.backup"
        print_success "Backed up existing screenshot script"
    fi

    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Screenshot installation restore script

echo "Restoring screenshot installation backup..."

if [[ -f config.txt.backup ]]; then
    sudo cp config.txt.backup /boot/config.txt
    echo "Restored /boot/config.txt"
fi

if [[ -f screenshot.sh.backup ]]; then
    cp screenshot.sh.backup /opt/pisignage/scripts/screenshot.sh
    echo "Restored screenshot script"
fi

echo "Restore completed. Reboot required for boot config changes."
EOF

    chmod +x "$BACKUP_DIR/restore.sh"
    print_success "Created restore script at $BACKUP_DIR/restore.sh"
}

# Installation functions
install_dependencies() {
    print_step "Installing system dependencies..."

    # Update package list
    print_info "Updating package list..."
    if ! sudo apt-get update -qq; then
        print_error "Failed to update package list"
        return 1
    fi

    # Core dependencies for building
    local build_deps=(
        "build-essential"
        "cmake"
        "git"
        "libpng-dev"
        "libpng16-16"
        "pkg-config"
    )

    # Screenshot tools (fallbacks)
    local screenshot_deps=(
        "scrot"
        "imagemagick"
        "fbgrab"
        "xserver-xorg-core"
        "x11-apps"
    )

    # Install build dependencies
    print_info "Installing build dependencies..."
    for dep in "${build_deps[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            print_info "Installing $dep..."
            if sudo apt-get install -y "$dep" >/dev/null 2>&1; then
                print_success "Installed $dep"
            else
                print_error "Failed to install $dep"
            fi
        else
            print_info "$dep already installed"
        fi
    done

    # Install screenshot tools
    print_info "Installing screenshot tools..."
    for dep in "${screenshot_deps[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            print_info "Installing $dep..."
            if sudo apt-get install -y "$dep" >/dev/null 2>&1; then
                print_success "Installed $dep"
            else
                print_warning "Failed to install $dep (non-critical)"
            fi
        else
            print_info "$dep already installed"
        fi
    done
}

build_raspi2png() {
    print_step "Building raspi2png from source..."

    # Clean build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Clone repository
    print_info "Cloning raspi2png repository..."
    if ! git clone "$RASPI2PNG_URL" raspi2png; then
        print_error "Failed to clone raspi2png repository"
        return 1
    fi

    cd raspi2png

    # Build
    print_info "Compiling raspi2png..."
    if ! make; then
        print_error "Failed to compile raspi2png"
        return 1
    fi

    # Install
    print_info "Installing raspi2png..."
    if ! sudo make install; then
        print_error "Failed to install raspi2png"
        return 1
    fi

    # Verify installation
    if command -v raspi2png >/dev/null 2>&1; then
        local version=$(raspi2png -h 2>&1 | head -1 || echo "Unknown version")
        print_success "raspi2png installed successfully: $version"
    else
        print_error "raspi2png installation verification failed"
        return 1
    fi

    # Clean up
    cd /
    rm -rf "$BUILD_DIR"
}

configure_boot_settings() {
    print_step "Configuring boot settings for optimal screenshot performance..."

    if [[ ! -f /boot/config.txt ]]; then
        print_error "/boot/config.txt not found"
        return 1
    fi

    local config_changes=0
    local temp_config="/tmp/config.txt.new"
    cp /boot/config.txt "$temp_config"

    # Set GPU memory to 256MB for better performance
    if ! grep -q "^gpu_mem=" /boot/config.txt; then
        echo "gpu_mem=256" >> "$temp_config"
        print_info "Added gpu_mem=256"
        config_changes=1
    else
        # Update existing value
        sed -i 's/^gpu_mem=.*/gpu_mem=256/' "$temp_config"
        print_info "Updated gpu_mem to 256"
        config_changes=1
    fi

    # Enable camera interface if not present (helps with display capture)
    if ! grep -q "^start_x=" /boot/config.txt && ! grep -q "^camera_auto_detect=" /boot/config.txt; then
        echo "start_x=1" >> "$temp_config"
        print_info "Added start_x=1 for camera interface"
        config_changes=1
    fi

    # Optimize display driver for Pi 4/5
    if [[ "$PI_MODEL" =~ "Raspberry Pi 4" ]] || [[ "$PI_MODEL" =~ "Raspberry Pi 5" ]]; then
        if ! grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
            # Remove any existing vc4 overlays
            sed -i '/^dtoverlay=vc4-/d' "$temp_config"
            echo "dtoverlay=vc4-fkms-v3d" >> "$temp_config"
            print_info "Added vc4-fkms-v3d overlay for Pi 4/5"
            config_changes=1
        fi
    fi

    # Apply changes if any were made
    if [[ $config_changes -eq 1 ]]; then
        sudo cp "$temp_config" /boot/config.txt
        print_success "Boot configuration updated"
        print_warning "Reboot required for changes to take effect"
    else
        print_info "Boot configuration already optimal"
    fi

    rm -f "$temp_config"
}

configure_shared_memory() {
    print_step "Configuring shared memory for screenshot cache..."

    # Create directory in /dev/shm for fast screenshot operations
    local shm_dir="/dev/shm/pisignage"
    if [[ ! -d "$shm_dir" ]]; then
        mkdir -p "$shm_dir"
        chmod 755 "$shm_dir"
        print_success "Created shared memory directory: $shm_dir"
    fi

    # Add to fstab for persistence if not already there
    if ! grep -q "tmpfs.*pisignage" /etc/fstab; then
        echo "tmpfs /dev/shm/pisignage tmpfs defaults,size=64m,uid=$(id -u),gid=$(id -g) 0 0" | sudo tee -a /etc/fstab >/dev/null
        print_success "Added shared memory mount to /etc/fstab"
    fi
}

create_systemd_service() {
    print_step "Creating systemd service for automatic screenshots..."

    local service_file="/etc/systemd/system/pisignage-screenshot.service"

    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=PiSignage Screenshot Service
After=graphical.target
Wants=graphical.target

[Service]
Type=oneshot
User=pi
Group=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStart=/opt/pisignage/scripts/screenshot.sh auto
WorkingDirectory=/opt/pisignage
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer for periodic screenshots
    local timer_file="/etc/systemd/system/pisignage-screenshot.timer"

    sudo tee "$timer_file" > /dev/null << EOF
[Unit]
Description=PiSignage Screenshot Timer
Requires=pisignage-screenshot.service

[Timer]
OnBootSec=60s
OnUnitActiveSec=300s
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable services
    sudo systemctl daemon-reload

    if sudo systemctl enable pisignage-screenshot.timer; then
        print_success "Enabled automatic screenshot timer (every 5 minutes)"
    else
        print_error "Failed to enable screenshot timer"
    fi
}

update_screenshot_script() {
    print_step "Updating screenshot script with hardware acceleration..."

    local script_path="/opt/pisignage/scripts/screenshot.sh"
    local temp_script="/tmp/screenshot.sh.new"

    # Create enhanced screenshot script
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# PiSignage v0.8.0 - Enhanced Screenshot Script with Hardware Acceleration
# Optimized for Raspberry Pi with multiple fallback methods

SCREENSHOT_DIR="/opt/pisignage/screenshots"
SHM_DIR="/dev/shm/pisignage"
LOG_FILE="/opt/pisignage/logs/screenshot.log"
MAX_SCREENSHOTS=50

# Create directories
mkdir -p "$SCREENSHOT_DIR" "$SHM_DIR" "$(dirname "$LOG_FILE")"

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
    local temp_file="$SHM_DIR/temp_$(basename "$filename")"

    log_message "Taking screenshot: $filename (method: $method)"

    case "$method" in
        "raspi2png")
            if command -v raspi2png >/dev/null 2>&1; then
                # Use hardware acceleration for best performance
                if raspi2png -p "$temp_file" 2>/dev/null; then
                    mv "$temp_file" "$filepath" 2>/dev/null
                    log_message "Screenshot taken with raspi2png (hardware): $filepath"
                    echo "$filepath"
                    return 0
                fi
            fi
            ;;
        "scrot")
            if command -v scrot >/dev/null 2>&1; then
                DISPLAY=:0 scrot -z "$temp_file" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    mv "$temp_file" "$filepath" 2>/dev/null
                    log_message "Screenshot taken with scrot: $filepath"
                    echo "$filepath"
                    return 0
                fi
            fi
            ;;
        "import")
            if command -v import >/dev/null 2>&1; then
                DISPLAY=:0 import -window root "$temp_file" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    mv "$temp_file" "$filepath" 2>/dev/null
                    log_message "Screenshot taken with ImageMagick: $filepath"
                    echo "$filepath"
                    return 0
                fi
            fi
            ;;
        "fbgrab")
            if command -v fbgrab >/dev/null 2>&1; then
                fbgrab "$temp_file" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    mv "$temp_file" "$filepath" 2>/dev/null
                    log_message "Screenshot taken with fbgrab: $filepath"
                    echo "$filepath"
                    return 0
                fi
            fi
            ;;
    esac

    return 1
}

auto_detect_method() {
    # Try hardware acceleration first, then fallbacks
    local methods=("raspi2png" "scrot" "import" "fbgrab")

    for method in "${methods[@]}"; do
        case "$method" in
            "raspi2png")
                command -v raspi2png >/dev/null 2>&1 && echo "raspi2png" && return
                ;;
            "scrot")
                command -v scrot >/dev/null 2>&1 && echo "scrot" && return
                ;;
            "import")
                command -v import >/dev/null 2>&1 && echo "import" && return
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
        ls -1t "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | tail -n "+$((MAX_SCREENSHOTS + 1))" | xargs rm -f
        log_message "Cleanup completed"
    fi
}

show_status() {
    echo "Screenshot Tool Status (Hardware Optimized):"
    echo "============================================="
    echo "Screenshot directory: $SCREENSHOT_DIR"
    echo "Shared memory cache: $SHM_DIR"
    echo "Log file: $LOG_FILE"
    echo "Max screenshots kept: $MAX_SCREENSHOTS"
    echo ""

    echo "Available screenshot methods:"
    command -v raspi2png >/dev/null 2>&1 && echo "  ✓ raspi2png (hardware)" || echo "  ✗ raspi2png (hardware)"
    command -v scrot >/dev/null 2>&1 && echo "  ✓ scrot" || echo "  ✗ scrot"
    command -v import >/dev/null 2>&1 && echo "  ✓ ImageMagick (import)" || echo "  ✗ ImageMagick (import)"
    command -v fbgrab >/dev/null 2>&1 && echo "  ✓ fbgrab" || echo "  ✗ fbgrab"

    echo ""
    echo "Auto-detected method: $(auto_detect_method)"

    local count=$(ls -1 "$SCREENSHOT_DIR"/screenshot-*.png 2>/dev/null | wc -l)
    echo "Current screenshots: $count"
}

# Main script logic
case "$1" in
    take|capture|auto)
        take_screenshot_auto "$2"
        if [[ $? -eq 0 ]]; then
            cleanup_old_screenshots
        fi
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup_old_screenshots
        ;;
    *)
        echo "Usage: $0 {take|auto|status|cleanup} [filename]"
        echo "Enhanced with hardware acceleration (raspi2png)"
        exit 1
        ;;
esac

exit $?
EOF

    # Install the enhanced script
    if cp "$temp_script" "$script_path"; then
        chmod +x "$script_path"
        print_success "Updated screenshot script with hardware acceleration"
    else
        print_error "Failed to update screenshot script"
        return 1
    fi

    rm -f "$temp_script"
}

test_screenshot_methods() {
    print_step "Testing all screenshot methods..."

    local test_dir="/tmp/screenshot-test"
    mkdir -p "$test_dir"

    local methods=("raspi2png" "scrot" "import" "fbgrab")
    local working_methods=()

    for method in "${methods[@]}"; do
        local test_file="$test_dir/test-$method.png"

        print_info "Testing $method..."

        case "$method" in
            "raspi2png")
                if command -v raspi2png >/dev/null 2>&1; then
                    if timeout 10s raspi2png -p "$test_file" 2>/dev/null; then
                        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
                            working_methods+=("$method")
                            print_success "$method: Working"
                        else
                            print_warning "$method: Command succeeded but no valid file created"
                        fi
                    else
                        print_warning "$method: Command failed or timed out"
                    fi
                else
                    print_info "$method: Not installed"
                fi
                ;;
            "scrot")
                if command -v scrot >/dev/null 2>&1; then
                    if timeout 10s env DISPLAY=:0 scrot "$test_file" 2>/dev/null; then
                        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
                            working_methods+=("$method")
                            print_success "$method: Working"
                        else
                            print_warning "$method: Command succeeded but no valid file created"
                        fi
                    else
                        print_warning "$method: Command failed or timed out"
                    fi
                else
                    print_info "$method: Not installed"
                fi
                ;;
            "import")
                if command -v import >/dev/null 2>&1; then
                    if timeout 10s env DISPLAY=:0 import -window root "$test_file" 2>/dev/null; then
                        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
                            working_methods+=("$method")
                            print_success "$method: Working"
                        else
                            print_warning "$method: Command succeeded but no valid file created"
                        fi
                    else
                        print_warning "$method: Command failed or timed out"
                    fi
                else
                    print_info "$method: Not installed"
                fi
                ;;
            "fbgrab")
                if command -v fbgrab >/dev/null 2>&1; then
                    if timeout 10s fbgrab "$test_file" 2>/dev/null; then
                        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
                            working_methods+=("$method")
                            print_success "$method: Working"
                        else
                            print_warning "$method: Command succeeded but no valid file created"
                        fi
                    else
                        print_warning "$method: Command failed or timed out"
                    fi
                else
                    print_info "$method: Not installed"
                fi
                ;;
        esac

        # Clean up test file
        rm -f "$test_file"
    done

    # Summary
    if [[ ${#working_methods[@]} -gt 0 ]]; then
        print_success "Working screenshot methods: ${working_methods[*]}"
        print_info "Recommended method: ${working_methods[0]}"
    else
        print_error "No working screenshot methods found"
        return 1
    fi

    # Clean up test directory
    rm -rf "$test_dir"
}

run_final_validation() {
    print_step "Running final validation..."

    local validation_errors=0

    # Test screenshot script
    if [[ -x /opt/pisignage/scripts/screenshot.sh ]]; then
        print_success "Screenshot script is executable"
    else
        print_error "Screenshot script is not executable"
        validation_errors=$((validation_errors + 1))
    fi

    # Test auto screenshot
    print_info "Testing automatic screenshot..."
    if /opt/pisignage/scripts/screenshot.sh auto test-install.png >/dev/null 2>&1; then
        print_success "Automatic screenshot test passed"
    else
        print_warning "Automatic screenshot test failed (may need X11 session)"
        validation_errors=$((validation_errors + 1))
    fi

    # Check systemd service
    if systemctl is-enabled pisignage-screenshot.timer >/dev/null 2>&1; then
        print_success "Screenshot timer service is enabled"
    else
        print_warning "Screenshot timer service is not enabled"
    fi

    # Check directories
    for dir in "/opt/pisignage/screenshots" "/dev/shm/pisignage"; do
        if [[ -d "$dir" ]]; then
            print_success "Directory exists: $dir"
        else
            print_error "Directory missing: $dir"
            validation_errors=$((validation_errors + 1))
        fi
    done

    return $validation_errors
}

rollback_installation() {
    print_error "Installation failed. Rolling back changes..."

    if [[ -d "$BACKUP_DIR" ]]; then
        # Run restore script
        if [[ -x "$BACKUP_DIR/restore.sh" ]]; then
            bash "$BACKUP_DIR/restore.sh"
            print_info "Rollback completed using restore script"
        fi
    fi

    # Remove any partially installed files
    sudo rm -f /usr/local/bin/raspi2png
    sudo rm -f /etc/systemd/system/pisignage-screenshot.*
    sudo systemctl daemon-reload

    print_warning "Rollback completed. Check $BACKUP_DIR for manual restoration if needed."
}

main() {
    print_header "PiSignage Screenshot Hardware Installation v0.8.0"

    # Prerequisite checks
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        exit 1
    fi

    if [[ ! -d /opt/pisignage ]]; then
        print_error "PiSignage directory not found. Please ensure PiSignage is installed."
        exit 1
    fi

    log_message "INFO" "Starting screenshot hardware installation"

    # System detection
    detect_pi_model || exit 1
    detect_os_version
    detect_display_config

    # Create backup
    create_backup || exit 1

    # Installation steps
    if ! install_dependencies; then
        rollback_installation
        exit 1
    fi

    if ! build_raspi2png; then
        print_warning "raspi2png build failed, continuing with fallback methods only"
    fi

    configure_boot_settings || print_warning "Boot configuration failed, continuing"
    configure_shared_memory || print_warning "Shared memory configuration failed, continuing"
    create_systemd_service || print_warning "Systemd service creation failed, continuing"

    if ! update_screenshot_script; then
        rollback_installation
        exit 1
    fi

    # Testing
    test_screenshot_methods || print_warning "Some screenshot methods may not work without X11 session"

    # Final validation
    if ! run_final_validation; then
        print_warning "Some validation checks failed, but installation may still be functional"
    fi

    # Summary
    print_header "Installation Summary"

    if [[ ${#INSTALL_ERRORS[@]} -eq 0 ]]; then
        print_success "Screenshot hardware installation completed successfully!"
    else
        print_warning "Installation completed with some warnings:"
        for error in "${INSTALL_ERRORS[@]}"; do
            echo -e "  ${YELLOW}•${NC} $error"
        done
    fi

    print_info "Backup created at: $BACKUP_DIR"
    print_info "Log file: $LOG_FILE"

    echo -e "\n${CYAN}Next steps:${NC}"
    echo "1. Reboot the system to apply boot configuration changes"
    echo "2. Test screenshots: /opt/pisignage/scripts/screenshot.sh auto"
    echo "3. Check status: /opt/pisignage/scripts/screenshot.sh status"
    echo "4. Start timer service: sudo systemctl start pisignage-screenshot.timer"

    if [[ ${#INSTALL_ERRORS[@]} -gt 3 ]]; then
        echo -e "\n${RED}Warning: Multiple errors occurred. Consider running rollback:${NC}"
        echo "bash $BACKUP_DIR/restore.sh"
        exit 1
    fi

    log_message "INFO" "Screenshot hardware installation completed"
}

# Handle interrupts
trap 'print_error "Installation interrupted"; rollback_installation; exit 1' INT TERM

# Run main installation
main "$@"