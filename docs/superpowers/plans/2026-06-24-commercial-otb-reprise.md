# Commercial OTB Reprise Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver two Zaforge images, a local free image and a commercial cloud image whose QR onboarding links a non-technical customer to `app.zaforge.com` end-to-end.

**Architecture:** Keep the existing local Pi assistant, relay, and Go agent, but make the commercial path explicit and verifiable. Add image edition flags, finish `BUILD_MODE` for image builds, move long onboarding work behind a root-owned orchestrator, write non-secret local state for kiosk progress, and let `/enroll/provision` create auto-confirming commercial codes.

**Tech Stack:** Bash/POSIX shell, PHP 8.4/FPM, Raspberry Pi OS Desktop Trixie, NetworkManager, systemd, sdm/qemu/Docker, Go agent, Node 20 fleet-api with better-sqlite3.

---

## Source Spec

Read this before executing any task:

- `docs/superpowers/specs/2026-06-24-commercial-otb-reprise-design.md`
- `docs/HANDOFF-CODEX-2026-06-24.md`

Operational constraints:

- Do not run `scripts/firstboot.sh` for real on `192.168.1.92`.
- Do not run `scripts/onboard-ap.sh up` remotely on `.92`; it cuts WiFi SSH.
- Do not re-link `.92` with a real enrollment code.
- On `.92`, copy via `~/`, not `/tmp`, then `sudo install ...`.
- After deploying PHP to `.92`, reload `php8.4-fpm`.
- VM600 relay is production. Recreate only `zf-fleet-api` when needed and expect transient MQTT reconnects.

## File Structure

**Image/install**

- Modify `install.sh`:
  - finish `BUILD_MODE=1`;
  - support `SOURCE_DIR`;
  - support `IMAGE_EDITION=free|commercial`;
  - avoid runtime service actions in chroot;
  - avoid `.provisioned` in image builds.
- Create `scripts/build-image.sh`: build orchestrator for sdm/qemu/pishrink/xz.
- Create `docker/image-builder/Dockerfile`: pinned image-build environment for Mac or VM600.
- Modify `scripts/bake-strip.sh`: preserve edition flags while stripping per-device state.

**First boot and privileged helpers**

- Modify `scripts/firstboot.sh`: commercial-only AP raising; dry-testable `ZF_AP_HELPER`.
- Modify `scripts/onboard-ap.sh`: keep bounded `nmcli -w 20`.
- Modify `scripts/relay-link.sh`: keep code via STDIN; preserve strict relay URL allowlist.
- Create `scripts/commercial-onboard.sh`: root-owned sudo entrypoint with no argv.
- Create `scripts/commercial-onboard-worker.php`: root-executed worker that validates input, applies WiFi, provisions commercial code, links relay, and writes state.

**Web onboarding**

- Modify `web/includes/onboarding.php`: add edition helpers and state readers.
- Modify `web/api/setup.php`: return early to the phone with `link_started`, then run worker after `fastcgi_finish_request()`.
- Modify `web/setup.php`: show phone handoff page and kiosk progress states.
- Modify `install.sh` sudoers block: add fixed grant for `commercial-onboard.sh`.

**Agent**

- Modify `agent/config.go`: add `RelayStatusJSON`.
- Create `agent/status.go`: write non-secret relay status atomically.
- Modify `agent/main.go` and `agent/mqtt.go`: update status on enrollment, MQTT connect, MQTT lost, and fatal retry.

**Relay**

- Modify `relay/fleet-api/db.js`: add migration `008_commercial_auto_confirm`.
- Modify `relay/fleet-api/routes/enroll.js`: commercial provision codes use `auto_confirm=1`; `/enroll` creates active devices when consuming such codes.
- Modify `relay/fleet-api/routes/admin.js`: manual codes stay `auto_confirm=0`.
- Create `relay/fleet-api/tests/enroll-auto-confirm.test.js`: in-memory/temporary DB tests for provision and enroll paths.

**Tests**

- Create `scripts/tests/firstboot-edition.test.sh`.
- Create `scripts/tests/install-build-mode.test.sh`.
- Create `scripts/tests/setup-state.test.sh`.
- Add test commands to the verification section of this plan.

---

### Task 1: Stabilize Existing C2 Hardening

**Files:**
- Modify: `scripts/firstboot.sh`
- Modify: `scripts/onboard-ap.sh`
- Modify: `scripts/tests/wifi-apply.test.sh`

- [ ] **Step 1: Confirm the intended C2 diff is present**

Run:

```bash
git diff -- scripts/firstboot.sh scripts/onboard-ap.sh scripts/tests/wifi-apply.test.sh
```

Expected: diff contains these exact implementation points:

```sh
timeout 10 hostnamectl set-hostname "$HN" 2>/dev/null || true
"$NMCLI" -w 20 con up "$AP_CON" >/dev/null 2>&1 || "$NMCLI" -w 20 con up "$AP_CON" >/dev/null 2>&1 || true
! grep -Eqi "motdepasse|\"psk\"|psk=|key-mgmt" "$STATE"
```

- [ ] **Step 2: Run syntax checks**

Run:

```bash
sh -n scripts/firstboot.sh
sh -n scripts/onboard-ap.sh
sh -n scripts/tests/wifi-apply.test.sh
git diff --check -- scripts/firstboot.sh scripts/onboard-ap.sh scripts/tests/wifi-apply.test.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Commit only the C2 hardening files**

Run:

```bash
git add scripts/firstboot.sh scripts/onboard-ap.sh scripts/tests/wifi-apply.test.sh
git commit -m "fix(image): bound firstboot and onboarding AP waits"
```

Expected: one commit touching only those three files.

---

### Task 2: Finish `BUILD_MODE` in `install.sh`

**Files:**
- Modify: `install.sh`
- Create: `scripts/tests/install-build-mode.test.sh`

- [ ] **Step 1: Replace the `sysd()` wrapper with a build-safe version**

Replace the current `sysd()` function near the top of `install.sh` with:

```bash
sysd() {
    if [ "$BUILD_MODE" = "1" ]; then
        case "${1:-}" in
            enable)
                local args=()
                for a in "$@"; do
                    [ "$a" = "--now" ] && continue
                    args+=("$a")
                done
                sudo systemctl "${args[@]}" 2>/dev/null || true
                ;;
            disable)
                sudo systemctl "$@" 2>/dev/null || true
                ;;
            daemon-reload|reload|restart|start|stop|is-active)
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    else
        sudo systemctl "$@"
    fi
}
```

- [ ] **Step 2: Route runtime service calls through `sysd`**

In `install.sh`, make these replacements:

```diff
-        sudo systemctl daemon-reload 2>/dev/null || true
-        sudo systemctl enable --now pisignage-kiosk-restart.timer 2>/dev/null || true
+        sysd daemon-reload 2>/dev/null || true
+        sysd enable --now pisignage-kiosk-restart.timer 2>/dev/null || true
```

```diff
-            sudo systemctl reload nginx || sudo systemctl restart nginx
+            sysd reload nginx || sysd restart nginx
```

```diff
-        sudo systemctl restart php${PHP_VERSION}-fpm || true
+        sysd restart php${PHP_VERSION}-fpm || true
```

```diff
-        sudo systemctl restart apache2 || true
+        sysd restart apache2 || true
```

```diff
-    sudo systemctl daemon-reload
-    sudo systemctl enable pisignage.service
-    sudo systemctl start pisignage.service || true
+    sysd daemon-reload
+    sysd enable pisignage.service
+    sysd start pisignage.service || true
```

```diff
-        sudo systemctl daemon-reload
-        sudo systemctl enable zaforge-agent.service 2>/dev/null || true
-        sudo systemctl restart zaforge-agent.service 2>/dev/null || true
+        sysd daemon-reload
+        sysd enable zaforge-agent.service 2>/dev/null || true
+        sysd restart zaforge-agent.service 2>/dev/null || true
```

```diff
-        sudo systemctl daemon-reload
-        sudo systemctl enable zaforge-firstboot.service 2>/dev/null || true
+        sysd daemon-reload
+        sysd enable zaforge-firstboot.service 2>/dev/null || true
```

- [ ] **Step 3: Use `SOURCE_DIR` in `clone_from_github()`**

Inside `clone_from_github()`, replace the clone block:

```bash
log_info "Clonage du dépôt PiSignage depuis GitHub..."
TEMP_DIR="/tmp/pisignage-clone-$$"
git clone https://github.com/elkir0/Pi-Signage.git "$TEMP_DIR"
```

with:

```bash
TEMP_DIR="/tmp/pisignage-clone-$$"
if [ -n "$SOURCE_DIR" ]; then
    log_info "Copie du dépôt local depuis SOURCE_DIR=$SOURCE_DIR"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cp -a "$SOURCE_DIR"/. "$TEMP_DIR"/
else
    log_info "Clonage du dépôt PiSignage depuis GitHub..."
    git clone "$GITHUB_REPO" "$TEMP_DIR"
fi
```

- [ ] **Step 4: Skip optional network/build-host actions in `BUILD_MODE`**

In the raspi2png block, before `cd /tmp`, add:

```bash
        if [ "$BUILD_MODE" = "1" ]; then
            log_info "BUILD_MODE=1: installation optionnelle de raspi2png sautée"
            return 0
        fi
```

In `configure_sudo()`, guard the WiFi sync:

```diff
-        sudo "$INSTALL_DIR/scripts/wifi-apply.sh" sync 2>/dev/null || true
+        if [ "$BUILD_MODE" != "1" ]; then
+            sudo "$INSTALL_DIR/scripts/wifi-apply.sh" sync 2>/dev/null || true
+        fi
```

At the beginning of `test_installation()`, after `log_step`, add:

```bash
    if [ "$BUILD_MODE" = "1" ]; then
        log_info "BUILD_MODE=1: tests runtime sautés (pas de systemd/nginx actifs dans le chroot)"
        return 0
    fi
```

Before the final banner IP in `main()`, replace:

```bash
local ip=$(hostname -I | awk '{print $1}')
```

with:

```bash
local ip="127.0.0.1"
if [ "$BUILD_MODE" != "1" ]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -n "$ip" ] || ip="127.0.0.1"
fi
```

- [ ] **Step 5: Do not write `.provisioned` in image builds**

Replace the sentinel write in `install_zaforge_agent()` with:

```bash
    if [ "$BUILD_MODE" = "1" ]; then
        log_info "BUILD_MODE=1: sentinel .provisioned non écrit (firstboot tournera sur l'image)"
    else
        printf 'provisioned-by-install %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | sudo tee "$INSTALL_DIR/config/.provisioned" >/dev/null
        sudo chmod 0644 "$INSTALL_DIR/config/.provisioned"
    fi
```

- [ ] **Step 6: Add a static build-mode test**

Create `scripts/tests/install-build-mode.test.sh`:

```sh
#!/bin/sh
set -u
fail=0
t() { if eval "$2" >/dev/null 2>&1; then echo "ok   - $1"; else echo "FAIL - $1"; fail=$((fail+1)); fi; }

t "install.sh syntax" "bash -n install.sh"
t "sysd exists" "grep -q '^sysd()' install.sh"
t "source_dir path exists" "grep -q 'SOURCE_DIR' install.sh && grep -q 'cp -a \"\\$SOURCE_DIR\"/.' install.sh"
t "wifi sync guarded" "grep -q 'BUILD_MODE\" != \"1\"' install.sh && grep -q 'wifi-apply.sh\" sync' install.sh"
t "sentinel build guard" "grep -q 'sentinel .provisioned non écrit' install.sh"
t "test_installation build skip" "grep -q 'tests runtime sautés' install.sh"

direct_runtime="$(grep -n 'sudo systemctl \\|hostname -I' install.sh | grep -v 'sudoers' | grep -v 'systemctl status' | grep -v 'ExecStart=/usr/bin/systemctl' || true)"
if [ -z "$direct_runtime" ]; then
  echo "ok   - no unguarded direct runtime probes"
else
  echo "$direct_runtime"
  echo "FAIL - unguarded direct runtime probes"
  fail=$((fail+1))
fi

exit "$fail"
```

Run:

```bash
chmod +x scripts/tests/install-build-mode.test.sh
scripts/tests/install-build-mode.test.sh
```

Expected output contains:

```text
ok   - install.sh syntax
ok   - sysd exists
ok   - no unguarded direct runtime probes
```

- [ ] **Step 7: Commit**

Run:

```bash
git add install.sh scripts/tests/install-build-mode.test.sh
git commit -m "feat(image): make install.sh build-mode safe"
```

---

### Task 3: Add Image Build Tooling and Edition Stamping

**Files:**
- Create: `scripts/build-image.sh`
- Create: `docker/image-builder/Dockerfile`
- Modify: `scripts/bake-strip.sh`
- Modify: `install.sh`

- [ ] **Step 1: Add edition parsing to `install.sh`**

Extend the top-level defaults:

```bash
IMAGE_EDITION="${IMAGE_EDITION:-free}"
```

In `main()` argument parsing, add:

```bash
            --edition=free)       export IMAGE_EDITION=free ;;
            --edition=commercial) export IMAGE_EDITION=commercial ;;
```

Add a helper before `main()`:

```bash
write_image_edition() {
    local FF="$INSTALL_DIR/config/feature_flags"
    sudo touch "$FF"
    sudo sed -i '/^ZAFORGE_EDITION=/d;/^ENABLE_COMMERCIAL_ONBOARDING=/d' "$FF" 2>/dev/null || true
    case "$IMAGE_EDITION" in
        commercial)
            {
                echo "ZAFORGE_EDITION=commercial"
                echo "ENABLE_COMMERCIAL_ONBOARDING=1"
            } | sudo tee -a "$FF" >/dev/null
            ;;
        free|"")
            echo "ZAFORGE_EDITION=free" | sudo tee -a "$FF" >/dev/null
            ;;
        *)
            log_error "Edition image invalide: $IMAGE_EDITION"
            exit 1
            ;;
    esac
}
```

Call `write_image_edition` immediately after `create_config`.

- [ ] **Step 2: Stamp edition in `IMAGE_VERSION`**

In `clone_from_github()`, replace the current stamp with:

```bash
printf 'version=%s\nsha=%s\nedition=%s\ndate=%s\n' "$VERSION" "$_sha" "$IMAGE_EDITION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | sudo tee "$INSTALL_DIR/IMAGE_VERSION" >/dev/null
```

- [ ] **Step 3: Create `scripts/build-image.sh`**

Create this executable script:

```sh
#!/bin/sh
set -eu

usage() {
    echo "usage: $0 --edition free|commercial --base-image /path/raspios.img [--out-dir dist/images]" >&2
    exit 2
}

EDITION=""
BASE_IMAGE=""
OUT_DIR="dist/images"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --edition) shift; EDITION="${1:-}" ;;
        --base-image) shift; BASE_IMAGE="${1:-}" ;;
        --out-dir) shift; OUT_DIR="${1:-}" ;;
        *) usage ;;
    esac
    shift || true
done

[ "$EDITION" = "free" ] || [ "$EDITION" = "commercial" ] || usage
[ -n "$BASE_IMAGE" ] && [ -f "$BASE_IMAGE" ] || usage

command -v sdm >/dev/null 2>&1 || { echo "sdm introuvable" >&2; exit 1; }
command -v xz >/dev/null 2>&1 || { echo "xz introuvable" >&2; exit 1; }

mkdir -p "$OUT_DIR" build/image
SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
WORK="build/image/zaforge-${EDITION}-${SHA}.img"
OUT="$OUT_DIR/zaforge-${EDITION}-${SHA}.img.xz"

cp "$BASE_IMAGE" "$WORK"

cat > build/image/zaforge-customize.sh <<'EOS'
#!/bin/sh
set -eu
cd /mnt/zaforge-src
BUILD_MODE=1 SOURCE_DIR=/mnt/zaforge-src HOME=/home/pi bash install.sh --auto --force "--edition=${IMAGE_EDITION}"
EOS
chmod +x build/image/zaforge-customize.sh

sdm --customize \
    --extend --xmb 2048 \
    --mount "$ROOT:/mnt/zaforge-src" \
    --env "IMAGE_EDITION=$EDITION" \
    --script build/image/zaforge-customize.sh \
    "$WORK"

ROOTFS="$(sdm --mount "$WORK" | awk '/mounted/ {print $NF}' | tail -1)"
if [ -n "$ROOTFS" ] && [ -d "$ROOTFS/opt/pisignage" ]; then
    "$ROOT/scripts/bake-strip.sh" "$ROOTFS"
    sdm --umount "$WORK"
else
    sdm --umount "$WORK" >/dev/null 2>&1 || true
    echo "rootfs monté introuvable pour bake-strip" >&2
    exit 1
fi

if command -v pishrink.sh >/dev/null 2>&1; then
    pishrink.sh -s "$WORK"
elif command -v pishrink >/dev/null 2>&1; then
    pishrink -s "$WORK"
else
    echo "pishrink introuvable; image non réduite" >&2
fi

xz -T0 -9 -f "$WORK"
mv "$WORK.xz" "$OUT"
echo "$OUT"
```

- [ ] **Step 4: Create `docker/image-builder/Dockerfile`**

Create:

```dockerfile
FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git jq kmod parted fdisk dosfstools e2fsprogs \
    xz-utils qemu-user-static binfmt-support python3 file sudo rsync \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/gitbls/sdm /opt/sdm \
    && ln -s /opt/sdm/sdm /usr/local/bin/sdm

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
```

- [ ] **Step 5: Preserve edition in `bake-strip.sh`**

After the `feature_flags` `sed` line in `scripts/bake-strip.sh`, add:

```sh
if [ -f "$C/feature_flags" ] && ! grep -q '^ZAFORGE_EDITION=' "$C/feature_flags" 2>/dev/null; then
    echo 'ZAFORGE_EDITION=free' >> "$C/feature_flags" 2>/dev/null || true
fi
```

- [ ] **Step 6: Run static checks**

Run:

```bash
sh -n scripts/build-image.sh
sh -n scripts/bake-strip.sh
bash -n install.sh
docker build --help >/dev/null 2>&1 && DOCKER_BUILDKIT=0 docker build -t zaforge-image-builder docker/image-builder || true
```

Expected:

- shell syntax checks exit `0`;
- Docker build may be skipped on machines without Docker;
- on VM600 use `DOCKER_BUILDKIT=0 docker build`, not `docker compose build`.

- [ ] **Step 7: Commit**

Run:

```bash
git add install.sh scripts/build-image.sh scripts/bake-strip.sh docker/image-builder/Dockerfile
git commit -m "feat(image): add free and commercial image build tooling"
```

---

### Task 4: Make First Boot Edition-Aware

**Files:**
- Modify: `scripts/firstboot.sh`
- Create: `scripts/tests/firstboot-edition.test.sh`

- [ ] **Step 1: Add testable helper overrides and feature flag readers**

At the top of `scripts/firstboot.sh`, replace:

```sh
AP_HELPER="/opt/pisignage/scripts/onboard-ap.sh"
```

with:

```sh
AP_HELPER="${ZF_AP_HELPER:-/opt/pisignage/scripts/onboard-ap.sh}"
```

Add these functions after `rand_hex()`:

```sh
flag_value() {
    key="$1"
    [ -f "$CONF/feature_flags" ] || return 1
    sed -n "s/^${key}=//p" "$CONF/feature_flags" 2>/dev/null | tail -1
}

commercial_onboarding_enabled() {
    edition="$(flag_value ZAFORGE_EDITION || true)"
    commercial="$(flag_value ENABLE_COMMERCIAL_ONBOARDING || true)"
    [ "$edition" = "commercial" ] && [ "$commercial" = "1" ]
}
```

- [ ] **Step 2: Gate AP re-raise by commercial edition**

Replace `reraise_ap()` with:

```sh
reraise_ap() {
    if commercial_onboarding_enabled && [ -f "$CONF/.onboarding" ] && [ ! -f "$CONF/.onboarded" ]; then
        [ "$DRY" = 1 ] || "$AP_HELPER" up >/dev/null 2>&1 || true
        log "onboarding commercial en cours -> AP re-levé"
    fi
}
```

- [ ] **Step 3: Gate initial AP raise by commercial edition**

Replace the final NEED block with:

```sh
NEED=0
WN="$CONF/wifi-networks.json"
{ [ ! -s "$WN" ] || ! grep -q '"ssid"' "$WN" 2>/dev/null; } && NEED=1
CODE="$(sed -n 's/.*"enrollment_code"[^"]*"\([^"]*\)".*/\1/p' "$CONF/relay.json" 2>/dev/null | head -1)"
[ -z "$CODE" ] && NEED=1
if [ "$NEED" = 1 ] && commercial_onboarding_enabled; then
    [ "$DRY" = 1 ] || "$AP_HELPER" up >/dev/null 2>&1 || true
    log "onboarding commercial requis -> AP levé"
elif [ "$NEED" = 1 ]; then
    log "configuration locale requise mais édition non commerciale -> AP commercial non levé"
else
    log "déjà configuré -> kiosk direct"
fi
```

- [ ] **Step 4: Add dry firstboot edition tests**

Create `scripts/tests/firstboot-edition.test.sh`:

```sh
#!/bin/sh
set -u
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fail=0
t() { if eval "$2" >/dev/null 2>&1; then echo "ok   - $1"; else echo "FAIL - $1"; fail=$((fail+1)); fi; }

run_case() {
    edition="$1"
    dir="$(mktemp -d)"
    helper="$dir/ap-helper.sh"
    cat > "$helper" <<'EOS'
#!/bin/sh
echo "$1" >> "$ZF_AP_LOG"
EOS
    chmod +x "$helper"
    if [ "$edition" = "commercial" ]; then
        printf 'ZAFORGE_EDITION=commercial\nENABLE_COMMERCIAL_ONBOARDING=1\n' > "$dir/feature_flags"
    else
        printf 'ZAFORGE_EDITION=free\n' > "$dir/feature_flags"
    fi
    ZF_CONF="$dir" ZF_DRY=0 ZF_AP_HELPER="$helper" ZF_AP_LOG="$dir/ap.log" sh "$ROOT/scripts/firstboot.sh" >/dev/null 2>&1 || true
    if [ "$edition" = "commercial" ]; then
        [ -s "$dir/ap.log" ]
    else
        [ ! -s "$dir/ap.log" ]
    fi
}

t "commercial raises AP" "run_case commercial"
t "free does not raise commercial AP" "run_case free"
t "firstboot syntax" "sh -n scripts/firstboot.sh"

exit "$fail"
```

Run:

```bash
chmod +x scripts/tests/firstboot-edition.test.sh
scripts/tests/firstboot-edition.test.sh
```

Expected:

```text
ok   - commercial raises AP
ok   - free does not raise commercial AP
ok   - firstboot syntax
```

- [ ] **Step 5: Commit**

Run:

```bash
git add scripts/firstboot.sh scripts/tests/firstboot-edition.test.sh
git commit -m "feat(onboarding): gate firstboot QR setup by commercial edition"
```

---

### Task 5: Add Non-Secret Setup State

**Files:**
- Modify: `web/includes/onboarding.php`
- Modify: `web/api/setup.php`
- Modify: `web/setup.php`
- Create: `scripts/tests/setup-state.test.sh`

- [ ] **Step 1: Add state readers to `web/includes/onboarding.php`**

Append:

```php
function zfFeatureFlags() {
    $out = [];
    $file = zfConfigDir() . '/feature_flags';
    if (!is_readable($file)) return $out;
    foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        if ($line === '' || $line[0] === '#' || strpos($line, '=') === false) continue;
        [$k, $v] = explode('=', $line, 2);
        $out[trim($k)] = trim($v);
    }
    return $out;
}

function zfCommercialOnboardingEnabled() {
    $f = zfFeatureFlags();
    return ($f['ZAFORGE_EDITION'] ?? '') === 'commercial'
        && ($f['ENABLE_COMMERCIAL_ONBOARDING'] ?? '') === '1';
}

function zfSetupState() {
    $file = zfConfigDir() . '/setup-state.json';
    if (!is_readable($file)) return [];
    $j = json_decode((string)@file_get_contents($file), true);
    return is_array($j) ? $j : [];
}
```

- [ ] **Step 2: Include setup state in `setupStatus()`**

In `web/api/setup.php`, replace `setupStatus()` with:

```php
function setupStatus() {
    $ap = apStatus();
    $state = function_exists('zfSetupState') ? zfSetupState() : [];
    jsonResponse(true, [
        'onboarding'     => true,
        'commercial'     => function_exists('zfCommercialOnboardingEnabled') ? zfCommercialOnboardingEnabled() : false,
        'phase'          => (string)($state['phase'] ?? 'qr_waiting'),
        'message'        => (string)($state['message'] ?? ''),
        'device_id'      => (string)($state['device_id'] ?? ''),
        'ap_ssid'        => $ap['ap_ssid'],
        'ap_up'          => $ap['ap_up'],
        'clients'        => $ap['clients'],
        'connected_ssid' => connectedSsid(),
    ], 'ok');
}
```

- [ ] **Step 3: Add a state secrecy test**

Create `scripts/tests/setup-state.test.sh`:

```sh
#!/bin/sh
set -u
fail=0
t() { if eval "$2" >/dev/null 2>&1; then echo "ok   - $1"; else echo "FAIL - $1"; fail=$((fail+1)); fi; }

STATE="$(mktemp)"
cat > "$STATE" <<'JSON'
{"edition":"commercial","phase":"link_started","message":"L'écran continue la configuration.","connected_ssid":"Cafe","device_id":"d_abc","updated_at":"2026-06-24T12:00:00Z"}
JSON

t "state has no psk" "! grep -Eqi 'psk|password|motdepasse|enrollment_code|mqtt|wireguard|private' \"$STATE\""
t "state has phase" "grep -q '\"phase\":\"link_started\"' \"$STATE\""
t "onboarding php syntax" "php -l web/includes/onboarding.php >/dev/null"
t "setup api syntax" "php -l web/api/setup.php >/dev/null"

rm -f "$STATE"
exit "$fail"
```

Run:

```bash
chmod +x scripts/tests/setup-state.test.sh
scripts/tests/setup-state.test.sh
```

Expected output contains:

```text
ok   - state has no psk
ok   - onboarding php syntax
ok   - setup api syntax
```

- [ ] **Step 4: Commit**

Run:

```bash
git add web/includes/onboarding.php web/api/setup.php scripts/tests/setup-state.test.sh
git commit -m "feat(onboarding): expose non-secret setup state"
```

---

### Task 6: Add Commercial Onboarding Orchestrator

**Files:**
- Create: `scripts/commercial-onboard.sh`
- Create: `scripts/commercial-onboard-worker.php`
- Modify: `install.sh`
- Modify: `web/api/setup.php`

- [ ] **Step 1: Create root sudo entrypoint**

Create `scripts/commercial-onboard.sh`:

```sh
#!/bin/sh
set -eu
exec /usr/bin/php /opt/pisignage/scripts/commercial-onboard-worker.php
```

- [ ] **Step 2: Create PHP worker with fixed helper paths**

Create `scripts/commercial-onboard-worker.php` with this contract:

```php
#!/usr/bin/env php
<?php
declare(strict_types=1);

const CONF = '/opt/pisignage/config';
const STATE = CONF . '/setup-state.json';
const WIFI_APPLY = '/opt/pisignage/scripts/wifi-apply.sh';
const ONBOARD_AP = '/opt/pisignage/scripts/onboard-ap.sh';
const RELAY_LINK = '/opt/pisignage/scripts/relay-link.sh';
const RELAY_BASE = 'https://relay.zaforge.com';

function write_state(array $state): void {
    $state['updated_at'] = gmdate('c');
    $json = json_encode($state, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $tmp = STATE . '.tmp';
    file_put_contents($tmp, $json . "\n");
    chmod($tmp, 0644);
    rename($tmp, STATE);
}

function fail_state(string $phase, string $message, int $code): void {
    write_state(['edition' => 'commercial', 'phase' => $phase, 'message' => $message]);
    passthru(ONBOARD_AP . ' up >/dev/null 2>&1', $ignored);
    exit($code);
}

function run_stdin(array $argv, string $payload): int {
    $desc = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = proc_open($argv, $desc, $pipes, null, null);
    if (!is_resource($proc)) return 127;
    fwrite($pipes[0], $payload);
    fclose($pipes[0]);
    stream_get_contents($pipes[1]); fclose($pipes[1]);
    stream_get_contents($pipes[2]); fclose($pipes[2]);
    return proc_close($proc);
}

function provision_code(string $email, string $password): ?string {
    $ch = curl_init(RELAY_BASE . '/enroll/provision');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => json_encode(['email' => $email, 'password' => $password]),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 25,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $resp = curl_exec($ch);
    $http = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($http !== 201) return null;
    $j = json_decode((string)$resp, true);
    return is_array($j) && preg_match('/^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/', (string)($j['code'] ?? ''))
        ? (string)$j['code']
        : null;
}

$raw = stream_get_contents(STDIN);
$input = json_decode($raw, true);
if (!is_array($input)) fail_state('failed', 'Configuration invalide.', 2);

$wifiLines = isset($input['wifi_lines']) && is_array($input['wifi_lines']) ? $input['wifi_lines'] : [];
$email = (string)($input['email'] ?? '');
$password = (string)($input['password'] ?? '');
if (!$wifiLines || $email === '' || $password === '') fail_state('failed', 'Informations manquantes.', 2);

write_state(['edition' => 'commercial', 'phase' => 'wifi_applying', 'message' => 'Connexion au WiFi du lieu.']);
passthru(ONBOARD_AP . ' down >/dev/null 2>&1', $ignored);
$rc = run_stdin(['sudo', WIFI_APPLY, 'apply'], implode("\n", $wifiLines) . "\n");
if ($rc !== 0) fail_state('wifi_failed', 'Connexion WiFi non confirmée. Vérifiez le mot de passe.', 3);

write_state(['edition' => 'commercial', 'phase' => 'agent_enrolling', 'message' => 'Liaison au compte Zaforge.']);
$code = provision_code($email, $password);
if ($code === null) fail_state('failed', 'Compte Zaforge refusé ou relais injoignable.', 4);

write_state(['edition' => 'commercial', 'phase' => 'link_started', 'message' => 'Liaison lancée. Continuez dans app.zaforge.com.']);
$rc = run_stdin(['sudo', RELAY_LINK], $code);
if ($rc !== 0) fail_state('failed', 'Liaison au compte échouée.', 5);

write_state(['edition' => 'commercial', 'phase' => 'agent_enrolling', 'message' => 'Connexion de l’écran au cloud Zaforge.']);
exit(0);
```

- [ ] **Step 3: Add sudoers grant and root ownership**

In `install.sh` sudoers heredoc, after `relay-link.sh`, add:

```sudoers
# Onboarding commercial : orchestrateur root sans argument utilisateur ; secrets via stdin.
# INVARIANT : commercial-onboard.sh et commercial-onboard-worker.php DOIVENT rester root:root 0755.
www-data ALL=(root) NOPASSWD: /opt/pisignage/scripts/commercial-onboard.sh
```

In the helper permission loop, change:

```bash
for h in onboard-ap.sh relay-link.sh firstboot.sh bake-strip.sh; do
```

to:

```bash
for h in onboard-ap.sh relay-link.sh firstboot.sh bake-strip.sh commercial-onboard.sh commercial-onboard-worker.php; do
```

- [ ] **Step 4: Modify `web/api/setup.php` to start async work**

Add:

```php
const COMMERCIAL_ONBOARD = '/opt/pisignage/scripts/commercial-onboard.sh';
```

Replace the body of `setupApply()` after validation with:

```php
    if (!function_exists('fastcgi_finish_request')) {
        jsonResponse(false, null, 'Runtime de configuration indisponible.');
    }

    $payload = json_encode([
        'wifi_lines' => $built['lines'],
        'email' => $email,
        'password' => $password,
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

    header('Content-Type: application/json');
    echo json_encode([
        'success' => true,
        'data' => [
            'phase' => 'link_started',
            'app_url' => 'https://app.zaforge.com',
        ],
        'message' => 'Liaison lancée. L’écran continue la configuration.',
        'timestamp' => date('Y-m-d H:i:s'),
    ]);
    fastcgi_finish_request();

    @set_time_limit(180);
    setupRunStdin(['sudo', COMMERCIAL_ONBOARD], $payload ?: '{}');
    exit;
```

Keep code-mode fallback out of this first commercial path; support codes can still use the existing `relay-link.sh` manually from an authenticated/admin surface.

- [ ] **Step 5: Run checks**

Run:

```bash
sh -n scripts/commercial-onboard.sh
php -l scripts/commercial-onboard-worker.php
php -l web/api/setup.php
bash -n install.sh
```

Expected: each command reports no syntax error.

- [ ] **Step 6: Commit**

Run:

```bash
git add install.sh web/api/setup.php scripts/commercial-onboard.sh scripts/commercial-onboard-worker.php
git commit -m "feat(onboarding): add commercial onboarding orchestrator"
```

---

### Task 7: Update Setup UI for Handoff and Progress

**Files:**
- Modify: `web/setup.php`
- Modify: `web/api/setup.php`
- Modify: `web/includes/onboarding.php`

- [ ] **Step 1: Phone view submits once and shows app handoff**

In the phone JavaScript `finish()` success branch, replace the current success text with:

```js
if(d.success){
  msg.className='msg ok';
  msg.innerHTML='Liaison lancée. L’écran continue la configuration.<br><a style="color:var(--ac);font-weight:700" href="https://app.zaforge.com">Continuer dans app.zaforge.com</a>';
  btn.style.display='none';
}
```

Keep the catch branch:

```js
catch(e){ msgErr('Réseau interrompu. Ouvrez app.zaforge.com avec votre connexion normale.'); btn.disabled=false; }
```

- [ ] **Step 2: Kiosk poll uses `phase` and app QR/link**

In kiosk `poll()`, after reading `s=d.data`, map phases:

```js
const phase=s.phase||'qr_waiting';
let step=0, t='En attente de connexion...';
if(s.clients>0){step=1;t='Téléphone connecté. Suivez l’assistant.';}
if(phase==='wifi_applying'){step=2;t='Connexion au WiFi du lieu.';}
if(phase==='link_started'||phase==='agent_enrolling'){step=2;t='Liaison au compte Zaforge en cours.';}
if(phase==='cloud_visible'||phase==='done'){step=2;t='Votre écran est visible dans Zaforge. Continuez dans app.zaforge.com.';}
if(phase==='cloud_delayed'){step=2;t='La connexion prend plus de temps que prévu. Ouvrez app.zaforge.com ou contactez le support.';}
if(phase==='wifi_failed'||phase==='failed'){step=1;t=s.message||'Configuration interrompue. Rejoignez le QR et réessayez.';}
```

Add an app link block in the kiosk card:

```html
<div class="pw"><div class="l">Console Zaforge</div><div class="v" style="font-size:15px">app.zaforge.com</div></div>
```

- [ ] **Step 3: Avoid cloud jargon**

Run:

```bash
rg -n "relay\\.json|WireGuard|MQTT|systemd|pending|enrollment|sudo" web/setup.php web/api/setup.php
```

Expected: no output in customer-visible strings.

- [ ] **Step 4: Run syntax**

Run:

```bash
php -l web/setup.php
php -l web/api/setup.php
```

Expected: both report no syntax errors.

- [ ] **Step 5: Commit**

Run:

```bash
git add web/setup.php web/api/setup.php web/includes/onboarding.php
git commit -m "feat(onboarding): guide commercial setup handoff"
```

---

### Task 8: Write Non-Secret Relay Status from the Agent

**Files:**
- Modify: `agent/config.go`
- Create: `agent/status.go`
- Modify: `agent/main.go`
- Modify: `agent/mqtt.go`
- Test: `agent/status_test.go`

- [ ] **Step 1: Add status path**

In `agent/config.go`, add to `Paths`:

```go
RelayStatusJSON string // .../relay-status.json (0644, non-secret, read by kiosk PHP)
```

In `resolvePaths()`, set:

```go
RelayStatusJSON: filepath.Join(dir, "relay-status.json"),
```

Do not put this file inside `config/relay/`; that directory is 0700 and holds secrets.

- [ ] **Step 2: Create `agent/status.go`**

```go
package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

type relayStatus struct {
	Enabled              bool   `json:"enabled"`
	Enrolled             bool   `json:"enrolled"`
	DeviceID             string `json:"device_id"`
	MQTTConnected         bool   `json:"mqtt_connected"`
	LastCloudConnectedAt string `json:"last_cloud_connected_at"`
	LastError            string `json:"last_error"`
}

func writeRelayStatus(path string, st relayStatus) error {
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	b = append(b, '\n')
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	return atomicWrite(path, b, 0644)
}

func cloudNow() string {
	return time.Now().UTC().Format(time.RFC3339)
}
```

- [ ] **Step 3: Add callbacks to MQTT connect**

Change `connectMQTT` signature in `agent/mqtt.go`:

```go
func connectMQTT(cfg EnrollMQTT, onCmd func(commandEnvelope), onConnected func(), onLost func(error)) (*MQTTAgent, error) {
```

Inside `SetOnConnectHandler`, after publishing online status:

```go
if onConnected != nil {
	onConnected()
}
```

Inside `SetConnectionLostHandler`, after logging:

```go
if onLost != nil {
	onLost(err)
}
```

- [ ] **Step 4: Update `runSession`**

Before `connectMQTT`, add:

```go
_ = writeRelayStatus(paths.RelayStatusJSON, relayStatus{
	Enabled:  true,
	Enrolled: true,
	DeviceID: er.DeviceID,
	LastError: "",
})
```

Replace the `connectMQTT` call with:

```go
mqttAgent, err = connectMQTT(er.MQTT, onCmd,
	func() {
		_ = writeRelayStatus(paths.RelayStatusJSON, relayStatus{
			Enabled: true, Enrolled: true, DeviceID: er.DeviceID,
			MQTTConnected: true, LastCloudConnectedAt: cloudNow(), LastError: "",
		})
	},
	func(e error) {
		_ = writeRelayStatus(paths.RelayStatusJSON, relayStatus{
			Enabled: true, Enrolled: true, DeviceID: er.DeviceID,
			MQTTConnected: false, LastError: e.Error(),
		})
	})
```

When `runSession` returns an error in `main()`, before sleeping, write:

```go
_ = writeRelayStatus(paths.RelayStatusJSON, relayStatus{
	Enabled: enableRelay(paths.FeatureFlags),
	LastError: err.Error(),
})
```

- [ ] **Step 5: Add status writer test**

Create `agent/status_test.go`:

```go
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteRelayStatusIsNonSecretAndReadable(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "relay-status.json")
	err := writeRelayStatus(path, relayStatus{
		Enabled: true, Enrolled: true, DeviceID: "d_test",
		MQTTConnected: true, LastCloudConnectedAt: "2026-06-24T12:00:00Z",
	})
	if err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	for _, forbidden := range []string{"password", "private", "enrollment_code", "mqtt_password", "wireguard"} {
		if strings.Contains(strings.ToLower(s), forbidden) {
			t.Fatalf("status contains forbidden token %q: %s", forbidden, s)
		}
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0644 {
		t.Fatalf("mode=%o want 0644", info.Mode().Perm())
	}
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
cd agent && go test ./...
```

Expected: `ok` for the package. If the local Mac kills the Go compiler with `signal: killed`, rerun on the Raspberry Pi or VM600 and record that environment in the final notes.

- [ ] **Step 7: Commit**

Run:

```bash
git add agent/config.go agent/status.go agent/main.go agent/mqtt.go agent/status_test.go
git commit -m "feat(agent): publish non-secret cloud linkage status"
```

---

### Task 9: Make Commercial Provision Codes Auto-Confirm

**Files:**
- Modify: `relay/fleet-api/db.js`
- Modify: `relay/fleet-api/routes/enroll.js`
- Modify: `relay/fleet-api/routes/admin.js`
- Create: `relay/fleet-api/tests/enroll-auto-confirm.test.js`
- Modify: `relay/fleet-api/package.json`

- [ ] **Step 1: Add append-only migration**

In `relay/fleet-api/db.js`, append migration:

```js
  {
    name: '008_commercial_auto_confirm',
    sql: `
    ALTER TABLE enrollment_codes ADD COLUMN auto_confirm INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE enrollment_codes ADD COLUMN source TEXT NOT NULL DEFAULT 'manual';
    `
  }
```

- [ ] **Step 2: Mark `/enroll/provision` codes commercial**

In `routes/enroll.js`, replace the insert in `provision()` with:

```js
  get().prepare(`INSERT INTO enrollment_codes(code_hash, tenant_id, rebind, auto_confirm, source, created_at, expires_at)
    VALUES (?,?,?,?,?,?,?)`).run(ids.sha256hex(code), tenantId, 0, 1, 'commercial_onboarding', ts, ts + ttl);
  return send(res, 201, { v: 1, code, expires_at: ts + ttl, auto_confirm: true });
```

- [ ] **Step 3: Activate devices consumed from auto-confirm codes**

In the fresh enroll insert in `handle()`, replace:

```js
VALUES (?,?,'pending',?,?,?,?,?,?,?,?,?,?,0,?,?)
```

with:

```js
VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?,?)
```

and pass state and confirmed timestamp explicitly:

```js
const initialState = code.auto_confirm === 1 ? 'active' : 'pending';
const confirmedAt = code.auto_confirm === 1 ? ts : null;
```

Use an insert statement with `confirmed_at`:

```js
db.prepare(`INSERT INTO devices(
  device_id, tenant_id, state, confirmed_at, hostname, machine_id, model, player_version,
  agent_version, wg_public_key, wg_ip, fingerprint, mqtt_username, mqtt_pw_fp,
  online, last_facts_json, created_at)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?,?)`)
  .run(deviceId, tenantId, initialState, confirmedAt, facts.hostname || null, facts.machine_id || null,
    facts.model || null, facts.player_version || null,
    (b.agent && b.agent.version) || null, b.wg_public_key, ip, fingerprint,
    deviceId, mqttPwFp, JSON.stringify(facts), ts);
```

In the event payload, include:

```js
JSON.stringify({ rebind, ip: dev.wg_ip, auto_confirm: code.auto_confirm === 1, source: code.source || 'manual' })
```

- [ ] **Step 4: Keep admin codes manual**

In `routes/admin.js`, keep the existing insert valid through defaults. Add `auto_confirm: false` to the response:

```js
return send(res, 201, { v: 1, code, tenant_id: tenantId, expires_at: ts + ttl, rebind: rebind === 1, auto_confirm: false });
```

- [ ] **Step 5: Add test script to `package.json`**

Add:

```json
"test:auto-confirm": "node tests/enroll-auto-confirm.test.js"
```

under `scripts`.

- [ ] **Step 6: Create relay auto-confirm test**

Create `relay/fleet-api/tests/enroll-auto-confirm.test.js`:

```js
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zf-relay-test-'));
process.env.DB_PATH = path.join(tmp, 'zaforge.db');
process.env.ADMIN_SECRET = 'zfadm_test_secret_123456789012345678901234567890123456789012';
process.env.WG_SERVER_PUBLIC_KEY = Buffer.alloc(32, 1).toString('base64');
process.env.MQTT_SVC_PASSWORD = 'mqttsvc';
process.env.DYNSEC_ADMIN_PASSWORD = 'dynsec';

const db = require('../db');
const ids = require('../ids');

db.init();
const d = db.get();
const ts = Math.floor(Date.now() / 1000);
d.prepare("INSERT INTO tenants(tenant_id,name,status,created_at,managed_state) VALUES ('t_test','Test','active',?,'managed-on')").run(ts);

const commercial = ids.newEnrollmentCode();
d.prepare(`INSERT INTO enrollment_codes(code_hash,tenant_id,rebind,auto_confirm,source,created_at,expires_at)
  VALUES (?,?,?,?,?,?,?)`).run(ids.sha256hex(commercial), 't_test', 0, 1, 'commercial_onboarding', ts, ts + 3600);
const manual = ids.newEnrollmentCode();
d.prepare(`INSERT INTO enrollment_codes(code_hash,tenant_id,rebind,created_at,expires_at)
  VALUES (?,?,?,?,?)`).run(ids.sha256hex(manual), 't_test', 0, ts, ts + 3600);

const c = d.prepare('SELECT auto_confirm, source FROM enrollment_codes WHERE code_hash=?').get(ids.sha256hex(commercial));
assert.strictEqual(c.auto_confirm, 1);
assert.strictEqual(c.source, 'commercial_onboarding');
const m = d.prepare('SELECT auto_confirm, source FROM enrollment_codes WHERE code_hash=?').get(ids.sha256hex(manual));
assert.strictEqual(m.auto_confirm, 0);
assert.strictEqual(m.source, 'manual');

console.log('auto-confirm schema ok');
```

- [ ] **Step 7: Run relay checks**

Run:

```bash
cd relay/fleet-api
node --check db.js
node --check routes/enroll.js
node --check routes/admin.js
npm run test:auto-confirm
```

Expected:

```text
auto-confirm schema ok
```

- [ ] **Step 8: Commit**

Run:

```bash
git add relay/fleet-api/db.js relay/fleet-api/routes/enroll.js relay/fleet-api/routes/admin.js relay/fleet-api/tests/enroll-auto-confirm.test.js relay/fleet-api/package.json
git commit -m "feat(relay): auto-confirm commercial onboarding enrollments"
```

---

### Task 10: Connect Kiosk Progress to Agent Cloud Status

**Files:**
- Modify: `web/includes/onboarding.php`
- Modify: `web/api/setup.php`
- Modify: `web/setup.php`

- [ ] **Step 1: Read `relay-status.json` in PHP**

Add to `web/includes/onboarding.php`:

```php
function zfRelayStatus() {
    $file = zfConfigDir() . '/relay-status.json';
    if (!is_readable($file)) return [];
    $j = json_decode((string)@file_get_contents($file), true);
    return is_array($j) ? $j : [];
}

function zfCloudVisible() {
    $s = zfRelayStatus();
    if (empty($s['enrolled']) || empty($s['device_id'])) return false;
    if (!empty($s['mqtt_connected'])) return true;
    $last = strtotime((string)($s['last_cloud_connected_at'] ?? ''));
    return $last !== false && (time() - $last) < 180;
}
```

- [ ] **Step 2: Merge cloud visibility into setup status**

In `setupStatus()`, after reading `$state`, add:

```php
$cloudVisible = function_exists('zfCloudVisible') ? zfCloudVisible() : false;
$relayStatus = function_exists('zfRelayStatus') ? zfRelayStatus() : [];
$phase = (string)($state['phase'] ?? 'qr_waiting');
if ($cloudVisible) $phase = 'cloud_visible';
```

Return:

```php
'phase' => $phase,
'device_id' => (string)($relayStatus['device_id'] ?? ($state['device_id'] ?? '')),
```

- [ ] **Step 3: Finalize only after cloud visible**

In `setupStatus()`, if `$cloudVisible` and `.onboarded` is absent, call:

```php
executeCommand(['sudo', ONBOARD_AP, 'finalize']);
```

Do not call finalize from `commercial-onboard-worker.php`; that worker only reaches `agent_enrolling`.

- [ ] **Step 4: Run checks**

Run:

```bash
php -l web/includes/onboarding.php
php -l web/api/setup.php
php -l web/setup.php
rg -n "cloud_visible|relay-status" web/includes/onboarding.php web/api/setup.php web/setup.php
```

Expected: syntax passes and `rg` shows the new code paths.

- [ ] **Step 5: Commit**

Run:

```bash
git add web/includes/onboarding.php web/api/setup.php web/setup.php
git commit -m "feat(onboarding): confirm setup when cloud status is visible"
```

---

### Task 11: Full Verification Pass

**Files:**
- No new files unless failures require fixes.

- [ ] **Step 1: Run local static tests**

Run:

```bash
bash -n install.sh
sh -n scripts/firstboot.sh scripts/onboard-ap.sh scripts/bake-strip.sh scripts/relay-link.sh scripts/commercial-onboard.sh scripts/build-image.sh
php -l web/api/setup.php
php -l web/setup.php
php -l web/includes/onboarding.php
php -l scripts/commercial-onboard-worker.php
scripts/tests/install-build-mode.test.sh
scripts/tests/firstboot-edition.test.sh
scripts/tests/setup-state.test.sh
php web/api/tests/wifi-lib.test.php
cd relay/fleet-api && npm run test:auto-confirm
```

Expected: all commands exit `0`.

- [ ] **Step 2: Run Go tests where resources allow**

Run:

```bash
cd agent && go test ./...
```

Expected: package passes. If the local machine reports `go: error obtaining buildID for go tool compile: signal: killed`, rerun on `.92` or VM600 and record that result.

- [ ] **Step 3: Run adversarial review checklist inline**

Check these invariants manually and record pass/fail in the implementation notes:

```text
1. No customer-visible string contains relay.json, WireGuard, MQTT, systemd, pending, enrollment, sudo.
2. No setup-state or relay-status file contains WiFi PSK, Zaforge password, enrollment code, MQTT password, WG private key.
3. Every sudo-granted helper is root:root 0755 and has fixed sudoers arguments.
4. commercial-onboard secrets enter through STDIN only.
5. free edition firstboot never raises the commercial AP.
6. commercial edition firstboot raises AP only when .onboarded is absent.
7. .onboarded is written only after local cloud visibility is true.
8. /enroll/provision creates auto_confirm=1 codes.
9. /admin/codes creates auto_confirm=0 codes.
10. Relay devices from commercial codes become active; manual codes remain pending.
```

- [ ] **Step 4: Commit verification fixes**

If fixes were required, inspect the exact modified files first:

```bash
git status --short
git diff --check
git add install.sh scripts/firstboot.sh scripts/onboard-ap.sh scripts/commercial-onboard.sh scripts/commercial-onboard-worker.php web/includes/onboarding.php web/api/setup.php web/setup.php agent/config.go agent/status.go agent/main.go agent/mqtt.go relay/fleet-api/db.js relay/fleet-api/routes/enroll.js relay/fleet-api/routes/admin.js
git commit -m "fix(onboarding): harden commercial OTB verification findings"
```

If `git status --short` shows a different fixed file, add that exact file instead of the broad command above. If no fixes were required, do not create an empty commit.

---

### Task 12: Safe Deployment and Physical Test Handoff

**Files:**
- Modify only if deployment reveals a fix.

- [ ] **Step 1: Deploy only safe non-AP files to `.92`**

Do not run AP or firstboot for real. For PHP changes:

```bash
scp web/api/setup.php pi@192.168.1.92:~/setup-api.php
scp web/setup.php pi@192.168.1.92:~/setup-page.php
scp web/includes/onboarding.php pi@192.168.1.92:~/onboarding-include.php
ssh pi@192.168.1.92 'echo palmer00 | sudo -S -v && sudo install -o www-data -g www-data -m 0644 ~/setup-api.php /opt/pisignage/web/api/setup.php && sudo install -o www-data -g www-data -m 0644 ~/setup-page.php /opt/pisignage/web/setup.php && sudo install -o www-data -g www-data -m 0644 ~/onboarding-include.php /opt/pisignage/web/includes/onboarding.php && sudo systemctl reload php8.4-fpm'
```

- [ ] **Step 2: Deploy relay change to VM600 only after review**

Build with Docker classic builder:

```bash
ssh -J root@37.187.155.234 deploy@10.10.10.160 'cd /home/deploy/zaforge-relay && DOCKER_BUILDKIT=0 docker build -t zaforge/fleet-api:1.0.0 ./fleet-api'
```

Then recreate only fleet-api:

```bash
ssh -J root@37.187.155.234 deploy@10.10.10.160 'cd /home/deploy/zaforge-relay && docker compose up -d --force-recreate fleet-api'
```

Expected: devices may transiently reconnect; no other containers are touched.

- [ ] **Step 3: Physical test checklist for owner**

Run on a spare Pi or freshly flashed SD, not the live `.92`:

```text
1. Flash commercial image.
2. Boot Pi with screen attached.
3. Confirm QR Zaforge setup is shown.
4. Scan QR with phone.
5. Submit wrong WiFi password; confirm AP returns and message is clear.
6. Submit valid WiFi and valid Zaforge account.
7. Confirm phone shows "liaison lancée" plus app.zaforge.com link before AP drops.
8. Confirm screen changes to cloud progress.
9. Confirm app.zaforge.com shows the device active and online.
10. Send a screenshot or reload command from app.zaforge.com.
11. Reboot Pi; confirm it does not return to setup.
12. Flash free image; confirm no commercial QR is forced.
```

- [ ] **Step 4: Final commit or release note**

If physical tests pass, create a final docs note:

```bash
git add docs/DEPLOYMENT-TEST-REPORT.md
git commit -m "docs(test): record commercial OTB physical validation"
```

If physical tests fail, commit the fix with a `fix(...)` message before updating the report.

---

## Self-Review

Spec coverage:

- Two images and edition split: Tasks 3 and 4.
- Commercial QR through local Pi assistant: Tasks 4, 6, 7.
- Phone handoff before AP down: Tasks 6 and 7.
- Non-secret setup state and cloud visibility: Tasks 5, 8, 10.
- Auto-confirm commercial devices: Task 9.
- C1 image build: Tasks 2 and 3.
- C2 hardening: Task 1.
- Tests and safe deployment: Tasks 11 and 12.

Type/name consistency:

- `ZAFORGE_EDITION`, `ENABLE_COMMERCIAL_ONBOARDING`, `ENABLE_RELAY` are the only feature flags introduced or changed.
- `setup-state.json` is written by root helpers and read by PHP.
- `relay-status.json` is written by the agent as mode `0644` outside the secret `relay/` directory.
- Commercial provisioning source is `commercial_onboarding`.

Risk notes:

- The plan intentionally does not run AP or firstboot for real on `.92`.
- The plan changes relay DB schema append-only via migration `008_commercial_auto_confirm`.
- The plan keeps manual/admin enrollment codes pending.
