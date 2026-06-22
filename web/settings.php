<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Paramètres';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$mustChange = !empty($_SESSION['must_change_password']);
?>
<div class="main">
    <?php pageHeader('Paramètres', 'Configuration du système et du lecteur', statusPill()); ?>

    <div class="content">
      <div class="content-inner">

        <?php if ($mustChange): ?>
        <div class="card" id="must-change-banner" style="border-color:var(--warn);background:var(--warn-soft)">
            <div class="card-head" style="margin-bottom:6px">
                <h2 class="card-title" style="color:var(--warn-text)"><?= icon('alert') ?>Mot de passe par défaut détecté</h2>
            </div>
            <p style="color:var(--text-dim);margin:0">
                Vous utilisez encore le mot de passe par défaut. Pour sécuriser l'accès,
                définissez un nouveau mot de passe dans la carte <strong>Sécurité</strong> ci-dessous.
            </p>
        </div>
        <?php endif; ?>

        <div class="grid grid-2">

            <!-- AUDIO -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('volume') ?>Sortie audio</h2>
                </div>
                <div class="form-group">
                    <label for="audio-output">Périphérique de sortie</label>
                    <select class="form-control" id="audio-output">
                        <option value="hdmi">HDMI</option>
                        <option value="jack">Jack 3.5 mm</option>
                    </select>
                </div>
                <button class="btn btn-primary" type="button" onclick="PiSignage.settings.saveAudio()">
                    <?= icon('check') ?>Appliquer
                </button>
            </div>

            <!-- SECURITE / MOT DE PASSE -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('lock') ?>Sécurité</h2>
                </div>
                <form id="password-form" autocomplete="off" onsubmit="return false;">
                    <div class="form-group">
                        <label for="old-password">Ancien mot de passe</label>
                        <input type="password" class="form-control" id="old-password"
                               placeholder="Ancien mot de passe" autocomplete="current-password">
                    </div>
                    <div class="form-group">
                        <label for="new-password">Nouveau mot de passe</label>
                        <input type="password" class="form-control" id="new-password"
                               placeholder="Au moins 6 caractères" autocomplete="new-password">
                    </div>
                    <div class="form-group">
                        <label for="confirm-password">Confirmer le mot de passe</label>
                        <input type="password" class="form-control" id="confirm-password"
                               placeholder="Confirmer le nouveau mot de passe" autocomplete="new-password">
                    </div>
                    <button type="button" class="btn btn-primary" onclick="PiSignage.settings.changePassword()">
                        <?= icon('lock') ?>Changer le mot de passe
                    </button>
                </form>
            </div>

            <!-- AFFICHAGE -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('monitor') ?>Affichage</h2>
                </div>
                <div class="form-group">
                    <label for="resolution">Résolution</label>
                    <select class="form-control" id="resolution">
                        <option value="1920x1080">1920 x 1080 (Full HD)</option>
                        <option value="1280x720">1280 x 720 (HD)</option>
                        <option value="1024x768">1024 x 768</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="rotation">Rotation</label>
                    <select class="form-control" id="rotation">
                        <option value="0">0° (Normal)</option>
                        <option value="90">90° (Droite)</option>
                        <option value="180">180° (Inversé)</option>
                        <option value="270">270° (Gauche)</option>
                    </select>
                </div>
                <button class="btn btn-primary" type="button" onclick="saveDisplayConfig()">
                    <?= icon('check') ?>Appliquer
                </button>
                <p style="color:var(--text-faint);font-size:13px;margin:10px 0 0">
                    Un redémarrage peut être nécessaire pour appliquer ces changements.
                </p>
            </div>

            <!-- RESEAU -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('wifi') ?>Réseau Wi-Fi</h2>
                </div>
                <form id="network-form" autocomplete="off" onsubmit="return false;">
                    <div class="form-group">
                        <label for="wifi-ssid">SSID</label>
                        <input type="text" class="form-control" id="wifi-ssid" placeholder="Nom du réseau">
                    </div>
                    <div class="form-group">
                        <label for="wifi-password">Mot de passe</label>
                        <input type="password" class="form-control" id="wifi-password"
                               placeholder="Mot de passe du réseau" autocomplete="new-password">
                    </div>
                    <button type="button" class="btn btn-primary" onclick="saveNetworkConfig()">
                        <?= icon('check') ?>Appliquer
                    </button>
                </form>
            </div>

        </div>

        <!-- SYSTEME -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('settings') ?>Actions système</h2>
            </div>
            <div class="row" style="gap:12px;flex-wrap:wrap">
                <button class="btn btn-secondary" type="button"
                        onclick="PiSignage.settings.systemAction('restart-player')">
                    <?= icon('refresh') ?>Redémarrer le lecteur
                </button>
                <button class="btn btn-secondary" type="button"
                        onclick="PiSignage.settings.systemAction('clear-cache')">
                    <?= icon('trash') ?>Vider le cache
                </button>
                <button class="btn btn-danger" type="button"
                        onclick="PiSignage.settings.systemAction('reboot')">
                    <?= icon('refresh') ?>Redémarrer
                </button>
                <button class="btn btn-danger" type="button"
                        onclick="PiSignage.settings.systemAction('shutdown')">
                    <?= icon('power') ?>Éteindre
                </button>
            </div>
        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
