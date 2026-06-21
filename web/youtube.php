<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Téléchargement YouTube';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';
?>
<div class="main">
    <?php pageHeader('Téléchargement YouTube', 'Importer une vidéo via yt-dlp'); ?>

    <div class="content">
      <div class="content-inner">

        <div class="cols-main">

          <!-- LEFT: download + live progress -->
          <div class="stack">
            <div class="card">
              <div class="card-head"><h2 class="card-title"><?= icon('youtube') ?>Télécharger une vidéo</h2></div>

              <div class="form-group">
                <label for="yt-url">URL YouTube</label>
                <input type="url" class="form-control" id="yt-url"
                       placeholder="https://www.youtube.com/watch?v=..." autocomplete="off">
              </div>

              <div class="form-row">
                <div class="form-group">
                  <label for="yt-quality">Qualité</label>
                  <select class="form-control" id="yt-quality">
                    <option value="best">Meilleure qualité</option>
                    <option value="1080p">1080p</option>
                    <option value="720p">720p</option>
                    <option value="480p">480p</option>
                    <option value="360p">360p</option>
                  </select>
                </div>
                <div class="form-group">
                  <label>Format</label>
                  <label class="checkbox-label" style="margin-top:4px">
                    <input type="checkbox" id="yt-audio"> Audio seulement (MP3)
                  </label>
                </div>
              </div>

              <button class="btn btn-primary btn-block" type="button" id="yt-download-btn">
                <?= icon('download') ?>Télécharger
              </button>
            </div>

            <!-- Live progress (hidden until a download starts) -->
            <div class="card hidden" id="yt-progress-card">
              <div class="card-head"><h2 class="card-title"><?= icon('download') ?>Téléchargement en cours</h2></div>

              <div class="row" style="justify-content:space-between;gap:12px">
                <div id="yt-progress-title" class="mono" style="min-width:0;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:13px">—</div>
                <div id="yt-progress-pct" style="font-weight:800;font-variant-numeric:tabular-nums">0%</div>
              </div>

              <div class="progress-bar" id="yt-progress-bar" style="margin:10px 0 6px">
                <div class="progress-fill" id="yt-progress-fill" style="width:0%"></div>
              </div>
              <div id="yt-progress-meta" class="text-faint" style="font-size:12.5px">—</div>

              <div style="margin-top:14px">
                <button class="btn btn-secondary btn-sm" type="button" id="yt-details-toggle">
                  <?= icon('logs') ?><span class="btn-label">Détails</span>
                </button>
              </div>
              <div class="log-viewer hidden" id="yt-log-panel" style="margin-top:12px;max-height:240px"></div>
            </div>
          </div>

          <!-- RIGHT: yt-dlp status + history -->
          <div class="stack">
            <div class="card">
              <div class="card-head"><h2 class="card-title"><?= icon('refresh') ?>Moteur yt-dlp</h2></div>
              <div id="yt-version-info" style="min-height:26px"><span class="spinner"></span></div>
              <button class="btn btn-secondary btn-block" type="button" id="yt-update-btn" style="margin-top:14px">
                <?= icon('download') ?><span class="btn-label">Vérifier les mises à jour</span>
              </button>
              <p class="text-faint" style="font-size:12px;margin-top:10px">
                yt-dlp est mis à jour fréquemment par ses auteurs pour suivre les changements de YouTube.
                Garder ce composant à jour évite les échecs de téléchargement.
              </p>
            </div>

            <div class="card">
              <div class="card-head">
                <h2 class="card-title"><?= icon('list') ?>Historique</h2>
                <button class="icon-btn" type="button" id="yt-history-refresh" title="Actualiser"><?= icon('refresh') ?></button>
              </div>
              <div id="yt-history"><div class="empty-state" style="padding:24px"><span class="spinner"></span><p>Chargement…</p></div></div>
            </div>
          </div>

        </div>

      </div>
    </div>
</div>

<style>
  #yt-progress-bar.is-error .progress-fill { background: var(--danger); }
  #yt-progress-bar.is-done  .progress-fill { background: linear-gradient(90deg, var(--accent-bright), var(--accent)); }
</style>
<script src="assets/js/youtube.js?v=<?= ASSET_VERSION ?>" defer></script>

<?php include 'includes/footer.php'; ?>
