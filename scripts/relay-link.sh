#!/bin/sh
# Zaforge — lie la box au compte/tenant du proprio : écrit relay.json (code d'enrôlement) +
# ENABLE_RELAY=1 puis redémarre l'agent (qui échange ensuite le code via /enroll, contrat inchangé).
# INVARIANT SÉCURITÉ : root:root 0755. Appelé par www-data via sudo (sudoers, args fixes) ;
# le CODE est lu sur STDIN (jamais en argv -> pas de fuite ps) et VALIDÉ ici (le helper ne fait
# jamais confiance à PHP).
#   Usage onboarding (1er lien)   : printf '%s' "<code>" | sudo relay-link.sh
#   Usage admin (re-lier un compte): printf '%s' "<code>" | sudo relay-link.sh rebind
# `rebind` pose "rebind": true dans relay.json -> le relais accepte de DÉPLACER un device
# déjà enrôlé vers le nouveau tenant (sinon il refuse). Tout autre argument est ignoré.
set -eu

REBIND="false"
if [ "${1:-}" = "rebind" ]; then REBIND="true"; fi

CONF=/opt/pisignage/config
RELAY_JSON="$CONF/relay.json"
FF="$CONF/feature_flags"
RELAY_URL_DEFAULT="https://relay.zaforge.com"

# Code depuis stdin (borné), espaces retirés.
code="$(head -c 80 2>/dev/null | tr -d '[:space:]')"
# Format strict : ZF-XXXX-XXXX-XXXX (groupes alphanum MAJUSCULES). Rien d'autre.
printf '%s' "$code" | grep -Eq '^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$' || { echo "code invalide" >&2; exit 2; }

# relay_url : conserver celle de relay.json si déjà dans l'allowlist, sinon le défaut.
url="$RELAY_URL_DEFAULT"
if [ -f "$RELAY_JSON" ]; then
    existing="$(sed -n 's/.*"relay_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RELAY_JSON" | head -1)"
    case "$existing" in https://relay.zaforge.com|https://*.zaforge.com) url="$existing" ;; esac
fi
# Allowlist stricte (anti-SSRF / anti-repoint vers un relais pirate).
case "$url" in https://relay.zaforge.com|https://*.zaforge.com) : ;; *) echo "relay_url non autorisee" >&2; exit 2 ;; esac

# Écrire relay.json (0640 pi:pi — possédé par l'agent).
tmp="$(mktemp)"
printf '{\n  "relay_url": "%s",\n  "enrollment_code": "%s",\n  "rebind": %s\n}\n' "$url" "$code" "$REBIND" > "$tmp"
chmod 0640 "$tmp"; chown pi:pi "$tmp"; mv -f "$tmp" "$RELAY_JSON"

# Activer le relais.
touch "$FF"
if grep -q '^ENABLE_RELAY=' "$FF"; then
    sed -i 's/^ENABLE_RELAY=.*/ENABLE_RELAY=1/' "$FF"
else
    echo 'ENABLE_RELAY=1' >> "$FF"
fi

# Redémarrer l'agent (lecture des fichiers au boot -> enrôlement via /enroll).
systemctl restart zaforge-agent.service 2>/dev/null || true
echo "linked"
