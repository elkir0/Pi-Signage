# Zaforge agent — config file shapes

All files live under `/opt/pisignage/config/`.

## Operator-provisioned (edit these)

### relay.json   (mode 0640 pi:pi)
The operator pastes the enrollment code generated in the console here, then
restarts the agent. Single source of the relay endpoint + bootstrap code.
```json
{
  "relay_url": "https://relay.zaforge.com",
  "enrollment_code": "ZF-7Q2M-K4XR-9TVB",
  "rebind": false
}
```
- `relay_url`     : HTTPS base for POST /enroll (fronted by CT101 later).
- `enrollment_code`: tenant-scoped, single-use, 60-min TTL. Empty = not yet enrolled.
- `rebind`        : if true AND machine_id matches an existing device, keep device_id.

### feature_flags  (append-only KEY=VALUE)
```
ENABLE_KIOSK=1
USE_CHROMIUM_PLAYER=1
ENABLE_RELAY=0      # <- flip to 1 to arm the agent
```

## Already deployed (Phase 0) — agent READS

### agent.json   (mode 0640 pi:www-data)
```json
{ "token": "<>=32-char loopback bridge token>", "created_at": "..." }
```
The agent reads `token` and sends it as `X-Agent-Token` on every loopback call.

## Agent-owned state (mode 0700 dir, 0600 files, pi:pi) — agent WRITES

```
/opt/pisignage/config/relay/
  wg_private.key      # base64 Curve25519 private key, generated once, never leaves the Pi
  wg.json             # VALIDATED data file the root helper consumes (NO secrets, just shape)
  enrollment.json     # persisted /enroll response (+ nonce) so reboots reconnect w/o re-enroll
```

### enrollment.json (shape)
```json
{
  "nonce": "<16-byte base64url>",
  "enrolled_at": 1718970000,
  "response": { ...full /enroll 200 body... }
}
```

### wg.json (shape) — the ONLY thing the privileged helper reads besides the key
The agent stages this STRICTLY-SHAPED data file; it contains NO secret material
(the private key stays in its own 0600 file, referenced by path). The root helper
re-validates every field with a regex before bringing the tunnel up.
```json
{
  "iface": "zf0",
  "address": "10.70.0.42/32",
  "private_key_path": "/opt/pisignage/config/relay/wg_private.key",
  "server_pubkey": "<base64 32-byte wg key>",
  "endpoint": "relay.zaforge.com:51820",
  "allowed_ips": "10.70.0.1/32",
  "keepalive": 25
}
```
- `allowed_ips` MUST be exactly `10.70.0.1/32` (the relay /32). The helper rejects
  anything else — never 0.0.0.0/0, never the customer LAN.

## Privileged bring-up (NO agent-authored conf, NO wg-quick, NO hooks)

The agent NEVER writes `/etc/wireguard/zf0.conf` and NEVER calls `wg-quick`
(wg-quick runs PostUp/PreUp lines as root → a pi-authored conf would be trivial
root). Instead the agent calls, with NO arguments:

```
sudo -n /opt/pisignage/scripts/zaforge-wg-up.sh     # reads wg.json + key, validates, brings zf0 up
sudo -n /opt/pisignage/scripts/zaforge-wg-down.sh   # tears zf0 down
```

Both helpers are `root:root 0755` (invariant: pi-writable would be a root
escalation). They build the interface with `ip(8)` + `wg setconf` from a
root-only `/run/zaforge/zf0.setconf` — no hook surface anywhere. The sudoers
grant is fixed-path and argument-less (no wildcards):
```
pi ALL=(root) NOPASSWD: /opt/pisignage/scripts/zaforge-wg-up.sh, /opt/pisignage/scripts/zaforge-wg-down.sh
```

## CLI
```
zaforge-agent --show-fingerprint   # prints SHA256:.. of the WG pubkey (admin confirm step)
zaforge-agent --version
zaforge-agent                       # normal run (gated by ENABLE_RELAY)
```
