/**
 * PiSignage — Theme manager (adaptive light/dark) + topbar clock.
 * Anti-flash theme is applied in <head>; this wires the toggle + OS-following + clock.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.theme = {
    KEY: 'pisignage-theme',

    get() { return document.documentElement.getAttribute('data-theme') || 'dark'; },

    set(t) {
        document.documentElement.setAttribute('data-theme', t);
        try { localStorage.setItem(this.KEY, t); } catch (e) {}
    },

    toggle() { this.set(this.get() === 'dark' ? 'light' : 'dark'); },

    init() {
        const btn = document.getElementById('theme-toggle');
        if (btn) btn.addEventListener('click', () => this.toggle());

        // Follow OS preference only while the user hasn't made an explicit choice.
        if (window.matchMedia) {
            const mq = window.matchMedia('(prefers-color-scheme: light)');
            const handler = (e) => {
                try { if (!localStorage.getItem(this.KEY)) this.set(e.matches ? 'light' : 'dark'); } catch (_) {}
            };
            if (mq.addEventListener) mq.addEventListener('change', handler);
            else if (mq.addListener) mq.addListener(handler);
        }

        this.startClock();
    },

    startClock() {
        const el = document.getElementById('topbar-clock');
        if (!el) return;
        const tick = () => { el.textContent = new Date().toLocaleTimeString('fr-FR'); };
        tick();
        setInterval(tick, 1000);
    }
};

document.addEventListener('DOMContentLoaded', () => PiSignage.theme.init());
console.log('✅ PiSignage theme module loaded');
