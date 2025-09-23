/**
 * PiSignage v0.8.0 - Service Worker
 * Optimizations for Raspberry Pi performance
 */

const CACHE_NAME = 'pisignage-v0.8.0';
const STATIC_CACHE = 'pisignage-static-v0.8.0';
const DYNAMIC_CACHE = 'pisignage-dynamic-v0.8.0';
const IMAGE_CACHE = 'pisignage-images-v0.8.0';

// Files to cache immediately
const STATIC_FILES = [
    '/',
    '/index-modern.php',
    '/assets/css/modern-ui.css',
    '/assets/js/pisignage-modern.js',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css'
];

// API endpoints that should be cached
const API_CACHE_PATTERNS = [
    /\/api\/system\.php$/,
    /\/api\/media\.php\?action=list$/,
    /\/api\/playlist\.php\?action=list$/
];

// Images and media cache patterns
const MEDIA_CACHE_PATTERNS = [
    /\/media\//,
    /\/screenshots\//,
    /\.(?:png|jpg|jpeg|svg|gif|webp)$/
];

// Cache duration for different types of content (in milliseconds)
const CACHE_DURATION = {
    static: 7 * 24 * 60 * 60 * 1000,    // 7 days
    api: 5 * 60 * 1000,                  // 5 minutes
    images: 24 * 60 * 60 * 1000,         // 1 day
    screenshots: 10 * 60 * 1000          // 10 minutes
};

// Install event - cache static files
self.addEventListener('install', event => {
    console.log('Service Worker installing...');

    event.waitUntil(
        Promise.all([
            // Cache static files
            caches.open(STATIC_CACHE).then(cache => {
                return cache.addAll(STATIC_FILES);
            }),

            // Skip waiting to activate immediately
            self.skipWaiting()
        ])
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
    console.log('Service Worker activating...');

    event.waitUntil(
        Promise.all([
            // Clean up old caches
            caches.keys().then(cacheNames => {
                return Promise.all(
                    cacheNames.map(cacheName => {
                        if (!cacheName.includes('v0.8.0')) {
                            console.log('Deleting old cache:', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            }),

            // Claim all clients
            self.clients.claim()
        ])
    );
});

// Fetch event - handle all network requests
self.addEventListener('fetch', event => {
    const request = event.request;
    const url = new URL(request.url);

    // Skip non-GET requests and external resources (except for CDN)
    if (request.method !== 'GET' ||
        (url.origin !== location.origin && !url.hostname.includes('cdnjs.cloudflare.com'))) {
        return;
    }

    event.respondWith(handleRequest(request));
});

/**
 * Handle different types of requests with appropriate caching strategies
 */
async function handleRequest(request) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    try {
        // Static files - Cache First strategy
        if (isStaticFile(pathname)) {
            return await cacheFirst(request, STATIC_CACHE);
        }

        // API calls - Stale While Revalidate for better UX
        if (isAPICall(pathname)) {
            return await staleWhileRevalidate(request, DYNAMIC_CACHE, CACHE_DURATION.api);
        }

        // Media files - Cache First with long expiration
        if (isMediaFile(pathname)) {
            return await cacheFirst(request, IMAGE_CACHE, CACHE_DURATION.images);
        }

        // Screenshots - Network First (fresh data) with fallback
        if (isScreenshot(pathname)) {
            return await networkFirst(request, DYNAMIC_CACHE, CACHE_DURATION.screenshots);
        }

        // Default: Network First for HTML pages
        return await networkFirst(request, DYNAMIC_CACHE);

    } catch (error) {
        console.error('Fetch error:', error);
        return await handleOffline(request);
    }
}

/**
 * Cache First strategy - try cache first, fallback to network
 */
async function cacheFirst(request, cacheName, maxAge = CACHE_DURATION.static) {
    const cache = await caches.open(cacheName);
    const cached = await cache.match(request);

    if (cached && !isExpired(cached, maxAge)) {
        return cached;
    }

    try {
        const response = await fetch(request);
        if (response.status === 200) {
            // Clone response before caching (can only be consumed once)
            const responseClone = response.clone();
            await cache.put(request, responseClone);
        }
        return response;
    } catch (error) {
        // If network fails, return cached version even if expired
        if (cached) {
            return cached;
        }
        throw error;
    }
}

/**
 * Network First strategy - try network first, fallback to cache
 */
async function networkFirst(request, cacheName, maxAge = CACHE_DURATION.api) {
    const cache = await caches.open(cacheName);

    try {
        const response = await fetch(request);
        if (response.status === 200) {
            const responseClone = response.clone();
            await cache.put(request, responseClone);
        }
        return response;
    } catch (error) {
        // Network failed, try cache
        const cached = await cache.match(request);
        if (cached && !isExpired(cached, maxAge)) {
            return cached;
        }
        throw error;
    }
}

/**
 * Stale While Revalidate - return cached version immediately, update in background
 */
async function staleWhileRevalidate(request, cacheName, maxAge = CACHE_DURATION.api) {
    const cache = await caches.open(cacheName);
    const cached = await cache.match(request);

    // Fetch fresh version in background
    const fetchPromise = fetch(request).then(response => {
        if (response.status === 200) {
            cache.put(request, response.clone());
        }
        return response;
    }).catch(error => {
        console.warn('Background fetch failed:', error);
    });

    // Return cached version immediately if available and not expired
    if (cached && !isExpired(cached, maxAge)) {
        return cached;
    }

    // If no cache or expired, wait for network
    return await fetchPromise;
}

/**
 * Check if cached response is expired
 */
function isExpired(response, maxAge) {
    const dateHeader = response.headers.get('date');
    if (!dateHeader) return false;

    const responseDate = new Date(dateHeader);
    const now = new Date();

    return (now.getTime() - responseDate.getTime()) > maxAge;
}

/**
 * Handle offline scenarios
 */
async function handleOffline(request) {
    const url = new URL(request.url);

    // Try to find any cached version
    const cacheNames = await caches.keys();
    for (const cacheName of cacheNames) {
        const cache = await caches.open(cacheName);
        const cached = await cache.match(request);
        if (cached) {
            return cached;
        }
    }

    // Return offline page for HTML requests
    if (request.headers.get('accept')?.includes('text/html')) {
        return new Response(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>PiSignage - Hors ligne</title>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
                        color: #f8fafc;
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        margin: 0;
                        text-align: center;
                    }
                    .offline-container {
                        max-width: 400px;
                        padding: 2rem;
                        background: rgba(30, 41, 59, 0.9);
                        border-radius: 12px;
                        border: 1px solid rgba(148, 163, 184, 0.2);
                        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
                    }
                    .offline-icon {
                        font-size: 4rem;
                        margin-bottom: 1rem;
                        opacity: 0.7;
                    }
                    h1 {
                        margin-bottom: 1rem;
                        color: #6366f1;
                    }
                    .retry-btn {
                        background: linear-gradient(135deg, #6366f1, #4f46e5);
                        color: white;
                        border: none;
                        padding: 12px 24px;
                        border-radius: 8px;
                        cursor: pointer;
                        font-weight: 500;
                        margin-top: 1rem;
                    }
                    .retry-btn:hover {
                        background: linear-gradient(135deg, #4f46e5, #3730a3);
                    }
                </style>
            </head>
            <body>
                <div class="offline-container">
                    <div class="offline-icon">📡</div>
                    <h1>Connexion perdue</h1>
                    <p>PiSignage n'arrive pas à se connecter au serveur. Vérifiez votre connexion réseau.</p>
                    <button class="retry-btn" onclick="window.location.reload()">
                        Réessayer
                    </button>
                </div>
            </body>
            </html>
        `, {
            headers: { 'Content-Type': 'text/html' }
        });
    }

    // Return minimal response for other requests
    return new Response('Offline', { status: 503 });
}

/**
 * Check if file is a static asset
 */
function isStaticFile(pathname) {
    return pathname.endsWith('.css') ||
           pathname.endsWith('.js') ||
           pathname.endsWith('.ico') ||
           pathname.endsWith('.woff') ||
           pathname.endsWith('.woff2') ||
           pathname.endsWith('.ttf') ||
           pathname === '/' ||
           pathname.endsWith('.php');
}

/**
 * Check if request is an API call
 */
function isAPICall(pathname) {
    return API_CACHE_PATTERNS.some(pattern => pattern.test(pathname));
}

/**
 * Check if file is a media file
 */
function isMediaFile(pathname) {
    return MEDIA_CACHE_PATTERNS.some(pattern => pattern.test(pathname));
}

/**
 * Check if file is a screenshot
 */
function isScreenshot(pathname) {
    return pathname.includes('/screenshots/') ||
           pathname.includes('screenshot');
}

// Message event - handle commands from main thread
self.addEventListener('message', event => {
    const { action, data } = event.data;

    switch (action) {
        case 'skipWaiting':
            self.skipWaiting();
            break;

        case 'clearCache':
            clearAllCaches().then(() => {
                event.ports[0].postMessage({ success: true });
            });
            break;

        case 'getCacheInfo':
            getCacheInfo().then(info => {
                event.ports[0].postMessage(info);
            });
            break;

        case 'preloadMedia':
            preloadMedia(data.urls).then(() => {
                event.ports[0].postMessage({ success: true });
            });
            break;
    }
});

/**
 * Clear all caches
 */
async function clearAllCaches() {
    const cacheNames = await caches.keys();
    await Promise.all(
        cacheNames.map(cacheName => caches.delete(cacheName))
    );
    console.log('All caches cleared');
}

/**
 * Get cache information
 */
async function getCacheInfo() {
    const cacheNames = await caches.keys();
    const info = {
        caches: {},
        totalSize: 0
    };

    for (const cacheName of cacheNames) {
        const cache = await caches.open(cacheName);
        const keys = await cache.keys();
        info.caches[cacheName] = {
            count: keys.length,
            keys: keys.map(key => key.url)
        };
    }

    return info;
}

/**
 * Preload media files for better performance
 */
async function preloadMedia(urls) {
    const cache = await caches.open(IMAGE_CACHE);

    const preloadPromises = urls.map(async url => {
        try {
            const response = await fetch(url);
            if (response.status === 200) {
                await cache.put(url, response);
            }
        } catch (error) {
            console.warn('Failed to preload:', url, error);
        }
    });

    await Promise.all(preloadPromises);
    console.log('Media preloading completed');
}

// Background sync for better reliability on poor connections
self.addEventListener('sync', event => {
    if (event.tag === 'background-sync') {
        event.waitUntil(doBackgroundSync());
    }
});

async function doBackgroundSync() {
    // Sync critical data when connection is restored
    try {
        // Refresh system stats
        await fetch('/api/system.php');

        // Refresh media list
        await fetch('/api/media.php?action=list');

        console.log('Background sync completed');
    } catch (error) {
        console.warn('Background sync failed:', error);
    }
}

// Push notification handling (for future features)
self.addEventListener('push', event => {
    if (event.data) {
        const data = event.data.json();
        const options = {
            body: data.body,
            icon: '/icon-192.png',
            badge: '/badge-72.png',
            tag: data.tag || 'pisignage-notification',
            renotify: true,
            requireInteraction: true,
            actions: [
                {
                    action: 'view',
                    title: 'Voir',
                    icon: '/icon-view.png'
                },
                {
                    action: 'dismiss',
                    title: 'Ignorer',
                    icon: '/icon-dismiss.png'
                }
            ]
        };

        event.waitUntil(
            self.registration.showNotification(data.title, options)
        );
    }
});

// Notification click handling
self.addEventListener('notificationclick', event => {
    event.notification.close();

    if (event.action === 'view') {
        event.waitUntil(
            clients.openWindow('/')
        );
    }
});

// Periodic background sync (for modern browsers)
self.addEventListener('periodicsync', event => {
    if (event.tag === 'content-sync') {
        event.waitUntil(doPeriodicSync());
    }
});

async function doPeriodicSync() {
    // Periodic sync for keeping data fresh
    try {
        const cache = await caches.open(DYNAMIC_CACHE);

        // Update system stats
        const systemResponse = await fetch('/api/system.php');
        if (systemResponse.ok) {
            await cache.put('/api/system.php', systemResponse);
        }

        console.log('Periodic sync completed');
    } catch (error) {
        console.warn('Periodic sync failed:', error);
    }
}

// Performance monitoring
let performanceData = {
    cacheHits: 0,
    cacheMisses: 0,
    networkRequests: 0,
    failedRequests: 0
};

function trackPerformance(type) {
    performanceData[type] = (performanceData[type] || 0) + 1;

    // Send performance data every 100 requests
    if (performanceData.networkRequests % 100 === 0) {
        self.clients.matchAll().then(clients => {
            clients.forEach(client => {
                client.postMessage({
                    type: 'performance-data',
                    data: performanceData
                });
            });
        });
    }
}

console.log('PiSignage Service Worker v0.8.0 loaded');