#!/usr/bin/env bash
# =============================================================================
# GATED — PROXMOX HOST ONLY (37.187.155.234). Additive DNAT for ZAFORGE relay.
# Adds: public UDP 51840 -> VM600 (10.10.10.160:51840) + FORWARD accept.
# Mirrors the VM400(51820)/CT220(51830) pattern; persists to /etc/iptables/rules.v4.
# Idempotent: every rule is -C checked before -A. Touches NOTHING else.
# Run as root ON THE HOST after operator approval:
#   ssh root@37.187.155.234 'bash -s' < scripts/apply-host-dnat.sh
# =============================================================================
set -euo pipefail

PUB_IFACE="vmbr0"          # public bridge
DST="10.10.10.160"          # VM600 zaforge-relay
PORT="51840"

add_if_absent() {
  local table="$1"; shift
  if ! iptables -t "$table" -C "$@" 2>/dev/null; then
    iptables -t "$table" -A "$@"
    echo "ADDED  [$table] $*"
  else
    echo "EXISTS [$table] $*"
  fi
}

echo "== ZAFORGE host DNAT (UDP $PORT -> $DST) =="

# 1) DNAT public UDP 51840 -> VM600
add_if_absent nat PREROUTING -i "$PUB_IFACE" -p udp --dport "$PORT" -j DNAT --to-destination "${DST}:${PORT}"

# 2) FORWARD accept (host has DROP policy + whitelist) — both directions of the
#    DNATed flow so the WireGuard handshake completes.
add_if_absent filter FORWARD -p udp -d "$DST" --dport "$PORT" -j ACCEPT
add_if_absent filter FORWARD -p udp -s "$DST" --sport "$PORT" -j ACCEPT

# 3) Persist (same store as 51820/51830/443).
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4
echo "Persisted to /etc/iptables/rules.v4"

# 4) Show the result for the operator to eyeball.
echo '--- nat PREROUTING (51840) ---'
iptables -t nat -L PREROUTING -n -v | grep -E "51840" || true
echo '--- filter FORWARD (51840) ---'
iptables -L FORWARD -n -v | grep -E "51840" || true
echo 'DONE. Validate from the Pi: wg show zf0 latest-handshakes (expect a recent handshake).'
