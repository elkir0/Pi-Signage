# Claude Development Protocol - PiSignage v0.11.0

## Project Overview

PiSignage is a professional digital signage solution optimized for Raspberry Pi hardware. Version 0.11.0 includes:
- **Chromium Kiosk Mode**: Wayland-based full-screen browser for HTML5 content
- **VLC Media Player**: Traditional video playback with HTTP API control
- **Dual Volume Control**: Independent VLC and system (ALSA) audio management
- **Modern Web Interface**: Redesigned UI with consistent design patterns
- **100% Reliable Playback**: Fixed single-file playback with 4-step verification

## Development Environment & Stack

### Hardware Target
- **Primary**: Raspberry Pi 4/5 (2GB+ RAM)
- **OS**: Raspberry Pi OS Trixie (Debian 13) with Wayland
- **Network**: Raspberry Pi at 192.168.1.62

### Technology Stack

#### Backend
- **PHP 8.4**: Web application backend (php8.4-fpm)
- **Nginx**: Web server with FastCGI
- **VLC 3.x**: Media player with HTTP API (port 9999)
- **Chromium**: Kiosk browser for HTML5 content

#### Frontend
- **Vanilla JavaScript**: No frameworks, modular ES6+ patterns
- **PiSignage Namespace**: Global `window.PiSignage` object for all modules
- **CSS Modules**: 6 modular stylesheets (main, core, layout, components, responsive, modern-ui)
- **RESTful APIs**: JSON-based communication layer

#### System Components
- **ALSA**: System-level audio control via amixer
- **Wayland (labwc)**: Display server for kiosk mode
- **greetd**: Auto-login session manager
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

### New Features (v0.11.0)

#### Dual Volume Control
- **VLC Player Volume**: 0-320 range (125% max boost) via HTTP API
- **System Volume (ALSA)**: 0-100% range via amixer commands
- **Independent Mute**: Separate mute buttons for VLC and system
- **API Endpoints Added to system.php**:
  - `GET /api/system.php?action=get_volume`
  - `POST /api/system.php?action=set_volume`
  - `POST /api/system.php?action=toggle_mute`
- **UI Components**: Dual slider controls with real-time feedback

### Development Insights

#### Cache Management
- Browser caches JavaScript with version parameter (`?v=869`)
- Direct Pi modifications require version bump or force refresh
- Use `sed` on Pi for emergency fixes to avoid cache issues

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

PiSignage now supports **Raspberry Pi OS Trixie (Debian 13)** with Wayland-based Chromium kiosk mode, in addition to traditional VLC media playback.

### Trixie Architecture

```
Boot → greetd (session manager)
     → labwc (Wayland compositor)
     → Chromium (kiosk browser, full-screen)
```

### Key Components

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **greetd** | Auto-login & session init | System-level |
| **labwc** | Wayland compositor | `~/.config/labwc/rc.xml` |
| **Chromium** | Kiosk browser | Autostart generated by `kiosk-apply` |
| **kiosk-apply** | Config generator | `/opt/pisignage/scripts/kiosk-apply` |

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