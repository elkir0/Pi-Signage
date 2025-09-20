/**
 * PiSignage Desktop v3.0 - JavaScript principal
 */

// Utilitaires globaux
window.PiSignage = {
    // Configuration
    config: {
        autoRefreshInterval: 30000, // 30 secondes
        toastDuration: 5000, // 5 secondes
        apiBase: '/api/v1/endpoints.php'
    },
    
    // État global
    state: {
        refreshInterval: null,
        isVisible: true
    },
    
    // Initialisation
    init() {
        this.loadTheme();
        this.setupEventListeners();
        this.handleToasts();
        this.setupVisibilityChange();
        console.log('PiSignage Desktop v3.0 - Interface initialisée');
    },
    
    // Gestion du thème
    loadTheme() {
        const savedTheme = localStorage.getItem('theme') || 'light';
        document.documentElement.setAttribute('data-theme', savedTheme);
        this.updateThemeToggle(savedTheme);
    },
    
    toggleTheme() {
        const html = document.documentElement;
        const currentTheme = html.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        html.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        this.updateThemeToggle(newTheme);
        
        // Animation smooth
        document.body.style.transition = 'background-color 0.3s ease, color 0.3s ease';
        setTimeout(() => {
            document.body.style.transition = '';
        }, 300);
    },
    
    updateThemeToggle(theme) {
        const toggleBtns = document.querySelectorAll('.theme-toggle');
        toggleBtns.forEach(btn => {
            btn.textContent = theme === 'dark' ? '☀️' : '🌙';
            btn.title = theme === 'dark' ? 'Mode clair' : 'Mode sombre';
        });
    },
    
    // Event listeners
    setupEventListeners() {
        // Délégation d'événements pour les boutons de thème
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('theme-toggle') || e.target.onclick?.toString().includes('toggleTheme')) {
                e.preventDefault();
                this.toggleTheme();
            }
        });
        
        // Gestion des erreurs globales
        window.addEventListener('error', (e) => {
            console.error('Erreur JavaScript:', e.error);
            this.showToast('Une erreur est survenue', 'error');
        });
        
        // Gestion des erreurs fetch
        window.addEventListener('unhandledrejection', (e) => {
            console.error('Erreur Promise non gérée:', e.reason);
            this.showToast('Erreur de connexion', 'error');
        });
    },
    
    // Gestion des toasts
    handleToasts() {
        const toasts = document.querySelectorAll('.toast');
        toasts.forEach(toast => {
            // Auto-masquage après délai
            setTimeout(() => {
                this.hideToast(toast);
            }, this.config.toastDuration);
            
            // Click pour masquer
            toast.addEventListener('click', () => {
                this.hideToast(toast);
            });
        });
    },
    
    hideToast(toast) {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(100%)';
        setTimeout(() => {
            toast.remove();
        }, 300);
    },
    
    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type} fade-in`;
        
        const icon = {
            success: '✅',
            error: '❌',
            warning: '⚠️',
            info: 'ℹ️'
        }[type] || 'ℹ️';
        
        toast.innerHTML = `${icon} ${message}`;
        
        document.body.appendChild(toast);
        
        // Auto-masquage
        setTimeout(() => {
            this.hideToast(toast);
        }, this.config.toastDuration);
        
        // Click pour masquer
        toast.addEventListener('click', () => {
            this.hideToast(toast);
        });
    },
    
    // Gestion de la visibilité de la page
    setupVisibilityChange() {
        document.addEventListener('visibilitychange', () => {
            this.state.isVisible = !document.hidden;
            
            if (this.state.isVisible && this.state.refreshInterval) {
                // Relancer le refresh si nécessaire
                console.log('Page visible - refresh relancé');
            }
        });
    },
    
    // API helpers
    async apiCall(action, method = 'GET', data = null) {
        try {
            const options = {
                method: method,
                headers: {
                    'Content-Type': 'application/json'
                }
            };
            
            if (data) {
                if (method === 'GET') {
                    // Pour GET, ajouter à l'URL
                    const params = new URLSearchParams(data);
                    action += '?' + params.toString();
                } else {
                    // Pour POST, PUT, DELETE, dans le body
                    options.body = JSON.stringify(data);
                }
            }
            
            let url = this.config.apiBase;
            if (method === 'GET' && !action.includes('?')) {
                url += '?action=' + action;
            } else if (method === 'GET') {
                url += action;
            }
            
            const response = await fetch(url, options);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
            
        } catch (error) {
            console.error('Erreur API:', error);
            throw error;
        }
    },
    
    // Formater les bytes
    formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 B';
        
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    },
    
    // Formater la durée
    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        if (hours > 0) {
            return `${hours}h ${minutes}m ${secs}s`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    },
    
    // Debounce function
    debounce(func, wait) {
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
    
    // Animation helpers
    fadeIn(element, duration = 300) {
        element.style.opacity = '0';
        element.style.display = 'block';
        
        let start = performance.now();
        
        function animate(timestamp) {
            let progress = (timestamp - start) / duration;
            
            if (progress > 1) progress = 1;
            
            element.style.opacity = progress;
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            }
        }
        
        requestAnimationFrame(animate);
    },
    
    fadeOut(element, duration = 300) {
        let start = performance.now();
        
        function animate(timestamp) {
            let progress = (timestamp - start) / duration;
            
            if (progress > 1) progress = 1;
            
            element.style.opacity = 1 - progress;
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            } else {
                element.style.display = 'none';
            }
        }
        
        requestAnimationFrame(animate);
    },
    
    // Validation helpers
    validateEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    },
    
    validateURL(url) {
        try {
            new URL(url);
            return true;
        } catch {
            return false;
        }
    },
    
    // Sécurité
    escapeHTML(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    },
    
    // Stockage local sécurisé
    setSecureItem(key, value) {
        try {
            localStorage.setItem(key, JSON.stringify(value));
            return true;
        } catch (error) {
            console.error('Erreur localStorage:', error);
            return false;
        }
    },
    
    getSecureItem(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error('Erreur localStorage:', error);
            return defaultValue;
        }
    }
};

// Extensions spécifiques aux pages

// Dashboard
if (window.location.pathname.includes('index.php') || window.location.pathname === '/') {
    window.PiSignage.Dashboard = {
        init() {
            this.setupAutoRefresh();
            this.loadSystemInfo();
        },
        
        setupAutoRefresh() {
            // Auto-refresh toutes les 30 secondes
            window.PiSignage.state.refreshInterval = setInterval(() => {
                if (window.PiSignage.state.isVisible) {
                    location.reload();
                }
            }, window.PiSignage.config.autoRefreshInterval);
        },
        
        async loadSystemInfo() {
            try {
                const data = await window.PiSignage.apiCall('system_info');
                if (data.success) {
                    this.updateSystemInfo(data.data);
                }
            } catch (error) {
                console.error('Erreur chargement infos système:', error);
            }
        },
        
        updateSystemInfo(data) {
            // Mettre à jour uptime et IP si les éléments existent
            const uptimeEl = document.getElementById('uptime');
            const ipEl = document.getElementById('ip-address');
            
            if (uptimeEl && data.uptime) {
                uptimeEl.textContent = data.uptime;
            }
            
            if (ipEl && data.ip) {
                ipEl.textContent = data.ip;
            }
        }
    };
}

// Gestion des vidéos
if (window.location.pathname.includes('videos.php')) {
    window.PiSignage.Videos = {
        init() {
            this.setupDragDrop();
            this.setupProgressTracking();
        },
        
        setupDragDrop() {
            const uploadArea = document.getElementById('upload-area');
            if (!uploadArea) return;
            
            ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
                uploadArea.addEventListener(eventName, this.preventDefaults, false);
            });
            
            ['dragenter', 'dragover'].forEach(eventName => {
                uploadArea.addEventListener(eventName, () => {
                    uploadArea.classList.add('dragover');
                }, false);
            });
            
            ['dragleave', 'drop'].forEach(eventName => {
                uploadArea.addEventListener(eventName, () => {
                    uploadArea.classList.remove('dragover');
                }, false);
            });
            
            uploadArea.addEventListener('drop', this.handleDrop, false);
        },
        
        preventDefaults(e) {
            e.preventDefault();
            e.stopPropagation();
        },
        
        handleDrop(e) {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                const videoInput = document.getElementById('video-input');
                if (videoInput) {
                    videoInput.files = files;
                    // Déclencher l'événement change
                    videoInput.dispatchEvent(new Event('change'));
                }
            }
        },
        
        setupProgressTracking() {
            const forms = document.querySelectorAll('form[enctype="multipart/form-data"]');
            forms.forEach(form => {
                form.addEventListener('submit', (e) => {
                    this.trackUploadProgress(form);
                });
            });
        },
        
        trackUploadProgress(form) {
            const progressDiv = document.getElementById('upload-progress');
            const progressBar = document.getElementById('upload-progress-bar');
            const statusDiv = document.getElementById('upload-status');
            
            if (!progressDiv || !progressBar) return;
            
            progressDiv.classList.remove('hidden');
            
            // Simulation de progression (en l'absence de XMLHttpRequest)
            let progress = 0;
            const interval = setInterval(() => {
                progress += Math.random() * 15;
                if (progress > 90) progress = 90;
                
                progressBar.style.width = progress + '%';
                
                if (statusDiv) {
                    statusDiv.textContent = `Upload en cours... ${Math.round(progress)}%`;
                }
            }, 500);
            
            // Nettoyer l'intervalle si la page change
            window.addEventListener('beforeunload', () => {
                clearInterval(interval);
            });
        }
    };
}

// Playlist
if (window.location.pathname.includes('playlist.php')) {
    window.PiSignage.Playlist = {
        init() {
            console.log('Playlist JavaScript initialisé');
            // La logique est déjà dans playlist.php
        }
    };
}

// Fonctions globales pour compatibilité
window.toggleTheme = function() {
    window.PiSignage.toggleTheme();
};

// Initialisation automatique
document.addEventListener('DOMContentLoaded', function() {
    window.PiSignage.init();
    
    // Initialiser les modules spécifiques aux pages
    if (window.PiSignage.Dashboard) {
        window.PiSignage.Dashboard.init();
    }
    
    if (window.PiSignage.Videos) {
        window.PiSignage.Videos.init();
    }
    
    if (window.PiSignage.Playlist) {
        window.PiSignage.Playlist.init();
    }
});

// Nettoyage avant déchargement
window.addEventListener('beforeunload', function() {
    if (window.PiSignage.state.refreshInterval) {
        clearInterval(window.PiSignage.state.refreshInterval);
    }
});

// Export pour utilisation modulaire si nécessaire
if (typeof module !== 'undefined' && module.exports) {
    module.exports = window.PiSignage;
}