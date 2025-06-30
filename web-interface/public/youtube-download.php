<?php
/**
 * Page de téléchargement YouTube avec progression
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Augmenter les limites pour les longs téléchargements
set_time_limit(0);
ini_set('output_buffering', 'off');
ini_set('zlib.output_compression', false);

// Forcer le flush immédiat
if (function_exists('apache_setenv')) {
    apache_setenv('no-gzip', '1');
}

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Téléchargement YouTube - Pi Signage</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <style>
        .download-container {
            max-width: 800px;
            margin: 0 auto;
        }
        
        .progress-container {
            display: none;
            margin-top: 2rem;
        }
        
        .progress {
            height: 30px;
            background-color: #f0f0f0;
            border-radius: 5px;
            overflow: hidden;
            position: relative;
        }
        
        .progress-bar {
            height: 100%;
            background-color: #4CAF50;
            width: 0%;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        
        .console-output {
            background-color: #1e1e1e;
            color: #d4d4d4;
            padding: 1rem;
            border-radius: 5px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9rem;
            max-height: 400px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
            margin-top: 1rem;
            display: none;
        }
        
        .status-message {
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 5px;
            display: none;
        }
        
        .status-success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .status-error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .status-info {
            background-color: #d1ecf1;
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        
        .video-info {
            background-color: #f8f9fa;
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
            display: none;
        }
        
        .video-info h3 {
            margin-top: 0;
        }
        
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(0,0,0,.3);
            border-radius: 50%;
            border-top-color: #000;
            animation: spin 1s ease-in-out infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <?php include dirname(__DIR__) . '/templates/navigation.php'; ?>
    
    <main class="container">
        <h1>📥 Téléchargement YouTube</h1>
        
        <div class="download-container">
            <div class="card">
                <h2>Télécharger une vidéo YouTube</h2>
                
                <form id="youtube-form">
                    <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                    
                    <div class="form-group">
                        <label for="url">URL de la vidéo YouTube</label>
                        <input type="url" 
                               id="url" 
                               name="url" 
                               placeholder="https://www.youtube.com/watch?v=..." 
                               required 
                               class="form-control">
                        <small class="form-text">
                            Entrez l'URL complète d'une vidéo YouTube
                        </small>
                    </div>
                    
                    <div class="form-group">
                        <label for="title">Titre personnalisé (optionnel)</label>
                        <input type="text" 
                               id="title" 
                               name="title" 
                               placeholder="Laissez vide pour utiliser le titre YouTube"
                               class="form-control">
                    </div>
                    
                    <div class="form-group">
                        <label>
                            <input type="checkbox" id="verbose" name="verbose" checked>
                            Mode verbeux (afficher les détails)
                        </label>
                    </div>
                    
                    <button type="submit" class="btn btn-success" id="download-btn">
                        📥 Télécharger la vidéo
                    </button>
                </form>
            </div>
            
            <!-- Informations sur la vidéo -->
            <div class="video-info" id="video-info">
                <h3>Informations de la vidéo</h3>
                <div id="video-details"></div>
            </div>
            
            <!-- Messages de statut -->
            <div class="status-message" id="status-message"></div>
            
            <!-- Barre de progression -->
            <div class="progress-container" id="progress-container">
                <h3>Progression du téléchargement</h3>
                <div class="progress">
                    <div class="progress-bar" id="progress-bar">0%</div>
                </div>
                <p id="progress-info" style="margin-top: 0.5rem; text-align: center;"></p>
            </div>
            
            <!-- Console de sortie -->
            <div class="console-output" id="console-output"></div>
            
            <!-- Bouton de retour -->
            <div style="margin-top: 2rem; text-align: center;">
                <a href="videos.php" class="btn btn-secondary">← Retour à la gestion des vidéos</a>
            </div>
        </div>
    </main>
    
    <script>
    document.getElementById('youtube-form').addEventListener('submit', function(e) {
        e.preventDefault();
        
        const url = document.getElementById('url').value;
        const title = document.getElementById('title').value;
        const verbose = document.getElementById('verbose').checked;
        const csrfToken = document.querySelector('[name="csrf_token"]').value;
        
        // UI Elements
        const downloadBtn = document.getElementById('download-btn');
        const statusMessage = document.getElementById('status-message');
        const progressContainer = document.getElementById('progress-container');
        const progressBar = document.getElementById('progress-bar');
        const progressInfo = document.getElementById('progress-info');
        const consoleOutput = document.getElementById('console-output');
        const videoInfo = document.getElementById('video-info');
        const videoDetails = document.getElementById('video-details');
        
        // Reset UI
        downloadBtn.disabled = true;
        downloadBtn.innerHTML = '<span class="spinner"></span> Téléchargement en cours...';
        statusMessage.style.display = 'none';
        videoInfo.style.display = 'none';
        
        if (verbose) {
            consoleOutput.style.display = 'block';
            consoleOutput.textContent = 'Démarrage du téléchargement...\n';
        }
        
        progressContainer.style.display = 'block';
        progressBar.style.width = '0%';
        progressBar.textContent = '0%';
        progressInfo.textContent = 'Récupération des informations...';
        
        // Créer un EventSource pour le streaming
        const formData = new FormData();
        formData.append('url', url);
        formData.append('title', title);
        formData.append('verbose', verbose ? '1' : '0');
        formData.append('csrf_token', csrfToken);
        formData.append('action', 'download');
        
        fetch('api/youtube-stream.php', {
            method: 'POST',
            body: formData
        })
        .then(response => {
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';
            
            function processStream() {
                reader.read().then(({done, value}) => {
                    if (done) {
                        return;
                    }
                    
                    buffer += decoder.decode(value, {stream: true});
                    const lines = buffer.split('\n');
                    buffer = lines.pop() || '';
                    
                    lines.forEach(line => {
                        if (line.trim()) {
                            try {
                                const data = JSON.parse(line);
                                handleStreamData(data);
                            } catch (e) {
                                // Ligne non-JSON, ignorer
                            }
                        }
                    });
                    
                    processStream();
                });
            }
            
            processStream();
        })
        .catch(error => {
            console.error('Erreur:', error);
            showError('Erreur de connexion: ' + error.message);
        });
        
        function handleStreamData(data) {
            switch(data.type) {
                case 'info':
                    if (data.video_info) {
                        videoInfo.style.display = 'block';
                        videoDetails.innerHTML = `
                            <strong>Titre:</strong> ${data.video_info.title}<br>
                            <strong>Durée:</strong> ${data.video_info.duration}<br>
                            <strong>Résolution:</strong> ${data.video_info.resolution || 'N/A'}<br>
                            <strong>Taille estimée:</strong> ${data.video_info.filesize || 'Calcul en cours...'}
                        `;
                    }
                    progressInfo.textContent = data.message;
                    break;
                    
                case 'progress':
                    progressBar.style.width = data.percent + '%';
                    progressBar.textContent = data.percent + '%';
                    if (data.speed) {
                        progressInfo.textContent = `Vitesse: ${data.speed} - Temps restant: ${data.eta || 'Calcul...'}`;
                    }
                    break;
                    
                case 'console':
                    if (verbose) {
                        consoleOutput.textContent += data.message + '\n';
                        consoleOutput.scrollTop = consoleOutput.scrollHeight;
                    }
                    break;
                    
                case 'success':
                    showSuccess(data.message);
                    progressBar.style.width = '100%';
                    progressBar.textContent = '100%';
                    progressInfo.textContent = 'Téléchargement terminé!';
                    downloadBtn.disabled = false;
                    downloadBtn.innerHTML = '📥 Télécharger une autre vidéo';
                    break;
                    
                case 'error':
                    showError(data.message);
                    downloadBtn.disabled = false;
                    downloadBtn.innerHTML = '📥 Télécharger la vidéo';
                    progressContainer.style.display = 'none';
                    break;
            }
        }
        
        function showSuccess(message) {
            statusMessage.className = 'status-message status-success';
            statusMessage.textContent = '✅ ' + message;
            statusMessage.style.display = 'block';
        }
        
        function showError(message) {
            statusMessage.className = 'status-message status-error';
            statusMessage.textContent = '❌ ' + message;
            statusMessage.style.display = 'block';
        }
    });
    </script>
</body>
</html>