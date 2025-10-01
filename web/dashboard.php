<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Dashboard Section -->
        <div id="dashboard" class="content-section active">
            <div class="header">
                <h1 class="page-title">Dashboard</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('dashboard')">
                        📸 Capture
                    </button>
                    <button class="btn btn-primary" onclick="refreshStats()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="grid grid-3">
                <div class="stat-card">
                    <div class="stat-value" id="cpu-usage">--</div>
                    <div class="stat-label">CPU</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="ram-usage">--</div>
                    <div class="stat-label">RAM</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="temperature">--</div>
                    <div class="stat-label">Température</div>
                </div>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🎵</span>
                        Lecteur Vidéo
                    </h3>
                    <!-- Sélecteur de lecteur vidéo -->
                    <div class="player-selector">
                        <div class="selector-title">Choisir le lecteur :</div>
                        <!-- PiSignage v0.8.9+ uses VLC exclusively -->
                        <div class="player-info">
                            <div class="option-content">
                                <div class="option-icon">🎛️</div>
                                <div class="option-details">
                                    <div class="option-name">Lecteur: VLC Media Player</div>
                                    <div class="option-desc">Contrôle complet, playlists, screenshots</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Statut du lecteur -->
                    <div class="player-status">
                        <div class="status-title">Statut : <span id="current-player">VLC</span></div>
                        <p><strong>État:</strong> <span id="player-state">Arrêté</span></p>
                        <p><strong>Fichier:</strong> <span id="player-file">Aucun</span></p>
                        <p><strong>Position:</strong> <span id="player-position">00:00</span></p>
                    </div>
                    <div class="player-controls">
                        <div class="player-btn" onclick="playerControl('play')">▶️</div>
                        <div class="player-btn" onclick="playerControl('pause')">⏸️</div>
                        <div class="player-btn" onclick="playerControl('stop')">⏹️</div>
                        <div class="player-btn" onclick="takeQuickScreenshot('player')">📸</div>
                    </div>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>📊</span>
                        Statistiques Système
                    </h3>
                    <div id="system-stats">
                        <p><strong>Uptime:</strong> <span id="uptime">--</span></p>
                        <p><strong>Stockage:</strong> <span id="storage">--</span></p>
                        <p><strong>Réseau:</strong> <span id="network">--</span></p>
                        <p><strong>Médias:</strong> <span id="media-count">--</span> fichiers</p>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>⚡</span>
                    Actions Rapides
                </h3>
                <div class="quick-actions" style="display: flex; gap: 15px; flex-wrap: wrap;">
                    <button class="btn btn-danger" onclick="systemAction('reboot')">
                        🔄 Redémarrer système
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('clear-cache')">
                        🗑️ Vider le cache
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('restart-player')">
                        🎵 Redémarrer lecteur
                    </button>
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>