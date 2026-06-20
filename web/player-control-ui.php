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
    <?php pageHeader('Lecteur', 'Contrôle de la lecture VLC', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <div class="cols-main">

          <!-- LECTURE EN COURS + TRANSPORT -->
          <div class="card">
            <div class="card-head">
              <h2 class="card-title"><?= icon('play-line') ?>Lecture en cours</h2>
              <span class="badge" id="player-mode-badge">VLC</span>
            </div>
            <div class="np">
              <div class="np-thumb"><span class="np-badge" id="np-badge" style="display:none">Live</span><?= icon('monitor') ?></div>
              <div class="np-info">
                <div class="np-title" id="current-file">Aucune lecture</div>
                <div class="np-sub" id="np-sub">&mdash;</div>
                <div class="np-progress" style="margin-top:6px">
                  <div class="np-track"><i id="progress-bar" style="width:0%"></i></div>
                  <div class="np-time"><span id="current-time">00:00</span><span id="duration">00:00</span></div>
                </div>
              </div>
            </div>
            <div class="transport">
              <button class="t-btn" type="button" title="Précédent" onclick="PiSignage.player.control('previous')"><?= icon('prev') ?></button>
              <button class="t-btn play" id="play-pause-btn" data-action="play" type="button" title="Lecture / Pause" onclick="PiSignage.player.togglePlayPause()"><span id="play-pause-ico"><?= icon('play') ?></span></button>
              <button class="t-btn" type="button" title="Suivant" onclick="PiSignage.player.control('next')"><?= icon('next') ?></button>
              <button class="t-btn" type="button" title="Stop" onclick="PiSignage.player.control('stop')"><?= icon('stop') ?></button>
            </div>
          </div>

          <!-- STATUT DÉTAILLÉ -->
          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('activity') ?>Statut détaillé</h2></div>
            <table class="table">
              <tbody>
                <tr><td>État</td><td style="text-align:right"><span class="badge" id="player-state">&mdash;</span></td></tr>
                <tr><td>Fichier</td><td style="text-align:right;max-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" id="status-file">&mdash;</td></tr>
                <tr><td>Position</td><td style="text-align:right" id="status-position">00:00 / 00:00</td></tr>
                <tr><td>Volume VLC</td><td style="text-align:right" id="status-vlc-vol">&mdash;</td></tr>
                <tr><td>File d'attente</td><td style="text-align:right" id="status-queue">&mdash;</td></tr>
              </tbody>
            </table>
          </div>

        </div>

        <!-- VOLUMES -->
        <div class="grid grid-2" style="margin-top:18px">

          <!-- VLC -->
          <div class="card">
            <div class="card-head">
              <h2 class="card-title"><?= icon('volume') ?>Volume lecteur (VLC)</h2>
              <span class="badge" id="vlc-volume-display">--%</span>
            </div>
            <div class="form-group" style="margin-bottom:10px">
              <input type="range" min="0" max="100" value="50" id="vlc-volume-slider" aria-label="Volume VLC">
            </div>
            <button class="btn btn-secondary btn-sm" id="vlc-mute-btn" type="button" onclick="PiSignage.player.toggleVlcMute()">
              <span id="vlc-mute-ico"><?= icon('volume') ?></span><span id="vlc-mute-text">Couper</span>
            </button>
          </div>

          <!-- ALSA -->
          <div class="card">
            <div class="card-head">
              <h2 class="card-title"><?= icon('volume') ?>Volume système (ALSA)</h2>
              <span class="badge" id="system-volume-display">--%</span>
            </div>
            <div class="form-group" style="margin-bottom:10px">
              <input type="range" min="0" max="100" value="100" id="system-volume-slider" aria-label="Volume système">
            </div>
            <button class="btn btn-secondary btn-sm" id="system-mute-btn" type="button" onclick="PiSignage.player.toggleSystemMute()">
              <span id="system-mute-ico"><?= icon('volume') ?></span><span id="system-mute-text">Couper</span>
            </button>
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
            <div class="card-head"><h2 class="card-title"><?= icon('playlist') ?>Lire une playlist</h2></div>
            <div class="form-group">
              <label for="playlist-select">Playlist</label>
              <select class="form-control" id="playlist-select">
                <option value="">-- Sélectionner une playlist --</option>
              </select>
            </div>
            <button class="btn btn-primary btn-block" type="button" onclick="PiSignage.player.playPlaylist()"><?= icon('play') ?>Lancer la playlist</button>
          </div>

        </div>

        <!-- ACTIONS + JOURNAL -->
        <div class="grid grid-2" style="margin-top:18px">

          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('settings') ?>Actions rapides</h2></div>
            <button class="btn btn-secondary btn-block" type="button" onclick="PiSignage.player.toggleFullscreen()"><?= icon('monitor') ?>Basculer plein écran</button>
            <button class="btn btn-danger btn-block" style="margin-top:10px" type="button" onclick="PiSignage.player.clearPlaylist()"><?= icon('trash') ?>Vider la file d'attente</button>
          </div>

          <div class="card">
            <div class="card-head"><h2 class="card-title"><?= icon('logs') ?>Journal</h2></div>
            <div id="status-log" style="max-height:160px;overflow-y:auto;font-size:12.5px;display:flex;flex-direction:column;gap:4px">
              <div style="color:var(--text-faint)">En attente d'événements&hellip;</div>
            </div>
          </div>

        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
