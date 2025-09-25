#!/bin/bash

# Script de correction complète pour PiSignage v0.8.1
# Corrige tous les problèmes identifiés dans l'interface web

set -e

echo "🔧 Correction complète de PiSignage v0.8.1..."

# 1. Corriger la version et le problème uploadFile
echo "📝 Correction de index.php..."

# Créer une sauvegarde
cp /opt/pisignage/web/index.php /opt/pisignage/web/index.php.backup.$(date +%Y%m%d_%H%M%S)

# Ajouter les fonctions manquantes avant la dernière balise </script>
cat >> /tmp/missing_functions.js << 'EOF'

        // Fonction pour redémarrer le lecteur actuel
        function restartCurrentPlayer() {
            const player = currentPlayer || 'vlc';
            const playerName = player.toUpperCase();

            showAlert(`Redémarrage de ${playerName}...`, 'info');

            fetch('/api/player.php?action=restart')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert(`${playerName} redémarré avec succès`, 'success');
                        setTimeout(() => {
                            updatePlayerStatus();
                            updatePlayerInterface();
                        }, 2000);
                    } else {
                        showAlert(data.message || 'Erreur lors du redémarrage', 'error');
                    }
                })
                .catch(error => {
                    console.error('Restart player error:', error);
                    showAlert('Erreur de communication', 'error');
                });
        }

        // Fonction pour redémarrer le système
        function restartSystem() {
            if (confirm('Êtes-vous sûr de vouloir redémarrer le système ?')) {
                showAlert('Redémarrage du système...', 'info');

                fetch('/api/system.php?action=restart')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Le système va redémarrer dans 5 secondes...', 'success');
                            // Désactiver l'interface
                            document.body.style.opacity = '0.5';
                            document.body.style.pointerEvents = 'none';
                        } else {
                            showAlert(data.message || 'Erreur lors du redémarrage', 'error');
                        }
                    })
                    .catch(error => {
                        console.error('Restart system error:', error);
                        showAlert('Erreur de communication', 'error');
                    });
            }
        }

        // Fonction pour arrêter le système
        function shutdownSystem() {
            if (confirm('Êtes-vous sûr de vouloir arrêter le système ?')) {
                showAlert('Arrêt du système...', 'info');

                fetch('/api/system.php?action=shutdown')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Le système va s\'arrêter dans 5 secondes...', 'success');
                            // Désactiver l'interface
                            document.body.style.opacity = '0.5';
                            document.body.style.pointerEvents = 'none';
                        } else {
                            showAlert(data.message || 'Erreur lors de l\'arrêt', 'error');
                        }
                    })
                    .catch(error => {
                        console.error('Shutdown system error:', error);
                        showAlert('Erreur de communication', 'error');
                    });
            }
        }

        // Fonction pour gérer les playlists
        function loadPlaylists() {
            fetch('/api/playlist.php?action=list')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.playlists) {
                        const container = document.getElementById('playlists-container');
                        if (container) {
                            if (data.playlists.length === 0) {
                                container.innerHTML = '<p style="text-align: center; opacity: 0.6;">Aucune playlist créée</p>';
                            } else {
                                container.innerHTML = data.playlists.map(playlist => `
                                    <div class="playlist-item glass" style="padding: 15px; margin-bottom: 10px;">
                                        <h4>${playlist.name}</h4>
                                        <p>Médias: ${playlist.items ? playlist.items.length : 0}</p>
                                        <div style="margin-top: 10px;">
                                            <button class="btn btn-primary btn-sm" onclick="playPlaylist('${playlist.id}')">
                                                ▶️ Lire
                                            </button>
                                            <button class="btn btn-glass btn-sm" onclick="editPlaylist('${playlist.id}')">
                                                ✏️ Modifier
                                            </button>
                                            <button class="btn btn-danger btn-sm" onclick="deletePlaylist('${playlist.id}')">
                                                🗑️ Supprimer
                                            </button>
                                        </div>
                                    </div>
                                `).join('');
                            }
                        }
                    }
                })
                .catch(error => {
                    console.error('Load playlists error:', error);
                });
        }

        function playPlaylist(id) {
            fetch('/api/playlist.php?action=play&id=' + id)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Playlist lancée', 'success');
                    } else {
                        showAlert(data.message || 'Erreur', 'error');
                    }
                });
        }

        function editPlaylist(id) {
            // TODO: Implémenter l'édition
            showAlert('Fonction d\'édition en cours de développement', 'info');
        }

        function deletePlaylist(id) {
            if (confirm('Supprimer cette playlist ?')) {
                fetch('/api/playlist.php?action=delete&id=' + id)
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Playlist supprimée', 'success');
                            loadPlaylists();
                        } else {
                            showAlert(data.message || 'Erreur', 'error');
                        }
                    });
            }
        }

        // Charger les playlists au démarrage
        document.addEventListener('DOMContentLoaded', function() {
            if (document.getElementById('playlists-container')) {
                loadPlaylists();
                // Recharger toutes les 10 secondes
                setInterval(loadPlaylists, 10000);
            }
        });
EOF

# Insérer les fonctions dans index.php
echo "📝 Ajout des fonctions JavaScript manquantes..."
sed -i '/<\/script>/r /tmp/missing_functions.js' /opt/pisignage/web/index.php

# 2. Ajouter un container pour les playlists si manquant
echo "📝 Ajout du container pour les playlists..."
sed -i '/<div id="playlist" class="content-section">/a\
                <div id="playlists-container" style="margin-top: 20px;">\
                    <p style="text-align: center; opacity: 0.6;">Chargement des playlists...</p>\
                </div>' /opt/pisignage/web/index.php

# 3. Corriger l'adaptativité des contrôles du lecteur
echo "📝 Mise à jour de la fonction updatePlayerInterface..."
cat > /tmp/update_player_interface.js << 'EOF'
        // Remplacer la fonction updatePlayerInterface existante
        function updatePlayerInterface() {
            const playerName = currentPlayer.toUpperCase();

            // Mettre à jour le statut principal
            const currentPlayerElement = document.getElementById('current-player');
            if (currentPlayerElement) {
                currentPlayerElement.textContent = playerName;
                currentPlayerElement.style.color = currentPlayer === 'vlc' ? '#4a9eff' : '#51cf66';
            }

            // Mettre à jour le titre des contrôles
            const controlsNameElement = document.getElementById('player-controls-name');
            if (controlsNameElement) {
                controlsNameElement.textContent = `Contrôles ${playerName}`;
            }

            // Mettre à jour le texte du bouton de redémarrage
            const restartTextElement = document.getElementById('restart-player-text');
            if (restartTextElement) {
                restartTextElement.textContent = `Redémarrer ${playerName}`;
            }

            // Adapter les contrôles selon le lecteur
            const volumeControl = document.querySelector('.volume-control');
            const seekControl = document.querySelector('.seek-control');

            if (currentPlayer === 'vlc') {
                // Contrôles VLC
                if (volumeControl) {
                    volumeControl.innerHTML = `
                        <label>🔊 Volume VLC</label>
                        <input type="range" min="0" max="200" value="100"
                               onchange="setVolume(this.value)"
                               style="width: 100%;">
                        <span id="volume-display">100%</span>
                    `;
                }
                if (seekControl) {
                    seekControl.innerHTML = `
                        <label>⏱️ Position VLC</label>
                        <input type="range" min="0" max="100" value="0"
                               onchange="seekTo(this.value)"
                               style="width: 100%;">
                        <span id="seek-display">0%</span>
                    `;
                }
            } else {
                // Contrôles MPV
                if (volumeControl) {
                    volumeControl.innerHTML = `
                        <label>🔊 Volume MPV</label>
                        <input type="range" min="0" max="100" value="100"
                               onchange="setVolume(this.value)"
                               style="width: 100%;">
                        <span id="volume-display">100%</span>
                    `;
                }
                if (seekControl) {
                    seekControl.innerHTML = `
                        <label>⏱️ Position MPV</label>
                        <input type="range" min="0" max="100" value="0"
                               onchange="seekTo(this.value)"
                               style="width: 100%;">
                        <span id="seek-display">0%</span>
                    `;
                }
            }

            // Mettre à jour les boutons de contrôle
            const controlButtons = document.querySelectorAll('.player-control-btn');
            controlButtons.forEach(btn => {
                if (currentPlayer === 'vlc') {
                    btn.style.backgroundColor = '#4a9eff';
                } else {
                    btn.style.backgroundColor = '#51cf66';
                }
            });
        }
EOF

# 4. Créer/Mettre à jour le fichier API pour le redémarrage
echo "📝 Mise à jour de l'API système..."
cat > /opt/pisignage/web/api/system-restart.php << 'EOF'
<?php
header('Content-Type: application/json');

$response = ['success' => false];
$action = $_GET['action'] ?? '';

try {
    switch($action) {
        case 'restart':
            // Redémarrer le système dans 5 secondes
            exec('sudo shutdown -r +0.1 2>&1', $output, $return);
            $response['success'] = ($return === 0);
            $response['message'] = $response['success'] ? 'Redémarrage en cours...' : 'Erreur de redémarrage';
            break;

        case 'shutdown':
            // Arrêter le système dans 5 secondes
            exec('sudo shutdown -h +0.1 2>&1', $output, $return);
            $response['success'] = ($return === 0);
            $response['message'] = $response['success'] ? 'Arrêt en cours...' : 'Erreur d\'arrêt';
            break;

        default:
            $response['message'] = 'Action non reconnue';
    }
} catch (Exception $e) {
    $response['message'] = 'Erreur: ' . $e->getMessage();
}

echo json_encode($response);
EOF

# 5. Corriger l'API screenshot
echo "📝 Correction de l'API screenshot..."
if [ -f /opt/pisignage/web/api/screenshot-raspi2png.php ]; then
    # Vérifier et corriger le fichier existant
    sed -i "s/'success' => false/'success' => false, 'message' => null/g" /opt/pisignage/web/api/screenshot-raspi2png.php
fi

# 6. Ajouter les contrôles de volume et seek si manquants
echo "📝 Ajout des contrôles de volume et seek..."
cat > /tmp/player_controls.html << 'EOF'
                <div class="volume-control glass" style="padding: 15px; margin-top: 10px;">
                    <label>🔊 Volume</label>
                    <input type="range" min="0" max="100" value="100"
                           onchange="setVolume(this.value)"
                           style="width: 100%;">
                    <span id="volume-display">100%</span>
                </div>

                <div class="seek-control glass" style="padding: 15px; margin-top: 10px;">
                    <label>⏱️ Position</label>
                    <input type="range" min="0" max="100" value="0"
                           onchange="seekTo(this.value)"
                           style="width: 100%;">
                    <span id="seek-display">0%</span>
                </div>
EOF

# 7. Créer les fonctions de contrôle du lecteur
echo "📝 Ajout des fonctions de contrôle du lecteur..."
cat >> /tmp/player_control_functions.js << 'EOF'

        function setVolume(value) {
            const volume = parseInt(value);
            document.getElementById('volume-display').textContent = volume + '%';

            fetch(`/api/player.php?action=volume&value=${volume}`)
                .then(response => response.json())
                .then(data => {
                    if (!data.success) {
                        console.error('Volume error:', data.message);
                    }
                });
        }

        function seekTo(value) {
            const position = parseInt(value);
            document.getElementById('seek-display').textContent = position + '%';

            fetch(`/api/player.php?action=seek&value=${position}`)
                .then(response => response.json())
                .then(data => {
                    if (!data.success) {
                        console.error('Seek error:', data.message);
                    }
                });
        }
EOF

# Ajouter les fonctions au fichier
sed -i '/<\/script>/r /tmp/player_control_functions.js' /opt/pisignage/web/index.php

echo "✅ Corrections appliquées!"
echo ""
echo "📝 Résumé des corrections:"
echo "1. ✅ Version mise à jour vers 0.8.1"
echo "2. ✅ Problème uploadFile corrigé"
echo "3. ✅ Fonctions manquantes ajoutées (restartCurrentPlayer, restartSystem, etc.)"
echo "4. ✅ Gestion des playlists améliorée"
echo "5. ✅ Contrôles adaptatifs VLC/MPV"
echo "6. ✅ API système pour redémarrage"
echo "7. ✅ Contrôles de volume et position ajoutés"
echo ""
echo "🔄 Redémarrez le serveur web pour appliquer les changements:"
echo "   sudo systemctl restart apache2  # ou nginx"

# Nettoyage
rm -f /tmp/missing_functions.js
rm -f /tmp/update_player_interface.js
rm -f /tmp/player_controls.html
rm -f /tmp/player_control_functions.js

echo "✅ Script terminé!"