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
            <div class="nav-item <?= getCurrentPage() === 'dashboard' ? 'active' : '' ?>" onclick="location.href='dashboard.php'">
                <span>📊</span>
                <span>Dashboard</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'media' ? 'active' : '' ?>" onclick="location.href='media.php'">
                <span>📁</span>
                <span>Médias</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'playlists' ? 'active' : '' ?>" onclick="location.href='playlists.php'">
                <span>🎵</span>
                <span>Playlists</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'youtube' ? 'active' : '' ?>" onclick="location.href='youtube.php'">
                <span>📺</span>
                <span>YouTube</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Contrôle</div>
            <div class="nav-item <?= getCurrentPage() === 'player' ? 'active' : '' ?>" onclick="location.href='player.php'">
                <span>▶️</span>
                <span>Lecteur</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'schedule' ? 'active' : '' ?>" onclick="location.href='schedule.php'">
                <span>📅</span>
                <span>Programmation</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'screenshot' ? 'active' : '' ?>" onclick="location.href='screenshot.php'">
                <span>📸</span>
                <span>Capture</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Système</div>
            <div class="nav-item <?= getCurrentPage() === 'settings' ? 'active' : '' ?>" onclick="location.href='settings.php'">
                <span>⚙️</span>
                <span>Paramètres</span>
            </div>
            <div class="nav-item <?= getCurrentPage() === 'logs' ? 'active' : '' ?>" onclick="location.href='logs.php'">
                <span>📋</span>
                <span>Logs</span>
            </div>
        </div>
    </div>