#!/bin/bash
# PiSignage v0.8.0 - Screenshot Help and Documentation
# Provides comprehensive help for screenshot functionality

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}$1${NC} ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

show_overview() {
    print_header "PiSignage Screenshot System Overview"

    echo -e "${BLUE}The PiSignage screenshot system provides multiple capture methods:${NC}"
    echo ""
    echo -e "${GREEN}1. Hardware Acceleration (raspi2png)${NC}"
    echo "   • Direct GPU access for fastest captures"
    echo "   • Best performance on Raspberry Pi"
    echo "   • Recommended for production use"
    echo ""
    echo -e "${GREEN}2. X11 Methods (scrot, ImageMagick)${NC}"
    echo "   • Works with desktop environments"
    echo "   • Good for development and testing"
    echo "   • Requires active X11 session"
    echo ""
    echo -e "${GREEN}3. Framebuffer Method (fbgrab)${NC}"
    echo "   • Direct framebuffer access"
    echo "   • Works without X11"
    echo "   • Good for headless setups"
    echo ""
}

show_installation() {
    print_header "Installation Guide"

    echo -e "${BLUE}Step 1: Test Installation Readiness${NC}"
    echo "/opt/pisignage/scripts/test-screenshot-install.sh"
    echo ""

    echo -e "${BLUE}Step 2: Run Installation${NC}"
    echo "sudo /opt/pisignage/scripts/install-screenshot.sh"
    echo ""

    echo -e "${BLUE}Step 3: Reboot System${NC}"
    echo "sudo reboot"
    echo ""

    echo -e "${BLUE}Step 4: Test Installation${NC}"
    echo "/opt/pisignage/scripts/screenshot.sh status"
    echo "/opt/pisignage/scripts/screenshot.sh auto"
    echo ""

    echo -e "${YELLOW}Installation includes:${NC}"
    echo "• raspi2png compilation and installation"
    echo "• Multiple fallback screenshot tools"
    echo "• Boot configuration optimization"
    echo "• Automatic screenshot service"
    echo "• Shared memory optimization"
    echo ""
}

show_usage() {
    print_header "Screenshot Script Usage"

    echo -e "${BLUE}Basic Commands:${NC}"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh auto${NC}"
    echo "   Take a screenshot using the best available method"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh auto my-screenshot.png${NC}"
    echo "   Take a screenshot with custom filename"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh status${NC}"
    echo "   Show current system status and available methods"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh cleanup${NC}"
    echo "   Remove old screenshots (keeps last 50)"
    echo ""

    echo -e "${BLUE}Advanced Commands:${NC}"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh take filename.png raspi2png${NC}"
    echo "   Use specific method (raspi2png, scrot, import, fbgrab)"
    echo ""
    echo -e "${GREEN}systemctl status pisignage-screenshot.timer${NC}"
    echo "   Check automatic screenshot service status"
    echo ""
    echo -e "${GREEN}sudo systemctl start pisignage-screenshot.timer${NC}"
    echo "   Enable automatic screenshots every 5 minutes"
    echo ""
}

show_troubleshooting() {
    print_header "Troubleshooting Guide"

    echo -e "${BLUE}Common Issues and Solutions:${NC}"
    echo ""

    echo -e "${YELLOW}1. No screenshot methods available${NC}"
    echo "   • Run: /opt/pisignage/scripts/install-screenshot.sh"
    echo "   • Check: /opt/pisignage/scripts/screenshot.sh status"
    echo ""

    echo -e "${YELLOW}2. raspi2png not working${NC}"
    echo "   • Check GPU memory: vcgencmd get_mem gpu"
    echo "   • Should be 256M or higher"
    echo "   • Reboot after boot config changes"
    echo ""

    echo -e "${YELLOW}3. X11 methods failing${NC}"
    echo "   • Check DISPLAY variable: echo \$DISPLAY"
    echo "   • Start X11: startx"
    echo "   • Or use framebuffer method instead"
    echo ""

    echo -e "${YELLOW}4. Permission errors${NC}"
    echo "   • Check directory permissions: ls -la /opt/pisignage/screenshots"
    echo "   • Fix: sudo chown -R pi:pi /opt/pisignage/screenshots"
    echo ""

    echo -e "${YELLOW}5. Automatic screenshots not working${NC}"
    echo "   • Check service: systemctl status pisignage-screenshot.timer"
    echo "   • Check logs: journalctl -u pisignage-screenshot.service"
    echo "   • Restart: sudo systemctl restart pisignage-screenshot.timer"
    echo ""

    echo -e "${BLUE}Log Files:${NC}"
    echo "• Installation: /opt/pisignage/logs/screenshot-install.log"
    echo "• Runtime: /opt/pisignage/logs/screenshot.log"
    echo "• System: journalctl -u pisignage-screenshot.service"
    echo ""
}

show_api_integration() {
    print_header "API Integration"

    echo -e "${BLUE}Screenshot API Endpoints:${NC}"
    echo ""
    echo -e "${GREEN}GET /api/screenshot.php${NC}"
    echo "   Returns latest screenshot as image"
    echo ""
    echo -e "${GREEN}POST /api/screenshot.php${NC}"
    echo "   Triggers new screenshot capture"
    echo "   Parameters: method (optional), filename (optional)"
    echo ""

    echo -e "${BLUE}Example API Calls:${NC}"
    echo ""
    echo -e "${GREEN}curl http://localhost/api/screenshot.php${NC}"
    echo "   Get latest screenshot"
    echo ""
    echo -e "${GREEN}curl -X POST http://localhost/api/screenshot.php${NC}"
    echo "   Take new screenshot"
    echo ""
    echo -e "${GREEN}curl -X POST http://localhost/api/screenshot.php -d 'method=raspi2png'${NC}"
    echo "   Take screenshot with specific method"
    echo ""
}

show_performance() {
    print_header "Performance Optimization"

    echo -e "${BLUE}Method Performance Comparison:${NC}"
    echo ""
    echo -e "${GREEN}raspi2png (Hardware):${NC}"
    echo "   • Speed: ⭐⭐⭐⭐⭐ (fastest)"
    echo "   • Quality: ⭐⭐⭐⭐⭐"
    echo "   • CPU Usage: ⭐⭐⭐⭐⭐ (lowest)"
    echo "   • Requirements: GPU memory ≥128MB"
    echo ""
    echo -e "${GREEN}scrot (X11):${NC}"
    echo "   • Speed: ⭐⭐⭐⭐"
    echo "   • Quality: ⭐⭐⭐⭐"
    echo "   • CPU Usage: ⭐⭐⭐"
    echo "   • Requirements: Active X11 session"
    echo ""
    echo -e "${GREEN}ImageMagick import:${NC}"
    echo "   • Speed: ⭐⭐⭐"
    echo "   • Quality: ⭐⭐⭐⭐⭐"
    echo "   • CPU Usage: ⭐⭐"
    echo "   • Requirements: X11, more memory"
    echo ""
    echo -e "${GREEN}fbgrab (Framebuffer):${NC}"
    echo "   • Speed: ⭐⭐⭐⭐"
    echo "   • Quality: ⭐⭐⭐⭐"
    echo "   • CPU Usage: ⭐⭐⭐"
    echo "   • Requirements: Framebuffer access"
    echo ""

    echo -e "${BLUE}Optimization Tips:${NC}"
    echo "• Use shared memory cache (/dev/shm/pisignage)"
    echo "• Set GPU memory to 256MB for best performance"
    echo "• Enable hardware acceleration with raspi2png"
    echo "• Use automatic cleanup to manage disk space"
    echo "• Configure appropriate screenshot intervals"
    echo ""
}

show_configuration() {
    print_header "Configuration Files"

    echo -e "${BLUE}Important Configuration Files:${NC}"
    echo ""
    echo -e "${GREEN}/boot/config.txt${NC}"
    echo "   gpu_mem=256              # GPU memory allocation"
    echo "   dtoverlay=vc4-fkms-v3d   # Display driver (Pi 4/5)"
    echo "   start_x=1                # Camera interface"
    echo ""
    echo -e "${GREEN}/etc/systemd/system/pisignage-screenshot.timer${NC}"
    echo "   OnUnitActiveSec=300s     # Screenshot interval (5 minutes)"
    echo ""
    echo -e "${GREEN}/opt/pisignage/scripts/screenshot.sh${NC}"
    echo "   MAX_SCREENSHOTS=50       # Number of screenshots to keep"
    echo "   SCREENSHOT_DIR=/opt/pisignage/screenshots"
    echo "   SHM_DIR=/dev/shm/pisignage"
    echo ""

    echo -e "${BLUE}Environment Variables:${NC}"
    echo "   DISPLAY=:0               # X11 display for GUI methods"
    echo "   XAUTHORITY=/home/pi/.Xauthority"
    echo ""
}

show_maintenance() {
    print_header "Maintenance Tasks"

    echo -e "${BLUE}Regular Maintenance:${NC}"
    echo ""
    echo -e "${GREEN}Weekly:${NC}"
    echo "• Check screenshot service: systemctl status pisignage-screenshot.timer"
    echo "• Review logs: tail -f /opt/pisignage/logs/screenshot.log"
    echo "• Clean old screenshots: /opt/pisignage/scripts/screenshot.sh cleanup"
    echo ""
    echo -e "${GREEN}Monthly:${NC}"
    echo "• Update system: sudo apt update && sudo apt upgrade"
    echo "• Check disk usage: df -h /opt/pisignage"
    echo "• Review screenshot quality and performance"
    echo ""
    echo -e "${GREEN}As Needed:${NC}"
    echo "• Update raspi2png: Rebuild from latest source"
    echo "• Adjust screenshot intervals based on usage"
    echo "• Optimize GPU memory allocation"
    echo ""

    echo -e "${BLUE}Backup Commands:${NC}"
    echo "• Backup screenshots: tar -czf screenshots-backup.tar.gz /opt/pisignage/screenshots"
    echo "• Backup config: cp /boot/config.txt config-backup.txt"
    echo "• Backup script: cp /opt/pisignage/scripts/screenshot.sh screenshot-backup.sh"
    echo ""
}

show_menu() {
    print_header "PiSignage Screenshot System Help"

    echo -e "${BLUE}Available Help Topics:${NC}"
    echo ""
    echo "1. overview      - System overview and features"
    echo "2. installation  - Installation guide"
    echo "3. usage         - How to use screenshot commands"
    echo "4. troubleshooting - Common problems and solutions"
    echo "5. api           - API integration guide"
    echo "6. performance   - Performance optimization"
    echo "7. configuration - Configuration files and settings"
    echo "8. maintenance   - Maintenance and backup tasks"
    echo "9. all           - Show all help topics"
    echo ""
    echo -e "${YELLOW}Usage: $0 [topic]${NC}"
    echo -e "${YELLOW}Example: $0 installation${NC}"
    echo ""
}

main() {
    case "${1:-menu}" in
        overview|1)
            show_overview
            ;;
        installation|install|2)
            show_installation
            ;;
        usage|use|3)
            show_usage
            ;;
        troubleshooting|trouble|debug|4)
            show_troubleshooting
            ;;
        api|integration|5)
            show_api_integration
            ;;
        performance|perf|optimize|6)
            show_performance
            ;;
        configuration|config|7)
            show_configuration
            ;;
        maintenance|maintain|8)
            show_maintenance
            ;;
        all)
            show_overview
            show_installation
            show_usage
            show_troubleshooting
            show_api_integration
            show_performance
            show_configuration
            show_maintenance
            ;;
        menu|help|*)
            show_menu
            ;;
    esac
}

main "$@"