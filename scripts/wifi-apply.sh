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

# SSID : 1-32 octets, ni " ni \, aucun caractère de contrôle, UTF-8 valide
# (un octet non-UTF-8 casserait wifi-networks.json -> json_decode null -> liste vidée).
valid_ssid() {
    printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{1,32}$' || return 1
    printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]' && return 1
    printf '%s' "$1" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1
}
# PSK : 8-63 caractères, ni " ni \, aucun contrôle (l'espace en tête/fin est rejeté côté PHP).
valid_psk()  { printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{8,63}$' && ! printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }
valid_priority() { case "$1" in 10|20|30) return 0 ;; *) return 1 ;; esac; }

# UUIDs des profils de type wifi (UUID = 1er champ, sans ':' → terse sûr).
wifi_uuids() { "$NMCLI" -t -f UUID,TYPE con show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}'; }
con_get()   { "$NMCLI" -s -g "$1" con show "$2" 2>/dev/null || true; }

# Lit le PSK d'un profil. NM renvoie parfois vide juste après un con up/reload (occupé) ->
# on réessaie brièvement, mais SEULEMENT si la sécurité est configurée (sinon réseau ouvert).
read_psk() {
    _p="$(con_get 802-11-wireless-security.psk "$1")"
    [ -n "$_p" ] && { printf '%s' "$_p"; return; }
    [ -n "$(con_get 802-11-wireless-security.key-mgmt "$1")" ] || { printf ''; return; }
    _i=0
    while [ "$_i" -lt 4 ]; do
        sleep 0.25
        _p="$(con_get 802-11-wireless-security.psk "$1")"
        [ -n "$_p" ] && break
        _i=$((_i+1))
    done
    printf '%s' "$_p"
}

# Snapshot ssid(b64)->psk(b64) de TOUS les profils wifi ; FOREIGN = UUIDs des profils non-nôtres.
# NOS profils sont écrits EN PREMIER -> lookup_psk (1er match) préfère notre PSK sur un doublon
# de SSID (ex. profil étranger résiduel avec un ancien mot de passe). $SNAP contient des PSK
# (base64 = clair) -> 0600 en plus du WORKDIR 0700.
build_snapshot() {
    : > "$FOREIGN"
    : > "$WORKDIR/snap.ours"; : > "$WORKDIR/snap.other"
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        ssid="$(con_get 802-11-wireless.ssid "$u")"
        [ -n "$ssid" ] || continue
        psk="$(read_psk "$u")"
        if is_ours "$id"; then
            printf '%s %s\n' "$(b64 "$ssid")" "$(b64 "$psk")" >> "$WORKDIR/snap.ours"
        else
            printf '%s %s\n' "$(b64 "$ssid")" "$(b64 "$psk")" >> "$WORKDIR/snap.other"
            printf '%s\n' "$u" >> "$FOREIGN"
        fi
    done
    cat "$WORKDIR/snap.ours" "$WORKDIR/snap.other" > "$SNAP"
    chmod 0600 "$SNAP" "$WORKDIR/snap.ours" "$WORKDIR/snap.other" 2>/dev/null || true
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
    # /run (tmpfs root) plutôt que /tmp : sur la box kiosk /tmp est souvent à 100% (Chromium) ->
    # un ENOSPC casserait l'apply en plein milieu (set -e). Repli /tmp si /run indisponible.
    WORKDIR="$(mktemp -d /run/wifi-apply.XXXXXX 2>/dev/null || mktemp -d /tmp/wifi-apply.XXXXXX)"; chmod 0700 "$WORKDIR"
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
            keep) psk="$(lookup_psk "$ssid")"; [ -n "$psk" ] || die "pas de mot de passe memorise pour ce reseau"
                  # PSK mémorisé = origine NM (possiblement étrangère) -> garde anti-injection keyfile
                  # (pas de longueur imposée : un PMK 64-hex est légitime ; on bloque les ctrl/newline).
                  printf '%s' "$psk" | LC_ALL=C grep -q '[[:cntrl:]]' && die "mot de passe memorise invalide" ;;
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

    # Connexion active AVANT toute opération destructive (anti-lock-out).
    active_before="$("$NMCLI" -t -g GENERAL.CONNECTION dev show "$IFACE" 2>/dev/null || true)"

    "$NMCLI" con reload >/dev/null 2>&1 || true

    # --- HANDOFF D'ABORD : connecter le meilleur réseau ciblé VISIBLE, sans couper un lien déjà bon. ---
    # nmcli -t échappe ':' en '\:' dans les SSID -> on les déséchappe (nos SSID n'ont jamais de '\').
    "$NMCLI" dev wifi list --rescan yes >/dev/null 2>&1 || true
    "$NMCLI" -t -f SSID dev wifi list 2>/dev/null | sed 's/\\:/:/g' > "$WORKDIR/visible" || true
    best=""
    while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
        s="$(unb64 "$ssidb")"
        if grep -Fxq "$s" "$WORKDIR/visible"; then best="$(prof_name "$s")"; break; fi
    done < "$PLAN"
    if [ -n "$best" ] && [ "$best" != "$active_before" ]; then "$NMCLI" con up "$best" >/dev/null 2>&1 || true; fi

    # État RÉEL après handoff : sommes-nous sur un réseau CIBLÉ ?
    active_now="$("$NMCLI" -t -g GENERAL.CONNECTION dev show "$IFACE" 2>/dev/null || true)"
    on_planned=0
    [ -n "$active_now" ] && grep -Fxq "$active_now" "$TARGETS" && on_planned=1

    # --- Élagage SÛR : supprimer NOS profils hors-cible, mais JAMAIS le profil actif tant qu'on
    #     n'a pas basculé sur un réseau ciblé (sinon on couperait le seul lien fonctionnel). ---
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        is_ours "$id" || continue
        grep -Fxq "$id" "$TARGETS" && continue
        if [ "$id" = "$active_now" ] && [ "$on_planned" = 0 ]; then continue; fi
        "$NMCLI" con delete "$u" >/dev/null 2>&1 || true
    done

    # Désactiver l'autoconnect des profils ÉTRANGERS UNIQUEMENT si on est bien sur un réseau ciblé
    # (sinon on laisserait la box sans repli au prochain reboot). Jamais zf0/eth0/lo/non-wifi.
    if [ "$on_planned" = 1 ]; then
        while read -r u; do [ -n "$u" ] && "$NMCLI" con modify "$u" connection.autoconnect no >/dev/null 2>&1 || true; done < "$FOREIGN"
    fi

    write_state_from_plan "$PLAN"
    n="$(wc -l < "$PLAN" | tr -d ' ')"
    if [ "$on_planned" = 1 ]; then
        log "applique ($n reseau(x), connecté)"
    else
        # Config écrite, mais pas (encore) connecté à un réseau ciblé -> signaler (exit 3) sans
        # avoir cassé le lien existant. config.php transforme ça en avertissement, pas en échec.
        log "applique ($n reseau(x)) mais NON connecté à un réseau configuré"
        exit 3
    fi
}

cmd_sync() {
    # /run (tmpfs root) plutôt que /tmp : sur la box kiosk /tmp est souvent à 100% (Chromium) ->
    # un ENOSPC casserait l'apply en plein milieu (set -e). Repli /tmp si /run indisponible.
    WORKDIR="$(mktemp -d /run/wifi-apply.XXXXXX 2>/dev/null || mktemp -d /tmp/wifi-apply.XXXXXX)"; chmod 0700 "$WORKDIR"
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
