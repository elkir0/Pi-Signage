<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Kiosk';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = '<span class="status-pill" id="kiosk-pill"><span class="live-dot"></span><span class="pill-text">Chromium</span></span>'
    . '<button class="icon-btn" id="btn-refresh-kiosk" type="button" title="Actualiser" onclick="PiSignage.kiosk && PiSignage.kiosk.refreshStatus()">' . icon('refresh') . '</button>';
?>
<div class="main">
    <?php pageHeader('Kiosk', 'Mode Chromium · Trixie / Wayland', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <div class="grid grid-2">

            <!-- Mode Kiosk -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('settings') ?>Mode Kiosk</h2>
                </div>
                <div class="form-group">
                    <label class="row" style="justify-content:space-between;align-items:center;gap:14px;margin:0">
                        <span>Activer le mode Kiosk</span>
                        <span class="toggle-switch">
                            <input type="checkbox" id="enable-kiosk">
                            <span class="toggle-slider"></span>
                        </span>
                    </label>
                    <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Active ou désactive l'affichage Chromium en kiosk au démarrage.</p>
                </div>
                <div class="form-group" style="margin-bottom:0">
                    <label class="row" style="justify-content:space-between;align-items:center;gap:14px;margin:0">
                        <span>Utiliser Chromium Player (HTML5)</span>
                        <span class="toggle-switch">
                            <input type="checkbox" id="use-chromium-player">
                            <span class="toggle-slider"></span>
                        </span>
                    </label>
                    <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Activé : Chromium joue la playlist en HTML5. Désactivé : repli VLC (lecture classique).</p>
                </div>
            </div>

            <!-- Statut Kiosk -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('activity') ?>Statut Kiosk</h2>
                    <span class="badge" id="status-indicator"><span class="live-dot"></span>Auto</span>
                </div>
                <div id="kiosk-status">
                    <div class="empty-state" style="padding:24px"><span class="spinner"></span><p>Chargement du statut…</p></div>
                </div>
            </div>

        </div>

        <!-- URL Kiosk -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('link') ?>URL Kiosk (mode dashboard)</h2>
            </div>
            <div class="form-group">
                <label for="kiosk-url">URL à afficher dans Chromium</label>
                <input type="url" id="kiosk-url" class="form-control" placeholder="https://dashboard.local">
                <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Player HTML5 : <code>http://127.0.0.1/player</code> · Dashboard : <code>https://grafana.local</code>, etc.</p>
            </div>
            <button class="btn btn-primary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.updateUrl()"><?= icon('check') ?>Appliquer</button>
        </div>

        <!-- Flags Chromium -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('settings') ?>Flags Chromium</h2>
            </div>
            <div class="form-group">
                <label for="chromium-flags">Arguments Chromium (un par ligne)</label>
                <textarea id="chromium-flags" class="form-control" rows="9" style="font-family:var(--font-mono);font-size:13px" placeholder="--ozone-platform=wayland&#10;--enable-features=UseOzonePlatform&#10;--autoplay-policy=no-user-gesture-required"></textarea>
                <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Flags Wayland et accélération matérielle déjà inclus par défaut. Éditer avec précaution.</p>
            </div>
            <div class="row" style="gap:10px">
                <button class="btn btn-primary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.updateFlags()"><?= icon('check') ?>Appliquer</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.resetFlags()"><?= icon('refresh') ?>Valeurs par défaut</button>
            </div>
        </div>

        <!-- Playlist Chromium Player -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('playlist') ?>Playlist Chromium Player</h2>
                <div class="row" style="gap:8px;flex-wrap:wrap">
                    <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.addItem()"><?= icon('plus') ?>Ajouter</button>
                    <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.openUpload()"><?= icon('upload') ?>Téléverser</button>
                    <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.validate()"><?= icon('check-circle') ?>Valider</button>
                    <button class="btn btn-primary btn-sm" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.save()"><?= icon('check') ?>Sauvegarder</button>
                </div>
            </div>

            <div id="playlist-items" class="playlist-items">
                <div class="empty-state" style="padding:24px"><span class="spinner"></span><p>Chargement de la playlist…</p></div>
            </div>

            <div class="card" style="background:var(--surface-2);margin-top:16px">
                <div class="section-title" style="margin:0 0 10px">Paramètres globaux</div>
                <label class="row" style="gap:10px;margin-bottom:8px;cursor:pointer">
                    <input type="checkbox" id="playlist-autoplay" checked>
                    <span>Lecture automatique au démarrage</span>
                </label>
                <label class="row" style="gap:10px;cursor:pointer">
                    <input type="checkbox" id="playlist-autoloop" checked>
                    <span>Boucler la playlist automatiquement</span>
                </label>
            </div>
        </div>

        <!-- Actions -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('power') ?>Actions</h2>
            </div>
            <div class="row" style="gap:10px;flex-wrap:wrap">
                <button class="btn btn-danger" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.restart()"><?= icon('refresh') ?>Redémarrer Chromium</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.refreshPlaylist()"><?= icon('refresh') ?>Recharger la playlist</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.previewPlayer()"><?= icon('eye') ?>Prévisualiser le player</button>
            </div>
        </div>

      </div>
    </div>
</div>

<!-- Modale : ajouter / modifier un média -->
<div id="playlist-item-modal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <h3 id="modal-title">Ajouter un média</h3>
            <button class="btn-close" type="button" onclick="PiSignage.ui.closeModal('playlist-item-modal')"><?= icon('close') ?></button>
        </div>
        <div class="modal-body">
            <div class="form-group">
                <label for="item-url">URL du média</label>
                <input type="text" id="item-url" class="form-control" placeholder="file:///opt/pisignage/media/video.mp4">
                <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0"><code>file://</code> pour local, <code>http(s)://</code> pour distant.</p>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label for="item-fit">Ajustement (object-fit)</label>
                    <select id="item-fit" class="form-control">
                        <option value="contain">Contain (conserver les proportions)</option>
                        <option value="cover">Cover (remplir l'écran)</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="item-duration">Durée (secondes, 0 = auto)</label>
                    <input type="number" id="item-duration" class="form-control" value="0" min="0">
                </div>
            </div>
            <div class="form-group" style="margin-bottom:0">
                <label class="row" style="gap:10px;margin-bottom:8px;cursor:pointer">
                    <input type="checkbox" id="item-mute">
                    <span>Muet</span>
                </label>
                <label class="row" style="gap:10px;margin:0;cursor:pointer">
                    <input type="checkbox" id="item-loop">
                    <span>Boucler cet élément</span>
                </label>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-secondary" type="button" onclick="PiSignage.ui.closeModal('playlist-item-modal')">Annuler</button>
            <button class="btn btn-primary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.saveItem()">Enregistrer</button>
        </div>
    </div>
</div>

<!-- Modale : téléverser un média -->
<div id="upload-modal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <h3>Téléverser un média</h3>
            <button class="btn-close" type="button" onclick="PiSignage.ui.closeModal('upload-modal')"><?= icon('close') ?></button>
        </div>
        <div class="modal-body">
            <div class="upload-zone" id="upload-area">
                <input type="file" id="file-input" accept="video/*" style="display:none">
                <div class="upload-prompt">
                    <?= icon('upload') ?>
                    <p>Cliquez ou glissez un fichier vidéo</p>
                    <p style="font-size:12.5px;color:var(--text-faint);margin:4px 0 0">MP4, WebM, MKV, etc. (max 500 Mo)</p>
                </div>
            </div>
            <div id="upload-progress" style="display:none;margin-top:14px">
                <div class="mini-bar"><i id="progress-fill" style="width:0%"></i></div>
                <p id="upload-status" style="font-size:13px;color:var(--text-dim);margin:8px 0 0">Téléversement en cours…</p>
            </div>
        </div>
    </div>
</div>

<script src="assets/js/kiosk-control.js?v=<?= ASSET_VERSION ?>" defer></script>

<?php include 'includes/footer.php'; ?>
