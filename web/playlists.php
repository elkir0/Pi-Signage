<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Playlists';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

// Le bouton "Nouvelle playlist" est masqué quand l'éditeur est ouvert (géré côté JS).
$actions =
      '<span class="status-pill" id="pl-active-pill" style="display:none">'
    .   '<span class="live-dot"></span><span class="pill-text" id="pl-active-pill-text">À l\'écran</span>'
    . '</span>'
    . '<button class="btn btn-primary btn-sm" type="button" id="pl-new-btn" onclick="PiSignage.playlists.newPlaylist()">'
    .   icon('plus') . 'Nouvelle playlist</button>';
?>
<div class="main">
    <?php pageHeader('Playlists', 'Composez et diffusez vos playlists', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- ============================ VUE LISTE ============================ -->
        <div id="pl-list-view">

            <!-- Bannière : playlist actuellement diffusée -->
            <div class="card" id="pl-active-banner" style="display:none;margin-bottom:18px">
                <div class="row" style="justify-content:space-between">
                    <div class="row" style="gap:12px;min-width:0">
                        <span class="status-pill is-playing"><span class="live-dot"></span>À l'écran</span>
                        <div style="min-width:0">
                            <div class="pl-banner-name" id="pl-active-name" style="font-weight:700;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis"></div>
                            <div style="font-size:12px;color:var(--text-faint)" id="pl-active-meta"></div>
                        </div>
                    </div>
                    <button class="btn btn-secondary btn-sm" type="button" id="pl-active-edit-btn">
                        <?= icon('edit') ?>Modifier
                    </button>
                </div>
            </div>

            <div class="section-title">Vos playlists</div>
            <div id="pl-cards" class="grid grid-3" style="margin-top:14px" aria-live="polite">
                <div class="empty-state" style="grid-column:1/-1">
                    <span class="spinner"></span>
                    <p style="margin-top:14px">Chargement des playlists…</p>
                </div>
            </div>
        </div>

        <!-- ============================ VUE ÉDITEUR ============================ -->
        <div id="pl-editor-view" style="display:none">

            <!-- Barre d'actions de l'éditeur -->
            <div class="card" style="margin-bottom:18px">
                <div class="row" style="justify-content:space-between;gap:14px">
                    <div class="row" style="gap:10px;flex:1;min-width:240px">
                        <button class="icon-btn" type="button" title="Retour à la liste" onclick="PiSignage.playlists.showList()">
                            <?= icon('chevron') ?>
                        </button>
                        <div class="form-group" style="margin:0;flex:1;min-width:180px">
                            <input type="text" id="pl-name" class="form-control" placeholder="Nom de la playlist" autocomplete="off">
                        </div>
                    </div>
                    <div class="row" style="gap:10px;flex-wrap:wrap">
                        <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.playlists.save(false)">
                            <?= icon('check') ?>Enregistrer
                        </button>
                        <button class="btn btn-primary btn-sm" type="button" onclick="PiSignage.playlists.save(true)">
                            <?= icon('play-line') ?>Enregistrer &amp; Diffuser
                        </button>
                    </div>
                </div>
            </div>

            <div class="playlist-editor-container">

                <!-- Bibliothèque média (gauche) -->
                <div class="playlist-panel media-library-panel">
                    <div class="panel-header">
                        <h3><?= icon('folder') ?>Bibliothèque média</h3>
                        <div class="panel-controls">
                            <input type="text" class="search-input" placeholder="Rechercher…" id="pl-media-search" autocomplete="off">
                            <button class="icon-btn" type="button" title="Actualiser" onclick="PiSignage.playlists.loadMedia()">
                                <?= icon('refresh') ?>
                            </button>
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="media-filters" id="pl-media-filters">
                            <button class="filter-btn active" type="button" data-type="all">Tous</button>
                            <button class="filter-btn" type="button" data-type="video">Vidéos</button>
                            <button class="filter-btn" type="button" data-type="image">Images</button>
                            <button class="filter-btn" type="button" data-type="audio">Audio</button>
                        </div>
                        <div class="media-library-list" id="pl-media-list">
                            <div class="empty-state"><span class="spinner"></span></div>
                        </div>
                    </div>
                </div>

                <!-- Contenu de la playlist (centre) -->
                <div class="playlist-panel workspace-panel">
                    <div class="panel-header">
                        <h3><?= icon('playlist') ?>Contenu de la playlist</h3>
                        <div class="panel-controls" style="color:var(--text-faint);font-size:12px">
                            <span id="pl-item-count">0 élément</span>
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="playlist-workspace">
                            <div class="drop-zone" id="pl-drop-zone">
                                <div class="drop-zone-content">
                                    <div class="drop-zone-icon"><?= icon('plus') ?></div>
                                    <p>Glissez des médias ici, ou cliquez sur « + » dans la bibliothèque.</p>
                                    <p class="drop-zone-hint">Les éléments se liront dans l'ordre affiché.</p>
                                </div>
                            </div>
                            <div class="playlist-items" id="pl-items"></div>
                        </div>
                    </div>
                </div>

                <!-- Options de la playlist (droite) -->
                <div class="playlist-panel properties-panel">
                    <div class="panel-header">
                        <h3><?= icon('settings') ?>Options de lecture</h3>
                    </div>
                    <div class="panel-content">
                        <div class="form-group">
                            <label class="row" style="justify-content:space-between;gap:12px;margin:0;cursor:pointer">
                                <span>Lecture automatique</span>
                                <span class="toggle-switch"><input type="checkbox" id="pl-autoplay" checked><span class="toggle-slider"></span></span>
                            </label>
                            <p style="font-size:11.5px;color:var(--text-faint);margin-top:6px">Démarre la lecture dès la mise à l'écran.</p>
                        </div>
                        <div class="form-group">
                            <label class="row" style="justify-content:space-between;gap:12px;margin:0;cursor:pointer">
                                <span>Lecture en boucle</span>
                                <span class="toggle-switch"><input type="checkbox" id="pl-autoloop" checked><span class="toggle-slider"></span></span>
                            </label>
                            <p style="font-size:11.5px;color:var(--text-faint);margin-top:6px">Reprend au début à la fin de la playlist.</p>
                        </div>

                        <div class="section-title" style="margin-top:8px">Élément sélectionné</div>
                        <div id="pl-item-options" style="margin-top:14px">
                            <div class="empty-state" style="padding:24px 8px">
                                <?= icon('list') ?>
                                <p>Sélectionnez un élément de la playlist pour ajuster ses options.</p>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
