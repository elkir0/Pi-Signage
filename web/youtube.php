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

            <!-- DOWNLOAD CARD -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('youtube') ?>Télécharger une vidéo</h2>
                </div>

                <div class="form-group">
                    <label for="youtube-url">URL YouTube</label>
                    <input type="url" class="form-control" id="youtube-url"
                           placeholder="https://www.youtube.com/watch?v=..." autocomplete="off">
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label for="youtube-quality">Qualité</label>
                        <select class="form-control" id="youtube-quality">
                            <option value="best">Meilleure qualité</option>
                            <option value="720p">720p</option>
                            <option value="480p">480p</option>
                            <option value="360p">360p</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="youtube-compression">Compression</label>
                        <select class="form-control" id="youtube-compression">
                            <option value="none">Aucune</option>
                            <option value="h264">H.264 optimisé</option>
                            <option value="ultralight">Ultra léger</option>
                        </select>
                    </div>
                </div>

                <button class="btn btn-primary btn-block" type="button" onclick="downloadYoutube()">
                    <?= icon('download') ?>Télécharger
                </button>

                <div class="progress-bar" id="youtube-progress" style="display:none;">
                    <div class="progress-fill" id="youtube-progress-fill" style="width:0%"></div>
                </div>
            </div>

            <!-- HISTORY CARD -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('list') ?>Historique</h2>
                    <button class="icon-btn" type="button" title="Actualiser" onclick="PiSignage.youtube && PiSignage.youtube.loadHistory()"><?= icon('refresh') ?></button>
                </div>
                <div id="youtube-history">
                    <div class="empty-state">
                        <span class="spinner"></span>
                        <p>Chargement de l'historique…</p>
                    </div>
                </div>
            </div>

        </div>

      </div>
    </div>
</div>

<script>
/* YouTube page — download history loader (download wiring lives in init.js: window.downloadYoutube). */
(function () {
    window.PiSignage = window.PiSignage || {};

    const STATUS_META = {
        completed:   { label: 'Terminé',        cls: 'badge-success' },
        downloading: { label: 'Téléchargement', cls: 'badge-info'    },
        queued:      { label: 'En file',        cls: 'badge-warn'    },
        error:       { label: 'Échec',          cls: 'badge-danger'  },
        cancelled:   { label: 'Annulé',         cls: 'badge-danger'  }
    };

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
        }[c]));
    }

    function renderItem(item) {
        const meta = STATUS_META[item.status] || { label: item.status || 'Inconnu', cls: 'badge-info' };
        const title = item.filename || item.url || 'Téléchargement';
        const when = item.completed_at || item.updated_at || item.started_at || '';
        const progress = (item.status === 'downloading' && item.progress != null)
            ? ' · ' + Math.round(item.progress) + '%'
            : '';
        return '' +
            '<div class="queue-item" style="cursor:default;margin-bottom:8px">' +
                '<div style="flex:1;min-width:0">' +
                    '<div style="font-weight:600;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + esc(title) + '</div>' +
                    '<div style="font-size:12.5px;color:var(--text-faint);margin-top:2px">' + esc(when) + esc(progress) + '</div>' +
                '</div>' +
                '<span class="badge ' + meta.cls + '">' + esc(meta.label) + '</span>' +
            '</div>';
    }

    function renderEmpty() {
        return '' +
            '<div class="empty-state">' +
                '<svg width="54" height="54" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="15" rx="2"/><polyline points="17 2 12 7 7 2"/></svg>' +
                '<h3>Aucun téléchargement</h3>' +
                '<p>Les vidéos importées apparaîtront ici.</p>' +
            '</div>';
    }

    PiSignage.youtube = {
        async loadHistory() {
            const box = document.getElementById('youtube-history');
            if (!box) return;
            try {
                const res = await PiSignage.api.request('/api/youtube.php');
                const list = (res && res.success && Array.isArray(res.data)) ? res.data : [];
                if (!list.length) { box.innerHTML = renderEmpty(); return; }
                list.sort((a, b) => String(b.started_at || '').localeCompare(String(a.started_at || '')));
                box.innerHTML = list.map(renderItem).join('');
            } catch (e) {
                box.innerHTML = renderEmpty();
            }
        },
        init() { this.loadHistory(); }
    };

    function boot() { PiSignage.youtube.init(); }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
</script>

<?php include 'includes/footer.php'; ?>
