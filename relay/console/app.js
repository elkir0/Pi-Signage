'use strict';
/*
 * Zaforge Fleet Console — app.zaforge.com
 * Static SPA. Same-origin BFF only: every request hits /console/* on the SAME
 * host, carrying the httpOnly session cookie (zf_console) the browser holds and
 * a double-submit CSRF token. NO ADMIN_SECRET, NO zfk_live_ key ever lives here.
 */
(function () {
  const API = '/console';
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));

  // ---- State ----
  const state = {
    me: null,            // { tenant_id, email, role, plan, managed_state }
    devices: [],
    filter: 'all',
    search: '',
    billing: null,       // { plan, sub_status, managed_state, billable_count, prices, ... }
    interval: 'month',
    currency: 'eur',
    pollTimer: null,
  };

  // =====================================================================
  //  HTTP layer — same-origin, cookie auth, CSRF double-submit
  // =====================================================================
  function readCookie(name) {
    const m = document.cookie.match('(?:^|; )' + name.replace(/([.$?*|{}()\[\]\\/+^])/g, '\\$1') + '=([^;]*)');
    return m ? decodeURIComponent(m[1]) : '';
  }

  async function api(path, opts) {
    opts = opts || {};
    const method = (opts.method || 'GET').toUpperCase();
    const headers = { 'Accept': 'application/json' };
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
    // Double-submit CSRF for state-changing verbs (defense-in-depth atop SameSite=Strict).
    if (method !== 'GET' && method !== 'HEAD') {
      const csrf = readCookie('zf_csrf');
      if (csrf) headers['X-CSRF-Token'] = csrf;
    }
    let res;
    try {
      res = await fetch(API + path, {
        method,
        headers,
        credentials: 'same-origin', // sends httpOnly zf_console cookie
        body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      });
    } catch (e) {
      throw new ApiError(0, 'network', 'Network error — check your connection.');
    }
    // Session gone/expired — bounce to login (except during the login call itself).
    if (res.status === 401 && !opts.noAuthRedirect) {
      showLogin();
      throw new ApiError(401, 'unauthorized', 'Session expired. Please sign in again.');
    }
    let data = null;
    const text = await res.text();
    if (text) { try { data = JSON.parse(text); } catch (_) { data = null; } }
    if (!res.ok) {
      const code = (data && data.error) || 'error';
      throw new ApiError(res.status, code, errorMessage(res.status, code));
    }
    return data;
  }

  function ApiError(status, code, message) {
    this.status = status; this.code = code; this.message = message;
  }
  ApiError.prototype = Object.create(Error.prototype);

  function errorMessage(status, code) {
    if (status === 402 || code === 'payment_required')
      return 'Subscription inactive — reactivate billing to perform this action. Your screens keep playing.';
    if (status === 403) return 'You do not have permission for this action.';
    if (status === 409 && code === 'device_not_active') return 'Device is not active yet.';
    if (status === 429) return 'Too many requests — please wait a moment.';
    if (status === 503) return 'Billing is temporarily unavailable. Try again shortly.';
    return ({ bad_tenant: 'Tenant scope error.', unknown_command: 'Unknown command.',
      not_found: 'Not found.', bad_request: 'Invalid request.' })[code] || 'Something went wrong.';
  }

  // =====================================================================
  //  Toasts (aria-live) + small helpers
  // =====================================================================
  function toast(msg, kind) {
    const el = document.createElement('div');
    el.className = 'toast toast-' + (kind || 'info');
    el.setAttribute('role', kind === 'error' ? 'alert' : 'status');
    el.textContent = msg;
    $('#toasts').appendChild(el);
    requestAnimationFrame(() => el.classList.add('show'));
    setTimeout(() => { el.classList.remove('show'); setTimeout(() => el.remove(), 250); }, 3800);
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function fmtAgo(ts) {
    if (!ts) return 'never';
    const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (s < 60) return s + 's ago';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    return Math.floor(s / 86400) + 'd ago';
  }
  function fmtDate(ts) {
    if (!ts) return '—';
    try { return new Date(ts * 1000).toLocaleString(); } catch (_) { return '—'; }
  }

  // =====================================================================
  //  View routing
  // =====================================================================
  function showLogin() {
    stopPolling();
    $('#view-app').hidden = true;
    $('#view-login').hidden = false;
    setTimeout(() => $('#login-email').focus(), 30);
  }
  function showApp() {
    $('#view-login').hidden = true;
    $('#view-app').hidden = false;
  }
  function navTo(name) {
    $$('.nav-item').forEach(b => {
      const on = b.dataset.nav === name;
      b.classList.toggle('is-active', on);
      if (on) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
    });
    $$('.page').forEach(p => { p.hidden = p.id !== 'page-' + name; });
    $('#page-title').textContent = ({ devices: 'Devices', enroll: 'Enroll', billing: 'Billing' })[name] || '';
    document.body.classList.remove('sidebar-open');
    $('#sidebar-toggle').setAttribute('aria-expanded', 'false');
    if (name === 'billing') loadBilling();
    if (name === 'devices') loadDevices();
  }

  // =====================================================================
  //  Bootstrap / session
  // =====================================================================
  async function bootstrap() {
    try {
      const me = await api('/me', { noAuthRedirect: true });
      state.me = me;
      hydrateMe();
      showApp();
      navTo('devices');
      startPolling();
    } catch (e) {
      showLogin();
    }
  }

  function hydrateMe() {
    const me = state.me || {};
    $('#who-email').textContent = me.email || '—';
    $('#who-tenant').textContent = me.tenant_id || '—';
    reflectManagedState(me.managed_state);
  }

  function reflectManagedState(managed) {
    const off = managed === 'managed-off';
    const grace = managed === 'grace';
    $('#managed-off-banner').hidden = !off;
    const pill = $('#managed-pill');
    if (off || grace) {
      pill.hidden = false;
      pill.textContent = off ? 'Billing inactive' : 'Payment retrying';
      pill.classList.toggle('pill-off', off);
      pill.classList.toggle('pill-grace', grace);
    } else {
      pill.hidden = true;
    }
    document.body.classList.toggle('managed-off', off);
  }

  // =====================================================================
  //  LOGIN
  // =====================================================================
  async function onLogin(e) {
    e.preventDefault();
    const btn = $('#login-submit');
    const errEl = $('#login-error');
    errEl.hidden = true;
    const email = $('#login-email').value.trim();
    const password = $('#login-password').value;
    if (!email || !password) { showFormError('Enter your email and password.'); return; }
    setBusy(btn, true);
    try {
      const r = await api('/login', { method: 'POST', body: { email, password }, noAuthRedirect: true });
      // Server set httpOnly zf_console + readable zf_csrf via Set-Cookie. Body carries no secret.
      state.me = { tenant_id: r.tenant_id, role: r.role, email };
      $('#login-password').value = '';
      await bootstrap();
    } catch (err) {
      showFormError(err.status === 401 ? 'Incorrect email or password.' : err.message);
    } finally {
      setBusy(btn, false);
    }
  }
  function showFormError(msg) {
    const el = $('#login-error'); el.textContent = msg; el.hidden = false;
  }
  function setBusy(btn, busy) {
    btn.disabled = busy;
    $('.spinner', btn).hidden = !busy;
    $('.btn-label', btn).style.opacity = busy ? '.5' : '1';
  }

  async function onLogout() {
    try { await api('/logout', { method: 'POST' }); } catch (_) {}
    state.me = null; state.devices = [];
    showLogin();
  }

  // =====================================================================
  //  DEVICES grid
  // =====================================================================
  async function loadDevices() {
    const grid = $('#device-grid');
    grid.setAttribute('aria-busy', 'true');
    if (!state.devices.length) grid.innerHTML = skeletonCards(6);
    try {
      const r = await api('/devices');
      state.devices = (r && r.devices) || [];
      renderDevices();
    } catch (e) {
      if (e.status !== 401) { grid.innerHTML = ''; toast(e.message, 'error'); }
    } finally {
      grid.setAttribute('aria-busy', 'false');
    }
  }

  function deviceMatchesFilter(d) {
    const f = state.filter;
    if (f === 'pending') return d.state === 'pending';
    if (f === 'all') return true;
    return (d.badge || 'offline') === f && d.state === 'active';
  }
  function deviceMatchesSearch(d) {
    if (!state.search) return true;
    const q = state.search.toLowerCase();
    return (d.hostname || '').toLowerCase().includes(q)
        || (d.model || '').toLowerCase().includes(q)
        || (d.device_id || '').toLowerCase().includes(q);
  }

  function renderDevices() {
    const grid = $('#device-grid');
    const list = state.devices.filter(deviceMatchesFilter).filter(deviceMatchesSearch);
    $('#device-empty').hidden = list.length !== 0;
    grid.innerHTML = list.map(deviceCardHtml).join('');
  }

  function badgeFor(d) {
    if (d.state === 'pending') return { cls: 'pending', label: 'Pending' };
    const b = d.badge || 'offline';
    return { cls: b, label: b.charAt(0).toUpperCase() + b.slice(1) };
  }

  function deviceCardHtml(d) {
    const b = badgeFor(d);
    const tel = d.telemetry_preview || {}; // best-effort; detail call has full telemetry
    const cpu = tel.cpu != null ? tel.cpu + '%' : '—';
    const temp = tel.temp != null ? Math.round(tel.temp) + '°C' : '—';
    const shot = d.last_screenshot_url
      ? `<img class="thumb" src="${esc(d.last_screenshot_url)}" alt="Last screen of ${esc(d.hostname || d.device_id)}" loading="lazy">`
      : `<div class="thumb thumb-empty" aria-hidden="true"><span>No screenshot</span></div>`;
    return `
      <button class="card device-card" role="listitem" data-id="${esc(d.device_id)}" type="button">
        <div class="device-thumb">${shot}
          <span class="badge badge-${b.cls}"><i class="dot"></i>${b.label}</span>
        </div>
        <div class="device-meta">
          <div class="device-name" title="${esc(d.hostname || '')}">${esc(d.hostname || d.device_id)}</div>
          <div class="device-sub">${esc(d.model || 'Unknown model')}</div>
          <dl class="kv">
            <div><dt>CPU</dt><dd>${cpu}</dd></div>
            <div><dt>Temp</dt><dd>${temp}</dd></div>
            <div><dt>Agent</dt><dd>${esc(d.agent_version || '—')}</dd></div>
            <div><dt>Player</dt><dd>${esc(d.player_version || '—')}</dd></div>
          </dl>
          <div class="device-foot">Seen ${esc(fmtAgo(d.last_seen_at))}</div>
        </div>
      </button>`;
  }

  function skeletonCards(n) {
    let s = '';
    for (let i = 0; i < n; i++) s += '<div class="card device-card is-skeleton"><div class="device-thumb skeleton"></div><div class="device-meta"><div class="skeleton-line"></div><div class="skeleton-line short"></div></div></div>';
    return s;
  }

  // =====================================================================
  //  DEVICE DETAIL drawer + commands
  // =====================================================================
  let lastFocused = null;
  async function openDevice(id) {
    lastFocused = document.activeElement;
    $('#device-drawer').hidden = false;
    $('#drawer-scrim').hidden = false;
    document.body.classList.add('drawer-open');
    $('#drawer-title').textContent = 'Loading…';
    $('#drawer-body').innerHTML = '<div class="skeleton-line"></div><div class="skeleton-line"></div><div class="skeleton-line short"></div>';
    $('#drawer-close').focus();
    try {
      const r = await api('/devices/' + encodeURIComponent(id));
      renderDrawer(r.device, r.telemetry);
    } catch (e) {
      if (e.status !== 401) $('#drawer-body').innerHTML = `<p class="form-error">${esc(e.message)}</p>`;
    }
  }

  function closeDrawer() {
    $('#device-drawer').hidden = true;
    $('#drawer-scrim').hidden = true;
    document.body.classList.remove('drawer-open');
    if (lastFocused && lastFocused.focus) lastFocused.focus();
  }

  // Command catalog — surfaced as buttons. type values match KNOWN_CMD_TYPES.
  const COMMANDS = [
    { type: 'screenshot', label: 'Screenshot', icon: 'M4 7h4l2-2h4l2 2h4v12H4z M12 11a3 3 0 1 0 0 6 3 3 0 0 0 0-6' },
    { type: 'reload', label: 'Reload', icon: 'M20 11A8 8 0 1 0 12 20a8 8 0 0 0 6.3-3M20 5v6h-6' },
    { type: 'push-playlist', label: 'Push playlist', icon: 'M4 6h16M4 12h10M4 18h7M18 14v6m-3-3h6' },
    { type: 'get-stats', label: 'Get stats', icon: 'M4 19V5m5 14V9m5 10V13m5 6V7' },
    { type: 'reboot', label: 'Reboot', icon: 'M12 4v5m6.4-2.4A8 8 0 1 1 5.6 6.6', danger: true },
  ];

  function renderDrawer(d, tel) {
    $('#drawer-title').textContent = d.hostname || d.device_id;
    const b = badgeFor(d);
    const sys = (tel && tel.system) || {};
    const player = (tel && tel.player) || {};
    const active = d.state === 'active';
    const managedOff = (state.me && state.me.managed_state) === 'managed-off';

    const shotUrl = d.last_screenshot_url;
    const shot = shotUrl
      ? `<img class="drawer-shot" src="${esc(shotUrl)}" alt="Last screen of ${esc(d.hostname || d.device_id)}">`
      : `<div class="drawer-shot drawer-shot-empty"><span>No screenshot yet</span></div>`;

    const cmds = COMMANDS.map(c => {
      const disabled = !active || managedOff;
      return `<button class="btn ${c.danger ? 'btn-danger' : 'btn-secondary'} cmd-btn"
        type="button" data-cmd="${c.type}" ${disabled ? 'disabled' : ''}
        title="${disabled ? (managedOff ? 'Billing inactive' : 'Device not active') : c.label}">
        <svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="${c.icon}"/></svg>
        <span>${c.label}</span></button>`;
    }).join('');

    const lifecycle = d.state === 'pending'
      ? `<div class="confirm-row">
           <div><strong>Pending enrollment.</strong> Match the fingerprint, then confirm to activate.</div>
           <button class="btn btn-primary" type="button" data-confirm="${esc(d.device_id)}" ${managedOff ? 'disabled' : ''}>Confirm device</button>
         </div>`
      : `<button class="btn btn-ghost btn-sm danger-text" type="button" data-retire="${esc(d.device_id)}" ${managedOff ? 'disabled' : ''}>Retire device</button>`;

    $('#drawer-body').innerHTML = `
      <div class="drawer-top">
        ${shot}
        <span class="badge badge-${b.cls} drawer-badge"><i class="dot"></i>${b.label}</span>
      </div>

      <div class="cmd-bar" role="group" aria-label="Device commands">${cmds}</div>
      ${managedOff ? '<p class="muted small">Commands are paused while billing is inactive. The screen keeps playing locally.</p>' : ''}

      <h4 class="sec-h">Identity</h4>
      <dl class="detail-list">
        <div><dt>Device ID</dt><dd class="mono">${esc(d.device_id)}</dd></div>
        <div><dt>Hostname</dt><dd>${esc(d.hostname || '—')}</dd></div>
        <div><dt>Model</dt><dd>${esc(d.model || '—')}</dd></div>
        <div><dt>State</dt><dd>${esc(d.state)}</dd></div>
        <div><dt>WG IP</dt><dd class="mono">${esc(d.wg_ip || '—')}</dd></div>
        <div><dt>Fingerprint</dt><dd class="mono fp">${esc(d.fingerprint || '—')}</dd></div>
        <div><dt>Agent</dt><dd>${esc(d.agent_version || '—')}</dd></div>
        <div><dt>Player</dt><dd>${esc(d.player_version || '—')}</dd></div>
      </dl>

      <h4 class="sec-h">Telemetry ${tel ? `<span class="muted small">(${esc(fmtAgo(tel.ts))})</span>` : ''}</h4>
      <dl class="detail-list">
        <div><dt>CPU</dt><dd>${(sys.cpu_pct != null ? sys.cpu_pct : sys.cpu) != null ? esc(Math.round(sys.cpu_pct != null ? sys.cpu_pct : sys.cpu)) + '%' : '—'}</dd></div>
        <div><dt>Temp</dt><dd>${(sys.temp_c != null ? sys.temp_c : sys.temp) != null ? esc(Math.round(sys.temp_c != null ? sys.temp_c : sys.temp)) + '°C' : '—'}</dd></div>
        <div><dt>Memory</dt><dd>${(sys.mem_pct != null ? sys.mem_pct : sys.mem) != null ? esc(Math.round(sys.mem_pct != null ? sys.mem_pct : sys.mem)) + '%' : '—'}</dd></div>
        <div><dt>Uptime</dt><dd>${sys.uptime != null ? esc(fmtUptime(sys.uptime)) : '—'}</dd></div>
        <div><dt>Now playing</dt><dd>${esc(player.now_playing || player.current || '—')}</dd></div>
        <div><dt>Playlist</dt><dd>${esc(player.playlist || '—')}</dd></div>
      </dl>

      <h4 class="sec-h">Lifecycle</h4>
      <div class="lifecycle">
        <div class="muted small">Last seen ${esc(fmtAgo(d.last_seen_at))} • enrolled ${esc(fmtDate(d.created_at))}</div>
        ${lifecycle}
      </div>`;
  }

  function fmtUptime(s) {
    s = Number(s) || 0;
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
    if (d) return d + 'd ' + h + 'h';
    if (h) return h + 'h ' + m + 'm';
    return m + 'm';
  }

  async function sendCommand(deviceId, type) {
    try {
      const r = await api('/devices/' + encodeURIComponent(deviceId) + '/command', {
        method: 'POST', body: { type },
      });
      toast('“' + type + '” sent (' + (r.cmd_id || 'queued') + ')', 'success');
    } catch (e) {
      if (e.status === 402) { reflectManagedState('managed-off'); navTo('billing'); }
      toast(e.message, 'error');
    }
  }

  async function confirmDevice(deviceId) {
    if (!confirm('Confirm this device? It will become active and (once content is cached) billable.')) return;
    try {
      await api('/devices/' + encodeURIComponent(deviceId) + '/confirm', { method: 'POST' });
      toast('Device activated.', 'success');
      closeDrawer(); await loadDevices();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function retireDevice(deviceId) {
    if (!confirm('Retire this device? It will be removed from your fleet.')) return;
    try {
      await api('/devices/' + encodeURIComponent(deviceId) + '/retire', { method: 'POST' });
      toast('Device retired.', 'success');
      closeDrawer(); await loadDevices();
    } catch (e) { toast(e.message, 'error'); }
  }

  // =====================================================================
  //  ENROLLMENT codes
  // =====================================================================
  async function generateCode() {
    const btn = $('#gen-code-btn');
    btn.disabled = true;
    try {
      const ttl = parseInt($('#code-ttl').value, 10) || 3600;
      const r = await api('/codes', { method: 'POST', body: { ttl_seconds: ttl } });
      $('#code-value').textContent = r.code;
      $('#code-expiry').textContent = 'Expires ' + fmtDate(r.expires_at) + ' • one-time use';
      $('#code-result').hidden = false;
      $('#copy-code-btn .copy-label').textContent = 'Copy';
    } catch (e) {
      if (e.status === 402) { reflectManagedState('managed-off'); navTo('billing'); }
      toast(e.message, 'error');
    } finally {
      btn.disabled = false;
    }
  }

  async function copyCode() {
    const code = $('#code-value').textContent.trim();
    if (!code || code === '—') return;
    const ok = await copyText(code);
    $('#copy-code-btn .copy-label').textContent = ok ? 'Copied!' : 'Copy failed';
    if (ok) toast('Enrollment code copied.', 'success');
    setTimeout(() => { $('#copy-code-btn .copy-label').textContent = 'Copy'; }, 1800);
  }

  async function copyText(text) {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text); return true;
      }
    } catch (_) {}
    try {
      const ta = document.createElement('textarea');
      ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
      document.body.appendChild(ta); ta.select();
      const ok = document.execCommand('copy'); ta.remove(); return ok;
    } catch (_) { return false; }
  }

  // =====================================================================
  //  BILLING
  // =====================================================================
  async function loadBilling() {
    const sum = $('#billing-summary');
    try {
      const r = await api('/billing');
      state.billing = r;
      if (r.managed_state) reflectManagedState(r.managed_state);
      renderBillingSummary(r);
      renderPlanCards(r);
    } catch (e) {
      sum.innerHTML = `<p class="form-error">${esc(e.message)}</p>`;
    }
  }

  function statusPill(s) {
    const map = { active: 'ok', trialing: 'ok', past_due: 'warn', unpaid: 'warn', canceled: 'off', none: 'muted' };
    return `<span class="status-pill status-${map[s] || 'muted'}">${esc(s || 'none')}</span>`;
  }

  function renderBillingSummary(r) {
    const planName = ({ community: 'Community', pro: 'Pro', business: 'Business' })[r.plan] || r.plan;
    const managedLabel = ({ 'managed-on': 'Active', grace: 'Payment retrying', 'managed-off': 'Inactive' })[r.managed_state] || r.managed_state;
    const cur = (r.currency || 'eur').toUpperCase();
    $('#billing-summary').innerHTML = `
      <div class="summary-grid">
        <div><span class="summary-k">Plan</span><span class="summary-v">${esc(planName)}</span></div>
        <div><span class="summary-k">Status</span><span class="summary-v">${statusPill(r.sub_status)}</span></div>
        <div><span class="summary-k">Cloud control</span><span class="summary-v">${esc(managedLabel)}</span></div>
        <div><span class="summary-k">Billable screens</span><span class="summary-v big">${esc(r.billable_count != null ? r.billable_count : 0)}</span></div>
        ${r.interval ? `<div><span class="summary-k">Interval</span><span class="summary-v">${esc(r.interval)}ly</span></div>` : ''}
        ${r.currency ? `<div><span class="summary-k">Currency</span><span class="summary-v">${esc(cur)}</span></div>` : ''}
      </div>
      <p class="muted small">A screen becomes billable only after its assigned content is fully cached on the Pi. Lapsing never stops playback — it only pauses cloud control.</p>
      <div class="summary-actions">
        ${r.plan && r.plan !== 'community'
          ? '<button id="portal-btn" class="btn btn-primary" type="button">Manage subscription</button>'
          : '<span class="muted small">Choose a plan below to start managing this fleet from the cloud.</span>'}
      </div>`;
    const pb = $('#portal-btn');
    if (pb) pb.addEventListener('click', openPortal);
  }

  function priceFor(r, tier) {
    const cat = (r.prices || []).find(p => p.tier === tier && p.interval === state.interval && p.currency === state.currency);
    return cat || null;
  }
  function money(p) {
    if (!p || p.amount == null) return '—';
    const sym = state.currency === 'usd' ? '$' : '€';
    const v = (p.amount / 100).toFixed(p.amount % 100 ? 2 : 0);
    return sym + v;
  }

  function renderPlanCards(r) {
    const tiers = [
      { tier: 'pro', name: 'Pro', blurb: 'Managed fleet, remote control, telemetry.',
        feats: ['Cloud remote control', 'Live telemetry & screenshots', 'Per-screen licensing'] },
      { tier: 'business', name: 'Business', blurb: 'Everything in Pro + HA, SLA, RBAC, white-label.',
        feats: ['Everything in Pro', 'HA relay & SLA', 'RBAC + white-label'] },
    ];
    const perUnit = state.interval === 'year' ? '/screen/yr' : '/screen/mo';
    const count = (r.billable_count != null ? r.billable_count : 0);
    $('#plan-cards').innerHTML = tiers.map(t => {
      const p = priceFor(r, t.tier);
      const current = r.plan === t.tier;
      const est = p && p.amount != null ? money({ amount: p.amount * Math.max(count, 1), }) : null;
      return `
        <div class="plan ${current ? 'is-current' : ''}">
          <div class="plan-head">
            <h4>${t.name}</h4>
            ${current ? '<span class="plan-badge">Current</span>' : ''}
          </div>
          <div class="plan-price">${money(p)}<span class="plan-unit">${perUnit}</span></div>
          <p class="plan-blurb">${t.blurb}</p>
          <ul class="plan-feats">${t.feats.map(f => `<li>${esc(f)}</li>`).join('')}</ul>
          ${est ? `<p class="muted small">~${est}${perUnit.replace('/screen','')} for ${count} screen${count === 1 ? '' : 's'}</p>` : ''}
          <button class="btn ${t.tier === 'business' ? 'btn-secondary' : 'btn-primary'} btn-block plan-cta"
            type="button" data-checkout="${t.tier}" ${current && r.managed_state === 'managed-on' ? 'disabled' : ''}>
            ${current ? (r.managed_state === 'managed-on' ? 'Active plan' : 'Reactivate') : 'Choose ' + t.name}
          </button>
        </div>`;
    }).join('');
  }

  async function startCheckout(tier) {
    try {
      const r = await api('/billing/checkout', {
        method: 'POST',
        body: { tier, interval: state.interval, currency: state.currency },
      });
      if (r && r.url) window.location.assign(r.url); // Stripe Checkout (entitlement only via webhook)
      else toast('Could not start checkout.', 'error');
    } catch (e) { toast(e.message, 'error'); }
  }

  async function openPortal() {
    const btn = $('#portal-btn');
    if (btn) btn.disabled = true;
    try {
      const r = await api('/billing/portal', { method: 'POST' });
      if (r && r.url) window.location.assign(r.url); // Stripe Billing Portal
      else toast('Could not open billing portal.', 'error');
    } catch (e) { toast(e.message, 'error'); if (btn) btn.disabled = false; }
  }

  // =====================================================================
  //  Polling (gentle, pauses when tab hidden)
  // =====================================================================
  function startPolling() {
    stopPolling();
    state.pollTimer = setInterval(() => {
      if (document.hidden) return;
      if (!$('#page-devices').hidden) loadDevices();
    }, 15000);
  }
  function stopPolling() { if (state.pollTimer) { clearInterval(state.pollTimer); state.pollTimer = null; } }

  // =====================================================================
  //  Event wiring
  // =====================================================================
  function wire() {
    $('#login-form').addEventListener('submit', onLogin);
    $('#logout-btn').addEventListener('click', onLogout);
    $('#refresh-btn').addEventListener('click', () => {
      if (!$('#page-devices').hidden) loadDevices();
      else if (!$('#page-billing').hidden) loadBilling();
    });
    $('#sidebar-toggle').addEventListener('click', () => {
      const open = document.body.classList.toggle('sidebar-open');
      $('#sidebar-toggle').setAttribute('aria-expanded', String(open));
    });

    // Nav (sidebar + any data-nav button such as the managed-off banner CTA)
    document.addEventListener('click', (e) => {
      const nav = e.target.closest('[data-nav]');
      if (nav) { navTo(nav.dataset.nav); return; }
    });

    // Device filters / search
    $$('.seg-btn[data-filter]').forEach(b => b.addEventListener('click', () => {
      $$('.seg-btn[data-filter]').forEach(x => x.classList.remove('is-active'));
      b.classList.add('is-active'); state.filter = b.dataset.filter; renderDevices();
    }));
    let searchT;
    $('#device-search').addEventListener('input', (e) => {
      clearTimeout(searchT);
      searchT = setTimeout(() => { state.search = e.target.value.trim(); renderDevices(); }, 120);
    });

    // Device grid -> open detail
    $('#device-grid').addEventListener('click', (e) => {
      const card = e.target.closest('.device-card[data-id]');
      if (card) openDevice(card.dataset.id);
    });

    // Drawer interactions (delegated)
    $('#drawer-close').addEventListener('click', closeDrawer);
    $('#drawer-scrim').addEventListener('click', closeDrawer);
    $('#drawer-body').addEventListener('click', (e) => {
      const cmd = e.target.closest('[data-cmd]');
      const conf = e.target.closest('[data-confirm]');
      const ret = e.target.closest('[data-retire]');
      if (cmd && !cmd.disabled) { const id = currentDrawerId(); if (id) sendCommand(id, cmd.dataset.cmd); }
      else if (conf && !conf.disabled) confirmDevice(conf.dataset.confirm);
      else if (ret && !ret.disabled) retireDevice(ret.dataset.retire);
    });

    // Enrollment
    $('#gen-code-btn').addEventListener('click', generateCode);
    $('#copy-code-btn').addEventListener('click', copyCode);

    // Billing toggles + checkout
    $$('.seg-btn[data-interval]').forEach(b => b.addEventListener('click', () => {
      $$('.seg-btn[data-interval]').forEach(x => x.classList.remove('is-active'));
      b.classList.add('is-active'); state.interval = b.dataset.interval;
      if (state.billing) renderPlanCards(state.billing);
    }));
    $$('.seg-btn[data-currency]').forEach(b => b.addEventListener('click', () => {
      $$('.seg-btn[data-currency]').forEach(x => x.classList.remove('is-active'));
      b.classList.add('is-active'); state.currency = b.dataset.currency;
      if (state.billing) renderPlanCards(state.billing);
    }));
    $('#plan-cards').addEventListener('click', (e) => {
      const cta = e.target.closest('[data-checkout]');
      if (cta && !cta.disabled) startCheckout(cta.dataset.checkout);
    });

    // Global keyboard: ESC closes drawer
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !$('#device-drawer').hidden) closeDrawer();
    });

    // Pause/resume polling on visibility
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && state.me && !$('#page-devices').hidden) loadDevices();
    });
  }

  // Track which device the drawer currently shows (title is set to hostname/id).
  let _drawerDeviceId = null;
  function currentDrawerId() { return _drawerDeviceId; }
  const _openDevice = openDevice;
  openDevice = function (id) { _drawerDeviceId = id; return _openDevice(id); };

  // ---- Boot ----
  document.addEventListener('DOMContentLoaded', () => {
    wire();
    bootstrap();
  });
})();
