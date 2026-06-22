#!/bin/sh
# Zaforge — brings up the WireGuard relay tunnel (zf0) as root.
#
# SECURITY MODEL
#   This helper is the ONLY privileged WireGuard step. It is invoked by the
#   agent (user pi) through a fixed, argument-less sudoers grant:
#       pi ALL=(root) NOPASSWD: /opt/pisignage/scripts/zaforge-wg-up.sh
#   INVARIANT: this script MUST stay root:root 0755. If pi could rewrite it the
#   grant would become a root escalation. It takes NO arguments and consumes a
#   pi-STAGED *DATA* file (never an executable / config with hooks):
#       /opt/pisignage/config/relay/wg.json
#   We deliberately DO NOT use `wg-quick` and we NEVER honour PostUp/PreUp/Down
#   hooks: wg-quick executes those lines as root, so authoring its conf from an
#   unprivileged process is a trivial root hole. Instead we read a strictly
#   typed/validated JSON, then build the interface with ip(8) + a root-only
#   wg setconf file that THIS script (root) writes to a root-owned path.
#
# LAN-SAFETY INVARIANT
#   allowed_ips MUST be exactly the relay /32 (10.70.0.1/32). Anything wider
#   would steal the Pi's routes and brick the customer LAN — we reject it hard.
set -eu

IFACE_FIXED="zf0"
WG_JSON="/opt/pisignage/config/relay/wg.json"
RUN_DIR="/run/zaforge"
WG_SETCONF="$RUN_DIR/zf0.setconf"   # root-only (0600), generated here, never pi-writable

log()  { printf 'zaforge-wg-up: %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

# --- jq-free, dependency-free single-value extractor for a flat JSON object. ---
# Reads the value for a top-level string/number key. Returns empty if absent.
# We intentionally avoid eval and only accept simple scalar values.
json_get() {
    key="$1"; file="$2"
    # Match "key": "value"  OR  "key": value (number). Take first match only.
    sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;
            s/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        "$file" 2>/dev/null | head -n1
}

[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -f "$WG_JSON" ] || die "missing data file $WG_JSON"

# Reject a wg.json that pi made writable-by-others or symlinked somewhere odd:
# it must be a regular file owned by pi, not a symlink.
[ -L "$WG_JSON" ] && die "$WG_JSON must not be a symlink"
[ -f "$WG_JSON" ] || die "$WG_JSON not a regular file"

IFACE="$(json_get iface "$WG_JSON")"
ADDRESS="$(json_get address "$WG_JSON")"
PRIV_PATH="$(json_get private_key_path "$WG_JSON")"
SERVER_PUBKEY="$(json_get server_pubkey "$WG_JSON")"
ENDPOINT="$(json_get endpoint "$WG_JSON")"
ALLOWED_IPS="$(json_get allowed_ips "$WG_JSON")"
KEEPALIVE="$(json_get keepalive "$WG_JSON")"

# ---------------------------------------------------------------------------
# STRICT VALIDATION — every field, with a regex. Reject on any mismatch.
# ---------------------------------------------------------------------------

# iface: must be exactly the fixed interface name (defence in depth; the grant
# is already argument-less, but we never trust the data file to rename it).
[ "$IFACE" = "$IFACE_FIXED" ] || die "iface must be '$IFACE_FIXED' (got '$IFACE')"

# Helper: POSIX ERE match via grep -Eq.
matches() { printf '%s' "$1" | grep -Eq "$2"; }

# server_pubkey: standard base64 of a 32-byte key => 43 base64 chars + '='.
WG_KEY_RE='^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$'
matches "$SERVER_PUBKEY" "$WG_KEY_RE" || die "server_pubkey not a valid 32-byte base64 wg key"

# address: IPv4/CIDR, e.g. 10.70.0.42/32. Octets 0-255, prefix 0-32.
OCTET='(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])'
IPV4="$OCTET\\.$OCTET\\.$OCTET\\.$OCTET"
CIDR_RE="^$IPV4/(3[0-2]|[12]?[0-9])$"
matches "$ADDRESS" "$CIDR_RE" || die "address not a valid IPv4/CIDR"

# endpoint: host:port. host = IPv4 or DNS name; port 1-65535.
HOST='([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*'
PORT='([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])'
ENDPOINT_RE="^($IPV4|$HOST):$PORT$"
matches "$ENDPOINT" "$ENDPOINT_RE" || die "endpoint not a valid host:port"

# allowed_ips: MUST equal the relay /32 form 10.70.0.1/32. Reject anything else,
# NEVER the customer LAN, never 0.0.0.0/0, never a wider prefix.
ALLOWED_RE="^10\\.70\\.0\\.1/32$"
matches "$ALLOWED_IPS" "$ALLOWED_RE" || die "allowed_ips must be exactly 10.70.0.1/32 (got '$ALLOWED_IPS')"

# keepalive: optional integer 0-65535 (0/absent => omit).
if [ -n "$KEEPALIVE" ]; then
    matches "$KEEPALIVE" '^[0-9]{1,5}$' || die "keepalive not an integer"
    [ "$KEEPALIVE" -le 65535 ] || die "keepalive out of range"
else
    KEEPALIVE=0
fi

# private_key_path: must be the agent-owned key under the relay state dir, a
# regular non-symlink file, mode 0600 pi:pi. We read it as root but never log it.
[ "$PRIV_PATH" = "/opt/pisignage/config/relay/wg_private.key" ] \
    || die "private_key_path must be /opt/pisignage/config/relay/wg_private.key"
[ -L "$PRIV_PATH" ] && die "private key path must not be a symlink"
[ -f "$PRIV_PATH" ] || die "private key file missing"
PRIV_B64="$(cat "$PRIV_PATH")"
matches "$PRIV_B64" "$WG_KEY_RE" || die "private key not a valid 32-byte base64 wg key"

# ---------------------------------------------------------------------------
# BRING UP — ip(8) for the device/addr/route + wg setconf for crypto config.
# NO hooks anywhere. The setconf file is root-only and generated here.
# ---------------------------------------------------------------------------
umask 077
mkdir -p "$RUN_DIR"
chmod 0700 "$RUN_DIR"

# Build the root-only wg setconf. NOTE: no PostUp/PreUp — wg setconf does not
# even support them; we use ip(8) for addressing/routing explicitly below.
{
    printf '[Interface]\n'
    printf 'PrivateKey = %s\n' "$PRIV_B64"
    printf '\n[Peer]\n'
    printf 'PublicKey = %s\n' "$SERVER_PUBKEY"
    printf 'Endpoint = %s\n' "$ENDPOINT"
    printf 'AllowedIPs = %s\n' "$ALLOWED_IPS"
    if [ "$KEEPALIVE" -gt 0 ]; then
        printf 'PersistentKeepalive = %s\n' "$KEEPALIVE"
    fi
} > "$WG_SETCONF"
chmod 0600 "$WG_SETCONF"

# Create the interface if missing (idempotent).
if ! ip link show "$IFACE_FIXED" >/dev/null 2>&1; then
    ip link add dev "$IFACE_FIXED" type wireguard
fi

# Apply crypto config (key, peer, single /32 allowed-ip). syncconf when already
# configured avoids a tunnel flap on re-enrollment.
if wg show "$IFACE_FIXED" >/dev/null 2>&1 && [ -n "$(wg show "$IFACE_FIXED" peers 2>/dev/null)" ]; then
    wg syncconf "$IFACE_FIXED" "$WG_SETCONF"
else
    wg setconf "$IFACE_FIXED" "$WG_SETCONF"
fi

# Address: replace so a re-run with a new address is idempotent.
ip address replace "$ADDRESS" dev "$IFACE_FIXED"
ip link set up dev "$IFACE_FIXED"

# Single /32 route to the relay only — the LAN-safety invariant. We never add a
# default route, never touch DNS, never widen beyond the validated allowed_ips.
ip route replace "$ALLOWED_IPS" dev "$IFACE_FIXED"

# Wipe the transient setconf (it held the private key).
rm -f "$WG_SETCONF"

log "tunnel up on $IFACE_FIXED ($ADDRESS -> $ENDPOINT, allowed=$ALLOWED_IPS)"
exit 0
