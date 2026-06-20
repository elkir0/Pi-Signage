<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Tableau de bord';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = statusPill()
    . '<button class="icon-btn" id="btn-refresh" type="button" title="Actualiser" onclick="PiSignage.dashboard.refreshAll()">' . icon('refresh') . '</button>';
?>
<div class="main">
    <?php pageHeader('Tableau de bord', 'Vue d\'ensemble · ' . htmlspecialchars(gethostname() ?: 'pisignage'), $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- STAT CARDS -->
        <div class="grid grid-4">
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico"><?= icon('media') ?></div></div>
                <div><div class="stat-val" id="stat-media">--</div><div class="stat-label">Médias</div></div>
            </div>
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico violet"><?= icon('playlist') ?></div></div>
                <div><div class="stat-val" id="stat-playlists">--</div><div class="stat-label">Playlists</div></div>
            </div>
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico blue"><?= icon('storage') ?></div></div>
                <div>
                    <div class="stat-val" id="stat-storage">--</div>
                    <div class="stat-label">Stockage</div>
                    <div class="mini-bar"><i id="stat-storage-bar" style="width:0%"></i></div>
                </div>
            </div>
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico amber"><?= icon('monitor') ?></div></div>
                <div><div class="stat-val" id="stat-uptime" style="font-size:18px">--</div><div class="stat-label">Disponibilité</div></div>
            </div>
        </div>

        <!-- NOW PLAYING + SYSTEM -->
        <div class="cols-main" style="margin-top:18px">
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('play-line') ?>Lecture en cours</h2>
                    <a class="card-link" href="player-control-ui.php">Ouvrir le lecteur →</a>
                </div>
                <div class="np">
                    <div class="np-thumb"><span class="np-badge" id="np-badge" style="display:none">Live</span><?= icon('monitor') ?></div>
                    <div class="np-info">
                        <div class="np-title" id="np-title">Aucune lecture</div>
                        <div class="np-sub" id="np-sub">—</div>
                        <div class="np-progress" style="margin-top:6px">
                            <div class="np-track"><i id="np-fill" style="width:0%"></i></div>
                            <div class="np-time"><span id="np-cur">00:00</span><span id="np-dur">00:00</span></div>
                        </div>
                    </div>
                </div>
                <div class="transport">
                    <button class="t-btn" type="button" title="Précédent" onclick="PiSignage.dashboard.control('previous')"><?= icon('prev') ?></button>
                    <button class="t-btn play" type="button" title="Lecture/Pause" onclick="PiSignage.dashboard.control('play')"><?= icon('play') ?></button>
                    <button class="t-btn" type="button" title="Suivant" onclick="PiSignage.dashboard.control('next')"><?= icon('next') ?></button>
                    <button class="t-btn" type="button" title="Stop" onclick="PiSignage.dashboard.control('stop')"><?= icon('stop') ?></button>
                </div>
            </div>

            <div class="card">
                <div class="card-head"><h2 class="card-title"><?= icon('cpu') ?>Ressources système</h2></div>
                <div class="gauges">
                    <div class="gauge"><div class="donut g-cpu" id="g-cpu"><span>--</span></div><small>CPU</small></div>
                    <div class="gauge"><div class="donut g-ram" id="g-ram"><span>--</span></div><small>RAM</small></div>
                    <div class="gauge"><div class="donut g-tmp" id="g-tmp"><span>--</span></div><small>Température</small></div>
                    <div class="gauge"><div class="donut g-dsk" id="g-dsk"><span>--</span></div><small>Disque</small></div>
                </div>
            </div>
        </div>

        <!-- QUICK ACTIONS -->
        <div class="section-title" style="margin-top:24px">Actions rapides</div>
        <div class="qa" style="margin-top:14px">
            <a class="qa-btn" href="media.php"><span class="qa-ico"><?= icon('upload') ?></span>Téléverser un média</a>
            <a class="qa-btn" href="playlists.php"><span class="qa-ico"><?= icon('plus') ?></span>Nouvelle playlist</a>
            <button class="qa-btn" type="button" onclick="PiSignage.dashboard.screenshot()"><span class="qa-ico"><?= icon('camera') ?></span>Capturer l'écran</button>
            <button class="qa-btn" type="button" onclick="PiSignage.dashboard.restartPlayer()"><span class="qa-ico"><?= icon('refresh') ?></span>Redémarrer le lecteur</button>
        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
