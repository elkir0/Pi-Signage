<?php
/**
 * Template de navigation Pi Signage
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    die('Direct access not allowed');
}

$currentPage = basename($_SERVER['PHP_SELF']);
?>
<nav class="navbar">
    <div class="navbar-brand">
        <a href="dashboard.php">
            <img src="assets/images/logo.png" alt="Pi Signage" class="navbar-logo">
            <span class="navbar-title">Pi Signage</span>
        </a>
    </div>
    
    <ul class="navbar-menu">
        <li class="<?= $currentPage === 'dashboard.php' ? 'active' : '' ?>">
            <a href="dashboard.php">📊 Tableau de bord</a>
        </li>
        <li class="<?= $currentPage === 'videos.php' ? 'active' : '' ?>">
            <a href="videos.php">📹 Vidéos</a>
        </li>
        <li class="<?= $currentPage === 'playlist.php' ? 'active' : '' ?>">
            <a href="playlist.php">📑 Playlist</a>
        </li>
        <li class="<?= $currentPage === 'settings.php' ? 'active' : '' ?>">
            <a href="settings.php">⚙️ Paramètres</a>
        </li>
    </ul>
    
    <div class="navbar-user">
        <span class="user-info">👤 <?= htmlspecialchars($_SESSION['username'] ?? 'Admin') ?></span>
        <a href="logout.php" class="btn-logout">Déconnexion</a>
    </div>
</nav>

<style>
.navbar {
    background: #333;
    color: white;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.navbar-brand a {
    color: white;
    text-decoration: none;
    font-size: 1.25rem;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 0.75rem;
}

.navbar-logo {
    height: 40px;
    width: auto;
    filter: brightness(0) invert(1);
    transition: transform 0.3s ease;
}

.navbar-brand a:hover .navbar-logo {
    transform: scale(1.05);
}

.navbar-title {
    display: inline-block;
}

.navbar-menu {
    display: flex;
    list-style: none;
    margin: 0;
    padding: 0;
    gap: 2rem;
}

.navbar-menu li a {
    color: rgba(255,255,255,0.8);
    text-decoration: none;
    transition: color 0.3s;
}

.navbar-menu li.active a,
.navbar-menu li a:hover {
    color: white;
}

.navbar-user {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.user-info {
    opacity: 0.8;
}

.btn-logout {
    background: #dc3545;
    color: white;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    text-decoration: none;
    transition: background 0.3s;
}

.btn-logout:hover {
    background: #c82333;
}

@media (max-width: 768px) {
    .navbar {
        flex-direction: column;
        gap: 1rem;
    }
    
    .navbar-menu {
        gap: 1rem;
    }
}
</style>