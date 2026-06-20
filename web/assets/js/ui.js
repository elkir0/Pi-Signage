/**
 * PiSignage — Shared UI helpers: toasts, modals, sidebar, logout.
 * Overrides legacy showAlert()/showNotification() with the new toast system.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.ui = {
    _icons: {
        success: '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m22 4-10 10-3-3"/>',
        error:   '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>',
        warning: '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>',
        info:    '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>'
    },

    _svg(name) {
        return '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" '
             + 'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
             + (this._icons[name] || this._icons.info) + '</svg>';
    },

    toast(message, type = 'info', timeout = 3600) {
        let cont = document.getElementById('toast-container');
        if (!cont) {
            cont = document.createElement('div');
            cont.id = 'toast-container';
            document.body.appendChild(cont);
        }
        const t = (type === 'error' || type === 'success' || type === 'warning') ? type : 'info';
        const el = document.createElement('div');
        el.className = 'toast toast-' + t;
        el.setAttribute('role', 'status');
        el.innerHTML = '<span class="toast-ico">' + this._svg(t) + '</span><span>' + message + '</span>';
        cont.appendChild(el);
        setTimeout(() => {
            el.classList.add('hide');
            setTimeout(() => el.remove(), 260);
        }, timeout);
        return el;
    },

    /* Sidebar (mobile) */
    toggleSidebar(force) {
        const sb = document.getElementById('sidebar');
        if (!sb) return;
        const open = (force === undefined) ? !sb.classList.contains('active') : !!force;
        sb.classList.toggle('active', open);
        const bd = document.getElementById('sidebar-backdrop');
        if (bd) bd.classList.toggle('active', open);
    },

    /* Modal helpers — correct event-handler pattern (clic-fond + ÉCHAP + cleanup) */
    openModal(el) {
        if (typeof el === 'string') el = document.getElementById(el);
        if (!el) return;
        el.classList.add('show');
        const esc = (e) => { if (e.key === 'Escape') PiSignage.ui.closeModal(el); };
        const bg = (e) => { if (e.target === el) PiSignage.ui.closeModal(el); };
        el._escHandler = esc;
        el._bgHandler = bg;
        document.addEventListener('keydown', esc);
        el.addEventListener('click', bg);
    },

    closeModal(el) {
        if (typeof el === 'string') el = document.getElementById(el);
        if (!el) return;
        el.classList.remove('show');
        if (el._escHandler) { document.removeEventListener('keydown', el._escHandler); delete el._escHandler; }
        if (el._bgHandler) { el.removeEventListener('click', el._bgHandler); delete el._bgHandler; }
        if (el.dataset && el.dataset.removeOnClose === '1') el.remove();
    },

    confirm(message) { return window.confirm(message); },

    logout() {
        fetch('/api/settings.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'logout' })
        }).catch(() => {}).finally(() => { window.location.href = '/login.php'; });
    }
};

/* Namespace + legacy backward-compat shims */
PiSignage.toast = (m, t) => PiSignage.ui.toast(m, t);
PiSignage.logout = () => PiSignage.ui.logout();
window.showAlert = (message, type = 'info') => PiSignage.ui.toast(message, type);
window.showNotification = window.showAlert;
window.toggleSidebar = () => PiSignage.ui.toggleSidebar();

console.log('✅ PiSignage UI module loaded — toasts ready');
