/**
 * PiSignage Settings module — wires the settings page to live APIs.
 * Audio output, password change, and system actions (reboot/shutdown/
 * clear-cache/restart-player). Display & network use the shared globals
 * defined in init.js (window.saveDisplayConfig / window.saveNetworkConfig).
 *
 * Dispatched by init.js via PiSignage.settings.init() (data-page="settings").
 */
window.PiSignage = window.PiSignage || {};

PiSignage.settings = {
    init() {
        this.loadCurrentSettings();
        this.initAccount();
    },

    /* ---------- compte Zaforge (liaison relais) ---------- */
    initAccount() {
        const mode = document.getElementById('account-mode');
        if (mode) {
            mode.addEventListener('change', () => this.toggleAccountMode());
            this.toggleAccountMode();
        }
        this.loadAccountStatus();
    },

    toggleAccountMode() {
        const mode = document.getElementById('account-mode');
        const login = document.getElementById('account-login-fields');
        const code = document.getElementById('account-code-fields');
        const isCode = mode && mode.value === 'code';
        if (login) login.style.display = isCode ? 'none' : '';
        if (code) code.style.display = isCode ? '' : 'none';
    },

    async loadAccountStatus() {
        const box = document.getElementById('account-status');
        const badge = document.getElementById('account-badge');
        try {
            const r = await PiSignage.api.account.status();
            if (!r || !r.success || !r.data) throw new Error((r && r.message) || 'Réponse invalide');
            this.renderAccountStatus(r.data);
        } catch (e) {
            if (badge) { badge.textContent = 'Indisponible'; badge.style.color = 'var(--text-faint)'; }
            if (box) box.innerHTML = '<p style="font-size:13px;color:var(--text-faint);margin:0">'
                + 'État de liaison indisponible (l\'agent relais est peut-être absent sur cette box).</p>';
        }
    },

    renderAccountStatus(s) {
        const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
        const badge = document.getElementById('account-badge');
        const box = document.getElementById('account-status');
        const connected = !!s.connected;
        const linked = !!s.linked;
        if (badge) {
            badge.textContent = connected ? 'Connecté' : (linked ? 'Lié · hors ligne' : 'Non lié');
            badge.style.color = connected ? 'var(--accent-text)' : (linked ? 'var(--warn-text)' : 'var(--text-faint)');
        }
        if (!box) return;
        if (!linked) {
            box.innerHTML = '<p style="font-size:13px;color:var(--text-dim);margin:0">'
                + 'Cette box n\'est liée à aucun compte Zaforge. Renseignez vos identifiants ou un code ci-dessous.</p>';
            return;
        }
        const dot = connected ? 'var(--accent)' : 'var(--warn)';
        const hb = (s.last_handshake_age_s == null) ? '—' : (s.last_handshake_age_s + ' s');
        const rows = [
            ['État', '<span style="display:inline-flex;align-items:center;gap:6px">'
                + '<span style="width:8px;height:8px;border-radius:50%;background:' + dot + ';display:inline-block"></span>'
                + (connected ? 'Connecté au relais' : 'Lié, en attente de connexion') + '</span>'],
            ['Compte (tenant)', esc(s.tenant_id) || '—'],
            ['Écran (device)', esc(s.device_id) || '—'],
            ['Relais', esc(s.relay_url) || '—'],
            ['Code', esc(s.code_masked) || '—'],
            ['Agent', esc(s.agent_active) + (s.tunnel_up ? ' · tunnel actif' : '')],
            ['Dernier contact', hb],
        ];
        box.innerHTML = '<div style="display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px">'
            + rows.map(([k, v]) => '<div style="color:var(--text-faint)">' + k + '</div>'
                + '<div style="color:var(--text);word-break:break-word">' + v + '</div>').join('')
            + '</div>';
    },

    async linkAccount() {
        const mode = (document.getElementById('account-mode') || {}).value || 'login';
        const btn = document.getElementById('account-link-btn');
        let payload;
        if (mode === 'code') {
            const code = ((document.getElementById('account-code') || {}).value || '').trim().toUpperCase();
            if (!/^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/.test(code)) {
                PiSignage.ui.toast('Code invalide (format ZF-XXXX-XXXX-XXXX)', 'error');
                return;
            }
            payload = { mode: 'code', code: code };
        } else {
            const email = ((document.getElementById('account-email') || {}).value || '').trim();
            const password = (document.getElementById('account-password') || {}).value || '';
            if (!email || !password) {
                PiSignage.ui.toast('E-mail et mot de passe requis', 'error');
                return;
            }
            payload = { mode: 'login', email: email, password: password };
        }
        if (!PiSignage.ui.confirm('Lier / re-lier cette box au compte Zaforge ?')) return;
        if (btn) { btn.disabled = true; }
        try {
            const r = await PiSignage.api.account.link(payload);
            if (r && r.success) {
                PiSignage.ui.toast(r.message || 'Box liée au compte', 'success');
                const pw = document.getElementById('account-password'); if (pw) pw.value = '';
                if (r.data) this.renderAccountStatus(r.data);
                // L'enrôlement prend quelques secondes : rafraîchir l'état deux fois.
                setTimeout(() => this.loadAccountStatus(), 4000);
                setTimeout(() => this.loadAccountStatus(), 9000);
            } else {
                PiSignage.ui.toast((r && r.message) || 'Liaison impossible', 'error');
            }
        } catch (e) {
            PiSignage.ui.toast('Erreur lors de la liaison', 'error');
        } finally {
            if (btn) { btn.disabled = false; }
        }
    },

    /* ---------- load ---------- */
    async loadCurrentSettings() {
        try {
            const res = await fetch('/api/settings.php');
            const data = await res.json();
            if (data && data.success && data.data) {
                const sel = document.getElementById('audio-output');
                if (sel && data.data.audio_output) {
                    sel.value = data.data.audio_output;
                }
            }
        } catch (e) {
            console.error('Settings load error', e);
        }
    },

    /* ---------- audio ---------- */
    async saveAudio() {
        const sel = document.getElementById('audio-output');
        if (!sel) return;
        try {
            const res = await fetch('/api/settings.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'update_audio', audio_output: sel.value })
            });
            const data = await res.json();
            PiSignage.ui.toast(
                (data && data.message) || (data && data.success ? 'Sortie audio mise à jour' : 'Erreur'),
                (data && data.success) ? 'success' : 'error'
            );
        } catch (e) {
            console.error('Audio save error', e);
            PiSignage.ui.toast('Erreur de communication avec le serveur', 'error');
        }
    },

    /* ---------- password ---------- */
    async changePassword() {
        const oldEl = document.getElementById('old-password');
        const newEl = document.getElementById('new-password');
        const confEl = document.getElementById('confirm-password');
        const oldPassword = oldEl ? oldEl.value : '';
        const newPassword = newEl ? newEl.value : '';
        const confirmPassword = confEl ? confEl.value : '';

        if (!oldPassword || !newPassword || !confirmPassword) {
            PiSignage.ui.toast('Tous les champs sont requis', 'error');
            return;
        }
        if (newPassword.length < 8) {
            PiSignage.ui.toast('Le nouveau mot de passe doit contenir au moins 8 caractères', 'error');
            return;
        }
        if (newPassword !== confirmPassword) {
            PiSignage.ui.toast('Les mots de passe ne correspondent pas', 'error');
            return;
        }

        try {
            const res = await fetch('/api/settings.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'update_password',
                    old_password: oldPassword,
                    new_password: newPassword
                })
            });
            const data = await res.json();
            if (data && data.success) {
                PiSignage.ui.toast(data.message || 'Mot de passe mis à jour', 'success');
                if (oldEl) oldEl.value = '';
                if (newEl) newEl.value = '';
                if (confEl) confEl.value = '';
                const banner = document.getElementById('must-change-banner');
                if (banner) banner.remove();
            } else {
                PiSignage.ui.toast((data && data.message) || 'Erreur lors de la mise à jour', 'error');
            }
        } catch (e) {
            console.error('Password change error', e);
            PiSignage.ui.toast('Erreur de communication avec le serveur', 'error');
        }
    },

    /* ---------- system actions ---------- */
    async systemAction(action) {
        const prompts = {
            'reboot': 'Redémarrer le système ?',
            'shutdown': 'Éteindre le système ?',
            'clear-cache': 'Vider le cache du système ?',
            'restart-player': 'Redémarrer le lecteur ?'
        };
        if (prompts[action] && !PiSignage.ui.confirm(prompts[action])) return;

        try {
            const data = await PiSignage.api.system.systemAction(action);
            if (data && data.success) {
                PiSignage.ui.toast(data.message || 'Action exécutée', 'success');
                if (action === 'reboot') {
                    PiSignage.ui.toast('Le système va redémarrer dans 1 minute', 'warning');
                } else if (action === 'shutdown') {
                    PiSignage.ui.toast('Le système va s\'éteindre dans 1 minute', 'warning');
                }
            } else {
                PiSignage.ui.toast((data && data.message) || 'Erreur lors de l\'exécution', 'error');
            }
        } catch (e) {
            console.error('System action error', e);
            PiSignage.ui.toast('Erreur de communication avec le serveur', 'error');
        }
    }
};

/* Logout helper kept global for any inline caller / navigation link. */
window.logout = async function () {
    if (!PiSignage.ui.confirm('Voulez-vous vraiment vous déconnecter ?')) return;
    try {
        await fetch('/api/settings.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'logout' })
        });
    } catch (e) {
        console.error('Logout error', e);
    }
    window.location.href = '/login.php';
};

console.log('PiSignage Settings module loaded');
