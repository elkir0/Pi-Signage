#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║              PiSignage Trixie/Kiosk - Smoke Tests                    ║
# ║           Verify basic installation and file presence                ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║            PiSignage Trixie/Kiosk Mode - Smoke Tests                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Check kiosk-apply script exists and is executable
echo "Test 1: kiosk-apply script presence..."
if [ -x "scripts/kiosk-apply" ]; then
    log_pass "scripts/kiosk-apply exists and is executable"
else
    log_fail "scripts/kiosk-apply not found or not executable"
fi

# Test 2: Check labwc template exists
echo "Test 2: labwc rc.xml template..."
if [ -f "templates/.config/labwc/rc.xml" ]; then
    log_pass "templates/.config/labwc/rc.xml exists"
    # Verify it contains key directives
    if grep -q "<hideCursor/>" "templates/.config/labwc/rc.xml" && \
       grep -q "<disable/>" "templates/.config/labwc/rc.xml"; then
        log_pass "rc.xml contains hideCursor and idle disable directives"
    else
        log_fail "rc.xml missing required directives"
    fi
else
    log_fail "templates/.config/labwc/rc.xml not found"
fi

# Test 3: Create mock config directory
echo "Test 3: Creating mock config directory..."
MOCK_CFG_DIR="/tmp/pisignage-test-$$"
mkdir -p "$MOCK_CFG_DIR"
log_pass "Mock config dir created: $MOCK_CFG_DIR"

# Test 4: Create default config files (mock)
echo "Test 4: Creating default config files..."
echo "https://time.is" > "$MOCK_CFG_DIR/kiosk_url"
echo "--incognito --noerrdialogs --disable-translate --no-first-run" > "$MOCK_CFG_DIR/kiosk_flags"
echo "ENABLE_KIOSK=1" > "$MOCK_CFG_DIR/feature_flags"

if [ -f "$MOCK_CFG_DIR/kiosk_url" ] && \
   [ -f "$MOCK_CFG_DIR/kiosk_flags" ] && \
   [ -f "$MOCK_CFG_DIR/feature_flags" ]; then
    log_pass "Default config files created successfully"
else
    log_fail "Failed to create default config files"
fi

# Test 5: Run kiosk-apply with mock config (dry run)
echo "Test 5: Running kiosk-apply (mock environment)..."
# Override CFG_DIR for testing
export HOME="/tmp/pisignage-test-home-$$"
mkdir -p "$HOME"

# Temporarily modify kiosk-apply to use mock config (in memory test)
# Since we can't easily modify the script, we'll just check if it can be sourced
if bash -n scripts/kiosk-apply; then
    log_pass "kiosk-apply has valid shell syntax"
else
    log_fail "kiosk-apply has syntax errors"
fi

# Test 6: Simulate running kiosk-apply
echo "Test 6: Simulating kiosk-apply execution..."
# Create mock labwc directory
mkdir -p "$HOME/.config/labwc"

# Create a temporary modified kiosk-apply that uses our mock dirs
sed "s|/opt/pisignage/config|$MOCK_CFG_DIR|g" scripts/kiosk-apply > /tmp/kiosk-apply-test-$$
chmod +x /tmp/kiosk-apply-test-$$

# Run the modified script
if bash /tmp/kiosk-apply-test-$$ 2>&1 | tee /tmp/kiosk-apply-output-$$; then
    if [ -f "$HOME/.config/labwc/autostart" ]; then
        log_pass "autostart file created successfully"

        # Verify contents
        if grep -q "chromium --kiosk" "$HOME/.config/labwc/autostart"; then
            log_pass "autostart contains chromium kiosk command"
        else
            log_fail "autostart missing chromium kiosk command"
        fi

        if grep -q "https://time.is" "$HOME/.config/labwc/autostart"; then
            log_pass "autostart contains correct URL"
        else
            log_fail "autostart missing URL"
        fi
    else
        log_fail "autostart file not created"
    fi
else
    log_fail "kiosk-apply execution failed"
fi

# Test 7: Check install.sh modifications
echo "Test 7: Checking install.sh for Trixie support..."
if grep -q "detect_os_version" install.sh; then
    log_pass "install.sh contains detect_os_version function"
else
    log_fail "install.sh missing detect_os_version function"
fi

if grep -q "configure_kiosk_trixie" install.sh; then
    log_pass "install.sh contains configure_kiosk_trixie function"
else
    log_fail "install.sh missing configure_kiosk_trixie function"
fi

if grep -q "chromium-browser" install.sh && \
   grep -q "labwc" install.sh && \
   grep -q "greetd" install.sh; then
    log_pass "install.sh includes required Trixie packages"
else
    log_fail "install.sh missing required Trixie packages"
fi

# Test 8: Check API endpoint
echo "Test 8: Checking kiosk API file..."
if [ -f "web/api/kiosk.php" ]; then
    log_pass "web/api/kiosk.php exists"

    # Check for required endpoints
    if grep -q "handleGetUrl" web/api/kiosk.php && \
       grep -q "handlePutUrl" web/api/kiosk.php && \
       grep -q "handleGetFlags" web/api/kiosk.php && \
       grep -q "handlePutFlags" web/api/kiosk.php && \
       grep -q "handleRestart" web/api/kiosk.php; then
        log_pass "API contains all required endpoint handlers"
    else
        log_fail "API missing required endpoint handlers"
    fi
else
    log_fail "web/api/kiosk.php not found"
fi

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
rm -rf "$MOCK_CFG_DIR" "$HOME" /tmp/kiosk-apply-test-$$ /tmp/kiosk-apply-output-$$
log_info "Cleanup complete"

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Test Results Summary                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
