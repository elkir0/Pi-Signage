# ZAFORGE Relay (VM600 — 10.10.10.160)

Multi-tenant fleet control plane for Zaforge devices (Raspberry Pi players).
Three containers, one network namespace, SQLite as the source of truth:

| Service     | Role                                                                 |
|-------------|----------------------------------------------------------------------|
| `wireguard` | `wg0` server (10.70.0.1/16). Owns the netns mosquitto shares.        |
| `mosquitto` | Broker w/ dynamic-security. `1883` on wg0 (in-tunnel, agents); `8883`/TLS on the private IP (fleet-api + future CT101). |
| `fleet-api` | Node control plane: enrollment, WG peer + dynsec provisioning, device fleet, command dispatch. SQLite at `/data/zaforge.db`. |

## Security model (the two CRITICAL isolation guarantees)

1. **No routing of device traffic.** `ip_forward` is pinned OFF on the wireguard
   container (`net.ipv4.ip_forward=0` in `docker-compose.yml`) and the
   linuxserver default MASQUERADE/FORWARD-ACCEPT PostUp is stripped in
   `wireguard/templates/server.conf`. This is a pure control-plane tunnel.

2. **Relay-side tenant isolation (wg0 → wg0 DROP).** The device-side AllowedIPs
   `10.70.0.1/32` is client-enforced and a rooted Pi can rewrite it, so the
   relay enforces isolation itself:
   `iptables -A FORWARD -i wg0 -o wg0 -j DROP` (in `server.conf` PostUp;
   PostDown removes it). Devices reach ONLY the relay services on `10.70.0.1`
   (that traffic is INPUT to the shared netns, not FORWARD), so dropping
   wg0→wg0 FORWARD blocks device↔device entirely.

Other invariants:
- Per-device mosquitto ACLs are **literal** (`zf/<tenant>/<device>/...`) — no
  `%c`/`%u`, no wildcards. The broker owns them; a rooted Pi cannot widen scope.
- WG IP allocator reserves `10.70.0.0/28` (holds the relay `10.70.0.1`); tenant
  `/28` blocks start at `10.70.0.16`. A device `/32` can never equal the relay IP.
- All host-published ports bind to the **private IP** `10.10.10.160` only.
- `1883` is **never** host-published; it lives on `wg0` (in-tunnel only).
- fleet-api ingest keys every DB write on the authenticated
  `mqtt_username → device → tenant` lookup, never on a topic segment.

## Layout

```
relay/
  fleet-api/            Node control plane (better-sqlite3 + mqtt)
    routes/{enroll,admin}.js
    Dockerfile .dockerignore package.json
    config.js ids.js db.js alloc.js wg.js dynsec.js mqtt.js auth.js http.js server.js reconcile.js
  mosquitto/
    config/mosquitto.conf
    data/dynamic-security.json   (PLACEHOLDERS — bootstrapped on the VM)
    certs/README.md              (how to obtain the 8883 TLS cert)
  wireguard/templates/server.conf
  docker-compose.yml             (the SINGLE authoritative compose)
  .env.example                   (PLACEHOLDERS — copy to .env on the VM)
  scripts/{apply-host-dnat.sh,bootstrap-dynsec.sh}
```

## Deploy on VM600 (Debian 13, Docker 26 + compose v2 + buildx)

This relay coexists with the existing skeleton at `/home/deploy/zaforge-relay`.
Deploy from this version-controlled tree.

> **Secrets are generated ON THE VM.** The committed `.env.example` and
> `dynamic-security.json` contain placeholders only.

```bash
# 0) Sync this tree to the VM (from the repo).
rsync -a --delete relay/ deploy@10.10.10.160:/home/deploy/zaforge-relay/

# 1) On VM600: secrets.
cd /home/deploy/zaforge-relay
cp .env.example .env && chmod 600 .env
openssl rand -base64 36                                   # -> DYNSEC_ADMIN_PASSWORD
openssl rand -base64 36                                   # -> MQTT_SVC_PASSWORD
printf 'zfadm_%s\n' "$(openssl rand -base64 36 | tr -d '/+=' | cut -c1-48)"  # -> ADMIN_SECRET
# Edit .env and paste the three values. Leave WG_SERVER_PUBLIC_KEY for step 4.

# 2) TLS for 8883 — see mosquitto/certs/README.md.
#    Place ca.crt / server.crt / server.key in mosquitto/certs/.
#    (GATED: Let's-Encrypt issuance happens on CT101 — do NOT auto-run.)

# 3) Build fleet-api with buildx, then bring up wireguard + mosquitto first.
docker buildx build --load -t zaforge/fleet-api:1.0.0 ./fleet-api
docker compose up -d wireguard mosquitto

# 4) Capture the wg0 server public key and put it in .env, then (re)start fleet-api.
docker exec zf-wireguard wg show wg0 public-key          # -> WG_SERVER_PUBLIC_KEY
sed -i "s|^WG_SERVER_PUBLIC_KEY=.*|WG_SERVER_PUBLIC_KEY=<paste>|" .env

# 5) One-time dynamic-security bootstrap (creates dynsec-admin + svc_fleetapi).
bash scripts/bootstrap-dynsec.sh

# 6) Start (or recreate) fleet-api.
docker compose up -d --force-recreate fleet-api

# 7) Smoke test (private IP, in-host).
curl -s http://10.10.10.160:3200/health        # {"v":1,"status":"ok"}
node fleet-api/alloc.js --selftest             # allocator invariants
```

### GATED steps (operator approval required — do NOT auto-run)

- **Proxmox host DNAT** (`scripts/apply-host-dnat.sh`): adds public UDP `41840`
  → VM600. Run on the Proxmox host (37.187.155.234) only after reviewing it
  against the existing `51820`=VM400 / `51830`=CT220 rules. It is idempotent
  (`iptables -C` before `-A`) and persists with `iptables-save` without flushing
  other rules.
  ```bash
  ssh root@37.187.155.234 'bash -s' < scripts/apply-host-dnat.sh
  ```
- **CT101 TLS issuance / nginx proxy**: certbot for `relay.zaforge.com` and the
  reverse proxy to `10.10.10.160:3200` live on CT101 (10.10.10.101). See
  `mosquitto/certs/README.md`.

## Operations

```bash
# Create a tenant (admin) — returns api_key ONCE.
curl -s -X POST http://10.10.10.160:3200/admin/tenants \
  -H "X-Admin-Secret: $ADMIN_SECRET" -H 'Content-Type: application/json' \
  -d '{"name":"Acme"}'

# Mint an enrollment code for a tenant — returns the plaintext code ONCE.
curl -s -X POST http://10.10.10.160:3200/admin/codes \
  -H "Authorization: Bearer <tenant api_key>" -H 'Content-Type: application/json' \
  -d '{"rebind":false}'

# List / confirm / retire / command devices: /admin/devices[...]
```

On boot, fleet-api **reconciles** wg peers and dynsec roles/clients from SQLite,
rebuilding active devices and **pruning orphan** dynsec `device_*` roles/clients.
