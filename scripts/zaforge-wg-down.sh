#!/bin/sh
# Zaforge — tears down the WireGuard relay tunnel (zf0) as root.
#
# SECURITY MODEL (mirror of zaforge-wg-up.sh)
#   Invoked by the agent (user pi) via a fixed, argument-less sudoers grant:
#       pi ALL=(root) NOPASSWD: /opt/pisignage/scripts/zaforge-wg-down.sh
#   INVARIANT: MUST stay root:root 0755. Takes NO arguments. Operates on the
#   FIXED interface name only; never reads a pi-supplied path.
set -eu

IFACE_FIXED="zf0"
RUN_DIR="/run/zaforge"

log() { printf 'zaforge-wg-down: %s\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] || { log "ERROR: must run as root"; exit 1; }

if ip link show "$IFACE_FIXED" >/dev/null 2>&1; then
    # Removing the device drops its address + the /32 route with it.
    ip link set down dev "$IFACE_FIXED" 2>/dev/null || true
    ip link delete dev "$IFACE_FIXED" 2>/dev/null || true
    log "tunnel $IFACE_FIXED torn down"
else
    log "interface $IFACE_FIXED not present (already down)"
fi

# Clean any transient setconf left behind (defence in depth; up.sh removes it).
rm -f "$RUN_DIR/zf0.setconf" 2>/dev/null || true
exit 0
