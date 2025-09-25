#!/bin/bash
#
# PiSignage v0.8.0 - Install raspi2png for hardware screenshot
# Optimized for Raspberry Pi 4 with 25-30ms capture time
#

set -e

echo "========================================="
echo "PiSignage - Installing raspi2png"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running on Raspberry Pi
if [[ ! -f /proc/device-tree/model ]]; then
    echo -e "${YELLOW}Warning: Not running on Raspberry Pi${NC}"
    echo "Installing fallback screenshot tools instead..."

    sudo apt-get update
    sudo apt-get install -y scrot imagemagick fbgrab

    echo -e "${GREEN}Fallback tools installed${NC}"
    exit 0
fi

MODEL=$(cat /proc/device-tree/model)
echo "Detected: $MODEL"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y \
    libpng-dev \
    build-essential \
    cmake \
    git \
    imagemagick

# Clone and build raspi2png
echo -e "${YELLOW}Building raspi2png...${NC}"
cd /tmp
rm -rf raspi2png

git clone https://github.com/AndrewFromMelbourne/raspi2png.git
cd raspi2png

# Build with optimizations
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Install
sudo make install
sudo ldconfig

# Verify installation
if command -v raspi2png &> /dev/null; then
    echo -e "${GREEN}✓ raspi2png installed successfully${NC}"
    raspi2png --help | head -5
else
    echo -e "${RED}✗ raspi2png installation failed${NC}"
    exit 1
fi

# Configure GPU memory if needed
echo -e "${YELLOW}Checking GPU memory configuration...${NC}"
GPU_MEM=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)

if [[ $GPU_MEM -lt 128 ]]; then
    echo -e "${YELLOW}GPU memory is ${GPU_MEM}MB, recommending 128MB for optimal capture${NC}"
    echo "Add 'gpu_mem=128' to /boot/config.txt for better performance"
fi

# Create cache directory
echo -e "${YELLOW}Setting up cache directory...${NC}"
sudo mkdir -p /dev/shm/pisignage-screenshots
sudo chown www-data:www-data /dev/shm/pisignage-screenshots

# Add www-data to video group for framebuffer access
sudo usermod -a -G video www-data

# Test capture
echo -e "${YELLOW}Testing screenshot capture...${NC}"
TEST_FILE="/tmp/test_screenshot.png"

if raspi2png -p "$TEST_FILE" 2>/dev/null; then
    if [[ -f "$TEST_FILE" ]]; then
        SIZE=$(stat -c%s "$TEST_FILE")
        echo -e "${GREEN}✓ Test capture successful (${SIZE} bytes)${NC}"
        rm -f "$TEST_FILE"
    else
        echo -e "${RED}✗ Test capture failed - no output file${NC}"
    fi
else
    echo -e "${RED}✗ Test capture failed${NC}"
    echo "Installing fallback tools..."
    sudo apt-get install -y scrot fbgrab
fi

# Install fallback tools anyway
echo -e "${YELLOW}Installing additional screenshot tools...${NC}"
sudo apt-get install -y scrot fbgrab || true

# Create systemd service for cache cleanup
echo -e "${YELLOW}Creating cache cleanup service...${NC}"
sudo tee /etc/systemd/system/pisignage-screenshot-cleanup.service > /dev/null << 'EOF'
[Unit]
Description=PiSignage Screenshot Cache Cleanup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'find /dev/shm/pisignage-screenshots -name "capture_*.jpg" -mmin +60 -delete 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/pisignage-screenshot-cleanup.timer > /dev/null << 'EOF'
[Unit]
Description=Run PiSignage Screenshot Cleanup every hour
Requires=pisignage-screenshot-cleanup.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pisignage-screenshot-cleanup.timer
sudo systemctl start pisignage-screenshot-cleanup.timer

# Summary
echo ""
echo "========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================="
echo ""
echo "Installed tools:"
command -v raspi2png &> /dev/null && echo "  ✓ raspi2png (hardware accelerated)"
command -v scrot &> /dev/null && echo "  ✓ scrot (X11 fallback)"
command -v fbgrab &> /dev/null && echo "  ✓ fbgrab (framebuffer fallback)"
command -v convert &> /dev/null && echo "  ✓ ImageMagick convert (JPEG conversion)"
echo ""
echo "Cache directory: /dev/shm/pisignage-screenshots"
echo "Cleanup service: pisignage-screenshot-cleanup.timer"
echo ""
echo -e "${YELLOW}Note: Reboot may be required for GPU settings${NC}"