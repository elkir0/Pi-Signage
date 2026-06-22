# Zaforge Fleet Console (`app.zaforge.com`)

Static single-page app (vanilla HTML/CSS/JS, **zero dependencies, no build step**).
Built on the Mac, deployed as plain files to CT101 and served behind nginx.

## What it is

The operator-facing console for a single tenant's fleet:

- **Login** — operator email + password.
- **Device grid** — liveness badge (online / stale / offline / pending), hostname, model,
  agent & player version, last CPU/temp telemetry, last screenshot.
- **Device detail** — full identity, telemetry, lifecycle (confirm / retire) and command
  buttons (reboot, screenshot, reload, push-playlist, get-stats).
- **Enroll** — generate a one-time enrollment code and copy it.
- **Billing** — plan, subscription status, billable screen count, plan picker (Checkout)
  and **Manage subscription** (Stripe Billing Portal).

## Security model (why no secret lives here)

The console is **NOT** a public SPA that talks to `relay.zaforge.com` with a key. It is
served from `app.zaforge.com` and talks **same-origin** to a thin BFF inside `fleet-api`
under `/console/*`. Auth is an **httpOnly, Secure, SameSite=Strict** session cookie
(`zf_console`) the browser cannot read, plus a readable `zf_csrf` cookie mirrored into the
`X-CSRF-Token` header on every state-changing request (double-submit CSRF).

- The cross-tenant `ADMIN_SECRET` and tenant `zfk_live_` keys **never** reach the browser.
- The session is server-side, tenant-scoped, and revocable.
- `fetch` uses `credentials: 'same-origin'`; the app only ever calls `/console/*`.

## Local preview (Mac)

```bash
cd relay/console
python3 -m http.server 5173
# open http://localhost:5173 — the login posts to /console/login, which only
# resolves against a running fleet-api (use a dev proxy or test on app.zaforge.com).
```

## Deploy

See `relay/deploy-ct101/app.zaforge.com.conf` and the deploy steps in the implementation
notes. The bundle is additive: it adds a new gated vhost and leaves `relay.zaforge.com`
(/enroll + /admin) untouched.
