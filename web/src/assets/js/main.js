/**
 * Pi Signage Digital - JavaScript Principal
 * @version 2.0.0
 */

// Fermeture des alertes
document.addEventListener('DOMContentLoaded', function() {
    // Gestion des boutons de fermeture d'alerte
    const closeButtons = document.querySelectorAll('.alert .close');
    closeButtons.forEach(button => {
        button.addEventListener('click', function() {
            const alert = this.closest('.alert');
            alert.style.transition = 'opacity 0.3s';
            alert.style.opacity = '0';
            setTimeout(() => alert.remove(), 300);
        });
    });
    
    // Auto-fermeture des alertes après 5 secondes
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(alert => {
        if (!alert.classList.contains('alert-info')) {
            setTimeout(() => {
                if (alert && alert.parentNode) {
                    alert.style.transition = 'opacity 0.3s';
                    alert.style.opacity = '0';
                    setTimeout(() => alert.remove(), 300);
                }
            }, 5000);
        }
    });
    
    // Menu mobile
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.querySelector('.sidebar');
    
    if (menuToggle) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('active');
        });
    }
    
    // Confirmation de suppression
    const deleteButtons = document.querySelectorAll('form[onsubmit*="confirm"]');
    deleteButtons.forEach(form => {
        form.addEventListener('submit', function(e) {
            if (!confirm('Êtes-vous sûr de vouloir supprimer cette vidéo ?')) {
                e.preventDefault();
            }
        });
    });
});

// Fonction pour mettre à jour le statut en temps réel
async function updateStatus() {
    try {
        const response = await fetch('/api/status.php');
        if (response.ok) {
            const data = await response.json();
            
            // Mettre à jour l'indicateur VLC
            const vlcIndicator = document.querySelector('.status-indicator');
            if (vlcIndicator) {
                if (data.vlc_status) {
                    vlcIndicator.classList.remove('offline');
                    vlcIndicator.classList.add('online');
                    vlcIndicator.textContent = 'VLC: Actif';
                } else {
                    vlcIndicator.classList.remove('online');
                    vlcIndicator.classList.add('offline');
                    vlcIndicator.textContent = 'VLC: Inactif';
                }
            }
            
            // Mettre à jour les statistiques
            if (data.system_info) {
                updateStatCard('cpu', data.system_info.cpu_usage);
                updateStatCard('memory', data.system_info.memory_usage);
                updateStatCard('temperature', data.system_info.temperature);
            }
        }
    } catch (error) {
        console.error('Erreur lors de la mise à jour du statut:', error);
    }
}

// Fonction pour mettre à jour une carte de statistique
function updateStatCard(type, value) {
    const card = document.querySelector(`[data-stat="${type}"]`);
    if (card) {
        const valueElement = card.querySelector('h3');
        if (valueElement) {
            switch(type) {
                case 'cpu':
                case 'memory':
                    valueElement.textContent = value + '%';
                    break;
                case 'temperature':
                    valueElement.textContent = value + '°C';
                    break;
                default:
                    valueElement.textContent = value;
            }
        }
    }
}

// Fonction pour formater les octets
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

// Fonction pour gérer le téléchargement YouTube avec progression
async function handleYouTubeDownload(form) {
    const url = form.youtube_url.value;
    const quality = form.quality.value;
    const progressDiv = document.getElementById('downloadProgress');
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');
    
    progressDiv.style.display = 'block';
    
    try {
        const response = await fetch('/api/download.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                url: url,
                quality: quality,
                csrf_token: form.csrf_token.value
            })
        });
        
        if (response.ok) {
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                
                const text = decoder.decode(value);
                const lines = text.split('\n');
                
                for (const line of lines) {
                    if (line.includes('download')) {
                        const match = line.match(/(\d+\.?\d*)%/);
                        if (match) {
                            const percent = parseFloat(match[1]);
                            progressBar.style.width = percent + '%';
                            progressBar.textContent = Math.round(percent) + '%';
                            
                            if (percent < 30) {
                                progressText.textContent = 'Téléchargement en cours...';
                            } else if (percent < 90) {
                                progressText.textContent = 'Traitement de la vidéo...';
                            } else {
                                progressText.textContent = 'Finalisation...';
                            }
                        }
                    }
                }
            }
            
            progressBar.style.width = '100%';
            progressBar.textContent = '100%';
            progressText.textContent = 'Téléchargement terminé !';
            
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
        } else {
            throw new Error('Erreur lors du téléchargement');
        }
    } catch (error) {
        console.error('Erreur:', error);
        progressText.textContent = 'Erreur lors du téléchargement';
        progressBar.classList.add('bg-danger');
    }
}

// Fonction pour afficher les notifications
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="close" data-dismiss="alert">&times;</button>
    `;
    
    const container = document.querySelector('.main-content');
    const firstCard = container.querySelector('.card');
    container.insertBefore(notification, firstCard);
    
    // Auto-fermeture après 5 secondes
    setTimeout(() => {
        notification.style.transition = 'opacity 0.3s';
        notification.style.opacity = '0';
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}

// Fonction pour gérer les uploads de fichiers
function handleFileUpload(input) {
    const files = input.files;
    const maxSize = 100 * 1024 * 1024; // 100MB
    
    for (let file of files) {
        // Vérifier le type
        const extension = file.name.split('.').pop().toLowerCase();
        const allowedExtensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'];
        
        if (!allowedExtensions.includes(extension)) {
            showNotification(`Format non supporté: ${file.name}`, 'error');
            continue;
        }
        
        // Vérifier la taille
        if (file.size > maxSize) {
            showNotification(`Fichier trop volumineux: ${file.name} (max 100MB)`, 'error');
            continue;
        }
        
        // Upload du fichier
        uploadFile(file);
    }
}

// Fonction pour uploader un fichier
async function uploadFile(file) {
    const formData = new FormData();
    formData.append('video', file);
    
    // Créer une barre de progression
    const progressContainer = createProgressBar(file.name);
    
    try {
        const xhr = new XMLHttpRequest();
        
        // Événements de progression
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percentComplete = (e.loaded / e.total) * 100;
                updateProgressBar(progressContainer, percentComplete);
            }
        });
        
        // Événement de fin
        xhr.addEventListener('load', () => {
            if (xhr.status === 200) {
                updateProgressBar(progressContainer, 100, 'success');
                setTimeout(() => window.location.reload(), 2000);
            } else {
                updateProgressBar(progressContainer, 0, 'error');
            }
        });
        
        // Événement d'erreur
        xhr.addEventListener('error', () => {
            updateProgressBar(progressContainer, 0, 'error');
        });
        
        // Envoyer la requête
        xhr.open('POST', '/api/upload.php');
        xhr.send(formData);
        
    } catch (error) {
        console.error('Erreur upload:', error);
        updateProgressBar(progressContainer, 0, 'error');
    }
}

// Fonction pour créer une barre de progression
function createProgressBar(filename) {
    const container = document.createElement('div');
    container.className = 'upload-progress-container';
    container.innerHTML = `
        <div class="upload-filename">${filename}</div>
        <div class="progress">
            <div class="progress-bar progress-bar-animated" style="width: 0%">0%</div>
        </div>
    `;
    
    const uploadList = document.getElementById('uploadList');
    if (uploadList) {
        uploadList.appendChild(container);
    }
    
    return container;
}

// Fonction pour mettre à jour la barre de progression
function updateProgressBar(container, percent, status = 'progress') {
    const bar = container.querySelector('.progress-bar');
    
    if (status === 'progress') {
        bar.style.width = percent + '%';
        bar.textContent = Math.round(percent) + '%';
    } else if (status === 'success') {
        bar.classList.remove('progress-bar-animated');
        bar.classList.add('bg-success');
        bar.style.width = '100%';
        bar.textContent = 'Terminé';
    } else if (status === 'error') {
        bar.classList.remove('progress-bar-animated');
        bar.classList.add('bg-danger');
        bar.textContent = 'Erreur';
    }
}

// Mise à jour automatique du statut toutes les 10 secondes (sur le dashboard)
if (window.location.pathname.includes('dashboard.php')) {
    setInterval(updateStatus, 10000);
    updateStatus(); // Première mise à jour immédiate
}

// Gestion du thème sombre/clair (pour une future fonctionnalité)
function toggleTheme() {
    const body = document.body;
    const currentTheme = body.getAttribute('data-theme') || 'dark';
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    body.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
}

// Appliquer le thème sauvegardé
const savedTheme = localStorage.getItem('theme') || 'dark';
document.body.setAttribute('data-theme', savedTheme);