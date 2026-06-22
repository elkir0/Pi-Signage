# Zaforge vitrine (zaforge.com)

Static marketing site for **Zaforge** — managed open-core digital signage for
Raspberry Pi. Built with [Astro](https://astro.build) in `output: 'static'`
mode. **Nothing runs at request time**: the build produces a plain `dist/`
directory of HTML/CSS/assets that nginx serves directly.

> Design intent: the VM stays lean. The site is **built on the Mac**; only the
> compiled `dist/` is shipped. No Node, no `npm install`, no Astro on the VM.

---

## 1. Place the real screenshots

The build references three PNGs the operator drops into `public/img/` before
building (they are product screenshots, not committed here):

```bash
cp ~/Desktop/zaforge-assets/zaforge-signage-live.png  public/img/zaforge-signage-live.png   # HERO
cp ~/Desktop/zaforge-assets/zaforge-dashboard.png      public/img/zaforge-dashboard.png
cp ~/Desktop/zaforge-assets/zaforge-login.png          public/img/zaforge-login.png
```

The pages degrade gracefully if an image is missing (alt text + neutral frame),
but ship all three for the intended effect.

---

## 2. Build (on the Mac)

```bash
cd relay/vitrine
npm install          # one-time, on the Mac only
npm run build        # -> writes ./dist
```

Preview locally before shipping:

```bash
npm run preview      # serves ./dist at http://localhost:4321
```

---

## 3. Ship `dist/` to VM600

Only the compiled output travels. `--delete` keeps the web root an exact mirror
of the build (no stale files). Adjust the path to your web root.

```bash
rsync -a --delete dist/ deploy@10.10.10.160:/srv/www/zaforge.com/
```

---

## 4. Serve it (nginx static on VM600 + CT101 vhost zaforge.com)

The public edge is **CT101** (10.10.10.101), which already terminates TLS for
`relay.zaforge.com`. Add an **additive** vhost for `zaforge.com`. Two options:

### Option A — nginx static directly on VM600, CT101 proxies
Serve the files on VM600 and reverse-proxy from CT101 (mirrors the relay vhost
pattern in `relay/deploy-ct101/relay.zaforge.com.conf`):

```nginx
# /etc/nginx/sites-available/zaforge.com.conf  (on CT101)
# Additive vhost — never edit other vhosts. Cert via certbot --webroot.
server {
    listen 80;
    server_name zaforge.com www.zaforge.com;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://zaforge.com$request_uri; }
}
server {
    listen 443 ssl http2;
    server_name www.zaforge.com;
    ssl_certificate     /etc/letsencrypt/live/zaforge.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zaforge.com/privkey.pem;
    return 301 https://zaforge.com$request_uri;   # canonical apex
}
server {
    listen 443 ssl http2;
    server_name zaforge.com;
    ssl_certificate     /etc/letsencrypt/live/zaforge.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zaforge.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    include /etc/nginx/snippets/security-headers.conf;

    location / {
        proxy_pass http://10.10.10.160:8081;   # nginx static on VM600
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Minimal static server on VM600:

```nginx
# /etc/nginx/sites-available/zaforge-vitrine.conf  (on VM600)
server {
    listen 10.10.10.160:8081;
    server_name zaforge.com;
    root /srv/www/zaforge.com;
    index index.html;

    # Pretty URLs from Astro (trailingSlash: 'ignore')
    location / { try_files $uri $uri/ $uri.html /404.html; }

    # Long-cache fingerprinted assets, no-cache HTML.
    location /assets/ { expires 1y; add_header Cache-Control "public, immutable"; }
    location ~* \.html$ { add_header Cache-Control "no-cache"; }

    error_page 404 /404.html;
}
```

### Option B — serve straight from CT101
If you prefer no VM600 hop, rsync `dist/` to CT101 and point `root` at it,
dropping the `proxy_pass`. Same `try_files` rule.

Reload after validating:

```bash
nginx -t && systemctl reload nginx
certbot certonly --webroot -w /var/www/certbot -d zaforge.com -d www.zaforge.com   # CT101, first issue only
```

---

## 5. Launch checklist

- [ ] All three screenshots present in `public/img/`.
- [ ] `npm run build` clean, `npm run preview` looks right.
- [ ] **Remove `noindex`** before launch: set `NOINDEX = false` in
      `src/consts.ts`, rebuild, redeploy. (It ships `noindex` ON by default.)
- [ ] Plausible domain configured (`PLAUSIBLE_DOMAIN` in `src/consts.ts`) — the
      cookieless script is only emitted when `NOINDEX = false` (i.e. at launch).
- [ ] DNS: `zaforge.com` + `www` → CT101 edge.
- [ ] Replace the privacy/terms placeholder bodies with reviewed legal copy.

---

## Structure

```
vitrine/
  astro.config.mjs
  package.json
  src/
    consts.ts                  Single source of truth: brand, pricing, flags
    layouts/BaseLayout.astro   <head>, noindex, skip-link, Plausible gate
    components/                 Header, Footer, CTAButton, FeatureTag, cards, diagram
    pages/                      index, how-it-works, features, pricing,
                                security, open-source, docs, contact,
                                privacy, terms, 404
    styles/global.css          Amber/dark design tokens + base styles
  public/
    img/                        (operator drops the 3 product PNGs here)
    favicon.svg  robots.txt  site.webmanifest
```

## Honesty policy

Every feature claim on the site is tagged **Live**, **Beta**, or **Roadmap** via
the shared `FeatureTag` component, sourced from `FEATURES` in `consts.ts`. Do
not present Beta/Roadmap items as shipped. The signup is a **waitlist**, not a
live billing flow, because self-serve billing is Roadmap.
