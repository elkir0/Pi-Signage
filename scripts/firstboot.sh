#!/bin/sh
# Zaforge — initialisation PAR-DEVICE au 1er démarrage d'une box flashée depuis l'image golden
# (identique sur toutes les cartes). Régénère l'identité unique. IDEMPOTENT et BEST-EFFORT :
# ne DOIT JAMAIS bloquer graphical.target / le kiosk (pas de set -e ; chaque opération est gardée).
# Gardé par le sentinel .provisioned. Testable hors-box via ZF_CONF (répertoire) + ZF_DRY=1
# (ne touche ni hostname, ni systemctl, ni l'AP, ni les chown).
set -u

CONF="${ZF_CONF:-/opt/pisignage/config}"
DRY="${ZF_DRY:-0}"
SENTINEL="$CONF/.provisioned"
AP_HELPER="/opt/pisignage/scripts/onboard-ap.sh"
LOGF="/opt/pisignage/logs/firstboot.log"

log() { echo "firstboot: $*" >&2; [ "$DRY" = 1 ] || echo "[firstboot] $*" >> "$LOGF" 2>/dev/null || true; }
rand_hex() { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

mkdir -p "$CONF" 2>/dev/null || true

# Ré-armer l'AP si on a redémarré EN PLEIN onboarding (le profil AP est autoconnect=no -> ne remonte
# pas seul). À faire sur CHAQUE boot tant que l'onboarding n'est pas terminé.
reraise_ap() {
    if [ -f "$CONF/.onboarding" ] && [ ! -f "$CONF/.onboarded" ]; then
        [ "$DRY" = 1 ] || "$AP_HELPER" up >/dev/null 2>&1 || true
        log "onboarding en cours -> AP re-levé"
    fi
}

# ---- FAST PATH : déjà provisionné (boot normal) ----
if [ -f "$SENTINEL" ]; then
    reraise_ap
    exit 0
fi

log "1er démarrage : régénération de l'identité par-device"

# 1) hostname zaforge-<8 premiers de machine-id> (RPi OS a déjà régénéré machine-id avant nous).
MID="$(cat /etc/machine-id 2>/dev/null || true)"
SHORT="$(printf '%s' "$MID" | tr -cd 'a-f0-9' | cut -c1-8)"
[ -n "$SHORT" ] || SHORT="$(date +%s 2>/dev/null | tail -c 9)"
HN="zaforge-$SHORT"
if [ "$DRY" != 1 ]; then
    hostnamectl set-hostname "$HN" 2>/dev/null || true
    grep -q "[[:space:]]$HN\$" /etc/hosts 2>/dev/null || echo "127.0.1.1 $HN" >> /etc/hosts 2>/dev/null || true
fi
log "hostname=$HN"

# 2) token agent (agent.json) 0640 pi:www-data — unique par device.
AGENT_JSON="$CONF/agent.json"
printf '{\n  "token": "%s",\n  "created_at": "%s"\n}\n' "$(rand_hex)" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" > "$AGENT_JSON"
chmod 0640 "$AGENT_JSON" 2>/dev/null || true
[ "$DRY" = 1 ] || chown pi:www-data "$AGENT_JSON" 2>/dev/null || true

# 3) relay-proxy-secret 0640 root:www-data — unique par device.
RPS="$CONF/relay-proxy-secret"
rand_hex > "$RPS"
chmod 0640 "$RPS" 2>/dev/null || true
[ "$DRY" = 1 ] || chown root:www-data "$RPS" 2>/dev/null || true

# 4) mot de passe admin ALÉATOIRE -> credentials.json (bcrypt) + .setup-admin-password (clair, affiché
#    une fois sur l'écran de setup, supprimé à la fin de l'onboarding). Supprime tout credentials baked.
rm -f "$CONF/credentials.json" 2>/dev/null || true
PW="$(LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom 2>/dev/null | head -c 10)"
[ -n "$PW" ] || PW="zaforge$(date +%s 2>/dev/null | tail -c 5)"
HASH="$(printf '%s' "$PW" | php -r 'echo password_hash(stream_get_contents(STDIN), PASSWORD_BCRYPT, ["cost"=>12]);' 2>/dev/null || true)"
if [ -n "$HASH" ]; then
    printf '{\n  "username": "admin",\n  "password": %s\n}\n' "$(printf '%s' "$HASH" | sed 's/.*/"&"/')" > "$CONF/credentials.json"
    chmod 0640 "$CONF/credentials.json" 2>/dev/null || true
    [ "$DRY" = 1 ] || chown www-data:www-data "$CONF/credentials.json" 2>/dev/null || true
    printf '%s' "$PW" > "$CONF/.setup-admin-password"
    chmod 0640 "$CONF/.setup-admin-password" 2>/dev/null || true
    [ "$DRY" = 1 ] || chown root:www-data "$CONF/.setup-admin-password" 2>/dev/null || true
    log "mot de passe admin par-device généré"
else
    log "php indisponible -> credentials.json laissé au défaut (mur de changement de mot de passe actif)"
fi

# 5) NON enrôlé au départ (relay.json code vide + ENABLE_RELAY=0) — l'enrôlement se fait à l'onboarding.
if [ ! -f "$CONF/relay.json" ]; then
    printf '{\n  "relay_url": "https://relay.zaforge.com",\n  "enrollment_code": "",\n  "rebind": false\n}\n' > "$CONF/relay.json"
    chmod 0640 "$CONF/relay.json" 2>/dev/null || true
    [ "$DRY" = 1 ] || chown pi:pi "$CONF/relay.json" 2>/dev/null || true
fi
FF="$CONF/feature_flags"; touch "$FF" 2>/dev/null || true
if grep -q '^ENABLE_RELAY=' "$FF" 2>/dev/null; then
    sed -i 's/^ENABLE_RELAY=.*/ENABLE_RELAY=0/' "$FF" 2>/dev/null || true
else
    echo 'ENABLE_RELAY=0' >> "$FF" 2>/dev/null || true
fi

# 6) sentinel ATOMIQUE (uniquement après les étapes d'identité).
printf 'provisioned %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" > "$SENTINEL.tmp" 2>/dev/null \
    && mv -f "$SENTINEL.tmp" "$SENTINEL" 2>/dev/null || true
log "identité provisionnée"

# 7) onboarding requis ? (aucun WiFi configuré OU pas enrôlé) -> lever l'AP (pose .onboarding).
NEED=0
WN="$CONF/wifi-networks.json"
{ [ ! -s "$WN" ] || ! grep -q '"ssid"' "$WN" 2>/dev/null; } && NEED=1
CODE="$(sed -n 's/.*"enrollment_code"[^"]*"\([^"]*\)".*/\1/p' "$CONF/relay.json" 2>/dev/null | head -1)"
[ -z "$CODE" ] && NEED=1
if [ "$NEED" = 1 ]; then
    [ "$DRY" = 1 ] || "$AP_HELPER" up >/dev/null 2>&1 || true
    log "onboarding requis -> AP levé"
else
    log "déjà configuré -> kiosk direct"
fi
exit 0
