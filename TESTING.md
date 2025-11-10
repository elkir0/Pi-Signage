# PiSignage Autonomous Testing Guide

## Overview

This document explains how to use the autonomous testing system powered by Playwright MCP for PiSignage UI verification, console monitoring, and accessibility auditing.

## Prerequisites

- **Playwright MCP Server**: Must be installed at `~/.mcp/playwright/`
- **Docker**: Running on the Mac
- **jq**: JSON processor (`brew install jq` if not installed)
- **Network Access**: Mac can reach Raspberry Pi at 192.168.1.62

## Quick Start

### 1. Ensure MCP is Running

```bash
# Check status
mcp status

# Start if not running
mcp start
```

### 2. Run the Test Suite

```bash
# Full test (all pages, screenshots, accessibility)
./test-ui-autonomous.sh --full

# Quick test (navigation and console errors only)
./test-ui-autonomous.sh --quick

# Test specific page
./test-ui-autonomous.sh --page dashboard.php
```

## Test Modes

### Full Mode (Default)
Tests all aspects of each page:
- ✅ Navigation and HTTP status
- ✅ Screenshot capture
- ✅ Console error detection
- ✅ Console warnings
- ✅ Network request monitoring
- ✅ Accessibility audit (axe-core)

**Usage:**
```bash
./test-ui-autonomous.sh
# or
./test-ui-autonomous.sh --full
```

**Duration:** ~2-3 minutes for all pages

### Quick Mode
Fast testing for rapid iteration:
- ✅ Navigation and HTTP status
- ✅ Console error detection
- ❌ Screenshots (skipped)
- ⚠️  Warnings (mentioned but not detailed)
- ❌ Network monitoring (skipped)
- ❌ Accessibility (skipped)

**Usage:**
```bash
./test-ui-autonomous.sh --quick
```

**Duration:** ~30 seconds for all pages

### Single Page Mode
Test one specific page:

**Usage:**
```bash
./test-ui-autonomous.sh --page dashboard.php
./test-ui-autonomous.sh --page player-control-ui.php --full
```

## Test Results

### Console Output

The script provides color-coded real-time output:
- 🔵 **Blue (ℹ️)**: Info messages
- 🟢 **Green (✅)**: Success/passed checks
- 🔴 **Red (❌)**: Errors/failed checks
- 🟡 **Yellow (⚠️)**: Warnings

### Report File

A detailed report is generated with timestamp:
```
test-report-20251109_223500.txt
```

Contains:
- Timestamp for each test
- Navigation results (HTTP status, title)
- Console errors and warnings with timestamps
- Accessibility violations with impact levels
- Network request issues
- Final summary with counts

### Screenshots

Captured in full mode, saved to:
```
~/.mcp/playwright/workspace/screenshots/
```

Format: `screenshot-<timestamp>.png`

## Understanding Test Output

### Navigation Test

```
✅ Page loaded successfully (HTTP 200)
ℹ️  Page title: PiSignage - Dashboard
```

**What it means:**
- Page is accessible
- Server responding correctly
- No redirect issues

**Potential issues:**
- ❌ Page returned HTTP 404 → File not found
- ❌ Page returned HTTP 500 → Server error
- ❌ Navigation failed → Network or server down

### Console Errors

```
❌ Found 2 console error(s):
   - [2025-11-09T22:35:12.345Z] Uncaught ReferenceError: foo is not defined
   - [2025-11-09T22:35:13.123Z] Failed to load resource: 404
```

**What to do:**
1. Check the referenced file/function exists
2. Verify JavaScript syntax
3. Check file paths in `<script>` tags
4. Review recent code changes

### Accessibility Violations

```
⚠️  Found 3 accessibility violation(s):
   - [color-contrast] Elements must have sufficient color contrast (Impact: serious)
   - [image-alt] Images must have alternate text (Impact: critical)
   - [label] Form elements must have labels (Impact: critical)
```

**Impact Levels:**
- **Critical**: Blocks users, must fix
- **Serious**: Causes difficulty, should fix
- **Moderate**: Inconvenience, nice to fix
- **Minor**: Aesthetic, optional fix

**Common Fixes:**
- Add `alt=""` to images
- Add `<label>` for form inputs
- Increase text/background contrast
- Add ARIA labels where needed

## Integration with Development Workflow

### After Making UI Changes

```bash
# 1. Deploy changes to Pi
scp file.php pi@192.168.1.62:/tmp/
ssh pi@192.168.1.62 'sudo cp /tmp/file.php /opt/pisignage/web/'

# 2. Test the changed page
./test-ui-autonomous.sh --page file.php

# 3. If errors found, fix and re-test
# ... make fixes ...
./test-ui-autonomous.sh --page file.php

# 4. Run full test before committing
./test-ui-autonomous.sh --full
```

### Before Committing Code

```bash
# Always run full test suite
./test-ui-autonomous.sh --full

# Review report
cat test-report-*.txt

# Fix any critical issues
# Commit only when tests pass
```

### Debugging Production Issues

```bash
# User reports error on specific page
./test-ui-autonomous.sh --page player-control-ui.php

# Capture evidence
ls -lh ~/.mcp/playwright/workspace/screenshots/

# Review console logs in report
grep "ERROR" test-report-*.txt

# Screenshot shows visual issue
open ~/.mcp/playwright/workspace/screenshots/screenshot-*.png
```

## Advanced Usage

### Custom Testing Script

```bash
#!/bin/bash

# Test only critical pages
CRITICAL_PAGES=("dashboard.php" "player-control-ui.php")

for page in "${CRITICAL_PAGES[@]}"; do
  echo "Testing $page..."
  ./test-ui-autonomous.sh --page "$page" --full

  if [ $? -ne 0 ]; then
    echo "❌ Critical page $page failed!"
    exit 1
  fi
done

echo "✅ All critical pages passed"
```

### Continuous Monitoring

```bash
# Run tests every hour
crontab -e

# Add line:
0 * * * * cd /path/to/pisignage && ./test-ui-autonomous.sh --quick >> test-cron.log 2>&1
```

### Integration with CI/CD

```yaml
# GitHub Actions example
name: UI Tests

on: [push, pull_request]

jobs:
  test-ui:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Start Playwright MCP
        run: |
          cd ~/.mcp/playwright
          docker-compose up -d

      - name: Run UI Tests
        run: |
          ./test-ui-autonomous.sh --full

      - name: Upload Screenshots
        if: failure()
        uses: actions/upload-artifact@v2
        with:
          name: screenshots
          path: ~/.mcp/playwright/workspace/screenshots/
```

## MCP Commands Reference

### Container Management

```bash
# Start MCP
mcp start

# Stop MCP
mcp stop

# Restart MCP
mcp restart

# Check status
mcp status

# View logs
mcp logs
```

### Manual Testing

```bash
# Navigate
mcp navigate http://192.168.1.62/dashboard.php

# Screenshot
mcp screenshot

# Console logs
mcp console

# Filter errors only
mcp console | jq '.logs[] | select(.type=="error")'

# Network requests
mcp network

# Execute JavaScript
mcp eval 'document.title'

# Accessibility audit
mcp a11y
```

## Troubleshooting

### MCP Not Starting

```bash
# Check Docker
docker ps

# Rebuild MCP
cd ~/.mcp/playwright
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### No Screenshots Captured

```bash
# Check workspace directory
ls -la ~/.mcp/playwright/workspace/screenshots/

# Check permissions
docker exec playwright-mcp ls -la /workspace
```

### Tests Fail with "Navigation failed"

```bash
# Check Pi is reachable
ping 192.168.1.62

# Check web server
curl -I http://192.168.1.62

# Check from browser
open http://192.168.1.62
```

### jq Command Not Found

```bash
# Install jq
brew install jq
```

## Best Practices

1. **Run tests before every commit**
2. **Fix critical issues immediately**
3. **Review warnings periodically**
4. **Keep screenshots for regression testing**
5. **Document known issues in comments**
6. **Use quick mode for rapid iteration**
7. **Use full mode before releases**

## Exit Codes

- **0**: All tests passed (or warnings only)
- **1**: One or more tests failed

```bash
# Use in scripts
if ./test-ui-autonomous.sh --quick; then
  echo "Tests passed, deploying..."
  # deployment commands
else
  echo "Tests failed, aborting deployment"
  exit 1
fi
```

## See Also

- [CLAUDE.md](CLAUDE.md) - Complete development guide
- [~/.mcp/playwright/README.md](~/.mcp/playwright/README.md) - MCP documentation
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - API reference

---

**Version**: 1.0
**Last Updated**: November 2025
**Maintainer**: PiSignage Development Team
