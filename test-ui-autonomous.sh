#!/bin/bash

###############################################################################
# PiSignage Autonomous UI Test Suite
#
# This script demonstrates autonomous testing capabilities using Playwright MCP.
# It can be run by Claude Code CLI to verify UI changes, detect errors, and
# ensure accessibility compliance.
#
# Usage:
#   ./test-ui-autonomous.sh [--full|--quick|--page PAGE_NAME]
#
# Options:
#   --full        Test all pages with full checks (default)
#   --quick       Quick test (navigation and console errors only)
#   --page NAME   Test specific page only
#
# Examples:
#   ./test-ui-autonomous.sh --quick
#   ./test-ui-autonomous.sh --page dashboard.php
#   ./test-ui-autonomous.sh --full
###############################################################################

set -e

# Configuration
MCP_CLI=~/.mcp/playwright/mcp-cli.sh
BASE_URL="http://192.168.1.62"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="test-report-${TIMESTAMP}.txt"

# Test pages
PAGES=(
  "dashboard.php"
  "media.php"
  "playlists.php"
  "player-control-ui.php"
  "settings.php"
  "youtube.php"
  "logs.php"
  "screenshot.php"
)

# Parse command line arguments
MODE="full"
SINGLE_PAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --full)
      MODE="full"
      shift
      ;;
    --quick)
      MODE="quick"
      shift
      ;;
    --page)
      SINGLE_PAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
  echo "[$(date +%H:%M:%S)] INFO: $1" >> "$REPORT_FILE"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
  echo "[$(date +%H:%M:%S)] SUCCESS: $1" >> "$REPORT_FILE"
  ((PASSED_TESTS++))
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
  echo "[$(date +%H:%M:%S)] ERROR: $1" >> "$REPORT_FILE"
  ((FAILED_TESTS++))
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
  echo "[$(date +%H:%M:%S)] WARNING: $1" >> "$REPORT_FILE"
  ((WARNINGS++))
}

# Ensure MCP is running
ensure_mcp_running() {
  log_info "Checking Playwright MCP status..."

  if $MCP_CLI status > /dev/null 2>&1; then
    log_success "MCP server is running"
  else
    log_info "Starting MCP server..."
    $MCP_CLI start
    sleep 3

    if $MCP_CLI status > /dev/null 2>&1; then
      log_success "MCP server started successfully"
    else
      log_error "Failed to start MCP server"
      exit 1
    fi
  fi
}

# Test single page
test_page() {
  local page=$1
  local url="$BASE_URL/$page"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Testing: $page"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  ((TOTAL_TESTS++))

  # 1. Navigation test
  log_info "Navigating to $url..."
  NAV_RESULT=$($MCP_CLI navigate "$url" 2>/dev/null)

  if echo "$NAV_RESULT" | jq -e '.success' > /dev/null 2>&1; then
    STATUS=$(echo "$NAV_RESULT" | jq -r '.status')
    TITLE=$(echo "$NAV_RESULT" | jq -r '.title')

    if [ "$STATUS" = "200" ]; then
      log_success "Page loaded successfully (HTTP $STATUS)"
      log_info "Page title: $TITLE"
    else
      log_error "Page returned HTTP $STATUS"
      return 1
    fi
  else
    log_error "Navigation failed"
    return 1
  fi

  # 2. Screenshot capture
  if [ "$MODE" = "full" ]; then
    log_info "Capturing screenshot..."
    SCREENSHOT=$($MCP_CLI screenshot 2>/dev/null)

    if echo "$SCREENSHOT" | jq -e '.success' > /dev/null 2>&1; then
      SCREENSHOT_FILE=$(echo "$SCREENSHOT" | jq -r '.filename')
      log_success "Screenshot saved: $SCREENSHOT_FILE"
    else
      log_warning "Screenshot capture failed"
    fi
  fi

  # 3. Console errors check
  log_info "Checking console for errors..."
  CONSOLE_RESULT=$($MCP_CLI console 2>/dev/null)

  if echo "$CONSOLE_RESULT" | jq -e '.success' > /dev/null 2>&1; then
    ERROR_COUNT=$(echo "$CONSOLE_RESULT" | jq '[.logs[] | select(.type=="error")] | length')

    if [ "$ERROR_COUNT" -eq 0 ]; then
      log_success "No console errors found"
    else
      log_error "Found $ERROR_COUNT console error(s):"
      echo "$CONSOLE_RESULT" | jq -r '.logs[] | select(.type=="error") | "   - [\(.timestamp)] \(.text)"' | tee -a "$REPORT_FILE"
    fi

    # Check for warnings
    WARNING_COUNT=$(echo "$CONSOLE_RESULT" | jq '[.logs[] | select(.type=="warning")] | length')
    if [ "$WARNING_COUNT" -gt 0 ]; then
      log_warning "Found $WARNING_COUNT console warning(s)"

      if [ "$MODE" = "full" ]; then
        echo "$CONSOLE_RESULT" | jq -r '.logs[] | select(.type=="warning") | "   - [\(.timestamp)] \(.text)"' | tee -a "$REPORT_FILE"
      fi
    fi
  else
    log_warning "Could not retrieve console logs"
  fi

  # 4. Network requests check (full mode only)
  if [ "$MODE" = "full" ]; then
    log_info "Checking network requests..."
    NETWORK_RESULT=$($MCP_CLI network 2>/dev/null)

    if echo "$NETWORK_RESULT" | jq -e '.success' > /dev/null 2>&1; then
      FAILED_REQUESTS=$(echo "$NETWORK_RESULT" | jq '[.requests[] | select(.url | test("(404|500)"))] | length')

      if [ "$FAILED_REQUESTS" -eq 0 ]; then
        log_success "No failed network requests"
      else
        log_warning "Found $FAILED_REQUESTS potentially failed request(s)"
      fi
    fi
  fi

  # 5. Accessibility audit (full mode only)
  if [ "$MODE" = "full" ]; then
    log_info "Running accessibility audit..."
    A11Y_RESULT=$($MCP_CLI a11y 2>/dev/null)

    if echo "$A11Y_RESULT" | jq -e '.success' > /dev/null 2>&1; then
      VIOLATION_COUNT=$(echo "$A11Y_RESULT" | jq '.violations | length')

      if [ "$VIOLATION_COUNT" -eq 0 ]; then
        log_success "No accessibility violations found"
      else
        log_warning "Found $VIOLATION_COUNT accessibility violation(s):"
        echo "$A11Y_RESULT" | jq -r '.violations[] | "   - [\(.id)] \(.description) (Impact: \(.impact))"' | tee -a "$REPORT_FILE"
      fi
    else
      log_warning "Accessibility audit failed"
    fi
  fi
}

# Main execution
main() {
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║     PiSignage Autonomous UI Test Suite v1.0           ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
  echo "Mode: $MODE"
  echo "Base URL: $BASE_URL"
  echo "Report: $REPORT_FILE"
  echo ""

  # Initialize report
  {
    echo "PiSignage Autonomous UI Test Report"
    echo "===================================="
    echo "Date: $(date)"
    echo "Mode: $MODE"
    echo "Base URL: $BASE_URL"
    echo ""
  } > "$REPORT_FILE"

  # Ensure MCP is running
  ensure_mcp_running

  # Test pages
  if [ -n "$SINGLE_PAGE" ]; then
    test_page "$SINGLE_PAGE"
  else
    for page in "${PAGES[@]}"; do
      test_page "$page"
    done
  fi

  # Summary
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║                    TEST SUMMARY                        ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
  echo "Total Tests:    $TOTAL_TESTS"
  echo -e "Passed:         ${GREEN}$PASSED_TESTS${NC}"
  echo -e "Failed:         ${RED}$FAILED_TESTS${NC}"
  echo -e "Warnings:       ${YELLOW}$WARNINGS${NC}"
  echo ""
  echo "📄 Full report saved to: $REPORT_FILE"
  echo "📸 Screenshots saved to: ~/.mcp/playwright/workspace/screenshots/"
  echo ""

  # Write summary to report
  {
    echo ""
    echo "SUMMARY"
    echo "======="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Warnings: $WARNINGS"
  } >> "$REPORT_FILE"

  # Exit code
  if [ "$FAILED_TESTS" -gt 0 ]; then
    echo -e "${RED}❌ Tests completed with failures${NC}"
    exit 1
  elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Tests completed with warnings${NC}"
    exit 0
  else
    echo -e "${GREEN}✅ All tests passed successfully!${NC}"
    exit 0
  fi
}

# Run main
main
