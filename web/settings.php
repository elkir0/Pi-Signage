<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Settings Section -->
        <div id="settings" class="content-section active">
            <div class="header">
                <h1 class="page-title">Paramètres</h1>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🔊</span>
                        Sortie Audio
                    </h3>
                    <div class="form-group">
                        <label class="form-label">Sélectionner la sortie audio</label>
                        <select class="form-control" id="audio-output">
                            <option value="hdmi">HDMI</option>
                            <option value="jack">Jack 3.5mm</option>
                        </select>
                    </div>
                    <button class="btn btn-primary" onclick="saveAudioConfig()">
                        💾 Appliquer
                    </button>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>🔒</span>
                        Sécurité
                    </h3>
                    <form id="password-form" onsubmit="return false;">
                        <div class="form-group">
                            <label class="form-label">Ancien mot de passe</label>
                            <input type="password" class="form-control" id="old-password" placeholder="Ancien mot de passe" autocomplete="current-password">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Nouveau mot de passe</label>
                            <input type="password" class="form-control" id="new-password" placeholder="Nouveau mot de passe (min. 6 caractères)" autocomplete="new-password">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Confirmer le mot de passe</label>
                            <input type="password" class="form-control" id="confirm-password" placeholder="Confirmer le nouveau mot de passe" autocomplete="new-password">
                        </div>
                        <button type="button" class="btn btn-primary" onclick="changePassword()">
                            🔑 Changer le mot de passe
                        </button>
                    </form>
                </div>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🖥️</span>
                        Affichage
                    </h3>
                    <div class="form-group">
                        <label class="form-label">Résolution</label>
                        <select class="form-control" id="resolution">
                            <option value="1920x1080">1920x1080 (Full HD)</option>
                            <option value="1280x720">1280x720 (HD)</option>
                            <option value="1024x768">1024x768</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Rotation</label>
                        <select class="form-control" id="rotation">
                            <option value="0">0° (Normal)</option>
                            <option value="90">90° (Droite)</option>
                            <option value="180">180° (Inversé)</option>
                            <option value="270">270° (Gauche)</option>
                        </select>
                    </div>
                    <button class="btn btn-primary" onclick="saveDisplayConfig()">
                        💾 Appliquer
                    </button>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>🌐</span>
                        Réseau
                    </h3>
                    <form id="network-form" onsubmit="return false;">
                        <div class="form-group">
                            <label class="form-label">WiFi SSID</label>
                            <input type="text" class="form-control" id="wifi-ssid" placeholder="Nom du réseau">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Mot de passe</label>
                            <input type="password" class="form-control" id="wifi-password" placeholder="Mot de passe" autocomplete="new-password">
                        </div>
                        <button type="button" class="btn btn-primary" onclick="saveNetworkConfig()">
                            💾 Appliquer
                        </button>
                    </form>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>🔧</span>
                    Actions système
                </h3>
                <div style="display: flex; gap: 15px; flex-wrap: wrap;">
                    <button class="btn btn-danger" onclick="systemAction('reboot')">
                        🔄 Redémarrer
                    </button>
                    <button class="btn btn-danger" onclick="systemAction('shutdown')">
                        ⚡ Éteindre
                    </button>
                    <button class="btn btn-glass" onclick="restartCurrentPlayer()">
                        🎵 <span id="restart-player-text">Redémarrer VLC</span>
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('clear-cache')">
                        🗑️ Vider le cache
                    </button>
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>