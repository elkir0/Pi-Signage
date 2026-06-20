<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Médias';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = '<button class="btn btn-primary" type="button" onclick="PiSignage.media.openUpload()">'
    . icon('upload') . 'Téléverser</button>';
?>
<div class="main">
    <?php pageHeader('Médias', 'Bibliothèque de fichiers', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- TOOLBAR: recherche + filtres -->
        <div class="card" style="margin-bottom:18px">
            <div class="row" style="justify-content:space-between">
                <div class="row" style="flex:1;min-width:220px">
                    <span style="display:inline-flex;color:var(--text-faint)"><?= icon('search') ?></span>
                    <input type="search" id="media-search" class="search-input" placeholder="Rechercher un média…" autocomplete="off">
                </div>
                <div class="row" id="media-filters" style="gap:6px">
                    <button type="button" class="filter-btn active" data-filter="all">Tous</button>
                    <button type="button" class="filter-btn" data-filter="video">Vidéos</button>
                    <button type="button" class="filter-btn" data-filter="image">Images</button>
                    <button type="button" class="filter-btn" data-filter="audio">Audio</button>
                </div>
            </div>
        </div>

        <!-- GRILLE DES MÉDIAS -->
        <div id="media-grid" class="media-grid" aria-live="polite">
            <div class="empty-state">
                <span class="spinner"></span>
                <p style="margin-top:14px">Chargement des médias…</p>
            </div>
        </div>

      </div>
    </div>
</div>

<!-- MODALE DE TÉLÉVERSEMENT -->
<div class="modal" id="upload-modal">
    <div class="modal-content">
        <div class="modal-header">
            <h3><?= icon('upload') ?> Téléverser des médias</h3>
            <button class="btn-close" type="button" onclick="PiSignage.ui.closeModal('upload-modal')"><?= icon('close') ?></button>
        </div>
        <div class="modal-body">
            <div class="upload-zone" id="upload-zone">
                <?= icon('upload') ?>
                <h3 style="margin:12px 0 6px">Glissez-déposez vos fichiers</h3>
                <p>ou cliquez pour parcourir</p>
                <p style="font-size:12px;margin-top:8px;color:var(--text-faint)">Vidéo, image ou audio · 500 Mo max par fichier</p>
                <input type="file" id="upload-input" multiple accept="video/*,image/*,audio/*" hidden>
            </div>
            <div id="upload-progress" style="display:none;margin-top:18px">
                <div class="row" style="justify-content:space-between;margin-bottom:4px">
                    <span id="upload-progress-label" style="font-size:13px;color:var(--text-dim)">Téléversement…</span>
                    <span id="upload-progress-pct" style="font-size:13px;font-weight:600;color:var(--accent-text)">0%</span>
                </div>
                <div class="progress-bar"><div class="progress-fill" id="upload-progress-fill" style="width:0%"></div></div>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-ghost" type="button" onclick="PiSignage.ui.closeModal('upload-modal')">Fermer</button>
            <button class="btn btn-primary" type="button" id="upload-browse-btn" onclick="document.getElementById('upload-input').click()"><?= icon('folder') ?>Parcourir</button>
        </div>
    </div>
</div>

<?php include 'includes/footer.php'; ?>
