# Claude Development Protocol - PiSignage v0.12.0

> **v0.12 — Diffusion unifiée (juin 2026)** : VLC a été **retiré**. Le moteur de lecture
> est désormais **unique** : Chromium HTML5 (`web/player.php` servi sur `/player`). Un seul
> modèle de playlist (API `playlists.php`, notion de « playlist active »), une diffusion
> (« Diffuser à l'écran »), un scheduler **réel** (dayparting via cron), et une UI consolidée.
> Voir la section « v0.12 — Unified Diffusion » plus bas.

## Project Overview

PiSignage is a professional digital signage solution optimized for Raspberry Pi hardware. Version 0.12.0 includes:
- **Chromium Kiosk Mode (lecteur unique)**: Wayland-based full-screen browser for HTML5 content (`/player`). C'est le SEUL moteur de lecture (VLC retiré).
- **Diffusion unifiée**: une API playlists unique + « playlist active » + bouton « Diffuser à l'écran ».
- **Programmation réelle (dayparting)**: exécuteur cron qui pose la playlist active selon l'heure/jour.
- **System Volume (ALSA)**: contrôle du volume système via amixer (plus de « volume VLC »).
- **Modern Web Interface**: design system adaptatif clair/sombre, accent emerald, icônes SVG (zéro emoji).

## Development Environment & Stack

### Hardware Target
- **Primary**: Raspberry Pi 4/5 (2GB+ RAM)
- **OS**: Raspberry Pi OS Trixie (Debian 13) with Wayland
- **Network**: Pi de test à 192.168.1.92 (SSH `pi` / mot de passe `palmer00`)

### Technology Stack

#### Backend
- **PHP 8.4**: Web application backend (php8.4-fpm)
- **Nginx**: Web server with FastCGI
- **Chromium**: lecteur kiosk **unique** (HTML5, `/player`). VLC a été retiré en v0.12.

#### Frontend
- **Vanilla JavaScript**: No frameworks, modular ES6+ patterns
- **PiSignage Namespace**: Global `window.PiSignage` object for all modules
- **CSS Modules**: 6 modular stylesheets (main, core, layout, components, responsive, modern-ui)
- **RESTful APIs**: JSON-based communication layer

#### System Components
- **ALSA**: System-level audio control via amixer (seul contrôle de volume)
- **Wayland (labwc)**: Display server for kiosk mode
- **lightdm**: Auto-login session manager (PAS greetd — autologin `pi` → labwc → Chromium)
- **cron**: `/etc/cron.d/pisignage-scheduler` (dayparting, www-data) + `/etc/cron.d/pisignage-screen` (extinction écran)
- **systemd**: Service management

### Development Workflow with MCP

#### MCP (Model Context Protocol) Integration

This project uses **MCP servers** to enhance Claude Code CLI capabilities:

1. **Filesystem MCP**: Access to local and remote files
2. **SSH MCP**: Direct Raspberry Pi command execution
3. **Web Testing MCP** (Playwright - To be configured): Browser automation and testing

#### Current MCP Usage Patterns

**Remote Development on Raspberry Pi:**
```bash
# Deploy files to Pi
scp /local/path/file.php pi@192.168.1.62:/tmp/
ssh pi@192.168.1.62 'sudo cp /tmp/file.php /opt/pisignage/web/ && sudo chown www-data:www-data /opt/pisignage/web/file.php'

# Test endpoints directly on Pi
ssh pi@192.168.1.62 'curl -s http://localhost/api/endpoint.php'

# Check logs
ssh pi@192.168.1.62 'tail -50 /var/log/nginx/error.log'
```

**Memory Optimization:**
- Use `grep` and `sed` commands on Pi instead of reading large files
- Fix code directly on Pi when possible (cache busting, quick patches)
- Pull only modified files back to local repo

#### GitHub Integration
- **Repository**: https://github.com/elkir0/Pi-Signage
- **Branch**: `feature/webadmin-kiosk-chromium-player`
- **Auth Token**: Stored in environment (ghp_...)
- **Workflow**: Local changes → Deploy to Pi → Test → Git commit → Push to GitHub

#### Playwright MCP Server (Browser Testing & Automation)

**Location**: `~/.mcp/playwright/`

A containerized Playwright server providing browser automation, screenshot capture, console monitoring, and accessibility testing.

**Quick Start:**
```bash
# Start MCP server
mcp start

# Test PiSignage UI
mcp navigate http://192.168.1.62
mcp screenshot
mcp console
mcp a11y

# Screenshots saved to ~/.mcp/playwright/workspace/screenshots/
```

**Available Commands:**
- `mcp start/stop/restart` - Container management
- `mcp status` - Check if MCP is running
- `mcp navigate <url>` - Navigate browser to URL
- `mcp screenshot` - Capture full-page screenshot
- `mcp console` - Get console logs (errors, warnings, info)
- `mcp network` - Get network requests
- `mcp eval '<script>'` - Execute JavaScript
- `mcp a11y` - Run accessibility audit with axe-core

**HTTP API** (for programmatic access):
```bash
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{"command": "navigate", "params": {"url": "http://192.168.1.62"}}'
```

**Integration Examples:**

*Test all PiSignage pages:*
```bash
for page in dashboard.php media.php playlists.php player-control-ui.php settings.php; do
  mcp navigate "http://192.168.1.62/$page"
  mcp screenshot
  mcp console | jq '.logs[] | select(.type=="error")'
done
```

*Automated UI testing:*
```bash
# Navigate and verify
mcp navigate http://192.168.1.62/dashboard.php

# Check for JavaScript errors
ERRORS=$(mcp console | jq -r '.logs[] | select(.type=="error") | .text')
if [ -n "$ERRORS" ]; then
  echo "❌ Errors found: $ERRORS"
else
  echo "✅ No errors"
fi

# Run accessibility audit
mcp a11y | jq '.violations'
```

**Features:**
- Multi-browser support (Chromium, Firefox, WebKit)
- Full-page screenshot capture
- Console log filtering by type (error, warning, info)
- Network request monitoring
- JavaScript execution in page context
- Accessibility auditing with axe-core
- Element interaction (click, type, wait)

**Documentation**: `~/.mcp/playwright/README.md`

### Autonomous Testing with Playwright MCP

**When to Use Playwright MCP in Future Sessions:**

The Playwright MCP enables Claude Code to perform autonomous UI testing, visual verification, and console monitoring. Use it proactively when:

1. **After implementing UI changes**: Verify the changes render correctly
2. **Before committing code**: Check for JavaScript errors and accessibility issues
3. **When debugging UI bugs**: Capture screenshots and console logs for analysis
4. **When user reports UI issues**: Reproduce and document the issue with evidence

**Autonomous Testing Workflow:**

```bash
# 1. Ensure MCP is running
~/.mcp/playwright/mcp-cli.sh status || ~/.mcp/playwright/mcp-cli.sh start

# 2. Navigate to the page under test
~/.mcp/playwright/mcp-cli.sh navigate http://192.168.1.62/page.php

# 3. Capture screenshot for visual verification
~/.mcp/playwright/mcp-cli.sh screenshot

# 4. Check console for errors
~/.mcp/playwright/mcp-cli.sh console | jq '.logs[] | select(.type=="error")'

# 5. Run accessibility audit
~/.mcp/playwright/mcp-cli.sh a11y | jq '.violations'

# 6. Analyze results and report findings
```

**Complete Testing Script Example:**

```bash
#!/bin/bash
# test-pisignage-ui.sh - Autonomous UI testing

MCP_CLI=~/.mcp/playwright/mcp-cli.sh
BASE_URL="http://192.168.1.62"
PAGES=(
  "dashboard.php"
  "media.php"
  "playlists.php"
  "player-control-ui.php"
  "settings.php"
  "youtube.php"
)

# Ensure MCP is running
$MCP_CLI status > /dev/null 2>&1 || $MCP_CLI start

echo "🧪 Starting PiSignage UI Test Suite"
echo "=================================="

for page in "${PAGES[@]}"; do
  echo ""
  echo "Testing: $page"
  echo "---"

  # Navigate
  NAV_RESULT=$($MCP_CLI navigate "$BASE_URL/$page")
  STATUS=$(echo "$NAV_RESULT" | jq -r '.status')

  if [ "$STATUS" != "200" ]; then
    echo "❌ Navigation failed (HTTP $STATUS)"
    continue
  fi

  echo "✅ Page loaded (HTTP $STATUS)"

  # Screenshot
  SCREENSHOT=$($MCP_CLI screenshot)
  SCREENSHOT_FILE=$(echo "$SCREENSHOT" | jq -r '.filename')
  echo "📸 Screenshot: $SCREENSHOT_FILE"

  # Console errors
  ERRORS=$($MCP_CLI console | jq -r '.logs[] | select(.type=="error") | .text')
  if [ -n "$ERRORS" ]; then
    echo "❌ Console Errors Found:"
    echo "$ERRORS" | sed 's/^/   /'
  else
    echo "✅ No console errors"
  fi

  # Accessibility
  A11Y_VIOLATIONS=$($MCP_CLI a11y | jq -r '.violations | length')
  if [ "$A11Y_VIOLATIONS" -gt 0 ]; then
    echo "⚠️  Accessibility violations: $A11Y_VIOLATIONS"
    $MCP_CLI a11y | jq -r '.violations[] | "   - \(.id): \(.description)"'
  else
    echo "✅ No accessibility violations"
  fi
done

echo ""
echo "=================================="
echo "✅ Test suite completed"
echo "📁 Screenshots: ~/.mcp/playwright/workspace/screenshots/"
```

**Integration with Claude Code Workflow:**

When Claude Code makes UI changes, it should:

1. **Deploy changes** to the Raspberry Pi
2. **Run MCP tests** to verify functionality
3. **Capture evidence** (screenshots, console logs)
4. **Report findings** to the user with visual proof
5. **Fix issues** if errors are detected
6. **Re-test** after fixes

**MCP Commands Reference for Claude Code:**

```bash
# Container Management
~/.mcp/playwright/mcp-cli.sh start      # Start MCP if not running
~/.mcp/playwright/mcp-cli.sh status     # Check if MCP is running
~/.mcp/playwright/mcp-cli.sh stop       # Stop MCP container
~/.mcp/playwright/mcp-cli.sh restart    # Restart MCP container
~/.mcp/playwright/mcp-cli.sh logs       # View MCP container logs

# Browser Testing
~/.mcp/playwright/mcp-cli.sh navigate <url>          # Navigate to URL
~/.mcp/playwright/mcp-cli.sh screenshot              # Capture screenshot
~/.mcp/playwright/mcp-cli.sh console                 # Get all console logs
~/.mcp/playwright/mcp-cli.sh network                 # Get network requests
~/.mcp/playwright/mcp-cli.sh eval '<js-code>'        # Execute JavaScript
~/.mcp/playwright/mcp-cli.sh a11y                    # Accessibility audit
```

**Programmatic HTTP API Usage:**

For complex testing scenarios, use the HTTP API directly:

```bash
# Navigate and wait for network idle
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "command": "navigate",
    "params": {
      "url": "http://192.168.1.62/dashboard.php",
      "options": {
        "waitUntil": "networkidle",
        "timeout": 30000
      }
    }
  }'

# Filter console logs for errors only
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "command": "console",
    "params": {
      "filter": {
        "type": "error"
      }
    }
  }'

# Execute JavaScript and get result
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "command": "evaluate",
    "params": {
      "script": "document.querySelectorAll(\".error\").length"
    }
  }'
```

**Best Practices for Autonomous Testing:**

1. **Always check MCP status** before running tests
2. **Use jq for JSON parsing** to extract specific data
3. **Capture screenshots** for visual verification
4. **Filter console logs** to focus on errors
5. **Run accessibility audits** to ensure inclusive design
6. **Save test results** for documentation
7. **Report findings clearly** to the user with evidence

**Screenshot Analysis:**

Screenshots are saved to `~/.mcp/playwright/workspace/screenshots/` and can be:
- Viewed locally on Mac
- Transferred to user for review
- Used for visual regression testing
- Included in bug reports with timestamps

**Console Log Analysis:**

Console logs include:
- **Errors**: JavaScript errors, API failures
- **Warnings**: Deprecation warnings, performance issues
- **Info**: Debug messages, status updates
- **Network**: Failed requests, 404s, 500s

**Accessibility Audit Results:**

The `a11y` command uses axe-core to check for:
- Missing alt text on images
- Insufficient color contrast
- Missing ARIA labels
- Keyboard navigation issues
- Semantic HTML violations

**Example: Debugging a Reported Issue**

```bash
# User reports: "Player control page shows errors in console"

# 1. Navigate to the problematic page
~/.mcp/playwright/mcp-cli.sh navigate http://192.168.1.62/player-control-ui.php

# 2. Capture current state
~/.mcp/playwright/mcp-cli.sh screenshot

# 3. Get console errors
ERRORS=$(~/.mcp/playwright/mcp-cli.sh console | jq -r '.logs[] | select(.type=="error")')

# 4. Analyze errors
echo "$ERRORS" | jq -r '.text'
# Output: "Uncaught ReferenceError: someFunction is not defined"

# 5. Fix the issue in code
# ... make changes ...

# 6. Deploy and re-test
scp file.js pi@192.168.1.62:/opt/pisignage/web/assets/js/
~/.mcp/playwright/mcp-cli.sh navigate http://192.168.1.62/player-control-ui.php
~/.mcp/playwright/mcp-cli.sh console | jq '.logs[] | select(.type=="error")'
# Output: {"logs": [], "count": 0} ✅

# 7. Capture proof of fix
~/.mcp/playwright/mcp-cli.sh screenshot
```

This autonomous testing capability significantly improves code quality and debugging efficiency.

## Recent Development Session (v0.11.0 - Nov 2025)

### Issues Resolved

#### BUG-013: Single File Playback Reliability
- **Problem**: Unreliable single file playback, files not starting consistently
- **Solution**: 4-step verification process in `player-control.php`
  1. Clear existing playlist
  2. Add file to playlist
  3. Verify file was added
  4. Start playback with retry logic
- **Files Modified**: `web/api/player-control.php`

#### BUG-014: Playlist Editing HTTP 500 Error
- **Problem**: Editing playlists returned HTTP 500, missing function
- **Root Cause**: `sanitizeFilename()` function missing from `config.php`
- **Solution**:
  - Added function to `config.php` (deployed to Pi)
  - Created `Default_Playlist.json` for filename mapping
- **Files Modified**: `web/config.php`

#### BUG-015: YouTube Download 404 Errors
- **Problem**: YouTube downloads failing with 404 errors after file cleanup
- **Root Cause**: JavaScript calling deleted `/api/youtube-simple.php`
- **Solution**: Updated API paths in `api.js` to `/api/youtube.php`
- **Files Modified**: `web/assets/js/api.js`
- **Note**: Browser cache required force refresh (Ctrl+F5)

#### BUG-016: Player Control UI Design Inconsistency
- **Problem**: Player control page using different design (Bootstrap 5) - "LAIDE"
- **Solution**: Complete redesign to match site design
  - Removed Bootstrap 5 CDN
  - Implemented card-based layout
  - Uses site's includes (header.php, footer.php, navigation.php)
  - Consistent styling with media.php and other pages
- **Files Modified**: `web/player-control-ui.php`

#### BUG-017: Player Control UI Console Errors
- **Problem**: TypeError: Cannot read properties of undefined (reading 'updateStatus')
- **Root Cause**: Missing PiSignage.player object initialization in player-control-ui.php
- **Solution**: Removed duplicate initialization code, relied on global init.js
- **Files Modified**: `web/player-control-ui.php`
- **Testing**: Playwright verified no console errors

#### BUG-018: Duplicate Default Playlists
- **Problem**: Two "Default" playlists showing in UI (Default and default)
- **Root Cause**: Filesystem has both `Default_Playlist.json` and `default.json`
- **Solution**: Documented filesystem reality, UI correctly shows both files
- **Status**: Not a bug - correct behavior

#### BUG-019: Playlist Modal Makes Page Unusable
- **Problem**: Clicking "Modifier" on playlist makes entire page unresponsive
- **Root Cause**: Modal overlay with z-index: 10000 intercepted ALL pointer events, even its own buttons
- **Solution**:
  - Removed inline onclick handlers
  - Added proper JavaScript event listeners after modal creation
  - Background click handler checks `e.target.id === 'editPlaylistModal'`
  - ESC key handler for keyboard accessibility
  - Proper cleanup in closeEditModal()
- **Files Modified**: `web/assets/js/playlists.js` (lines 158-274)
- **Testing**: X button, Annuler button, ESC key all work correctly
- **User Feedback**: "super ça fonctionne correctement"

#### BUG-020: Settings Reboot Button Not Working
- **Problem**: Reboot button in settings.php doesn't restart Raspberry Pi
- **Root Cause**: JavaScript functions not defined (only backend API existed)
- **Solution**: Added complete 127-line JavaScript section with:
  - `systemAction()` for reboot/shutdown/clear-cache
  - `restartCurrentPlayer()` for VLC restart
  - `saveAudioConfig()`, `saveDisplayConfig()`, `saveNetworkConfig()`
  - `changePassword()` with validation
  - `showAlert()` helper function
- **Files Modified**: `web/settings.php` (lines 132-257)
- **Testing**: API call succeeded, had to cancel real reboot with `sudo shutdown -c`

#### BUG-021: Logs Page Showing Nothing
- **Problem**: logs.php displayed completely blank page
- **Root Cause**: No JavaScript functions defined to load or display logs
- **Solution**: Added comprehensive 305-line logging interface with:
  - Multi-source selector (PiSignage, System, VLC, Nginx errors/access, All)
  - Line count selector (50/100/200/500 lines)
  - Color-coded log levels (ERROR=red, WARNING=yellow, INFO=blue)
  - Stats display (sources count, error count, total size)
  - Real-time filter with instant search
  - Auto-refresh toggle (5s interval)
  - Available sources list with file sizes and dates
  - Scroll to top/bottom buttons
- **Files Modified**: `web/logs.php` (complete rewrite)
- **Testing**: 75 log lines displayed, 9 sources detected, 50MB total
- **Features**: Filters, auto-refresh, multi-source support all functional

#### BUG-022: Log Files Growing Too Large
- **Problem**: Logs at 50MB+ (Nginx access.log was 52MB), risking disk space issues
- **Root Cause**: No automatic log rotation or cleanup system in place
- **Solution**: Created comprehensive automated log rotation system with:
  - **Size-based rotation:**
    - PiSignage logs >10MB → rotate + gzip compress
    - Nginx logs >50MB → rotate + gzip compress
  - **Age-based cleanup:**
    - YouTube download logs >7 days → delete
    - Rotated logs >30 days → delete
    - Old Nginx logs >14 days → delete
  - **Automated daily execution:**
    - Cron job installed to `/etc/cron.daily/pisignage-rotate-logs`
    - Runs automatically at 3am daily
    - Logs output to `/opt/pisignage/logs/rotation.log`
  - **Manual UI trigger:**
    - "Rotation & Nettoyage" button in logs.php
    - Confirmation dialog explaining actions
    - Progress indicator during rotation
    - Auto-refresh after success
- **Files Added**:
  - `scripts/rotate-logs.sh` (155 lines) - Main rotation script with colored output
  - `scripts/setup-log-rotation-cron.sh` (57 lines) - Installation script
- **Files Modified**: `web/logs.php` (added rotation button and rotateLogs() function)
- **Testing Results**:
  - Before: Nginx logs = 63MB (access.log = 52MB)
  - After: Nginx logs = 13MB (access.log.1.gz = 649KB)
  - Space saved: 50MB immediately
- **Deployment**: Scripts deployed to Pi, cron installed, fully functional

### New Features (v0.11.0)

#### Volume Control (ALSA, v0.12)
> Le « volume VLC » a disparu avec VLC. Le lecteur Chromium utilise l'audio système, donc
> il n'y a plus qu'**un** volume : le volume système (ALSA).
- **System Volume (ALSA)**: 0-100% range via amixer commands
- **API Endpoints (system.php)**:
  - `GET /api/system.php?action=get_volume`
  - `POST /api/system.php?action=set_volume`
  - `POST /api/system.php?action=toggle_mute`

### Development Insights

#### Cache Management
- Browser caches JavaScript with version parameter (`?v=869`)
- Direct Pi modifications require version bump or force refresh
- Use `sed` on Pi for emergency fixes to avoid cache issues
- Playwright MCP container cache: Use `~/.mcp/playwright/mcp-cli.sh restart` to clear

#### Modal Event Handling Pattern
When creating modal overlays that block page interaction:
```javascript
// ❌ WRONG: pointer-events CSS approach
modal.style.pointerEvents = 'none';  // Allows unwanted click-through
modalContent.style.pointerEvents = 'auto';

// ✅ CORRECT: JavaScript event handler approach
const modal = document.getElementById('myModal');

// Background click handler
const backgroundClickHandler = function(e) {
    if (e.target.id === 'myModal') {  // Only if clicking overlay
        closeModal();
    }
};
modal.addEventListener('click', backgroundClickHandler);
modal._backgroundClickHandler = backgroundClickHandler;  // Store for cleanup

// ESC key handler
const escapeHandler = function(e) {
    if (e.key === 'Escape') {
        closeModal();
    }
};
document.addEventListener('keydown', escapeHandler);
modal._escapeHandler = escapeHandler;  // Store for cleanup

// Cleanup function
function closeModal() {
    const modal = document.getElementById('myModal');
    if (modal) {
        // Remove event handlers to prevent memory leaks
        if (modal._escapeHandler) {
            document.removeEventListener('keydown', modal._escapeHandler);
        }
        if (modal._backgroundClickHandler) {
            modal.removeEventListener('click', modal._backgroundClickHandler);
        }
        modal.remove();
    }
}
```

#### Log Rotation Best Practices
When implementing log management on Raspberry Pi:
- **Size thresholds**: 10MB for app logs, 50MB for system logs (Nginx)
- **Age thresholds**: 7 days for temporary logs, 30 days for rotated archives
- **Compression**: Always use gzip for rotated logs (50MB → 649KB = 98.7% savings)
- **Cron timing**: Schedule at 3am to avoid peak usage
- **Logging the logger**: Log rotation events to system.log for audit trail
- **Manual trigger**: Provide UI button for emergency cleanup

#### Filename Sanitization Pattern
```php
function sanitizeFilename($filename) {
    // Remove special characters
    $filename = preg_replace('/[^a-zA-Z0-9\-\_\.]/', '_', $filename);
    // Prevent double dots
    $filename = preg_replace('/\.+/', '.', $filename);
    // Prevent empty names
    if (empty($filename) || $filename === '.') {
        $filename = 'file_' . time();
    }
    return $filename;
}
```

#### Design Consistency Checklist
When creating new pages, ensure:
- [ ] Uses `includes/auth.php` for authentication
- [ ] Uses `includes/header.php` for head section
- [ ] Uses `includes/navigation.php` for sidebar
- [ ] Uses `includes/footer.php` for closing tags
- [ ] Card-based layout with `.card`, `.card-header`, `.card-body`
- [ ] Consistent button styles (`.btn`, `.btn-primary`, etc.)
- [ ] No external CSS frameworks (Bootstrap, Tailwind, etc.)

## Current Architecture (v0.11.0)

### Modular Multi-Page Application
- **9 PHP pages**: dashboard.php, media.php, playlists.php, player.php, settings.php, logs.php, screenshot.php, youtube.php, schedule.php
- **6 CSS modules**: main.css, core.css, layout.css, components.css, responsive.css, modern-ui.css
- **7 JavaScript modules**: core.js, api.js, dashboard.js, media.js, playlists.js, player.js, init.js
- **Shared components**: includes/header.php, includes/navigation.php, includes/auth.php

### Performance Improvements
- **80% faster loading** (5s → 1s on Raspberry Pi)
- **73% less memory usage** (150MB → 40MB per page)
- **83% faster JavaScript parsing** (3s → 0.5s)
- **400% better maintainability** (2/10 → 8/10 score)

## Development Guidelines

### When Working on PiSignage

1. **Understand the Architecture**: Review [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for complete technical details
2. **Maintain Modularity**: Keep page-specific code isolated to respective modules
3. **Performance First**: Always consider Raspberry Pi constraints
4. **Test Thoroughly**: Verify on actual Raspberry Pi hardware when possible

### Code Organization

#### PHP Files
```
/web/
├── [page].php        # Individual page files (~500 lines max)
├── includes/         # Shared components
└── api/             # REST API endpoints
```

#### CSS Structure
```
/assets/css/
├── main.css         # Entry point (imports others)
├── core.css         # Base styles, resets
├── layout.css       # Grid system, layouts
├── components.css   # UI components
├── responsive.css   # Mobile/tablet support
└── modern-ui.css    # Advanced effects
```

#### JavaScript Modules
```
/assets/js/
├── core.js          # PiSignage namespace, utilities
├── api.js           # API communication layer
├── [module].js      # Page-specific functionality
└── init.js          # Application initialization
```

### Development Workflow

1. **Feature Development**:
   - Identify which page/module needs modification
   - Create isolated changes in appropriate files
   - Test functionality without affecting other modules
   - Verify performance impact on Raspberry Pi

2. **Testing Requirements**:
   - Test on Raspberry Pi 4 (primary target)
   - Verify mobile responsiveness
   - Check API compatibility
   - Validate navigation between pages

3. **Performance Considerations**:
   - Keep individual files under 500 lines
   - Minimize JavaScript execution time
   - Optimize for low-power ARM processors
   - Consider memory constraints

### API Development

#### Endpoint Standards
- All endpoints return JSON with consistent structure:
```json
{
  "success": true|false,
  "data": {...},
  "message": "Human-readable message",
  "timestamp": "ISO 8601 format"
}
```

#### Security Requirements
- Input validation on all endpoints
- Proper error handling
- File upload security (type, size validation)
- SQL injection prevention (if using database)

### Common Development Tasks

#### Adding a New Page
1. Create `/web/newpage.php` following existing pattern
2. Add navigation link in `includes/navigation.php`
3. Create `/assets/js/newpage.js` if needed
4. Add CSS rules in appropriate module
5. Update documentation

#### Modifying Existing Functionality
1. Identify the correct module (page, CSS, or JS file)
2. Make isolated changes
3. Test that other modules remain unaffected
4. Verify API compatibility

#### Performance Optimization
1. Profile current performance
2. Identify bottlenecks
3. Optimize without breaking modularity
4. Test on Raspberry Pi hardware
5. Document improvements

### Debugging Guidelines

#### Common Issues
- **Navigation errors**: Check JavaScript namespace conflicts
- **CSS styling issues**: Verify CSS import order in main.css
- **API failures**: Check PHP error logs and endpoint responses
- **Performance problems**: Monitor memory usage and CPU load

#### Debugging Tools
```bash
# System monitoring
htop                           # CPU/Memory usage
journalctl -u pisignage -f     # Service logs
tail -f /var/log/nginx/error.log  # Web server errors

# Application logs
tail -f /opt/pisignage/logs/pisignage.log

# Network debugging
curl -v http://localhost/api/system.php
```

### Version Control

#### Git Workflow
- **Main branch**: Production-ready code
- **Feature branches**: Individual feature development
- **Hotfix branches**: Critical bug fixes

#### Commit Guidelines
```
type(scope): description

feat(media): add drag-and-drop file upload
fix(navigation): resolve mobile menu toggle issue
perf(dashboard): optimize stats loading
docs(readme): update installation instructions
```

### Testing Protocol

#### Manual Testing Checklist
- [ ] Web interface loads correctly
- [ ] Navigation between pages works
- [ ] Media upload/management functions
- [ ] Player controls work (VLC exclusive)
- [ ] API endpoints respond correctly
- [ ] Mobile interface is functional
- [ ] Performance is acceptable on Pi

#### Automated Testing
```bash
# Run verification script
./scripts/verify-system.sh

# Performance benchmarks
./scripts/benchmark.sh

# API endpoint tests
./scripts/test-api.sh
```

### Deployment Protocol

#### Production Deployment
1. **Pre-deployment**:
   - Run full test suite
   - Verify on staging Raspberry Pi
   - Check performance metrics
   - Review security considerations

2. **Deployment**:
   - Create system backup
   - Deploy code changes
   - Restart necessary services
   - Verify functionality

3. **Post-deployment**:
   - Monitor system logs
   - Check performance metrics
   - Verify all features work
   - Document any issues

#### Rollback Procedure
```bash
# Emergency rollback
sudo systemctl stop pisignage nginx
sudo cp -r /opt/pisignage-backup /opt/pisignage
sudo systemctl start nginx pisignage
```

### Documentation Standards

#### Code Documentation
- PHP functions must have PHPDoc comments
- JavaScript functions need JSDoc comments
- CSS components should have usage comments
- API endpoints require full documentation

#### User Documentation
- Update README.md for feature changes
- Maintain CHANGELOG.md for releases
- Update ARCHITECTURE.md for structural changes
- Keep MIGRATION.md current for version upgrades

### Security Considerations

#### Input Validation
```php
// Example validation pattern
function validateFilename($filename) {
    return preg_match('/^[a-zA-Z0-9._-]+$/', $filename);
}
```

#### File Upload Security
- Validate file types and extensions
- Check file sizes (500MB limit)
- Scan for malicious content
- Store in designated directories only

#### API Security
- Rate limiting for API endpoints
- Input sanitization
- Proper error handling (don't expose internals)
- CSRF protection for state-changing operations

### Performance Optimization

#### Raspberry Pi Specific
- Minimize DOM manipulation
- Use efficient CSS selectors
- Optimize image formats and sizes
- Cache static resources
- Minimize JavaScript execution

#### Memory Management
```javascript
// Cleanup pattern
window.addEventListener('beforeunload', function() {
    // Clean up event listeners
    // Clear intervals/timeouts
    // Remove DOM references
});
```

### Common Pitfalls to Avoid

1. **Global Namespace Pollution**: Always use PiSignage namespace
2. **Monolithic Functions**: Keep functions focused and small
3. **Excessive DOM Queries**: Cache DOM references
4. **Blocking Operations**: Use async/await for API calls
5. **Memory Leaks**: Clean up event listeners and timers

### Future Development Considerations

#### Scalability
- Maintain modular architecture
- Plan for additional pages/features
- Consider microservice patterns for complex features
- Design for multiple Pi installations

#### Technology Evolution
- Monitor web technology changes
- Consider Progressive Web App (PWA) features
- Plan for WebRTC streaming capabilities
- Evaluate container deployment options

### Contact and Support

#### Development Team
- Primary repository: https://github.com/elkir0/Pi-Signage
- Issue tracking: GitHub Issues
- Documentation: GitHub Wiki

#### Code Review Process
- All changes require review
- Performance impact assessment
- Security review for sensitive changes
- Documentation updates required

---

## Raspberry Pi OS Trixie & Kiosk Mode (feature/trixie-kiosk-chromium)

### Overview

PiSignage runs on **Raspberry Pi OS Trixie (Debian 13)** with a Wayland-based Chromium kiosk as the **single** playback engine (VLC retiré en v0.12).

### Trixie Architecture

```
Boot → lightdm (autologin 'pi', session manager — PAS greetd)
     → labwc (Wayland compositor)
     → Chromium (kiosk browser, full-screen, --kiosk http://127.0.0.1/player)
```

### Key Components

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **lightdm** | Autologin `pi` & session init | `/etc/lightdm/lightdm.conf.d/10-pisignage-autologin.conf` |
| **labwc** | Wayland compositor | `~/.config/labwc/rc.xml`, autostart `~/.config/labwc/autostart` |
| **Chromium** | Kiosk browser (lecteur unique) | Autostart généré par `kiosk-apply` |
| **kiosk-apply** | Générateur d'autostart | `/opt/pisignage/scripts/kiosk-apply` |
| **scheduler.php** | Exécuteur dayparting (cron 1×/min, www-data) | `/etc/cron.d/pisignage-scheduler` |

### Development Guidelines for Trixie

1. **Wayland-First**: No X11 tools (no `xdotool`, `unclutter`, etc.)
2. **POSIX Shell**: Scripts use POSIX sh, not bash-specific features
3. **Idempotent**: Scripts safe to re-run without side effects
4. **Feature Flag**: `ENABLE_KIOSK=0` for easy rollback

### Configuration Files

```
/opt/pisignage/config/
├── kiosk_url           # Target URL (default: https://time.is)
├── kiosk_flags         # Chromium flags
└── feature_flags       # ENABLE_KIOSK=1 or 0
```

### Kiosk API Development

New REST API endpoints for remote kiosk management:

```php
// Example: Update kiosk URL
PUT /api/kiosk.php/url
{
  "url": "https://dashboard.local"
}

// Example: Restart Chromium
POST /api/kiosk.php/restart
```

See [API_DOCUMENTATION.md](API_DOCUMENTATION.md#kiosk-api-apikioskphp-) for complete API reference.

### Testing Kiosk Features

```bash
# Run smoke tests (local, no Pi needed)
bash scripts/tests/smoke.sh

# Run API tests (requires server running)
bash scripts/tests/api.sh
```

### Common Kiosk Development Tasks

#### Modify Chromium Flags
```bash
# Edit flags file
sudo nano /opt/pisignage/config/kiosk_flags

# Regenerate autostart
bash /opt/pisignage/scripts/kiosk-apply
```

#### Change Kiosk URL
```bash
# Via API
curl -X PUT http://[pi-ip]/api/kiosk.php/url \
  -H "Content-Type: application/json" \
  -d '{"url":"https://new-url.com"}'

# Or manually
echo "https://new-url.com" | sudo tee /opt/pisignage/config/kiosk_url
bash /opt/pisignage/scripts/kiosk-apply
```

#### Disable Kiosk Mode
```bash
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags
sudo reboot
```

### Troubleshooting Kiosk

**Chromium not starting:**
```bash
# Check autostart file
cat ~/.config/labwc/autostart

# Regenerate
bash /opt/pisignage/scripts/kiosk-apply

# Check logs
journalctl --user -u labwc -n 50
```

**Network timeout:**
```bash
# kiosk-apply waits max 20s for network
# Check network status
ip a

# Restart networking
sudo systemctl restart NetworkManager
```

### Documentation References

- **[UPGRADE_TRIXIE.md](UPGRADE_TRIXIE.md)** - Complete Trixie installation & config guide
- **[README.md](README.md#-trixie--wayland-kiosk-mode)** - Trixie feature overview
- **[CHANGELOG.md](CHANGELOG.md)** - Release history including Trixie updates

---

## v0.12 — Unified Diffusion (architecture de référence)

Modèle mental : **MÉDIAS → PLAYLISTS (composer + ordonner) → DIFFUSION → ÉCRAN**, avec
**PROGRAMMATION** qui décide quelle playlist est ACTIVE selon l'heure/jour. Un seul moteur,
un seul modèle de playlist, un seul scheduler.

### Moteur de lecture unique
- **Chromium HTML5** : `web/player.php` servi sur `/player`, lit `/opt/pisignage/media/playlist.json`.
  C'est le SEUL lecteur affiché en kiosk. VLC retiré (service, paquet, port 8080 supprimés).
- Le player **poll** un canal de commande (2s) et **rapporte** son état (5s) à `api/display.php`.

### APIs (source de vérité)
- **`api/display.php`** — contrôle du moteur réel :
  - `POST ?action=command {cmd:next|prev|play|pause|reload}` (admin) ; `GET ?action=command` (public, le player poll).
  - `POST ?action=state` (public, le player rapporte) ; `GET ?action=state` (admin : état + online + playlist active).
  - `POST ?action=playmedia {file}` (admin : lecture directe = playlist live 1-élément).
- **`api/playlists.php`** — playlists unifiées : `GET` (liste + active), `GET ?name=X`, `POST` (créer/maj),
  `POST ?action=activate&name=X` (« Diffuser »), `DELETE ?name=X`. Stockage `PLAYLISTS_PATH/<slug>.json`,
  pointeur actif `config/active-playlist.json`. « Diffuser » écrit `media/playlist.json` + bump version → reload.
- **`api/playlists-core.php`** — NOYAU partagé (modèle, normalisation `{file}→{url}`, `playlistActivateByName`,
  `playlistPushLive`, intégrité média rename/suppression). Inclus par `playlists.php`, `scheduler.php`, `media.php`, `schedule.php`.
- **`api/scheduler.php`** — EXÉCUTEUR CLI (cron 1×/min, www-data). Lit `data/schedules.json`, pose la playlist
  active (récurrence + priorité), idempotent, revert en fin de fenêtre, écrit `config/scheduler-state.json`.
- **`api/system.php`** — volume **ALSA** (`get_volume`/`set_volume`/`toggle_mute`), `restart-player` = `restart display-manager`.
- **Dépréciés (HTTP 410)** : `player.php`, `player-control.php` (contrôle VLC), `playlist-simple.php` (lecture-seule + 410 en écriture).
- **Inchangé / load-bearing** : `GET /api/playlist` (= `playlist.php`) que le player lit pour la playlist live.

### Pages UI (rôles)
- **Playlists** : composer/ordonner + **Diffuser** (au même endroit).
- **Lecteur** (`player-control-ui.php`) : pilote le moteur réel (play/pause/skip/reload), état live, volume ALSA.
- **Kiosk** : réglages d'**affichage** uniquement (mode, URL, flags Chromium, extinction écran, redémarrage).
- **Programmation** : dayparting réel (badge « En cours » = état réel via `is_active_now`).

### Pièges (timezone, cache, perms)
- **Fuseau horaire** : `config.php` aligne PHP sur `/etc/timezone` (php.ini=UTC mais les heures de planning
  sont LOCALES — sans ça le dayparting ne se déclenche jamais).
- **Cron scheduler en www-data** (même utilisateur que l'API) → aucune divergence de permissions sur
  `media/playlist.json`, `config/*.json`, `logs/system.log`.
- **player.php envoie `Cache-Control: no-store`** (sinon Chromium garde l'ancienne page en cache disque).
- Le report d'état périodique n'utilise **pas** `keepalive` (quota navigateur → battement figé sur Pi lent).

---

## Summary

PiSignage v0.8.9 represents a modern, modular approach to digital signage software. The architecture prioritizes performance, maintainability, and developer experience while maintaining full compatibility with existing installations.

Key principles:
- **Modularity**: Keep concerns separated
- **Performance**: Optimize for Raspberry Pi
- **Maintainability**: Write clear, testable code
- **Compatibility**: Preserve existing functionality
- **Documentation**: Keep docs current and comprehensive

When in doubt, refer to the existing code patterns and prioritize the user experience on Raspberry Pi hardware.

---

*This protocol document should be reviewed and updated with each major release to reflect current best practices and architectural decisions.*