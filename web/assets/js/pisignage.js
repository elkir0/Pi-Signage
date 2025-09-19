/**
 * PiSignage Web Interface JavaScript
 * Version: 1.0
 */

class PiSignage {
    constructor() {
        this.apiBaseUrl = 'api/control.php';
        this.refreshInterval = 30000; // 30 secondes
        this.statusCheckInterval = null;
        
        this.init();
    }
    
    init() {
        this.bindEvents();
        this.startStatusMonitoring();
        this.loadInitialData();
    }
    
    bindEvents() {
        // Boutons de contrôle du lecteur
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('player-control')) {
                const action = e.target.dataset.action;
                this.controlPlayer(action);
            }
            
            if (e.target.classList.contains('refresh-status')) {
                this.checkSystemStatus();
            }
            
            if (e.target.classList.contains('play-media')) {
                const file = e.target.dataset.file;
                const duration = e.target.dataset.duration || 10;
                this.playMedia(file, duration);
            }
        });
        
        // Actualisation automatique
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.stopStatusMonitoring();
            } else {
                this.startStatusMonitoring();
            }
        });
    }
    
    async apiCall(params) {
        try {
            const url = new URL(this.apiBaseUrl, window.location.origin);
            Object.keys(params).forEach(key => url.searchParams.append(key, params[key]));
            
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error('API call failed:', error);
            this.showNotification('Erreur de communication avec l\'API', 'error');
            throw error;
        }
    }
    
    async checkSystemStatus() {
        try {
            this.showSpinner('system-status');
            
            const response = await this.apiCall({ action: 'status' });
            
            const statusElement = document.getElementById('system-status');
            if (statusElement) {
                statusElement.className = `status ${response.status}`;
                statusElement.innerHTML = response.status === 'online' 
                    ? '● Système en ligne' 
                    : '● Système hors ligne';
            }
            
            this.updateLastCheck();
            
        } catch (error) {
            const statusElement = document.getElementById('system-status');
            if (statusElement) {
                statusElement.className = 'status offline';
                statusElement.innerHTML = '● Erreur de connexion';
            }
        }
    }
    
    async controlPlayer(command) {
        try {
            this.showSpinner(`btn-${command}`);
            
            const response = await this.apiCall({
                action: 'player',
                command: command
            });
            
            if (response.success) {
                this.showNotification(`Commande "${command}" exécutée avec succès`, 'success');
                // Actualiser le statut après la commande
                setTimeout(() => this.checkSystemStatus(), 1000);
            } else {
                this.showNotification(response.message || 'Erreur lors de l\'exécution', 'error');
            }
            
        } catch (error) {
            this.showNotification('Erreur lors de l\'exécution de la commande', 'error');
        }
    }
    
    async playMedia(file, duration = 10) {
        try {
            const response = await this.apiCall({
                action: 'play',
                file: file,
                duration: duration
            });
            
            if (response.success) {
                this.showNotification(`Lecture de "${file}" démarrée`, 'success');
            } else {
                this.showNotification(response.message || 'Erreur lors de la lecture', 'error');
            }
            
        } catch (error) {
            this.showNotification('Erreur lors du démarrage de la lecture', 'error');
        }
    }
    
    async loadMediaList() {
        try {
            const response = await this.apiCall({ action: 'media' });
            
            if (response.success && response.files) {
                this.updateMediaCount(response.files.length);
                this.renderMediaList(response.files);
            }
            
        } catch (error) {
            console.error('Erreur lors du chargement des médias:', error);
        }
    }
    
    renderMediaList(files) {
        const container = document.getElementById('media-list');
        if (!container) return;
        
        if (files.length === 0) {
            container.innerHTML = '<p>Aucun fichier média trouvé</p>';
            return;
        }
        
        const listHTML = files.map(file => `
            <div class="media-item card">
                <h4>${file.name}</h4>
                <p>Type: ${file.type} | Taille: ${this.formatFileSize(file.size)}</p>
                <p>Modifié: ${file.modified}</p>
                <button class="btn btn-primary play-media" 
                        data-file="${file.name}" 
                        data-duration="${file.type === 'image' ? 10 : 0}">
                    Lire
                </button>
            </div>
        `).join('');
        
        container.innerHTML = listHTML;
    }
    
    updateMediaCount(count) {
        const element = document.getElementById('media-count');
        if (element) {
            element.textContent = count;
        }
    }
    
    updateLastCheck() {
        const element = document.getElementById('last-check');
        if (element) {
            element.textContent = new Date().toLocaleTimeString();
        }
    }
    
    showSpinner(elementId) {
        const element = document.getElementById(elementId);
        if (element) {
            const originalText = element.innerHTML;
            element.innerHTML = '<span class="spinner"></span> Chargement...';
            
            setTimeout(() => {
                element.innerHTML = originalText;
            }, 2000);
        }
    }
    
    showNotification(message, type = 'info') {
        // Créer ou mettre à jour la zone de notification
        let notification = document.getElementById('notification');
        if (!notification) {
            notification = document.createElement('div');
            notification.id = 'notification';
            notification.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                padding: 15px 20px;
                border-radius: 5px;
                color: white;
                font-weight: 500;
                z-index: 1000;
                opacity: 0;
                transition: opacity 0.3s ease;
            `;
            document.body.appendChild(notification);
        }
        
        // Définir la couleur selon le type
        const colors = {
            success: '#2ecc71',
            error: '#e74c3c',
            warning: '#f39c12',
            info: '#3498db'
        };
        
        notification.style.backgroundColor = colors[type] || colors.info;
        notification.textContent = message;
        notification.style.opacity = '1';
        
        // Masquer après 5 secondes
        setTimeout(() => {
            notification.style.opacity = '0';
        }, 5000);
    }
    
    startStatusMonitoring() {
        if (this.statusCheckInterval) {
            clearInterval(this.statusCheckInterval);
        }
        
        // Vérification immédiate
        this.checkSystemStatus();
        
        // Vérifications périodiques
        this.statusCheckInterval = setInterval(() => {
            this.checkSystemStatus();
        }, this.refreshInterval);
    }
    
    stopStatusMonitoring() {
        if (this.statusCheckInterval) {
            clearInterval(this.statusCheckInterval);
            this.statusCheckInterval = null;
        }
    }
    
    loadInitialData() {
        this.loadMediaList();
    }
    
    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
}

// Initialisation automatique quand le DOM est prêt
document.addEventListener('DOMContentLoaded', () => {
    window.pisignage = new PiSignage();
});

// Fonctions globales pour la compatibilité
function checkStatus() {
    if (window.pisignage) {
        window.pisignage.checkSystemStatus();
    }
}

function controlPlayer(action) {
    if (window.pisignage) {
        window.pisignage.controlPlayer(action);
    }
}