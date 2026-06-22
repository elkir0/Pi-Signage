#!/usr/bin/env bash
# install.sh wiring snippet for the Zaforge fleet agent.
# Call install_zaforge_agent from install.sh AFTER configure_sudo so the agent's
# extra sudoers line is appended consistently (or fold these rules into the
# existing /etc/sudoers.d/pisignage heredoc in configure_sudo).
set -euo pipefail

INSTALL_DIR="/opt/pisignage"
AGENT_SRC_DIR="${AGENT_SRC_DIR:-/opt/pisignage/agent-src}"  # where agent/*.go was synced

install_zaforge_agent() {
    echo "[zaforge-agent] building + installing"

    # --- 1) Build the static binary (native on the Pi, or cross-compiled) ---
    # On the Pi (arm64):   CGO_ENABLED=0 go build -o zaforge-agent ./agent
    # Cross from a dev box: GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o zaforge-agent ./agent
    sudo mkdir -p "$INSTALL_DIR/bin"
    if command -v go >/dev/null 2>&1; then
        ( cd "$AGENT_SRC_DIR" && CGO_ENABLED=0 go build -trimpath -o /tmp/zaforge-agent ./agent )
        sudo install -o root -g root -m 0755 /tmp/zaforge-agent "$INSTALL_DIR/bin/zaforge-agent"
        rm -f /tmp/zaforge-agent
    else
        echo "[zaforge-agent] 'go' not found — copy a prebuilt arm64 binary to $INSTALL_DIR/bin/zaforge-agent"
    fi

    # --- 2) relay.json template (operator fills enrollment_code in console) ---
    # Mode 0640 pi:pi — readable by the agent (pi), not world-readable.
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

    # --- 3) agent-owned WG state dir (private key, wg.json data file, enrollment.json) ---
    # The agent (pi) writes ONLY pi-owned files here: wg_private.key (0600),
    # wg.json (0600, the validated DATA file the root helper consumes), and
    # enrollment.json (0600). It NEVER authors a file a privileged tool executes.
    sudo mkdir -p "$INSTALL_DIR/config/relay"
    sudo chown pi:pi "$INSTALL_DIR/config/relay"
    sudo chmod 0700 "$INSTALL_DIR/config/relay"

    # --- 4) Root-owned WireGuard helpers (root:root 0755) ---
    # SECURITY: the agent NEVER writes /etc/wireguard/zf0.conf and we do NOT use
    # wg-quick (its PostUp/PreUp lines run as root = trivial root from a pi-authored
    # conf). The ONLY privileged step is these two fixed helpers, which read the
    # pi-staged DATA file, validate every field, and bring the iface up with
    # ip(8) + `wg setconf` from a root-only file — no hook surface. INVARIANT:
    # they MUST be root:root 0755 (a pi-writable helper would be a root escalation).
    # Source of truth is install.sh configure_sudo; here we just enforce ownership
    # in case this snippet runs standalone against a synced agent-src checkout.
    if [ -f "$AGENT_SRC_DIR/scripts/zaforge-wg-up.sh" ]; then
        sudo install -o root -g root -m 0755 \
            "$AGENT_SRC_DIR/scripts/zaforge-wg-up.sh"   "$INSTALL_DIR/scripts/zaforge-wg-up.sh"
        sudo install -o root -g root -m 0755 \
            "$AGENT_SRC_DIR/scripts/zaforge-wg-down.sh" "$INSTALL_DIR/scripts/zaforge-wg-down.sh"
    else
        echo "[zaforge-agent] WG helpers not found in $AGENT_SRC_DIR/scripts — run install.sh configure_sudo to generate them root:root 0755"
    fi

    # --- 5) Sudoers: the two fixed, ARGUMENT-LESS WG helpers ONLY ---
    # No wg / wg-quick grant, NO wildcards. The agent does its own wg status via
    # an unprivileged `wg show` (read-only) — never via sudo. Reboot reuses the
    # NARROW grant already in /etc/sudoers.d/pisignage:
    #   pi ALL=(root) NOPASSWD: /sbin/shutdown, /sbin/reboot,
    #                           /bin/systemctl reboot, /bin/systemctl poweroff
    local SUDO_TMP; SUDO_TMP="$(mktemp)"
    cat > "$SUDO_TMP" <<'SUDOERS'
# Zaforge agent — WireGuard tunnel control via FIXED, argument-less root helpers only.
# No wg/wg-quick, no wildcards. The helpers (root:root 0755) revalidate every field
# and use no PostUp/PreUp hooks.
pi ALL=(root) NOPASSWD: /opt/pisignage/scripts/zaforge-wg-up.sh, /opt/pisignage/scripts/zaforge-wg-down.sh
SUDOERS
    if sudo visudo -cf "$SUDO_TMP" >/dev/null 2>&1; then
        sudo install -o root -g root -m 0440 "$SUDO_TMP" /etc/sudoers.d/zaforge-agent
    else
        echo "[zaforge-agent] sudoers invalid — not installed"
    fi
    rm -f "$SUDO_TMP"

    # --- 6) feature flag default OFF (idempotent append) ---
    local FF="$INSTALL_DIR/config/feature_flags"
    if ! grep -q '^ENABLE_RELAY=' "$FF" 2>/dev/null; then
        echo 'ENABLE_RELAY=0' | sudo tee -a "$FF" >/dev/null
    fi

    # --- 7) systemd unit (enabled; self-exits while ENABLE_RELAY=0) ---
    sudo install -o root -g root -m 0644 \
        "$AGENT_SRC_DIR/deploy/systemd/zaforge-agent.service" \
        /etc/systemd/system/zaforge-agent.service
    sudo systemctl daemon-reload
    sudo systemctl enable zaforge-agent.service
    sudo systemctl restart zaforge-agent.service || true

    echo "[zaforge-agent] installed. Enable with: ENABLE_RELAY=1 in $FF + set enrollment_code in relay.json, then: sudo systemctl restart zaforge-agent"
}

install_zaforge_agent
