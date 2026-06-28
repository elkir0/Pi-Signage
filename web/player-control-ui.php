<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Lecteur';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = statusPill()
    . '<button class="icon-btn" id="btn-refresh" type="button" title="Actualiser" onclick="PiSignage.player.refreshPlayerStatus()">' . icon('refresh') . '</button>';
?>
<div class="main">
    <?php pageHeader('Lecteur', "Contrôle du lecteur affiché à l'écran", $actions); ?>

    <div class="content">
      <div class="content-inner">

        <div class="cols-main">

          <!-- LECTURE EN COURS + TRANSPORT -->
          <div class="card">
            <div class="card-head">
              <h2 class="card-title"><?= icon('play-line') ?>Lecture en cours</h2>
              <span class="badge" id="player-mode-badge">Écran</span>
            </div>
            <div class="np">
              <div class="np-thumb"><span class="np-badge" id="np-badge" style="display:none">Live</span><?= icon('monitor') ?></div>
              <div class="np-info">
                <div class="np-title" id="current-file">Aucune lecture</div>
                <div class="np-sub" id="np-sub">&mdash;</div>
              </div>
            </div>
            <div class="transport">
              <button class="t-btn" type="button" title="Précédent" onclick="PiSignage.player.control('previous')"><?= icon('prev') ?></button>
              <button class="t-btn play" id="play-pause-btn" data-action="play" type="button" title="Lecture / Pause" onclick="PiSignage.player.togglePlayPause()"><span id="play-pause-ico"><?= icon('play') ?></span></button>
              <button class="t-btn" type="button" title="Suivant" onclick="PiSignage.player.control('next')"><?= icon('next') ?></button>
              <button class="t-btn" type="button" title="Recharger le contenu" onclick="PiSignage.player.control('reload')"><?= icon('refresh') ?></button>
            </div>
          </div>

          <!-- STATUT DÉTAILLÉ -->
          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('activity') ?>Statut détaillé</h2></div>
            <table class="table">
              <tbody>
                <tr><td>État</td><td style="text-align:right"><span class="badge" id="player-state">&mdash;</span></td></tr>
                <tr><td>Média courant</td><td style="text-align:right;max-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" id="status-file">&mdash;</td></tr>
                <tr><td>Position</td><td style="text-align:right" id="status-position">&mdash;</td></tr>
                <tr><td>Playlist active</td><td style="text-align:right" id="status-active">&mdash;</td></tr>
                <tr><td>Connexion</td><td style="text-align:right"><span class="badge" id="status-online">&mdash;</span></td></tr>
              </tbody>
            </table>
          </div>

        </div>

        <!-- VOLUME SYSTÈME (ALSA) -->
        <div class="grid grid-2" style="margin-top:18px">

          <div class="card">
            <div class="card-head">
              <h2 class="card-title"><?= icon('volume') ?>Volume système</h2>
              <span class="badge" id="system-volume-display">--%</span>
            </div>
            <div class="form-group" style="margin-bottom:10px">
              <input type="range" min="0" max="100" value="100" id="system-volume-slider" aria-label="Volume système">
            </div>
            <button class="btn btn-secondary btn-sm" id="system-mute-btn" type="button" onclick="PiSignage.player.toggleSystemMute()">
              <span id="system-mute-ico"><?= icon('volume') ?></span><span id="system-mute-text">Couper</span>
            </button>
            <p style="margin:12px 0 0;color:var(--text-faint);font-size:12.5px">
              Le lecteur Chromium utilise l'audio système : ce réglage agit sur le son réellement diffusé.
            </p>
          </div>

          <!-- JOURNAL -->
          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('logs') ?>Journal</h2></div>
            <div id="status-log" style="max-height:200px;overflow-y:auto;font-size:12.5px;display:flex;flex-direction:column;gap:4px">
              <div style="color:var(--text-faint)">En attente d'événements&hellip;</div>
            </div>
          </div>

        </div>

        <!-- LECTURE D'UN MÉDIA / PLAYLIST -->
        <div class="grid grid-2" style="margin-top:18px">

          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('media') ?>Lire un média</h2></div>
            <div class="form-group">
              <label for="media-select">Fichier</label>
              <select class="form-control" id="media-select">
                <option value="">-- Sélectionner un fichier --</option>
              </select>
            </div>
            <button class="btn btn-primary btn-block" type="button" onclick="PiSignage.player.playMediaFile()"><?= icon('play') ?>Lire le fichier</button>
          </div>

          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('playlist') ?>Diffuser une playlist</h2></div>
            <div class="form-group">
              <label for="playlist-select">Playlist</label>
              <select class="form-control" id="playlist-select">
                <option value="">-- Sélectionner une playlist --</option>
              </select>
            </div>
            <button class="btn btn-primary btn-block" type="button" onclick="PiSignage.player.playPlaylist()"><?= icon('play') ?>Diffuser à l'écran</button>
          </div>

        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
