<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Logs système';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions =
      '<button class="icon-btn" id="logs-refresh" type="button" title="Actualiser">' . icon('refresh') . '</button>';
?>
<div class="main">
    <?php pageHeader('Logs système', 'Visionneuse multi-sources', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- STAT CARDS -->
        <div class="grid grid-3">
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico blue"><?= icon('folder') ?></div></div>
                <div><div class="stat-val" id="sources-count">--</div><div class="stat-label">Sources disponibles</div></div>
            </div>
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico danger"><?= icon('alert') ?></div></div>
                <div><div class="stat-val" id="error-count">--</div><div class="stat-label">Erreurs</div></div>
            </div>
            <div class="card stat">
                <div class="stat-top"><div class="stat-ico amber"><?= icon('storage') ?></div></div>
                <div><div class="stat-val" id="total-size" style="font-size:20px">--</div><div class="stat-label">Taille totale</div></div>
            </div>
        </div>

        <!-- LOG VIEWER -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('logs') ?><span id="log-title">Logs récents</span></h2>
            </div>

            <!-- Toolbar -->
            <div class="form-row" style="align-items:flex-end">
                <div class="form-group">
                    <label for="log-source">Source</label>
                    <select id="log-source" class="form-control">
                        <option value="pisignage">Zaforge (application)</option>
                        <option value="syslog">Système</option>
                        <option value="nginx_error">Nginx · erreurs</option>
                        <option value="nginx_access">Nginx · accès</option>
                        <option value="php_error">PHP-FPM</option>
                        <option value="kern">Noyau</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="log-lines">Lignes</label>
                    <select id="log-lines" class="form-control">
                        <option value="50">50 lignes</option>
                        <option value="100" selected>100 lignes</option>
                        <option value="200">200 lignes</option>
                        <option value="500">500 lignes</option>
                    </select>
                </div>
                <div class="form-group" style="flex:1 1 220px">
                    <label for="log-filter">Filtre</label>
                    <input type="text" id="log-filter" class="form-control" placeholder="Filtrer les logs…">
                </div>
            </div>

            <div class="row" style="gap:12px;flex-wrap:wrap;align-items:center;margin-top:12px">
                <label class="toggle-switch" title="Rafraîchissement automatique (5s)">
                    <input type="checkbox" id="auto-refresh">
                    <span class="toggle-slider"></span>
                </label>
                <span class="text-dim" style="font-size:13px">Auto‑actualisation</span>
                <span style="flex:1"></span>
                <button class="btn btn-secondary btn-sm" id="logs-scroll-top" type="button"><?= icon('chevron') ?>Haut</button>
                <button class="btn btn-secondary btn-sm" id="logs-scroll-bottom" type="button"><?= icon('chevron') ?>Bas</button>
                <button class="btn btn-danger btn-sm" id="logs-rotate" type="button"><?= icon('refresh') ?>Rotation &amp; nettoyage</button>
            </div>

            <div class="log-viewer" id="logs-content" style="margin-top:14px">
                <div class="log-line log-info">Chargement des logs…</div>
            </div>
        </div>

        <!-- AVAILABLE SOURCES -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('list') ?>Sources de logs disponibles</h2>
            </div>
            <div id="available-sources">
                <div class="empty-state"><?= icon('folder') ?><h3>Chargement…</h3></div>
            </div>
        </div>

      </div>
    </div>
</div>

<style>
/* Page-local: source list rows + log line layout (tokens only, no hardcoded colors) */
.logs-source-row{display:flex;justify-content:space-between;align-items:center;gap:12px;
    padding:10px 12px;border-bottom:1px solid var(--border)}
.logs-source-row:last-child{border-bottom:0}
.logs-source-row:hover{background:var(--surface-hover)}
.logs-source-row .lsr-name{font-weight:600;color:var(--text)}
.logs-source-row .lsr-meta{color:var(--text-dim);font-size:12px}
.logs-source-row .lsr-right{text-align:right;color:var(--text-dim);font-size:12px;white-space:nowrap}
.log-line{display:flex;gap:8px;align-items:baseline}
.log-line .ll-time{color:var(--text-faint);flex:0 0 auto}
.log-line .ll-level{flex:0 0 auto;font-weight:700;font-size:10.5px;letter-spacing:.04em;
    padding:0 6px;border-radius:var(--radius-pill);text-transform:uppercase}
.log-line .ll-level.lvl-error{background:var(--danger-soft);color:var(--danger-text)}
.log-line .ll-level.lvl-warning{background:var(--warn-soft);color:var(--warn-text)}
.log-line .ll-level.lvl-info{background:var(--info-soft);color:var(--info-text)}
.log-line .ll-msg{flex:1 1 auto;word-break:break-word}
</style>

<script>
/* Logs page — self-contained module (auto-executed on DOMContentLoaded so the
   deferred PiSignage.* modules are ready). Wires via addEventListener to avoid
   collision with the legacy window.refreshLogs handler in init.js. */
(function () {
    'use strict';

    function ready(fn) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', fn, { once: true });
        } else {
            fn();
        }
    }

    ready(function () {
        var page = (document.body && document.body.getAttribute('data-page')) || '';
        if (page !== 'logs') return;

        var els = {
            source:      document.getElementById('log-source'),
            lines:       document.getElementById('log-lines'),
            filter:      document.getElementById('log-filter'),
            auto:        document.getElementById('auto-refresh'),
            title:       document.getElementById('log-title'),
            content:     document.getElementById('logs-content'),
            sources:     document.getElementById('available-sources'),
            sourcesCount:document.getElementById('sources-count'),
            errorCount:  document.getElementById('error-count'),
            totalSize:   document.getElementById('total-size'),
            btnRefresh:  document.getElementById('logs-refresh'),
            btnRotate:   document.getElementById('logs-rotate'),
            btnTop:      document.getElementById('logs-scroll-top'),
            btnBottom:   document.getElementById('logs-scroll-bottom')
        };

        var allLogs = [];
        var autoTimer = null;

        function toast(msg, type) {
            if (window.PiSignage && PiSignage.ui && PiSignage.ui.toast) {
                PiSignage.ui.toast(msg, type || 'info');
            }
        }

        function escapeHtml(text) {
            var div = document.createElement('div');
            div.textContent = text == null ? '' : text;
            return div.innerHTML;
        }

        function formatBytes(bytes) {
            if (bytes === null || bytes === undefined) return '--';
            if (!bytes) return '0 o';
            var k = 1024, sizes = ['o', 'Ko', 'Mo', 'Go', 'To'];
            var i = Math.floor(Math.log(bytes) / Math.log(k));
            return (Math.round(bytes / Math.pow(k, i) * 100) / 100) + ' ' + sizes[i];
        }

        function levelClass(level) {
            var l = String(level || 'INFO').toUpperCase();
            if (l === 'ERROR') return 'error';
            if (l === 'WARNING' || l === 'WARN') return 'warning';
            return 'info';
        }

        function displayLogs(logs) {
            if (!logs || !logs.length) {
                els.content.innerHTML = '<div class="log-line log-info">Aucun log disponible</div>';
                return;
            }
            var html = '';
            for (var i = 0; i < logs.length; i++) {
                var log = logs[i];
                var level = (log.level || 'INFO');
                var cls = levelClass(level);
                html += '<div class="log-line log-' + cls + '">'
                     +  '<span class="ll-time">' + escapeHtml(log.timestamp || '') + '</span>'
                     +  '<span class="ll-level lvl-' + cls + '">' + escapeHtml(String(level).toUpperCase()) + '</span>'
                     +  '<span class="ll-msg">' + escapeHtml(log.message || log.raw || '') + '</span>'
                     +  '</div>';
            }
            els.content.innerHTML = html;
        }

        function applyFilter() {
            var f = (els.filter.value || '').toLowerCase();
            if (!f) { displayLogs(allLogs); return; }
            var filtered = allLogs.filter(function (log) {
                var msg = (log.message || log.raw || '').toLowerCase();
                var lvl = (log.level || '').toLowerCase();
                return msg.indexOf(f) !== -1 || lvl.indexOf(f) !== -1;
            });
            displayLogs(filtered);
        }

        async function refreshLogs() {
            var source = els.source.value;
            var lines = els.lines.value;
            els.title.textContent = 'Logs : ' + source + ' (' + lines + ' lignes)';
            els.content.innerHTML = '<div class="log-line log-info">Chargement…</div>';
            try {
                var resp = await fetch('/api/logs.php?action=recent&source='
                    + encodeURIComponent(source) + '&lines=' + encodeURIComponent(lines));
                var data = await resp.json();
                if (data && data.success && data.data && data.data.logs) {
                    allLogs = data.data.logs;
                    applyFilter();
                } else {
                    els.content.innerHTML = '<div class="log-line log-error">Aucun log disponible</div>';
                }
            } catch (e) {
                console.error('Error loading logs:', e);
                els.content.innerHTML = '<div class="log-line log-error">Erreur de chargement des logs</div>';
            }
        }

        async function loadSources() {
            try {
                var resp = await fetch('/api/logs.php?action=sources');
                var data = await resp.json();
                if (data && data.success && data.data) displaySources(data.data);
            } catch (e) {
                console.error('Error loading log sources:', e);
            }
        }

        function displaySources(sources) {
            var keys = sources ? Object.keys(sources) : [];
            if (!keys.length) {
                els.sources.innerHTML = '<div class="empty-state">'
                    + '<h3>Aucune source</h3><p>Aucun fichier de log accessible.</p></div>';
                els.sourcesCount.textContent = '0';
                return;
            }
            var html = '';
            for (var i = 0; i < keys.length; i++) {
                var s = sources[keys[i]];
                var size = formatBytes(s.size);
                var date = s.modified ? new Date(s.modified * 1000).toLocaleString('fr-FR') : '';
                html += '<div class="logs-source-row">'
                     +  '<div><div class="lsr-name">' + escapeHtml(s.name || keys[i]) + '</div>'
                     +  '<div class="lsr-meta">' + escapeHtml(s.file || '') + '</div></div>'
                     +  '<div class="lsr-right"><div>' + escapeHtml(size) + '</div>'
                     +  '<div>' + escapeHtml(date) + '</div></div>'
                     +  '</div>';
            }
            els.sources.innerHTML = html;
            els.sourcesCount.textContent = String(keys.length);
        }

        async function loadStats() {
            try {
                var resp = await fetch('/api/logs.php?action=stats');
                var data = await resp.json();
                if (data && data.success && data.data) {
                    els.errorCount.textContent = (data.data.error_count != null) ? data.data.error_count : 0;
                    els.totalSize.textContent = data.data.total_size_formatted || '--';
                }
            } catch (e) {
                console.error('Error loading log stats:', e);
            }
        }

        function setAutoRefresh(on) {
            if (autoTimer) { clearInterval(autoTimer); autoTimer = null; }
            if (on) {
                autoTimer = setInterval(refreshLogs, 5000);
                refreshLogs();
            }
        }

        async function rotateLogs() {
            var ok = (window.PiSignage && PiSignage.ui && PiSignage.ui.confirm)
                ? PiSignage.ui.confirm('Lancer la rotation et le nettoyage des logs ?\n\n'
                    + 'Compresse les gros logs, supprime les anciens logs YouTube (>7j) '
                    + 'et libère de l\'espace disque.')
                : window.confirm('Lancer la rotation et le nettoyage des logs ?');
            if (!ok) return;

            var btn = els.btnRotate;
            var original = btn.innerHTML;
            btn.innerHTML = '<span class="spinner"></span>Rotation…';
            btn.disabled = true;
            try {
                var resp = await fetch('/api/logs.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'rotate' })
                });
                var data = await resp.json();
                if (data && data.success) {
                    toast('Rotation des logs terminée', 'success');
                    loadStats();
                    loadSources();
                    refreshLogs();
                } else {
                    toast('Erreur lors de la rotation : ' + ((data && data.message) || 'inconnue'), 'error');
                }
            } catch (e) {
                console.error('Rotation error:', e);
                toast('Erreur de communication avec le serveur', 'error');
            } finally {
                btn.innerHTML = original;
                btn.disabled = false;
            }
        }

        /* ---- wiring ---- */
        els.source.addEventListener('change', refreshLogs);
        els.lines.addEventListener('change', refreshLogs);
        els.filter.addEventListener('input', applyFilter);
        els.auto.addEventListener('change', function () { setAutoRefresh(els.auto.checked); });
        els.btnRefresh.addEventListener('click', refreshLogs);
        els.btnRotate.addEventListener('click', rotateLogs);
        els.btnTop.addEventListener('click', function () { els.content.scrollTop = 0; });
        els.btnBottom.addEventListener('click', function () { els.content.scrollTop = els.content.scrollHeight; });

        /* ---- initial load ---- */
        refreshLogs();
        loadSources();
        loadStats();
    });
})();
</script>

<?php include 'includes/footer.php'; ?>
