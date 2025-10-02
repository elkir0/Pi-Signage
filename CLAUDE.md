alors# Claude Development Protocol - PiSignage v0.8.9

## Project Overview

PiSignage is a professional digital signage solution optimized for Raspberry Pi hardware. Version 0.8.9 represents a complete architectural transformation from a monolithic SPA to a modular MPA system with VLC-exclusive player support.

## Current Architecture (v0.8.9)

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
- [ ] Player controls work (VLC/MPV)
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

## Summary

PiSignage v0.8.5 represents a modern, modular approach to digital signage software. The architecture prioritizes performance, maintainability, and developer experience while maintaining full compatibility with existing installations.

Key principles:
- **Modularity**: Keep concerns separated
- **Performance**: Optimize for Raspberry Pi
- **Maintainability**: Write clear, testable code
- **Compatibility**: Preserve existing functionality
- **Documentation**: Keep docs current and comprehensive

When in doubt, refer to the existing code patterns and prioritize the user experience on Raspberry Pi hardware.

---

*This protocol document should be reviewed and updated with each major release to reflect current best practices and architectural decisions.*