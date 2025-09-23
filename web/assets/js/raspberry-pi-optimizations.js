/**
 * PiSignage v0.8.0 - Raspberry Pi Specific Optimizations
 * Performance and hardware-specific enhancements
 */

class RaspberryPiOptimizations {
    constructor() {
        this.isRaspberryPi = this.detectRaspberryPi();
        this.performanceMode = 'auto'; // auto, performance, power-save
        this.gpuMemory = null;
        this.thermalThrottle = false;
        this.hardwareInfo = {};

        this.init();
    }

    init() {
        if (this.isRaspberryPi) {
            console.log('🍓 Raspberry Pi detected - Applying optimizations');
            this.applyRaspberryPiOptimizations();
            this.monitorHardware();
        }

        this.setupPerformanceMonitoring();
        this.optimizeForLowPower();
        this.setupHardwareAcceleration();
    }

    /**
     * Detect if running on Raspberry Pi
     */
    detectRaspberryPi() {
        // Check user agent and platform
        const ua = navigator.userAgent.toLowerCase();
        const platform = navigator.platform.toLowerCase();

        // Common Raspberry Pi indicators
        const indicators = [
            ua.includes('raspberry'),
            ua.includes('armv'),
            platform.includes('arm'),
            ua.includes('linux arm'),
            // Check for specific hardware capabilities
            navigator.hardwareConcurrency <= 4,
            navigator.deviceMemory && navigator.deviceMemory <= 8
        ];

        // Additional detection via performance characteristics
        const hasLimitedGPU = this.detectLimitedGPU();
        const hasLimitedRAM = this.detectLimitedRAM();

        return indicators.filter(Boolean).length >= 2 || hasLimitedGPU || hasLimitedRAM;
    }

    detectLimitedGPU() {
        // Check WebGL capabilities typical of Raspberry Pi
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

        if (!gl) return true; // No WebGL likely indicates limited GPU

        const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
        if (debugInfo) {
            const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
            return renderer.toLowerCase().includes('videocore') ||
                   renderer.toLowerCase().includes('broadcom') ||
                   renderer.toLowerCase().includes('vc4');
        }

        return false;
    }

    detectLimitedRAM() {
        // Estimate available RAM
        if (navigator.deviceMemory) {
            return navigator.deviceMemory <= 4; // 4GB or less
        }

        // Fallback: performance-based detection
        const start = performance.now();
        const testArray = new Array(1000000).fill(0);
        const end = performance.now();

        return (end - start) > 100; // Slow allocation indicates limited RAM
    }

    /**
     * Apply Raspberry Pi specific optimizations
     */
    applyRaspberryPiOptimizations() {
        // Reduce animation complexity
        this.reduceAnimations();

        // Optimize rendering
        this.optimizeRendering();

        // Reduce polling frequency
        this.adjustPollingFrequency();

        // Optimize image loading
        this.optimizeImageLoading();

        // Enable hardware acceleration where possible
        this.enableHardwareAcceleration();

        // Adjust cache strategies
        this.adjustCacheStrategies();
    }

    reduceAnimations() {
        // Add CSS to reduce animations on Pi
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi {
                --transition-fast: 0.1s ease;
                --transition-normal: 0.2s ease;
                --transition-slow: 0.3s ease;
            }

            .raspberry-pi * {
                animation-duration: 0.3s !important;
                transition-duration: 0.2s !important;
            }

            .raspberry-pi .loading {
                animation-duration: 0.8s !important;
            }

            /* Disable complex animations on Pi */
            .raspberry-pi .nav-tab::before,
            .raspberry-pi .btn::before,
            .raspberry-pi .progress-fill::after {
                display: none !important;
            }

            /* Simplify hover effects */
            .raspberry-pi .card:hover {
                transform: translateY(-2px) !important;
            }

            .raspberry-pi .media-item:hover {
                transform: translateY(-2px) !important;
            }
        `;

        document.head.appendChild(style);
        document.body.classList.add('raspberry-pi');
    }

    optimizeRendering() {
        // Reduce rendering complexity
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi {
                /* Disable expensive filters on Pi */
                backdrop-filter: none !important;
                -webkit-backdrop-filter: none !important;
            }

            .raspberry-pi .header,
            .raspberry-pi .card {
                background: rgba(30, 41, 59, 0.95) !important;
                backdrop-filter: none !important;
            }

            /* Simplify shadows */
            .raspberry-pi .card {
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1) !important;
            }

            /* Disable text shadows */
            .raspberry-pi .logo-title {
                text-shadow: none !important;
            }
        `;

        document.head.appendChild(style);

        // Use simpler gradients
        this.simplifyGradients();
    }

    simplifyGradients() {
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi .btn-primary {
                background: #6366f1 !important;
            }

            .raspberry-pi .btn-success {
                background: #10b981 !important;
            }

            .raspberry-pi .btn-danger {
                background: #ef4444 !important;
            }

            .raspberry-pi .progress-fill {
                background: #6366f1 !important;
            }

            .raspberry-pi .player-btn {
                background: #6366f1 !important;
            }
        `;

        document.head.appendChild(style);
    }

    adjustPollingFrequency() {
        // Reduce system stats polling on Pi
        if (window.app && window.app.config) {
            window.app.config.statsUpdateInterval = 10000; // 10 seconds instead of 5
        }

        // Reduce auto-screenshot frequency
        const intervalInput = document.getElementById('auto-interval');
        if (intervalInput) {
            intervalInput.min = '10'; // Minimum 10 seconds
            intervalInput.value = Math.max(intervalInput.value, '30');
        }
    }

    optimizeImageLoading() {
        // Implement lazy loading with intersection observer
        this.setupIntersectionObserver();

        // Optimize image sizes
        this.setupResponsiveImages();

        // Preload critical images only
        this.preloadCriticalImages();
    }

    setupIntersectionObserver() {
        if ('IntersectionObserver' in window) {
            const imageObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        this.loadImage(entry.target);
                        imageObserver.unobserve(entry.target);
                    }
                });
            }, {
                rootMargin: '50px 0px',
                threshold: 0.1
            });

            // Observe all images with data-src
            document.querySelectorAll('img[data-src]').forEach(img => {
                imageObserver.observe(img);
            });
        }
    }

    loadImage(img) {
        img.src = img.dataset.src;
        img.removeAttribute('data-src');
        img.classList.add('loaded');
    }

    setupResponsiveImages() {
        // Convert high-res images to appropriate sizes
        const images = document.querySelectorAll('.media-thumbnail img');
        images.forEach(img => {
            img.addEventListener('load', () => {
                this.optimizeImageSize(img);
            });
        });
    }

    optimizeImageSize(img) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');

        // Limit image size for Pi
        const maxWidth = 400;
        const maxHeight = 300;

        if (img.naturalWidth > maxWidth || img.naturalHeight > maxHeight) {
            const ratio = Math.min(maxWidth / img.naturalWidth, maxHeight / img.naturalHeight);

            canvas.width = img.naturalWidth * ratio;
            canvas.height = img.naturalHeight * ratio;

            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

            // Replace with optimized version
            img.src = canvas.toDataURL('image/jpeg', 0.8);
        }
    }

    preloadCriticalImages() {
        // Only preload essential UI images
        const criticalImages = [
            '/assets/images/logo.png',
            '/assets/images/icons/play.svg',
            '/assets/images/icons/pause.svg'
        ];

        criticalImages.forEach(src => {
            const img = new Image();
            img.src = src;
        });
    }

    enableHardwareAcceleration() {
        // Enable GPU acceleration where available
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi .card,
            .raspberry-pi .nav-tab,
            .raspberry-pi .btn {
                will-change: transform;
                transform: translateZ(0);
            }

            /* Use transform3d for better GPU acceleration */
            .raspberry-pi .card:hover {
                transform: translate3d(0, -2px, 0);
            }

            .raspberry-pi .nav-tab:hover {
                transform: translate3d(0, -1px, 0);
            }
        `;

        document.head.appendChild(style);
    }

    adjustCacheStrategies() {
        // Configure service worker for Pi-specific caching
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.ready.then(registration => {
                registration.active.postMessage({
                    action: 'configurePi',
                    config: {
                        maxCacheSize: 50 * 1024 * 1024, // 50MB max cache
                        maxImageSize: 2 * 1024 * 1024,  // 2MB max per image
                        aggressivePurging: true
                    }
                });
            });
        }
    }

    /**
     * Monitor hardware performance
     */
    monitorHardware() {
        setInterval(() => {
            this.checkThermalThrottling();
            this.checkMemoryUsage();
            this.checkGPUUsage();
            this.adjustPerformanceMode();
        }, 30000); // Check every 30 seconds
    }

    async checkThermalThrottling() {
        try {
            // Check if temperature is causing throttling
            if (window.app) {
                const stats = await window.app.loadSystemStats();
                if (stats && stats.temperature) {
                    const temp = parseFloat(stats.temperature);
                    if (temp > 70) { // Above 70°C
                        this.enablePowerSaveMode();
                        this.thermalThrottle = true;
                    } else if (temp < 60 && this.thermalThrottle) {
                        this.disablePowerSaveMode();
                        this.thermalThrottle = false;
                    }
                }
            }
        } catch (error) {
            console.warn('Thermal monitoring failed:', error);
        }
    }

    checkMemoryUsage() {
        // Monitor memory usage and adjust accordingly
        if (performance.memory) {
            const memoryInfo = performance.memory;
            const usagePercent = (memoryInfo.usedJSHeapSize / memoryInfo.jsHeapSizeLimit) * 100;

            if (usagePercent > 80) {
                this.enableMemoryOptimizations();
            }
        }
    }

    checkGPUUsage() {
        // Simple GPU usage estimation
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl');

        if (gl) {
            const start = performance.now();

            // Simple GPU test
            const texture = gl.createTexture();
            gl.bindTexture(gl.TEXTURE_2D, texture);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 256, 256, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);

            const end = performance.now();
            const gpuTime = end - start;

            if (gpuTime > 10) { // Slow GPU operations
                this.enableGPUOptimizations();
            }

            gl.deleteTexture(texture);
        }
    }

    adjustPerformanceMode() {
        const systemLoad = this.calculateSystemLoad();

        if (systemLoad > 0.8) {
            this.setPerformanceMode('power-save');
        } else if (systemLoad < 0.3) {
            this.setPerformanceMode('performance');
        } else {
            this.setPerformanceMode('balanced');
        }
    }

    calculateSystemLoad() {
        // Estimate system load based on various factors
        let load = 0;

        // Memory usage
        if (performance.memory) {
            const memoryUsage = performance.memory.usedJSHeapSize / performance.memory.jsHeapSizeLimit;
            load += memoryUsage * 0.4;
        }

        // Frame rate estimation
        const frameRate = this.getFrameRate();
        if (frameRate < 30) {
            load += 0.3;
        }

        // Active animations
        const animatedElements = document.querySelectorAll(':not(.raspberry-pi) [style*="transform"]').length;
        load += Math.min(animatedElements / 20, 0.3);

        return Math.min(load, 1);
    }

    getFrameRate() {
        // Simple frame rate estimation
        let frameCount = 0;
        const startTime = performance.now();

        const countFrames = () => {
            frameCount++;
            if (performance.now() - startTime < 1000) {
                requestAnimationFrame(countFrames);
            }
        };

        requestAnimationFrame(countFrames);

        return new Promise(resolve => {
            setTimeout(() => resolve(frameCount), 1000);
        });
    }

    setPerformanceMode(mode) {
        if (this.performanceMode === mode) return;

        this.performanceMode = mode;
        document.body.classList.remove('performance-mode', 'balanced-mode', 'power-save-mode');
        document.body.classList.add(mode + '-mode');

        switch (mode) {
            case 'performance':
                this.enablePerformanceMode();
                break;
            case 'balanced':
                this.enableBalancedMode();
                break;
            case 'power-save':
                this.enablePowerSaveMode();
                break;
        }

        console.log('🍓 Performance mode changed to:', mode);
    }

    enablePerformanceMode() {
        // Enable full features
        const style = document.createElement('style');
        style.id = 'performance-mode-style';
        style.textContent = `
            .performance-mode {
                --transition-normal: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                --transition-slow: 0.5s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .performance-mode .card {
                backdrop-filter: blur(20px);
            }
        `;

        this.removeStyleById('power-save-mode-style');
        this.removeStyleById('balanced-mode-style');
        document.head.appendChild(style);
    }

    enableBalancedMode() {
        const style = document.createElement('style');
        style.id = 'balanced-mode-style';
        style.textContent = `
            .balanced-mode {
                --transition-normal: 0.2s ease;
                --transition-slow: 0.3s ease;
            }

            .balanced-mode .card {
                backdrop-filter: blur(10px);
            }
        `;

        this.removeStyleById('performance-mode-style');
        this.removeStyleById('power-save-mode-style');
        document.head.appendChild(style);
    }

    enablePowerSaveMode() {
        const style = document.createElement('style');
        style.id = 'power-save-mode-style';
        style.textContent = `
            .power-save-mode {
                --transition-normal: 0.1s ease;
                --transition-slow: 0.2s ease;
            }

            .power-save-mode * {
                animation: none !important;
                transition: none !important;
            }

            .power-save-mode .card {
                backdrop-filter: none !important;
                background: rgba(30, 41, 59, 0.95) !important;
            }

            .power-save-mode .btn::before,
            .power-save-mode .nav-tab::before {
                display: none !important;
            }
        `;

        this.removeStyleById('performance-mode-style');
        this.removeStyleById('balanced-mode-style');
        document.head.appendChild(style);
    }

    enableMemoryOptimizations() {
        // Clear unused caches
        if ('caches' in window) {
            caches.keys().then(names => {
                names.forEach(name => {
                    if (!name.includes('v0.8.0')) {
                        caches.delete(name);
                    }
                });
            });
        }

        // Reduce image cache
        this.reduceImageCache();

        // Force garbage collection if available
        if (window.gc) {
            window.gc();
        }
    }

    enableGPUOptimizations() {
        // Disable expensive GPU operations
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi {
                filter: none !important;
                backdrop-filter: none !important;
                -webkit-backdrop-filter: none !important;
            }

            .raspberry-pi * {
                box-shadow: none !important;
                text-shadow: none !important;
            }
        `;

        document.head.appendChild(style);
    }

    reduceImageCache() {
        // Remove large images from cache
        const images = document.querySelectorAll('img');
        images.forEach(img => {
            if (img.naturalWidth > 800 || img.naturalHeight > 600) {
                this.optimizeImageSize(img);
            }
        });
    }

    removeStyleById(id) {
        const existingStyle = document.getElementById(id);
        if (existingStyle) {
            existingStyle.remove();
        }
    }

    /**
     * Performance monitoring
     */
    setupPerformanceMonitoring() {
        // Monitor performance metrics
        this.performanceMetrics = {
            frameRate: 60,
            memoryUsage: 0,
            loadTime: 0,
            renderTime: 0
        };

        this.startPerformanceMonitoring();
    }

    startPerformanceMonitoring() {
        let lastTime = performance.now();
        let frameCount = 0;

        const monitorFrame = () => {
            frameCount++;
            const currentTime = performance.now();

            if (currentTime - lastTime >= 1000) {
                this.performanceMetrics.frameRate = frameCount;
                frameCount = 0;
                lastTime = currentTime;

                this.updatePerformanceUI();
            }

            requestAnimationFrame(monitorFrame);
        };

        requestAnimationFrame(monitorFrame);
    }

    updatePerformanceUI() {
        // Update performance indicators in UI
        const perfIndicator = document.getElementById('performance-indicator');
        if (perfIndicator) {
            const fps = this.performanceMetrics.frameRate;
            let status = 'good';
            if (fps < 30) status = 'poor';
            else if (fps < 50) status = 'fair';

            perfIndicator.className = `performance-indicator ${status}`;
            perfIndicator.textContent = `${fps} FPS`;
        }
    }

    /**
     * Optimize for low power
     */
    optimizeForLowPower() {
        // Reduce CPU usage when tab is not visible
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.enterLowPowerMode();
            } else {
                this.exitLowPowerMode();
            }
        });

        // Optimize for battery
        if ('getBattery' in navigator) {
            navigator.getBattery().then(battery => {
                if (battery.level < 0.2) {
                    this.enablePowerSaveMode();
                }

                battery.addEventListener('levelchange', () => {
                    if (battery.level < 0.2) {
                        this.enablePowerSaveMode();
                    }
                });
            });
        }
    }

    enterLowPowerMode() {
        // Reduce polling frequency
        if (window.app && window.app.systemStatsInterval) {
            clearInterval(window.app.systemStatsInterval);
            window.app.systemStatsInterval = setInterval(
                () => window.app.loadSystemStats(),
                30000 // 30 seconds
            );
        }

        // Pause animations
        document.body.classList.add('low-power');
    }

    exitLowPowerMode() {
        // Restore normal operation
        if (window.app && window.app.config) {
            if (window.app.systemStatsInterval) {
                clearInterval(window.app.systemStatsInterval);
            }
            window.app.systemStatsInterval = setInterval(
                () => window.app.loadSystemStats(),
                window.app.config.statsUpdateInterval
            );
        }

        document.body.classList.remove('low-power');
    }

    /**
     * Hardware acceleration setup
     */
    setupHardwareAcceleration() {
        // Check for hardware acceleration support
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

        if (gl) {
            // WebGL available - use for hardware acceleration
            this.enableWebGLOptimizations();
        } else {
            // Fallback to software rendering optimizations
            this.enableSoftwareOptimizations();
        }

        // Check for CSS hardware acceleration
        this.checkCSSAcceleration();
    }

    enableWebGLOptimizations() {
        console.log('🍓 WebGL detected - enabling GPU optimizations');

        // Use GPU for image processing where possible
        this.setupGPUImageProcessing();
    }

    enableSoftwareOptimizations() {
        console.log('🍓 Software rendering - applying CPU optimizations');

        // Disable expensive CSS effects
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi {
                filter: none !important;
                backdrop-filter: none !important;
                transform3d: none !important;
            }
        `;

        document.head.appendChild(style);
    }

    checkCSSAcceleration() {
        // Test CSS hardware acceleration
        const testElement = document.createElement('div');
        testElement.style.cssText = `
            position: absolute;
            top: -1000px;
            transform: translateZ(0);
            will-change: transform;
        `;

        document.body.appendChild(testElement);

        const computedStyle = getComputedStyle(testElement);
        const hasAcceleration = computedStyle.transform !== 'none';

        if (!hasAcceleration) {
            // Disable hardware acceleration attempts
            this.disableHardwareAcceleration();
        }

        document.body.removeChild(testElement);
    }

    disableHardwareAcceleration() {
        const style = document.createElement('style');
        style.textContent = `
            .raspberry-pi * {
                will-change: auto !important;
                transform: none !important;
            }
        `;

        document.head.appendChild(style);
    }

    setupGPUImageProcessing() {
        // Use WebGL for image effects where beneficial
        this.createImageProcessor();
    }

    createImageProcessor() {
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl');

        if (!gl) return;

        // Simple GPU-based image processing for screenshots
        this.imageProcessor = {
            canvas: canvas,
            gl: gl,
            processImage: (imageData) => {
                // GPU-based image processing
                return this.processImageWithGPU(imageData);
            }
        };
    }

    processImageWithGPU(imageData) {
        // Implement GPU-based image processing
        // This would include operations like resizing, filtering, etc.
        return imageData;
    }

    /**
     * Get optimization status
     */
    getOptimizationStatus() {
        return {
            isRaspberryPi: this.isRaspberryPi,
            performanceMode: this.performanceMode,
            thermalThrottle: this.thermalThrottle,
            hardwareAcceleration: !!this.imageProcessor,
            metrics: this.performanceMetrics
        };
    }
}

// Initialize optimizations
const piOptimizations = new RaspberryPiOptimizations();

// Export for global access
window.PiOptimizations = piOptimizations;

// Add performance indicator to UI
document.addEventListener('DOMContentLoaded', () => {
    const statusIndicator = document.querySelector('.status-indicator');
    if (statusIndicator && piOptimizations.isRaspberryPi) {
        const perfIndicator = document.createElement('div');
        perfIndicator.id = 'performance-indicator';
        perfIndicator.className = 'performance-indicator good';
        perfIndicator.style.cssText = `
            margin-left: 10px;
            padding: 4px 8px;
            background: var(--bg-glass);
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
        `;
        perfIndicator.textContent = '60 FPS';
        statusIndicator.appendChild(perfIndicator);
    }
});

console.log('🍓 Raspberry Pi optimizations loaded');