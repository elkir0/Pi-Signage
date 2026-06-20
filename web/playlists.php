<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Playlists';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions =
      '<button class="btn btn-primary btn-sm" type="button" onclick="createNewPlaylist()">' . icon('plus') . 'Nouvelle</button>'
    . '<button class="btn btn-secondary btn-sm" type="button" onclick="loadExistingPlaylist()">' . icon('folder') . 'Charger</button>'
    . '<button class="btn btn-secondary btn-sm" type="button" id="save-playlist-btn" onclick="saveCurrentPlaylist()" disabled>' . icon('check') . 'Sauvegarder</button>';
?>
<div class="main">
    <?php pageHeader('Éditeur de playlists', 'Organisez vos médias', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- Existing playlists overview -->
        <div class="section-title">Playlists existantes</div>
        <div id="playlist-container" class="grid grid-3" style="margin-top:14px">
            <!-- Playlists will be loaded here dynamically -->
        </div>

        <!-- Playlist editor interface -->
        <div id="playlist-editor" class="playlist-editor-container">
            <!-- Media library panel (left) -->
            <div class="playlist-panel media-library-panel">
                <div class="panel-header">
                    <h3><?= icon('folder') ?>Bibliothèque média</h3>
                    <div class="panel-controls">
                        <button class="btn-icon" type="button" onclick="refreshMediaLibrary()" title="Actualiser">
                            <?= icon('refresh') ?>
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

            <!-- Playlist workspace panel (center) -->
            <div class="playlist-panel workspace-panel">
                <div class="panel-header">
                    <h3><?= icon('playlist') ?>Espace de travail</h3>
                    <div class="playlist-info">
                        <span id="playlist-name-display">Nouvelle playlist</span>
                        <span class="playlist-stats">
                            <span id="item-count">0 élément</span> ·
                            <span id="total-duration">00:00</span>
                        </span>
                    </div>
                </div>
                <div class="panel-content">
                    <div class="playlist-workspace" id="playlist-workspace">
                        <div class="drop-zone" id="playlist-drop-zone">
                            <div class="drop-zone-content">
                                <div class="drop-zone-icon"><?= icon('upload') ?></div>
                                <p>Glissez des médias ici pour créer votre playlist</p>
                                <p class="drop-zone-hint">Ou cliquez sur « + » dans la bibliothèque</p>
                            </div>
                        </div>
                        <div class="playlist-items" id="playlist-items">
                            <!-- Playlist items will be added here -->
                        </div>
                    </div>
                </div>
            </div>

            <!-- Properties panel (right) -->
            <div class="playlist-panel properties-panel">
                <div class="panel-header">
                    <h3><?= icon('settings') ?>Propriétés</h3>
                </div>
                <div class="panel-content">
                    <div class="properties-section">
                        <h4>Playlist</h4>
                        <div class="form-group">
                            <label>Nom</label>
                            <input type="text" id="playlist-name-input" class="form-control" placeholder="Nom de la playlist" oninput="updatePlaylistName()">
                        </div>
                        <div class="form-group">
                            <label class="checkbox-label">
                                <input type="checkbox" id="playlist-loop" onchange="updatePlaylistSettings()">
                                Lecture en boucle
                            </label>
                        </div>
                        <div class="form-group">
                            <label class="checkbox-label">
                                <input type="checkbox" id="playlist-shuffle" onchange="updatePlaylistSettings()">
                                Lecture aléatoire
                            </label>
                        </div>
                        <div class="form-group">
                            <label class="checkbox-label">
                                <input type="checkbox" id="playlist-auto-advance" checked onchange="updatePlaylistSettings()">
                                Avancement automatique
                            </label>
                        </div>
                    </div>

                    <div class="properties-section" id="item-properties" style="display: none;">
                        <h4>Élément sélectionné</h4>
                        <div class="form-group">
                            <label>Fichier</label>
                            <span id="selected-file-name">—</span>
                        </div>
                        <div class="form-group">
                            <label>Durée (secondes)</label>
                            <input type="number" id="item-duration" class="form-control" min="1" max="3600" value="10" onchange="updateItemDuration()">
                        </div>
                        <div class="form-group">
                            <label>Transition</label>
                            <select id="item-transition" class="form-control" onchange="updateItemTransition()">
                                <option value="none">Aucune</option>
                                <option value="fade">Fondu</option>
                                <option value="slide-left">Glissement gauche</option>
                                <option value="slide-right">Glissement droite</option>
                                <option value="zoom">Zoom</option>
                                <option value="dissolve">Dissolution</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Durée transition (ms)</label>
                            <input type="number" id="transition-duration" class="form-control" min="0" max="5000" value="1000" onchange="updateTransitionDuration()">
                        </div>
                    </div>

                    <div class="properties-section">
                        <h4>Actions</h4>
                        <button class="btn btn-primary btn-block" onclick="previewPlaylist()" id="preview-btn" disabled>
                            <?= icon('play') ?>Aperçu
                        </button>
                        <button class="btn btn-secondary btn-block" style="margin-top:10px" onclick="clearPlaylist()">
                            <?= icon('trash') ?>Vider
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Loading existing playlists modal -->
        <div id="load-playlist-modal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Charger une playlist</h3>
                    <button class="btn-close" type="button" onclick="PiSignage.ui.closeModal('load-playlist-modal')"><?= icon('close') ?></button>
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
</div>
<?php include 'includes/footer.php'; ?>
