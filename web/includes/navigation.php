<?php
/**
 * PiSignage — Sidebar navigation. SVG icons, 3 sections. No emoji.
 * Requires icons.php (loaded by header.php) and getCurrentPage().
 */
require_once __DIR__ . '/icons.php';
$cur = getCurrentPage();
$nav = [
    'Principal' => [
        ['dashboard.php',          'dashboard', 'Tableau de bord', 'dashboard'],
        ['media.php',              'media',     'Médias',          'media'],
        ['playlists.php',          'playlists', 'Playlists',       'playlist'],
        ['youtube.php',            'youtube',   'YouTube',         'youtube'],
    ],
    'Diffusion' => [
        ['player-control-ui.php',  'player-control-ui', 'Lecteur',      'play-line'],
        ['music.php',              'music',     'Musique',         'volume'],
        ['kiosk.php',              'kiosk',     'Kiosk',           'kiosk'],
        ['overlay.php',            'overlay',   'Overlay',         'layers'],
        ['schedule.php',           'schedule',  'Programmation',   'calendar'],
        ['screenshot.php',         'screenshot','Capture',         'camera'],
    ],
    'Système' => [
        ['settings.php',           'settings',  'Paramètres',      'settings'],
        ['logs.php',               'logs',      'Logs',            'logs'],
    ],
];
?>
<aside class="sidebar" id="sidebar">
    <div class="brand">
        <div class="brand-logo"><?= icon('zaforge') ?></div>
        <div>
            <span class="brand-name">Zaforge</span>
            <span class="brand-ver">v<?= htmlspecialchars($config['version'] ?? '0.12.0') ?></span>
        </div>
    </div>

    <?php foreach ($nav as $section => $items): ?>
    <nav class="nav-group">
        <div class="nav-label"><?= $section ?></div>
        <?php foreach ($items as [$href, $page, $label, $ico]): ?>
        <a href="<?= $href ?>" class="nav-item <?= $cur === $page ? 'active' : '' ?>">
            <?= icon($ico) ?><span><?= $label ?></span>
        </a>
        <?php endforeach; ?>
    </nav>
    <?php endforeach; ?>

    <div class="nav-spacer"></div>
    <a href="#" class="nav-item" onclick="event.preventDefault(); PiSignage.logout();">
        <?= icon('logout') ?><span>Déconnexion</span>
    </a>
    <div class="nav-user">
        <div class="avatar"><?= strtoupper(substr($_SESSION['username'] ?? 'A', 0, 1)) ?></div>
        <div class="nav-user-meta">
            <b><?= htmlspecialchars($_SESSION['username'] ?? 'admin') ?></b>
            <span>Administrateur</span>
        </div>
    </div>
</aside>
<div class="sidebar-backdrop" id="sidebar-backdrop" onclick="PiSignage.ui.toggleSidebar(false)"></div>
