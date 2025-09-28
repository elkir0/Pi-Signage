/**
 * PiSignage Core JavaScript Module
 * Handles namespace, navigation, utilities, and shared functions
 * CRITICAL: All functions made globally accessible to fix showSection issue
 */

// Create global PiSignage namespace
window.PiSignage = window.PiSignage || {
    navigation: {},
    dashboard: {},
    media: {},
    playlists: {},
    player: {},
    api: {},
    utils: {},
    config: {
        version: '0.8.3',
        currentSection: 'dashboard',
        currentPlayer: 'vlc',
        selectedPlayer: 'vlc'
    }
};

// Global variables for compatibility
let currentSection = 'dashboard';
let autoScreenshotInterval = null;
let systemStatsInterval = null;
let currentPlayer = 'vlc';
let selectedPlayer = 'vlc';

// CRITICAL: Global showSection function for navigation
window.showSection = function(section) {
    console.log('🧭 Navigating to section:', section);

    // Update sections
    document.querySelectorAll('.content-section').forEach(el => {
        el.classList.remove('active');
    });
    const targetSection = document.getElementById(section);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    // Update nav items
    document.querySelectorAll('.nav-item').forEach(el => {
        el.classList.remove('active');
        // Check if this nav item corresponds to the current section
        const onclick = el.getAttribute('onclick');
        if (onclick && onclick.includes(`'${section}'`)) {
            el.classList.add('active');
        }
    });

    // Initialize playlist editor if switching to playlists
    if (section === 'playlists') {
        setTimeout(() => {
            if (typeof initPlaylistEditor === 'function') {
                initPlaylistEditor();
            } else if (typeof window.PiSignage.playlists.loadPlaylists === 'function') {
                window.PiSignage.playlists.loadPlaylists();
            } else if (typeof loadPlaylists === 'function') {
                loadPlaylists(); // Fallback to old function
            }
        }, 100);
    }

    // Update global state
    currentSection = section;
    PiSignage.config.currentSection = section;
};

// Global toggleSidebar function for mobile
window.toggleSidebar = function() {
    const sidebar = document.getElementById('sidebar');
    if (sidebar) {
        sidebar.classList.toggle('active');
    }
};

// Navigation utilities
PiSignage.navigation = {
    showSection: window.showSection,
    toggleSidebar: window.toggleSidebar,

    getCurrentSection: function() {
        return currentSection;
    },

    setCurrentSection: function(section) {
        currentSection = section;
        PiSignage.config.currentSection = section;
    }
};

// Global alert/notification system - CRITICAL: Must remain global
window.showAlert = function(message, type = 'info') {
    console.log(`📢 Alert [${type}]:`, message);

    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type}`;
    alertDiv.innerHTML = message;

    // Styling for better visibility
    alertDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 8px;
        color: white;
        z-index: 10000;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        animation: slideInFromRight 0.3s ease-out;
        max-width: 350px;
        word-wrap: break-word;
    `;

    // Color based on type
    switch(type) {
        case 'success':
            alertDiv.style.backgroundColor = '#28a745';
            break;
        case 'error':
            alertDiv.style.backgroundColor = '#dc3545';
            break;
        case 'warning':
            alertDiv.style.backgroundColor = '#ffc107';
            alertDiv.style.color = '#212529';
            break;
        default:
            alertDiv.style.backgroundColor = '#17a2b8';
    }

    // Add to alert container or body
    const container = document.getElementById('alert-container') || document.body;
    container.appendChild(alertDiv);

    setTimeout(() => {
        alertDiv.style.animation = 'slideOutToRight 0.3s ease-in';
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.remove();
            }
        }, 300);
    }, 3000);
};

// Utility functions
PiSignage.utils = {
    showAlert: window.showAlert,

    formatTime: function(seconds) {
        if (!seconds || isNaN(seconds)) return '00:00';
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    },

    formatFileSize: function(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    },

    debounce: function(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    throttle: function(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
};

// Player state management
PiSignage.player = {
    state: {
        isPlaying: false,
        isPaused: false,
        currentFile: null,
        position: 0,
        duration: 0,
        volume: 50,
        isMuted: false,
        isLooping: false,
        isShuffling: false
    },

    getCurrentPlayer: function() {
        return currentPlayer;
    },

    setCurrentPlayer: function(player) {
        currentPlayer = player;
        selectedPlayer = player;
        PiSignage.config.currentPlayer = player;
        PiSignage.config.selectedPlayer = player;
    },

    updateState: function(newState) {
        Object.assign(this.state, newState);
    }
};

// Global functions for backward compatibility - CRITICAL
window.getCurrentPlayer = function() {
    return PiSignage.player.getCurrentPlayer();
};

window.setCurrentPlayer = function(player) {
    PiSignage.player.setCurrentPlayer(player);
};

// Common intervals management
PiSignage.intervals = {
    stats: null,
    player: null,

    startStatsRefresh: function(interval = 5000) {
        if (this.stats) {
            clearInterval(this.stats);
        }
        this.stats = setInterval(() => {
            if (typeof window.refreshStats === 'function') {
                window.refreshStats();
            } else if (typeof PiSignage.dashboard.refreshStats === 'function') {
                PiSignage.dashboard.refreshStats();
            }
        }, interval);
        console.log('📊 Stats refresh interval started');
    },

    startPlayerStatusRefresh: function(interval = 3000) {
        if (this.player) {
            clearInterval(this.player);
        }
        this.player = setInterval(() => {
            if (typeof window.updatePlayerStatus === 'function') {
                window.updatePlayerStatus();
            } else if (typeof PiSignage.player.updateStatus === 'function') {
                PiSignage.player.updateStatus();
            }
        }, interval);
        console.log('🎮 Player status refresh interval started');
    },

    stopAll: function() {
        if (this.stats) {
            clearInterval(this.stats);
            this.stats = null;
        }
        if (this.player) {
            clearInterval(this.player);
            this.player = null;
        }
        console.log('⏹️ All intervals stopped');
    }
};

// CSS animations for alerts
const alertStyles = document.createElement('style');
alertStyles.textContent = `
    @keyframes slideInFromRight {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }

    @keyframes slideOutToRight {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(alertStyles);

console.log('✅ PiSignage Core module loaded - Navigation and utilities ready');