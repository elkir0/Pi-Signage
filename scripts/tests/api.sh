#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║              PiSignage Trixie/Kiosk - API Tests                      ║
# ║              Test kiosk API endpoints (if server running)            ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
API_BASE="http://127.0.0.1:8080"

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

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              PiSignage Trixie/Kiosk - API Tests                     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if server is running
echo "Checking if API server is accessible at $API_BASE..."
if ! curl -sf --connect-timeout 2 "$API_BASE" >/dev/null 2>&1; then
    log_warn "API server not running at $API_BASE"
    echo ""
    echo -e "${BLUE}To run these tests, start the API server first:${NC}"
    echo "  1. On Raspberry Pi: nginx should be running automatically"
    echo "  2. For local testing:"
    echo "     cd web && php -S 0.0.0.0:8080"
    echo ""
    echo "These tests are INFORMATIONAL and will be skipped."
    exit 0
fi

log_pass "API server is accessible"

# Test 1: GET /api/kiosk (status)
echo ""
echo "Test 1: GET /api/kiosk (status)..."
RESPONSE=$(curl -sf "$API_BASE/api/kiosk" 2>/dev/null || echo "")
if [ -n "$RESPONSE" ]; then
    log_pass "GET /api/kiosk returned response"
    echo "Response: $RESPONSE" | head -c 200
    echo ""
else
    log_fail "GET /api/kiosk failed"
fi

# Test 2: GET /api/kiosk/url
echo ""
echo "Test 2: GET /api/kiosk/url..."
RESPONSE=$(curl -sf "$API_BASE/api/kiosk/url" 2>/dev/null || echo "")
if [ -n "$RESPONSE" ]; then
    log_pass "GET /api/kiosk/url returned response"
    echo "Response: $RESPONSE" | head -c 200
    echo ""

    # Check if response is valid JSON with 'url' field
    if echo "$RESPONSE" | jq -e '.data.url' >/dev/null 2>&1; then
        CURRENT_URL=$(echo "$RESPONSE" | jq -r '.data.url')
        log_pass "Response contains valid URL: $CURRENT_URL"
    else
        log_warn "Response doesn't contain expected 'url' field"
    fi
else
    log_fail "GET /api/kiosk/url failed"
fi

# Test 3: PUT /api/kiosk/url
echo ""
echo "Test 3: PUT /api/kiosk/url..."
TEST_URL="https://example.com/test"
RESPONSE=$(curl -sf -X PUT "$API_BASE/api/kiosk/url" \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"$TEST_URL\"}" 2>/dev/null || echo "")

if [ -n "$RESPONSE" ]; then
    log_pass "PUT /api/kiosk/url accepted request"
    echo "Response: $RESPONSE" | head -c 200
    echo ""

    # Verify the URL was updated
    sleep 1
    VERIFY=$(curl -sf "$API_BASE/api/kiosk/url" 2>/dev/null || echo "")
    if echo "$VERIFY" | jq -e '.data.url' >/dev/null 2>&1; then
        UPDATED_URL=$(echo "$VERIFY" | jq -r '.data.url')
        if [ "$UPDATED_URL" = "$TEST_URL" ]; then
            log_pass "URL successfully updated to: $UPDATED_URL"
        else
            log_fail "URL not updated correctly (expected: $TEST_URL, got: $UPDATED_URL)"
        fi
    fi

    # Restore original URL if we had one
    if [ -n "$CURRENT_URL" ]; then
        curl -sf -X PUT "$API_BASE/api/kiosk/url" \
            -H "Content-Type: application/json" \
            -d "{\"url\":\"$CURRENT_URL\"}" >/dev/null 2>&1 || true
        log_info "Restored original URL"
    fi
else
    log_fail "PUT /api/kiosk/url failed"
fi

# Test 4: GET /api/kiosk/flags
echo ""
echo "Test 4: GET /api/kiosk/flags..."
RESPONSE=$(curl -sf "$API_BASE/api/kiosk/flags" 2>/dev/null || echo "")
if [ -n "$RESPONSE" ]; then
    log_pass "GET /api/kiosk/flags returned response"
    echo "Response: $RESPONSE" | head -c 200
    echo ""

    if echo "$RESPONSE" | jq -e '.data.flags' >/dev/null 2>&1; then
        CURRENT_FLAGS=$(echo "$RESPONSE" | jq -r '.data.flags')
        log_pass "Response contains flags: $CURRENT_FLAGS"
    fi
else
    log_fail "GET /api/kiosk/flags failed"
fi

# Test 5: PUT /api/kiosk/flags
echo ""
echo "Test 5: PUT /api/kiosk/flags..."
TEST_FLAGS="--incognito --test-flag"
RESPONSE=$(curl -sf -X PUT "$API_BASE/api/kiosk/flags" \
    -H "Content-Type: application/json" \
    -d "{\"flags\":\"$TEST_FLAGS\"}" 2>/dev/null || echo "")

if [ -n "$RESPONSE" ]; then
    log_pass "PUT /api/kiosk/flags accepted request"
    echo "Response: $RESPONSE" | head -c 200
    echo ""

    # Verify flags were updated
    sleep 1
    VERIFY=$(curl -sf "$API_BASE/api/kiosk/flags" 2>/dev/null || echo "")
    if echo "$VERIFY" | jq -e '.data.flags' >/dev/null 2>&1; then
        UPDATED_FLAGS=$(echo "$VERIFY" | jq -r '.data.flags')
        if [ "$UPDATED_FLAGS" = "$TEST_FLAGS" ]; then
            log_pass "Flags successfully updated"
        else
            log_fail "Flags not updated correctly"
        fi
    fi

    # Restore original flags if we had them
    if [ -n "$CURRENT_FLAGS" ]; then
        curl -sf -X PUT "$API_BASE/api/kiosk/flags" \
            -H "Content-Type: application/json" \
            -d "{\"flags\":\"$CURRENT_FLAGS\"}" >/dev/null 2>&1 || true
        log_info "Restored original flags"
    fi
else
    log_fail "PUT /api/kiosk/flags failed"
fi

# Test 6: POST /api/kiosk/restart
echo ""
echo "Test 6: POST /api/kiosk/restart..."
RESPONSE=$(curl -sf -X POST "$API_BASE/api/kiosk/restart" 2>/dev/null || echo "")
if [ -n "$RESPONSE" ]; then
    log_pass "POST /api/kiosk/restart returned response"
    echo "Response: $RESPONSE" | head -c 200
    echo ""
else
    log_fail "POST /api/kiosk/restart failed"
fi

# Test 7: Invalid endpoint (should return 404)
echo ""
echo "Test 7: Invalid endpoint (expect 404)..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "$API_BASE/api/kiosk/invalid" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "404" ]; then
    log_pass "Invalid endpoint correctly returns 404"
else
    log_warn "Invalid endpoint returned: $HTTP_CODE (expected 404)"
fi

# Test 8: Invalid method (should return 405)
echo ""
echo "Test 8: Invalid method (expect 405)..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" -X DELETE "$API_BASE/api/kiosk/url" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "405" ]; then
    log_pass "Invalid method correctly returns 405"
else
    log_warn "Invalid method returned: $HTTP_CODE (expected 405)"
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                        Test Results Summary                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All API tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. This may be expected if running in mock environment.${NC}"
    exit 1
fi
