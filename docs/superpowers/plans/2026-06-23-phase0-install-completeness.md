# Phase 0 — install.sh completeness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, ultracode). Steps use `- [ ]`.
> Prerequisite for B (onboarding) + C (image). Spec: `docs/superpowers/specs/2026-06-23-onboarding-and-image-design.md`.

**Goal:** Make a normal `bash install.sh` produce a COMPLETE Zaforge box: the fleet agent built+installed, the relay-proxy-secret provisioned, the B/C runtime packages present, and a single reconciled version stamped.

**Architecture:** Wire the existing-but-orphaned `deploy/install-snippet.sh` logic into `install.sh` as `install_zaforge_agent` (copy agent source during clone, build with Go, deploy relay.json/feature_flags/systemd). Add `provision_relay_proxy_secret`. Add B/C packages. Reconcile VERSION across files and stamp `/opt/pisignage/IMAGE_VERSION`. (The chroot `BUILD_MODE` guard is Phase C1, not here.)

**Tech Stack:** POSIX/bash `install.sh`, Go (agent build), systemd, openssl, apt.

---

## File Structure

- **Modify** `install.sh` — `clone_from_github` (copy agent source), `install_dependencies` (packages), new `install_zaforge_agent`, new `provision_relay_proxy_secret`, version reconciliation + `IMAGE_VERSION` stamp, `main()` wiring.
- **Modify** `VERSION` — align to `v0.12.4` (match `web/version.php`, the single source of truth for the product version).
- **Reuse** `deploy/install-snippet.sh` (logic source), `deploy/systemd/zaforge-agent.service`, `agent/*.go`, `scripts/zaforge-wg-*.sh`.

---

## Task 1: Reconcile the product version

**Files:** Modify `VERSION`, `install.sh:17`

- [ ] **Step 1 — Align the VERSION file** to the product version in `web/version.php` (`v0.12.4`). Overwrite `VERSION` with:

```
v0.12.4
```

- [ ] **Step 2 — Align the install.sh banner version** (`install.sh:17` `VERSION="0.12.0"`):

```bash
VERSION="0.12.4"
```

- [ ] **Step 3 — Verify they match version.php**

Run: `grep -o '0\.12\.[0-9]*' VERSION web/version.php; grep '^VERSION=' install.sh`
Expected: all show `0.12.4`.

- [ ] **Step 4 — Commit**: `git add VERSION install.sh && git commit -m "fix(version): reconcile VERSION/install.sh to v0.12.4 (match version.php)"`

---

## Task 2: Add B/C runtime packages to install_dependencies

**Files:** Modify `install.sh` (the apt install list in `install_dependencies`)

- [ ] **Step 1 — Locate the package list**

Run: `grep -n "apt.*install\|PACKAGES\|network-manager\|dnsmasq" install.sh | head`
Read the `install_dependencies` function to find the exact apt line.

- [ ] **Step 2 — Ensure these packages are in the install list** (add any missing to the existing apt-get install invocation): `network-manager` (WiFi/AP via nmcli — confirm present), `dnsmasq-base` (NM shared-mode DHCP/DNS for the onboarding AP), `qrencode` (server-side QR fallback), `golang-go` (build the agent). Edit the apt list to include them, e.g. append `network-manager dnsmasq-base qrencode golang-go` to the package string.

- [ ] **Step 3 — Verify syntax**: `bash -n install.sh` → no errors.

- [ ] **Step 4 — Commit**: `git add install.sh && git commit -m "feat(install): add network-manager/dnsmasq-base/qrencode/golang-go for onboarding+agent"`

---

## Task 3: Copy agent source during clone_from_github

**Files:** Modify `install.sh` (`clone_from_github`, near the `scripts/` copy ~line 452)

- [ ] **Step 1 — Add agent-source copy** right after the `scripts/` copy (`sudo cp -r "$TEMP_DIR/scripts"/* ...`). The agent build needs `agent/`, `deploy/`, `go.mod`, `go.sum` persisted (TEMP_DIR is removed at the end of clone):

```bash
        # Persister la source de l'agent (Go) pour install_zaforge_agent (build après clone).
        sudo rm -rf "$INSTALL_DIR/agent-src"
        sudo mkdir -p "$INSTALL_DIR/agent-src/agent" "$INSTALL_DIR/agent-src/scripts" "$INSTALL_DIR/agent-src/deploy"
        sudo cp -r "$TEMP_DIR/agent"/*       "$INSTALL_DIR/agent-src/agent/"   2>/dev/null || true
        sudo cp -r "$TEMP_DIR/scripts"/*     "$INSTALL_DIR/agent-src/scripts/" 2>/dev/null || true
        sudo cp -r "$TEMP_DIR/deploy"/*      "$INSTALL_DIR/agent-src/deploy/"  2>/dev/null || true
        [ -f "$TEMP_DIR/go.mod" ] && sudo cp "$TEMP_DIR/go.mod" "$INSTALL_DIR/agent-src/" 2>/dev/null || true
        [ -f "$TEMP_DIR/go.sum" ] && sudo cp "$TEMP_DIR/go.sum" "$INSTALL_DIR/agent-src/" 2>/dev/null || true
```

  Note: `go.mod` lives at `agent/go.mod` (module is the `agent` package). Verify with `cat agent/go.mod` and adjust the build dir in Task 4 accordingly (build `./` inside `agent-src/agent` if go.mod is there, or `./agent` if at root).

- [ ] **Step 2 — Verify syntax**: `bash -n install.sh` → no errors.

- [ ] **Step 3 — Commit**: `git add install.sh && git commit -m "feat(install): persist agent source to /opt/pisignage/agent-src during clone"`

---

## Task 4: Define + wire install_zaforge_agent

**Files:** Modify `install.sh` (new function before `main()`, call in `main()`)

- [ ] **Step 1 — Add the function** (adapted from `deploy/install-snippet.sh`; AGENT_SRC_DIR = the persisted source; build dir matches where `go.mod` is; WG helpers already deployed root:root by `configure_sudo`, here we only ensure ownership; systemd via the real systemctl since Phase 0 = normal install):

```bash
# Construit + installe l'agent de flotte Zaforge (zaforge-agent). Idempotent.
# Le binaire est buildé depuis /opt/pisignage/agent-src (persisté au clone).
install_zaforge_agent() {
    log_step "Installation de l'agent Zaforge"
    local SRC="$INSTALL_DIR/agent-src"
    # Le module Go vit dans agent/ (go.mod y est) -> on build le package du répertoire courant.
    local BUILDDIR="$SRC/agent"
    [ -f "$SRC/go.mod" ] && BUILDDIR="$SRC"

    sudo mkdir -p "$INSTALL_DIR/bin"
    if command -v go >/dev/null 2>&1 && [ -d "$BUILDDIR" ]; then
        if ( cd "$BUILDDIR" && sudo env CGO_ENABLED=0 HOME=/root go build -trimpath -o /tmp/zaforge-agent . ); then
            sudo install -o root -g root -m 0755 /tmp/zaforge-agent "$INSTALL_DIR/bin/zaforge-agent"
            sudo rm -f /tmp/zaforge-agent
            log_info "agent buildé -> $INSTALL_DIR/bin/zaforge-agent"
        else
            log_warning "build agent échoué — binaire non installé (l'agent restera inactif)"
        fi
    else
        log_warning "'go' absent ou source manquante — agent non buildé (copier un binaire arm64 dans $INSTALL_DIR/bin/zaforge-agent)"
    fi

    # relay.json (gabarit ; enrollment_code rempli à l'onboarding/console). 0640 pi:pi.
    if [ ! -f "$INSTALL_DIR/config/relay.json" ]; then
        sudo tee "$INSTALL_DIR/config/relay.json" >/dev/null <<'RELAYJSON'
{
  "relay_url": "https://relay.zaforge.com",
  "enrollment_code": "",
  "rebind": false
}
RELAYJSON
        sudo chown pi:pi "$INSTALL_DIR/config/relay.json"
        sudo chmod 0640 "$INSTALL_DIR/config/relay.json"
    fi

    # Répertoire d'état WG possédé par l'agent (pi), 0700.
    sudo mkdir -p "$INSTALL_DIR/config/relay"
    sudo chown pi:pi "$INSTALL_DIR/config/relay"
    sudo chmod 0700 "$INSTALL_DIR/config/relay"

    # Invariant sécurité : helpers WG root:root 0755 (déjà déployés via scripts/ + configure_sudo).
    for h in zaforge-wg-up.sh zaforge-wg-down.sh; do
        if [ -f "$INSTALL_DIR/scripts/$h" ]; then
            sudo chown root:root "$INSTALL_DIR/scripts/$h"; sudo chmod 0755 "$INSTALL_DIR/scripts/$h"
        fi
    done

    # feature flag par défaut OFF (l'agent s'auto-arrête tant que ENABLE_RELAY=0).
    local FF="$INSTALL_DIR/config/feature_flags"
    sudo touch "$FF"
    if ! sudo grep -q '^ENABLE_RELAY=' "$FF" 2>/dev/null; then
        echo 'ENABLE_RELAY=0' | sudo tee -a "$FF" >/dev/null
    fi

    # Unité systemd (activée ; self-exit tant que ENABLE_RELAY=0).
    if [ -f "$SRC/deploy/systemd/zaforge-agent.service" ]; then
        sudo install -o root -g root -m 0644 "$SRC/deploy/systemd/zaforge-agent.service" /etc/systemd/system/zaforge-agent.service
        sudo systemctl daemon-reload
        sudo systemctl enable zaforge-agent.service 2>/dev/null || true
        sudo systemctl restart zaforge-agent.service 2>/dev/null || true
        log_info "service zaforge-agent installé + activé (ENABLE_RELAY=0 -> dormant)"
    else
        log_warning "unité zaforge-agent.service introuvable dans $SRC/deploy/systemd"
    fi
}
```

- [ ] **Step 2 — Call it in `main()`** right after `provision_agent_token`:

```bash
    provision_agent_token
    install_zaforge_agent
```

- [ ] **Step 3 — Verify syntax**: `bash -n install.sh` → no errors.

- [ ] **Step 4 — Verify the agent compiles** (cross-compile arm64 on the dev machine, proves the build step is sound without touching the live box):

Run: `cd /Users/anthony/pisignage && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -o /tmp/zaforge-agent ./agent && echo BUILD_OK && rm -f /tmp/zaforge-agent`
Expected: `BUILD_OK` (if `go` isn't on the Mac, run the build inside the agent dir per its go.mod location; if no Go locally, defer this check to the .92 verification).

- [ ] **Step 5 — Commit**: `git add install.sh && git commit -m "feat(install): define+wire install_zaforge_agent (build+deploy agent, relay.json, systemd)"`

---

## Task 5: Provision relay-proxy-secret

**Files:** Modify `install.sh` (new `provision_relay_proxy_secret`, call in `main()`)

- [ ] **Step 1 — Add the function** (mirrors `provision_agent_token`; consumed by `web/includes/auth.php:40` for the mode-complet bridge; 0640 root:www-data so php-fpm reads it but not world):

```bash
# Provisionne le secret du pont proxy "mode complet" (lu par auth.php). Idempotent.
# Per-device : pour l'image, firstboot.sh le régénère (Phase C2) ; ici on le crée pour une install normale.
provision_relay_proxy_secret() {
    local F="$INSTALL_DIR/config/relay-proxy-secret"
    if [ ! -s "$F" ]; then
        openssl rand -hex 32 | sudo tee "$F" >/dev/null
        sudo chown root:www-data "$F"
        sudo chmod 0640 "$F"
        log_info "relay-proxy-secret généré"
    fi
}
```

- [ ] **Step 2 — Call it in `main()`** right after `install_zaforge_agent`:

```bash
    install_zaforge_agent
    provision_relay_proxy_secret
```

- [ ] **Step 3 — Verify syntax**: `bash -n install.sh` → no errors.

- [ ] **Step 4 — Commit**: `git add install.sh && git commit -m "feat(install): provision relay-proxy-secret (mode-complet bridge dep)"`

---

## Task 6: Stamp IMAGE_VERSION (version + git SHA)

**Files:** Modify `install.sh` (stamp in `clone_from_github` after deploy, or a small step)

- [ ] **Step 1 — Stamp the deployed version + SHA** for fleet traceability. In `clone_from_github`, after the web deploy + `chown`, add (uses the cloned checkout's SHA if available, else the install.sh VERSION):

```bash
        # Traçabilité flotte : version + SHA déployés.
        local _sha; _sha="$( (cd "$TEMP_DIR" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null) || echo unknown )"
        printf 'version=%s\nsha=%s\ndate=%s\n' "$VERSION" "$_sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | sudo tee "$INSTALL_DIR/IMAGE_VERSION" >/dev/null
        sudo chmod 0644 "$INSTALL_DIR/IMAGE_VERSION"
```

- [ ] **Step 2 — Verify syntax**: `bash -n install.sh` → no errors.

- [ ] **Step 3 — Commit**: `git add install.sh && git commit -m "feat(install): stamp /opt/pisignage/IMAGE_VERSION (version+SHA) for fleet traceability"`

---

## Task 7: Safe verification on the live box (.92) — non-destructive

**Files:** none (verification only)

- [ ] **Step 1 — Confirm the function is defined + called** (static): `grep -n "install_zaforge_agent\|provision_relay_proxy_secret" install.sh` → function defs + main() calls present.

- [ ] **Step 2 — Provision relay-proxy-secret on .92 IF absent** (additive, safe; the live box's mode-complet may already have one from the manual deploy — check first, only create if missing):

Run on .92 (via `echo palmer00 | sudo -S` pattern): check `/opt/pisignage/config/relay-proxy-secret` exists + non-empty; if missing, generate it (openssl rand -hex 32, 0640 root:www-data).
Expected: file present, 0640 root:www-data.

- [ ] **Step 3 — Confirm B/C packages installable** (dry, safe): on .92 `apt-cache policy network-manager dnsmasq-base qrencode golang-go` shows candidates.

- [ ] **Step 4 — Do NOT rebuild/restart the live agent** (it's online + enrolled). Build validation was done in Task 4 Step 4 (cross-compile). Confirm the live agent is still online afterward (`systemctl is-active zaforge-agent`).

- [ ] **Step 5 — Commit any verification notes if needed** (usually none).

---

## Self-Review

**Spec coverage (Phase 0 items):** define+call install_zaforge_agent ✓ (T4) · provision relay-proxy-secret ✓ (T5) · packages network-manager/dnsmasq-base/qrencode ✓ (T2) · golang for agent build ✓ (T2) · reconcile + stamp version ✓ (T1,T6). BUILD_MODE/chroot guard is explicitly deferred to Phase C1 (not in scope here).

**Placeholders:** none — real code in every step. The only conditional is the `go.mod` location (Task 3/4 note) which the engineer resolves with `cat agent/go.mod`.

**Consistency:** `install_zaforge_agent` (T4) + `provision_relay_proxy_secret` (T5) names match their `main()` calls; `AGENT_SRC_DIR`=`/opt/pisignage/agent-src` consistent between T3 (writes) and T4 (reads); VERSION `v0.12.4` consistent T1/T6.
