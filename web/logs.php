<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Logs Section -->
        <div id="logs" class="content-section active">
            <div class="header">
                <h1 class="page-title">Logs Système</h1>
                <div class="header-actions">
                    <select id="log-source" onchange="refreshLogs()" class="form-control" style="width: auto; display: inline-block; margin-right: 10px;">
                        <option value="pisignage">📝 PiSignage App</option>
                        <option value="system">🖥️ System</option>
                        <option value="vlc">🎵 VLC Player</option>
                        <option value="nginx_error">🌐 Nginx Errors</option>
                        <option value="nginx_access">📊 Nginx Access</option>
                        <option value="all">🔍 All Sources</option>
                    </select>
                    <select id="log-lines" onchange="refreshLogs()" class="form-control" style="width: auto; display: inline-block; margin-right: 10px;">
                        <option value="50">50 lignes</option>
                        <option value="100" selected>100 lignes</option>
                        <option value="200">200 lignes</option>
                        <option value="500">500 lignes</option>
                    </select>
                    <button class="btn btn-primary" onclick="refreshLogs()">
                        🔄 Actualiser
                    </button>
                    <button class="btn btn-secondary" onclick="toggleAutoRefresh()">
                        <span id="auto-refresh-icon">⏸️</span> Auto
                    </button>
                    <button class="btn btn-danger" onclick="rotateLogs()">
                        🔄 Rotation & Nettoyage
                    </button>
                </div>
            </div>

            <!-- Log Stats -->
            <div class="grid grid-3" id="log-stats">
                <div class="card">
                    <h4>📊 Sources Disponibles</h4>
                    <div id="sources-count" style="font-size: 2rem; color: #4a9eff;">-</div>
                </div>
                <div class="card">
                    <h4>⚠️ Erreurs</h4>
                    <div id="error-count" style="font-size: 2rem; color: #ff6b6b;">-</div>
                </div>
                <div class="card">
                    <h4>💾 Taille Totale</h4>
                    <div id="total-size" style="font-size: 2rem; color: #51cf66;">-</div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">
                        <span>📋</span>
                        <span id="log-title">Logs récents</span>
                    </h3>
                    <div style="display: flex; gap: 10px;">
                        <input type="text" id="log-filter" placeholder="Filtrer les logs..." class="form-control" style="width: 300px;" onkeyup="filterLogs()">
                        <button class="btn btn-outline-primary" onclick="scrollToBottom()">⬇️ Bas</button>
                        <button class="btn btn-outline-primary" onclick="scrollToTop()">⬆️ Haut</button>
                    </div>
                </div>
                <div id="logs-content" style="background: rgba(0,0,0,0.3); padding: 20px; border-radius: 10px; font-family: 'Courier New', monospace; font-size: 13px; max-height: 600px; overflow-y: auto; line-height: 1.6;">
                    <div style="color: #888; text-align: center; padding: 20px;">
                        Chargement des logs...
                    </div>
                </div>
            </div>

            <!-- Available Sources -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">
                        <span>📂</span>
                        Sources de Logs Disponibles
                    </h3>
                </div>
                <div id="available-sources" style="max-height: 300px; overflow-y: auto;">
                    <!-- Sources list -->
                </div>
            </div>
        </div>
    </div>

<style>
.log-line {
    margin-bottom: 2px;
    padding: 4px 8px;
    border-radius: 3px;
    transition: background 0.2s;
}

.log-line:hover {
    background: rgba(255,255,255,0.05);
}

.log-line.error {
    background: rgba(255, 107, 107, 0.1);
    border-left: 3px solid #ff6b6b;
}

.log-line.warning {
    background: rgba(255, 200, 50, 0.1);
    border-left: 3px solid #ffc832;
}

.log-line.info {
    border-left: 3px solid #4a9eff;
}

.log-timestamp {
    color: #888;
    margin-right: 10px;
}

.log-level {
    font-weight: bold;
    margin-right: 10px;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
}

.log-level.ERROR {
    background: #ff6b6b;
    color: white;
}

.log-level.WARNING {
    background: #ffc832;
    color: #333;
}

.log-level.INFO {
    background: #4a9eff;
    color: white;
}

.log-message {
    color: #eee;
}

.source-item {
    padding: 10px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.source-item:hover {
    background: rgba(255,255,255,0.05);
}
</style>

<script>
let autoRefreshInterval = null;
let allLogsData = [];

// Load logs on page load
document.addEventListener('DOMContentLoaded', function() {
    refreshLogs();
    loadLogSources();
    loadLogStats();
});

async function refreshLogs() {
    const source = document.getElementById('log-source').value;
    const lines = document.getElementById('log-lines').value;
    const logsContent = document.getElementById('logs-content');
    const logTitle = document.getElementById('log-title');

    logTitle.textContent = `Logs: ${source} (${lines} lignes)`;
    logsContent.innerHTML = '<div style="color: #888; text-align: center; padding: 20px;">Chargement...</div>';

    try {
        const response = await fetch(`/api/logs.php?action=recent&source=${source}&lines=${lines}`);
        const data = await response.json();

        if (data.success && data.data && data.data.logs) {
            allLogsData = data.data.logs;
            displayLogs(allLogsData);
        } else {
            logsContent.innerHTML = '<div style="color: #ff6b6b;">Erreur: Aucun log disponible</div>';
        }
    } catch (error) {
        console.error('Error loading logs:', error);
        logsContent.innerHTML = '<div style="color: #ff6b6b;">Erreur de chargement des logs</div>';
    }
}

function displayLogs(logs) {
    const logsContent = document.getElementById('logs-content');

    if (!logs || logs.length === 0) {
        logsContent.innerHTML = '<div style="color: #888; text-align: center; padding: 20px;">Aucun log disponible</div>';
        return;
    }

    let html = '';
    logs.forEach(log => {
        const level = log.level || 'INFO';
        const levelClass = level.toUpperCase();
        const lineClass = levelClass === 'ERROR' ? 'error' : levelClass === 'WARNING' ? 'warning' : 'info';

        html += `<div class="log-line ${lineClass}">`;
        html += `<span class="log-timestamp">${log.timestamp || ''}</span>`;
        html += `<span class="log-level ${levelClass}">${level}</span>`;
        html += `<span class="log-message">${escapeHtml(log.message || log.raw)}</span>`;
        html += `</div>`;
    });

    logsContent.innerHTML = html;
}

function filterLogs() {
    const filter = document.getElementById('log-filter').value.toLowerCase();

    if (!filter) {
        displayLogs(allLogsData);
        return;
    }

    const filtered = allLogsData.filter(log => {
        const message = (log.message || log.raw || '').toLowerCase();
        const level = (log.level || '').toLowerCase();
        return message.includes(filter) || level.includes(filter);
    });

    displayLogs(filtered);
}

async function loadLogSources() {
    try {
        const response = await fetch('/api/logs.php?action=sources');
        const data = await response.json();

        if (data.success && data.data) {
            displayLogSources(data.data);
        }
    } catch (error) {
        console.error('Error loading log sources:', error);
    }
}

function displayLogSources(sources) {
    const container = document.getElementById('available-sources');

    if (!sources || Object.keys(sources).length === 0) {
        container.innerHTML = '<div style="padding: 20px; text-align: center; color: #888;">Aucune source disponible</div>';
        return;
    }

    let html = '';
    for (const [key, source] of Object.entries(sources)) {
        const size = formatBytes(source.size);
        const date = new Date(source.modified * 1000).toLocaleString('fr-FR');

        html += `<div class="source-item">`;
        html += `<div>`;
        html += `<strong>${source.name}</strong><br>`;
        html += `<small style="color: #888;">${source.file}</small>`;
        html += `</div>`;
        html += `<div style="text-align: right;">`;
        html += `<div>${size}</div>`;
        html += `<small style="color: #888;">${date}</small>`;
        html += `</div>`;
        html += `</div>`;
    }

    container.innerHTML = html;
    document.getElementById('sources-count').textContent = Object.keys(sources).length;
}

async function loadLogStats() {
    try {
        const response = await fetch('/api/logs.php?action=stats');
        const data = await response.json();

        if (data.success && data.data) {
            document.getElementById('error-count').textContent = data.data.error_count || 0;
            document.getElementById('total-size').textContent = data.data.total_size_formatted || '-';
        }
    } catch (error) {
        console.error('Error loading log stats:', error);
    }
}

function toggleAutoRefresh() {
    const icon = document.getElementById('auto-refresh-icon');

    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
        icon.textContent = '⏸️';
    } else {
        autoRefreshInterval = setInterval(refreshLogs, 5000);
        icon.textContent = '⏵️';
        refreshLogs();
    }
}

function scrollToBottom() {
    const logsContent = document.getElementById('logs-content');
    logsContent.scrollTop = logsContent.scrollHeight;
}

function scrollToTop() {
    const logsContent = document.getElementById('logs-content');
    logsContent.scrollTop = 0;
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    if (bytes === null) return '-';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

async function rotateLogs() {
    if (!confirm('Lancer la rotation et le nettoyage des logs ?\n\n' +
                 'Cela va:\n' +
                 '- Compresser les gros logs (>10MB)\n' +
                 '- Supprimer les vieux logs YouTube (>7j)\n' +
                 '- Nettoyer les logs Nginx (>50MB)\n' +
                 '- Libérer de l\'espace disque')) {
        return;
    }

    const originalText = event.target.textContent;
    event.target.textContent = '⏳ Rotation en cours...';
    event.target.disabled = true;

    try {
        const response = await fetch('/api/logs.php', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({action: 'rotate'})
        });

        const data = await response.json();

        if (data.success) {
            alert('✅ Rotation des logs terminée avec succès!\n\nActualisez la page pour voir les nouvelles tailles.');
            setTimeout(() => {
                location.reload();
            }, 1000);
        } else {
            alert('❌ Erreur lors de la rotation: ' + (data.message || 'Erreur inconnue'));
        }
    } catch (error) {
        console.error('Rotation error:', error);
        alert('❌ Erreur de communication avec le serveur');
    } finally {
        event.target.textContent = originalText;
        event.target.disabled = false;
    }
}
</script>

<?php include 'includes/footer.php'; ?>