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
        if (newPassword.length < 6) {
            PiSignage.ui.toast('Le nouveau mot de passe doit contenir au moins 6 caractères', 'error');
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
