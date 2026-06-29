<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Musique';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';
?>
<div class="main">
    <?php pageHeader('Musique d’ambiance', 'Webradio ou musiques locales pendant la diffusion', statusPill()); ?>

    <div class="content">
      <div class="content-inner">

        <div class="card" style="margin-bottom:18px">
            <div class="row" style="justify-content:space-between;gap:16px;align-items:flex-start">
                <div style="min-width:0">
                    <div class="card-head" style="margin-bottom:6px">
                        <h2 class="card-title"><?= icon('volume') ?>Mode musique</h2>
                    </div>
                    <p style="color:var(--text-faint);font-size:13px;margin:0;max-width:760px">
                        Quand ce mode est activé, le player coupe automatiquement le son des vidéos et diffuse
                        la musique choisie en fond. Le volume reste le volume système existant.
                    </p>
                </div>
                <label class="row" style="gap:10px;margin:0;cursor:pointer;flex:none">
                    <span id="music-enabled-label" style="font-weight:700;color:var(--text-dim)">Désactivé</span>
                    <span class="toggle-switch">
                        <input type="checkbox" id="music-enabled">
                        <span class="toggle-slider"></span>
                    </span>
                </label>
            </div>
        </div>

        <div class="grid grid-2">
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('settings') ?>Source</h2>
                </div>

                <div class="form-group">
                    <label for="music-source">Type de musique</label>
                    <select class="form-control" id="music-source">
                        <option value="webradio">Webradio</option>
                        <option value="local">Musiques fournies</option>
                    </select>
                </div>

                <div id="music-radio-panel">
                    <div class="form-group">
                        <label for="music-radio">Webradio</label>
                        <select class="form-control" id="music-radio"></select>
                        <p style="font-size:11.5px;color:var(--text-faint);margin-top:6px">
                            Sélection de flux publics orientés ambiance, lounge, jazz, pop soft et indé.
                        </p>
                    </div>
                    <div id="music-radio-meta" style="font-size:12px;color:var(--text-faint)"></div>
                </div>

                <div id="music-local-panel" style="display:none">
                    <div class="form-group">
                        <label for="music-playback">Lecture des fichiers</label>
                        <select class="form-control" id="music-playback">
                            <option value="order">Ordre choisi</option>
                            <option value="random">Aléatoire</option>
                        </select>
                    </div>
                    <div class="row" style="gap:8px;flex-wrap:wrap;margin-bottom:10px">
                        <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.music.selectAllTracks(true)">
                            <?= icon('check') ?>Tout sélectionner
                        </button>
                        <button class="btn btn-ghost btn-sm" type="button" onclick="PiSignage.music.selectAllTracks(false)">
                            <?= icon('close') ?>Tout désélectionner
                        </button>
                    </div>
                    <div id="music-tracks" aria-live="polite">
                        <div class="empty-state"><span class="spinner"></span><p>Chargement des fichiers audio…</p></div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('info') ?>Effet à l’écran</h2>
                </div>
                <div id="music-summary" style="font-size:14px;color:var(--text-dim);line-height:1.55">
                    Chargement de la configuration…
                </div>
                <div style="height:1px;background:var(--border);margin:18px 0"></div>
                <button class="btn btn-primary btn-block" type="button" onclick="PiSignage.music.save()">
                    <?= icon('check') ?>Enregistrer
                </button>
                <p style="color:var(--text-faint);font-size:12px;margin:10px 0 0">
                    Le player relit ce réglage automatiquement sous quelques secondes. Aucun redémarrage n’est nécessaire.
                </p>
            </div>
        </div>

      </div>
    </div>
</div>

<?php include 'includes/footer.php'; ?>
