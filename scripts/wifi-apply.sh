#!/bin/sh
# PiSignage/Zaforge — Multi-WiFi fallback via NetworkManager.
# INVARIANT SÉCURITÉ : ce script DOIT rester root:root 0755 (sinon la grant sudo www-data
# deviendrait une escalade vers root). Appelé par www-data via sudo (sudoers à args fixes) :
#   printf '%s' "<payload>" | sudo /opt/pisignage/scripts/wifi-apply.sh apply
#   sudo /opt/pisignage/scripts/wifi-apply.sh sync
#
# 'apply' : lit STDIN, 1 ligne/slot (ordre = priorité décroissante), champs TAB-séparés :
#   <priority>\t<ssid>\t<mode>\t<secret>   (priority 30|20|10 ; mode new|keep)
# Le PSK ne transite QUE par stdin et n'est écrit QUE dans les keyfiles NM root 0600
# (jamais en argv → pas de fuite via ps/proc). Chaque réseau = 1 profil NM nommé
# zf-wifi-<sha1(ssid)[:12]> (identité STABLE par SSID → un réordonnancement ne change
# QUE autoconnect-priority, jamais le SSID du profil actif → pas de déconnexion).
set -eu

IFACE="wlan0"
NMCLI="/usr/bin/nmcli"
NMDIR="/etc/NetworkManager/system-connections"
STATE_JSON="/opt/pisignage/config/wifi-networks.json"

WORKDIR=""
cleanup() { [ -n "$WORKDIR" ] && rm -rf "$WORKDIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

log() { echo "wifi-apply: $*" >&2; }
die() { log "ERREUR: $*"; exit 1; }

b64()   { printf '%s' "$1" | base64 | tr -d '\n'; }
unb64() { printf '%s' "$1" | base64 -d 2>/dev/null || true; }

prof_name() { printf 'zf-wifi-%s' "$(printf '%s' "$1" | sha1sum | cut -c1-12)"; }
is_ours()   { printf '%s' "$1" | grep -Eq '^zf-wifi-[0-9a-f]{12}$'; }

# SSID : 1-32 octets, ni " ni \, aucun caractère de contrôle.
valid_ssid() { printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{1,32}$' && ! printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }
# PSK : 8-63 caractères, ni " ni \, aucun contrôle (l'espace en tête/fin est rejeté côté PHP).
valid_psk()  { printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{8,63}$' && ! printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }
valid_priority() { case "$1" in 10|20|30) return 0 ;; *) return 1 ;; esac; }

# UUIDs des profils de type wifi (UUID = 1er champ, sans ':' → terse sûr).
wifi_uuids() { "$NMCLI" -t -f UUID,TYPE con show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}'; }
con_get()   { "$NMCLI" -s -g "$1" con show "$2" 2>/dev/null || true; }

# Snapshot ssid(b64)->psk(b64) de TOUS les profils wifi ; FOREIGN = UUIDs des profils non-nôtres.
build_snapshot() {
    : > "$SNAP"; : > "$FOREIGN"
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        ssid="$(con_get 802-11-wireless.ssid "$u")"
        [ -n "$ssid" ] || continue
        psk="$(con_get 802-11-wireless-security.psk "$u")"
        printf '%s %s\n' "$(b64 "$ssid")" "$(b64 "$psk")" >> "$SNAP"
        is_ours "$id" || printf '%s\n' "$u" >> "$FOREIGN"
    done
}
lookup_psk() { line="$(awk -v w="$(b64 "$1")" '$1==w{print $2; exit}' "$SNAP")"; [ -n "$line" ] && unb64 "$line" || true; }

# ssid -> "104;101;...;" (tableau d'octets : aucun échappement GKeyFile à gérer).
ssid_bytes() { printf '%s' "$1" | od -An -tu1 | tr -s ' \n' '\n\n' | sed '/^$/d' | while read -r b; do printf '%s;' "$b"; done; }
json_str()   { printf '"%s"' "$1"; }   # ssid validé sans "/\/ctrl → sûr en JSON

write_keyfile() { # name priority ssid psk
    name="$1"; priority="$2"; ssid="$3"; psk="$4"
    file="$NMDIR/$name.nmconnection"
    uuid=""; [ -f "$file" ] && uuid="$(awk -F= '/^uuid=/{print $2; exit}' "$file" 2>/dev/null || true)"
    [ -n "$uuid" ] || uuid="$(cat /proc/sys/kernel/random/uuid)"
    tmp="$WORKDIR/kf"
    {
        printf '[connection]\nid=%s\nuuid=%s\ntype=wifi\ninterface-name=%s\nautoconnect=true\nautoconnect-priority=%s\n' "$name" "$uuid" "$IFACE" "$priority"
        printf '\n[wifi]\nmode=infrastructure\nssid=%s\n' "$(ssid_bytes "$ssid")"
        printf '\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n' "$psk"
        printf '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n'
    } > "$tmp"
    chmod 0600 "$tmp"; chown root:root "$tmp"; mv -f "$tmp" "$file"
}

write_state_from_plan() { # PLAN(slot priority ssidb pskb)
    tmp="$WORKDIR/state"
    {
        printf '{"networks":['
        first=1
        while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
            [ "$first" = 1 ] || printf ','; first=0
            printf '{"slot":%s,"ssid":%s,"has_password":true}' "$slot" "$(json_str "$(unb64 "$ssidb")")"
        done < "$1"
        printf ']}'
    } > "$tmp"
    chmod 0644 "$tmp"; chown root:root "$tmp"
    mkdir -p "$(dirname "$STATE_JSON")"; mv -f "$tmp" "$STATE_JSON"
}

cmd_apply() {
    WORKDIR="$(mktemp -d /tmp/wifi-apply.XXXXXX)"; chmod 0700 "$WORKDIR"
    SNAP="$WORKDIR/snap"; FOREIGN="$WORKDIR/foreign"; PLAN="$WORKDIR/plan"
    build_snapshot

    : > "$PLAN"; slot=0; seen=" "
    # Lire + valider TOUT avant de modifier (rejet => rien n'est touché).
    while IFS="$(printf '\t')" read -r priority ssid mode secret || [ -n "${priority:-}" ]; do
        [ -n "${priority:-}" ] || continue
        slot=$((slot+1)); [ "$slot" -le 3 ] || die "trop de slots"
        valid_priority "$priority" || die "priorite invalide"
        valid_ssid "$ssid" || die "ssid invalide"
        k="$(b64 "$ssid")"; case "$seen" in *" $k "*) die "ssid doublon" ;; esac; seen="$seen$k "
        case "$mode" in
            new)  valid_psk "$secret" || die "mot de passe invalide"; psk="$secret" ;;
            keep) psk="$(lookup_psk "$ssid")"; [ -n "$psk" ] || die "pas de mot de passe memorise pour ce reseau" ;;
            *)    die "mode invalide" ;;
        esac
        printf '%s\t%s\t%s\t%s\n' "$slot" "$priority" "$(b64 "$ssid")" "$(b64 "$psk")" >> "$PLAN"
    done
    [ -s "$PLAN" ] || die "aucun reseau"

    # (Re)construire les profils cibles (1 par ssid, nom = hash stable).
    TARGETS="$WORKDIR/targets"; : > "$TARGETS"
    while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
        ssid="$(unb64 "$ssidb")"; psk="$(unb64 "$pskb")"; name="$(prof_name "$ssid")"
        write_keyfile "$name" "$priority" "$ssid" "$psk"
        printf '%s\n' "$name" >> "$TARGETS"
    done < "$PLAN"

    "$NMCLI" con reload >/dev/null 2>&1 || true

    # Supprimer NOS anciens profils dont le ssid n'est plus ciblé.
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        if is_ours "$id" && ! grep -Fxq "$id" "$TARGETS"; then
            "$NMCLI" con delete "$u" >/dev/null 2>&1 || true
        fi
    done

    # Désactiver l'autoconnect des profils WiFi ÉTRANGERS (jamais zf0/eth0/lo/non-wifi).
    while read -r u; do [ -n "$u" ] && "$NMCLI" con modify "$u" connection.autoconnect no >/dev/null 2>&1 || true; done < "$FOREIGN"

    # Connecter le meilleur réseau VISIBLE si on n'est pas déjà dessus (handoff / prise de possession).
    "$NMCLI" dev wifi list --rescan yes >/dev/null 2>&1 || true
    visible="$("$NMCLI" -t -f SSID dev wifi list 2>/dev/null || true)"
    active_id="$("$NMCLI" -t -g GENERAL.CONNECTION dev show "$IFACE" 2>/dev/null || true)"
    best=""
    while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
        s="$(unb64 "$ssidb")"
        if printf '%s\n' "$visible" | grep -Fxq "$s"; then best="$(prof_name "$s")"; break; fi
    done < "$PLAN"
    if [ -n "$best" ] && [ "$best" != "$active_id" ]; then "$NMCLI" con up "$best" >/dev/null 2>&1 || true; fi

    write_state_from_plan "$PLAN"
    log "applique ($(wc -l < "$PLAN" | tr -d ' ') reseau(x))"
}

cmd_sync() {
    WORKDIR="$(mktemp -d /tmp/wifi-apply.XXXXXX)"; chmod 0700 "$WORKDIR"
    PLAN="$WORKDIR/plan"; list="$WORKDIR/list"; : > "$PLAN"; : > "$list"
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        if is_ours "$id"; then
            pr="$(con_get connection.autoconnect-priority "$u")"; [ -n "$pr" ] || pr=0
            ssid="$(con_get 802-11-wireless.ssid "$u")"
            [ -n "$ssid" ] && printf '%s\t%s\n' "$pr" "$(b64 "$ssid")" >> "$list"
        fi
    done
    if [ -s "$list" ]; then
        sort -t"$(printf '\t')" -k1,1 -rn "$list" > "$list.sorted"
        slot=0
        while IFS="$(printf '\t')" read -r pr ssidb; do
            slot=$((slot+1)); printf '%s\t30\t%s\t\n' "$slot" "$ssidb" >> "$PLAN"
        done < "$list.sorted"
    else
        # Aucun profil à nous : pré-remplir le slot 1 depuis le WiFi actif (migration).
        au="$("$NMCLI" -t -f UUID,TYPE,ACTIVE con show 2>/dev/null | awk -F: '$2=="802-11-wireless" && $3=="yes"{print $1; exit}')"
        if [ -n "${au:-}" ]; then
            ssid="$(con_get 802-11-wireless.ssid "$au")"
            [ -n "$ssid" ] && printf '1\t30\t%s\t\n' "$(b64 "$ssid")" >> "$PLAN"
        fi
    fi
    if [ -s "$PLAN" ]; then write_state_from_plan "$PLAN"; else printf '{"networks":[]}' > "$STATE_JSON"; chmod 0644 "$STATE_JSON" 2>/dev/null || true; fi
    log "sync ok"
}

case "${1:-}" in
    apply) cmd_apply ;;
    sync)  cmd_sync ;;
    *)     echo "usage: $0 apply|sync" >&2; exit 2 ;;
esac
