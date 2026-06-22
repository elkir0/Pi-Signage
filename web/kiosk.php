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
                    <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Active ou désactive l'affichage Chromium en kiosk au démarrage. Chromium HTML5 est le lecteur unique (VLC retiré).</p>
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

        <!-- Écran (extinction programmée) -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('monitor') ?>Écran (extinction programmée)</h2>
                <span class="badge" id="screen-state-badge"><span class="live-dot"></span>Écran</span>
            </div>
            <div class="form-group">
                <label class="row" style="justify-content:space-between;align-items:center;gap:14px;margin:0">
                    <span>Activer l'extinction programmée</span>
                    <span class="toggle-switch">
                        <input type="checkbox" id="screen-schedule-enabled">
                        <span class="toggle-slider"></span>
                    </span>
                </label>
                <p style="font-size:12.5px;color:var(--text-faint);margin:8px 0 0">Éteint puis rallume l'écran (HDMI) aux heures choisies, les jours sélectionnés.</p>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label for="screen-on-time">Heure d'allumage</label>
                    <input type="time" id="screen-on-time" class="form-control" value="07:00">
                </div>
                <div class="form-group">
                    <label for="screen-off-time">Heure d'extinction</label>
                    <input type="time" id="screen-off-time" class="form-control" value="22:00">
                </div>
            </div>
            <div class="form-group">
                <label>Jours actifs</label>
                <div class="row" id="screen-days" style="gap:8px;flex-wrap:wrap">
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="1" checked><span>Lun</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="2" checked><span>Mar</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="3" checked><span>Mer</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="4" checked><span>Jeu</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="5" checked><span>Ven</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="6" checked><span>Sam</span></label>
                    <label class="row" style="gap:6px;cursor:pointer"><input type="checkbox" class="screen-day" value="0" checked><span>Dim</span></label>
                </div>
            </div>
            <div class="row" style="gap:10px;flex-wrap:wrap">
                <button class="btn btn-primary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.saveScreenSchedule()"><?= icon('check') ?>Enregistrer le planning</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.screenOn()"><?= icon('sun') ?>Allumer maintenant</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.screenOff()"><?= icon('moon') ?>Éteindre maintenant</button>
            </div>
        </div>

        <!-- Composition des playlists -> page dédiée (consolidation : le Kiosk ne règle que l'affichage) -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('playlist') ?>Contenu diffusé</h2>
            </div>
            <p style="color:var(--text-dim);margin:0 0 14px">
                La composition des playlists et la diffusion à l'écran se font désormais
                au même endroit, sur la page <strong>Playlists</strong>. Cette page Kiosk
                ne gère que les réglages d'affichage (mode, URL, flags, écran).
            </p>
            <div class="row" style="gap:10px;flex-wrap:wrap">
                <a class="btn btn-primary" href="playlists.php"><?= icon('playlist') ?>Composer / diffuser des playlists</a>
                <a class="btn btn-secondary" href="player-control-ui.php"><?= icon('play') ?>Contrôler le lecteur</a>
            </div>
        </div>

        <!-- Actions -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('power') ?>Actions</h2>
            </div>
            <div class="row" style="gap:10px;flex-wrap:wrap">
                <button class="btn btn-danger" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.restart()"><?= icon('refresh') ?>Redémarrer Chromium</button>
                <button class="btn btn-danger" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.restartSession()"><?= icon('power') ?>Redémarrer la session</button>
                <button class="btn btn-secondary" type="button" onclick="PiSignage.kiosk && PiSignage.kiosk.previewPlayer()"><?= icon('eye') ?>Prévisualiser le player</button>
            </div>
            <p style="font-size:12.5px;color:var(--text-faint);margin:10px 0 0">« Redémarrer Chromium » relance uniquement le navigateur. « Redémarrer la session » relance toute la session graphique (labwc + Chromium).</p>
        </div>

      </div>
    </div>
</div>

<script src="assets/js/kiosk-control.js?v=<?= ASSET_VERSION ?>" defer></script>

<?php include 'includes/footer.php'; ?>
