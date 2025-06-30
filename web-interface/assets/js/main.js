// Pi Signage Web Interface - Main JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all modules
    initNavigation();
    initForms();
    initVideoControls();
    initSystemMonitoring();
});

// Navigation handling
function initNavigation() {
    const currentPath = window.location.pathname;
    const navLinks = document.querySelectorAll('nav a');
    
    navLinks.forEach(link => {
        if (link.getAttribute('href') === currentPath) {
            link.classList.add('active');
        }
    });
}

// Form handling
function initForms() {
    // CSRF token handling
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            // Add loading state
            const submitBtn = form.querySelector('[type="submit"]');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.textContent = 'Traitement...';
            }
        });
    });
    
    // File upload preview
    const fileInputs = document.querySelectorAll('input[type="file"]');
    fileInputs.forEach(input => {
        input.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                const preview = document.getElementById('file-preview');
                if (preview) {
                    preview.textContent = `Fichier sélectionné: ${file.name} (${formatFileSize(file.size)})`;
                }
            }
        });
    });
}

// Video player controls
function initVideoControls() {
    const playBtn = document.getElementById('play-btn');
    const pauseBtn = document.getElementById('pause-btn');
    const nextBtn = document.getElementById('next-btn');
    const statusElement = document.getElementById('player-status');
    
    if (playBtn) {
        playBtn.addEventListener('click', () => controlPlayer('play'));
    }
    
    if (pauseBtn) {
        pauseBtn.addEventListener('click', () => controlPlayer('pause'));
    }
    
    if (nextBtn) {
        nextBtn.addEventListener('click', () => controlPlayer('next'));
    }
    
    // Update player status every 5 seconds
    if (statusElement) {
        updatePlayerStatus();
        setInterval(updatePlayerStatus, 5000);
    }
}

// Player control API calls
async function controlPlayer(action) {
    try {
        const response = await fetch('/api/player.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ action: action })
        });
        
        const data = await response.json();
        if (data.success) {
            showNotification('Commande envoyée', 'success');
            updatePlayerStatus();
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    } catch (error) {
        showNotification('Erreur de connexion', 'error');
    }
}

// Update player status
async function updatePlayerStatus() {
    try {
        const response = await fetch('/api/status.php');
        const data = await response.json();
        
        const statusElement = document.getElementById('player-status');
        if (statusElement && data.player) {
            statusElement.innerHTML = `
                <span class="status ${data.player.state === 'playing' ? 'status-active' : 'status-inactive'}">
                    ${data.player.state === 'playing' ? 'En lecture' : 'Arrêté'}
                </span>
                ${data.player.current ? `<br>Vidéo: ${data.player.current}` : ''}
            `;
        }
    } catch (error) {
        console.error('Erreur mise à jour status:', error);
    }
}

// System monitoring
function initSystemMonitoring() {
    const cpuGauge = document.getElementById('cpu-usage');
    const memGauge = document.getElementById('memory-usage');
    const diskGauge = document.getElementById('disk-usage');
    const tempGauge = document.getElementById('temperature');
    
    if (cpuGauge || memGauge || diskGauge || tempGauge) {
        updateSystemStats();
        setInterval(updateSystemStats, 10000); // Update every 10 seconds
    }
}

// Update system statistics
async function updateSystemStats() {
    try {
        const response = await fetch('/api/system.php');
        const data = await response.json();
        
        if (data.success) {
            updateGauge('cpu-usage', data.cpu);
            updateGauge('memory-usage', data.memory);
            updateGauge('disk-usage', data.disk);
            updateGauge('temperature', data.temperature, '°C');
        }
    } catch (error) {
        console.error('Erreur stats système:', error);
    }
}

// Update gauge display
function updateGauge(elementId, value, suffix = '%') {
    const element = document.getElementById(elementId);
    if (element) {
        const progressBar = element.querySelector('.progress-bar');
        const valueText = element.querySelector('.gauge-value');
        
        if (progressBar) {
            progressBar.style.width = value + '%';
            progressBar.className = 'progress-bar';
            
            // Add color based on value
            if (value > 80) {
                progressBar.classList.add('bg-danger');
            } else if (value > 60) {
                progressBar.classList.add('bg-warning');
            } else {
                progressBar.classList.add('bg-success');
            }
        }
        
        if (valueText) {
            valueText.textContent = value + suffix;
        }
    }
}

// Notification system
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type}`;
    notification.textContent = message;
    
    const container = document.getElementById('notifications') || document.querySelector('.container');
    container.insertBefore(notification, container.firstChild);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
        notification.remove();
    }, 5000);
}

// Utility functions
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Video deletion confirmation
function confirmDelete(videoName) {
    if (confirm(`Êtes-vous sûr de vouloir supprimer "${videoName}" ?`)) {
        return true;
    }
    return false;
}

// YouTube download
function downloadYouTube() {
    const urlInput = document.getElementById('youtube-url');
    const downloadBtn = document.getElementById('download-btn');
    const progressDiv = document.getElementById('download-progress');
    const csrfToken = document.querySelector('#youtube-form input[name="csrf_token"]').value;
    
    if (!urlInput || !urlInput.value) {
        showNotification('Veuillez entrer une URL YouTube', 'warning');
        return;
    }
    
    downloadBtn.disabled = true;
    progressDiv.style.display = 'block';
    progressDiv.innerHTML = '<div class="spinner"></div><p>Téléchargement en cours...</p>';
    
    fetch('/api/youtube.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ url: urlInput.value, csrf_token: csrfToken })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Téléchargement terminé!', 'success');
            urlInput.value = '';
            if (data.output) {
                progressDiv.innerHTML = '<pre>' + data.output + '</pre>';
            }
            if (data.playlist_updated) {
                progressDiv.innerHTML += '<p>✓ Playlist mise à jour</p>';
            }
            // Rafraîchir la liste des vidéos après 2 secondes
            setTimeout(() => {
                if (typeof refreshVideoList === 'function') {
                    refreshVideoList();
                } else {
                    // Recharger la page si la fonction n'existe pas
                    window.location.reload();
                }
            }, 2000);
        } else {
            showNotification('Erreur de téléchargement', 'error');
            if (data.output) {
                progressDiv.innerHTML = '<pre>' + data.output + '</pre>';
            }
            if (data.error) {
                progressDiv.innerHTML += '<p>Erreur: ' + data.error + '</p>';
            }
        }
        downloadBtn.disabled = false;
    })
    .catch((error) => {
        showNotification('Erreur de téléchargement', 'error');
        progressDiv.innerHTML = '<p>Erreur: ' + error.message + '</p>';
        downloadBtn.disabled = false;
    });
}

// Fonction de suivi de progression supprimée - Non utilisée
// Si besoin de réimplémenter un suivi de progression, créer une nouvelle fonction

// Service control
async function controlService(service, action) {
    try {
        const response = await fetch('/api/service.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
                service: service,
                action: action 
            })
        });
        
        const data = await response.json();
        if (data.success) {
            showNotification(`Service ${service} ${action}`, 'success');
            // Update service status
            updateServiceStatus(service);
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    } catch (error) {
        showNotification('Erreur de contrôle service', 'error');
    }
}

// Update service status
async function updateServiceStatus(service) {
    try {
        const response = await fetch(`/api/service.php?service=${service}`);
        const data = await response.json();
        
        const statusElement = document.getElementById(`${service}-status`);
        if (statusElement && data.status) {
            statusElement.className = `status ${data.status === 'active' ? 'status-active' : 'status-inactive'}`;
            statusElement.textContent = data.status === 'active' ? 'Actif' : 'Inactif';
        }
    } catch (error) {
        console.error('Erreur status service:', error);
    }
}

// Export functions for external use
window.piSignage = {
    controlPlayer,
    controlService,
    showNotification,
    confirmDelete,
    downloadYouTube
};