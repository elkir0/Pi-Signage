    <!-- Sidebar -->
    <div class="sidebar" id="sidebar">
        <div class="logo">
            <div>
                🖥️ PiSignage
                <span class="logo-version">v<?= $config['version'] ?></span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Principal</div>
            <a href="dashboard.php" class="nav-item <?= getCurrentPage() === 'dashboard' ? 'active' : '' ?>">
                <span>📊</span>
                <span>Dashboard</span>
            </a>
            <a href="media.php" class="nav-item <?= getCurrentPage() === 'media' ? 'active' : '' ?>">
                <span>📁</span>
                <span>Médias</span>
            </a>
            <a href="playlists.php" class="nav-item <?= getCurrentPage() === 'playlists' ? 'active' : '' ?>">
                <span>🎵</span>
                <span>Playlists</span>
            </a>
            <a href="youtube.php" class="nav-item <?= getCurrentPage() === 'youtube' ? 'active' : '' ?>">
                <span>📺</span>
                <span>YouTube</span>
            </a>
        </div>

        <div class="nav-section">
            <div class="nav-title">Contrôle</div>
            <a href="player-control-ui.php" class="nav-item <?= getCurrentPage() === 'player-control-ui' ? 'active' : '' ?>">
                <span>▶️</span>
                <span>Lecteur</span>
            </a>
            <a href="schedule.php" class="nav-item <?= getCurrentPage() === 'schedule' ? 'active' : '' ?>">
                <span>📅</span>
                <span>Programmation</span>
            </a>
            <a href="screenshot.php" class="nav-item <?= getCurrentPage() === 'screenshot' ? 'active' : '' ?>">
                <span>📸</span>
                <span>Capture</span>
            </a>
        </div>

        <div class="nav-section">
            <div class="nav-title">Système</div>
            <a href="settings.php" class="nav-item <?= getCurrentPage() === 'settings' ? 'active' : '' ?>">
                <span>⚙️</span>
                <span>Paramètres</span>
            </a>
            <a href="logs.php" class="nav-item <?= getCurrentPage() === 'logs' ? 'active' : '' ?>">
                <span>📋</span>
                <span>Logs</span>
            </a>
            <a href="#" class="nav-item" onclick="event.preventDefault(); logout();">
                <span>🚪</span>
                <span>Déconnexion</span>
            </a>
        </div>
    </div>