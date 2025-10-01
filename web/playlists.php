<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Playlists Section -->
        <div id="playlists" class="content-section active">
            <div class="header">
                <h1 class="page-title">Éditeur de Playlists</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="createNewPlaylist()">
                        ➕ Nouvelle Playlist
                    </button>
                    <button class="btn btn-secondary" onclick="loadExistingPlaylist()">
                        📂 Charger
                    </button>
                    <button class="btn btn-success" onclick="saveCurrentPlaylist()" id="save-playlist-btn" disabled>
                        💾 Sauvegarder
                    </button>
                </div>
            </div>

            <!-- Existing Playlists Overview -->
            <div class="playlists-overview" style="margin: 30px 0;">
                <h2 style="color: #4a9eff; margin-bottom: 20px; font-size: 1.5rem;">
                    📋 Playlists Existantes
                </h2>
                <div id="playlist-container" class="playlists-grid" style="
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                ">
                    <!-- Playlists will be loaded here dynamically -->
                </div>
            </div>

            <hr style="border: none; border-top: 1px solid rgba(74, 158, 255, 0.2); margin: 30px 0;">

            <!-- Playlist Editor Interface -->
            <div id="playlist-editor" class="playlist-editor-container">
                <!-- Media Library Panel (Left) -->
                <div class="playlist-panel media-library-panel">
                    <div class="panel-header">
                        <h3>📁 Bibliothèque Média</h3>
                        <div class="panel-controls">
                            <button class="btn-icon" onclick="refreshMediaLibrary()" title="Actualiser">
                                🔄
                            </button>
                            <input type="text" class="search-input" placeholder="Rechercher..." id="media-search" onkeyup="filterMediaLibrary()">
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="media-filters">
                            <button class="filter-btn active" data-type="all" onclick="filterMediaType('all')">Tous</button>
                            <button class="filter-btn" data-type="video" onclick="filterMediaType('video')">Vidéos</button>
                            <button class="filter-btn" data-type="image" onclick="filterMediaType('image')">Images</button>
                            <button class="filter-btn" data-type="audio" onclick="filterMediaType('audio')">Audio</button>
                        </div>
                        <div class="media-library-list" id="media-library-list">
                            <!-- Media files will be loaded here -->
                        </div>
                    </div>
                </div>

                <!-- Playlist Workspace Panel (Center) -->
                <div class="playlist-panel workspace-panel">
                    <div class="panel-header">
                        <h3>🎵 Playlist Workspace</h3>
                        <div class="playlist-info">
                            <span id="playlist-name-display">Nouvelle Playlist</span>
                            <span class="playlist-stats">
                                <span id="item-count">0 éléments</span> -
                                <span id="total-duration">00:00</span>
                            </span>
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="playlist-workspace" id="playlist-workspace">
                            <div class="drop-zone" id="playlist-drop-zone">
                                <div class="drop-zone-content">
                                    <div class="drop-zone-icon">📁</div>
                                    <p>Glissez des médias ici pour créer votre playlist</p>
                                    <p class="drop-zone-hint">Ou cliquez sur "+" dans la bibliothèque</p>
                                </div>
                            </div>
                            <div class="playlist-items" id="playlist-items">
                                <!-- Playlist items will be added here -->
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Properties Panel (Right) -->
                <div class="playlist-panel properties-panel">
                    <div class="panel-header">
                        <h3>⚙️ Propriétés</h3>
                    </div>
                    <div class="panel-content">
                        <div class="properties-section">
                            <h4>Playlist</h4>
                            <div class="form-group">
                                <label>Nom:</label>
                                <input type="text" id="playlist-name-input" placeholder="Nom de la playlist" onchange="updatePlaylistName()">
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-loop" onchange="updatePlaylistSettings()">
                                    Lecture en boucle
                                </label>
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-shuffle" onchange="updatePlaylistSettings()">
                                    Lecture aléatoire
                                </label>
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-auto-advance" checked onchange="updatePlaylistSettings()">
                                    Avancement automatique
                                </label>
                            </div>
                        </div>

                        <div class="properties-section" id="item-properties" style="display: none;">
                            <h4>Élément sélectionné</h4>
                            <div class="form-group">
                                <label>Fichier:</label>
                                <span id="selected-file-name">-</span>
                            </div>
                            <div class="form-group">
                                <label>Durée (secondes):</label>
                                <input type="number" id="item-duration" min="1" max="3600" value="10" onchange="updateItemDuration()">
                            </div>
                            <div class="form-group">
                                <label>Transition:</label>
                                <select id="item-transition" onchange="updateItemTransition()">
                                    <option value="none">Aucune</option>
                                    <option value="fade">Fondu</option>
                                    <option value="slide-left">Glissement gauche</option>
                                    <option value="slide-right">Glissement droite</option>
                                    <option value="zoom">Zoom</option>
                                    <option value="dissolve">Dissolution</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Durée transition (ms):</label>
                                <input type="number" id="transition-duration" min="0" max="5000" value="1000" onchange="updateTransitionDuration()">
                            </div>
                        </div>

                        <div class="properties-section">
                            <h4>Actions</h4>
                            <button class="btn btn-primary btn-block" onclick="previewPlaylist()" id="preview-btn" disabled>
                                ▶️ Aperçu
                            </button>
                            <button class="btn btn-secondary btn-block" onclick="clearPlaylist()">
                                🗑️ Vider
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Loading existing playlists modal -->
            <div id="load-playlist-modal" class="modal" style="display: none;">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3>Charger une Playlist</h3>
                        <button class="btn-close" onclick="closeLoadPlaylistModal()">×</button>
                    </div>
                    <div class="modal-body">
                        <div id="existing-playlists-list">
                            <!-- Existing playlists will be loaded here -->
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>