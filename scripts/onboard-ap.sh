#!/bin/sh
# Zaforge — point d'accès d'onboarding (radio UNIQUE, séquentiel : AP et STA ne coexistent pas sur
# le Pi4, le firmware brcmfmac plante en simultané). INVARIANT SÉCURITÉ : root:root 0755.
# Aucun argument utilisateur (config AP fixe dérivée de machine-id) -> surface minimale.
# Appelé par www-data via sudo (sudoers à args fixes) : up | down | status.
#   up     : lève l'AP ouvert zf-onboard-ap (NM keyfile, ipv4.method=shared = DHCP/DNS interne) +
#            drop-in dnsmasq captif (DNS wildcard + RFC 8910), pose le marqueur .onboarding.
#   down   : abaisse l'AP + retire le drop-in (le profil persiste pour un re-up).
#   status : ap_up=yes|no ap_ssid=... clients=N
# ATTENTION : 'up' coupe la connexion STA (wlan0) — sur une box gérée à distance par WiFi, c'est une
# perte de lien voulue (l'onboarding se fait sur place). N'est lancé que par firstboot/setup.
set -eu

NMCLI=/usr/bin/nmcli
IFACE=wlan0
CONF=/opt/pisignage/config
DROPIN=/etc/NetworkManager/dnsmasq-shared.d/00-zaforge-captive.conf
AP_CON=zf-onboard-ap
AP_IP=10.42.0.1

ap_ssid() { id="$(cut -c1-4 /etc/machine-id 2>/dev/null || true)"; [ -n "$id" ] || id="0000"; printf 'Zaforge-Setup-%s' "$id"; }

ensure_profile() {
    ssid="$(ap_ssid)"
    if "$NMCLI" -g connection.id con show "$AP_CON" >/dev/null 2>&1; then
        "$NMCLI" con modify "$AP_CON" 802-11-wireless.ssid "$ssid" \
            ipv4.method shared ipv4.addresses "$AP_IP/24" connection.autoconnect no >/dev/null
    else
        "$NMCLI" con add type wifi ifname "$IFACE" con-name "$AP_CON" ssid "$ssid" \
            802-11-wireless.mode ap 802-11-wireless.band bg 802-11-wireless.channel 6 \
            802-11-wireless-security.key-mgmt none \
            ipv4.method shared ipv4.addresses "$AP_IP/24" ipv6.method ignore \
            connection.autoconnect no >/dev/null
    fi
}

install_dropin() {
    mkdir -p "$(dirname "$DROPIN")"
    {
        echo "# Zaforge captive portal (généré par onboard-ap.sh) — tout le DNS -> la box + URL portail."
        echo "address=/#/$AP_IP"
        echo "dhcp-option=114,http://$AP_IP/setup"
    } > "$DROPIN"
    chmod 0644 "$DROPIN"
}

cmd_up() {
    ensure_profile
    install_dropin
    # 2 tentatives : NM peut être occupé à libérer le STA juste avant.
    "$NMCLI" con up "$AP_CON" >/dev/null 2>&1 || "$NMCLI" con up "$AP_CON" >/dev/null 2>&1 || true
    mkdir -p "$CONF"; touch "$CONF/.onboarding"
    printf 'ap_up=yes ap_ssid=%s\n' "$(ap_ssid)"
}

cmd_down() {
    "$NMCLI" con down "$AP_CON" >/dev/null 2>&1 || true
    rm -f "$DROPIN" 2>/dev/null || true
    # Sortie propre d'onboarding : retirer le marqueur (le gate se referme, les endpoints publics
    # s'auto-désactivent). En cas d'échec STA, l'appelant relance 'up' qui le repose.
    rm -f "$CONF/.onboarding" 2>/dev/null || true
    printf 'ap_down\n'
}

# Finalise l'onboarding (appelé en fin de flux complet, Phase B2) : marqueur collant .onboarded +
# nettoyage. Une fois posé, la box ne repasse JAMAIS par l'onboarding.
cmd_finalize() {
    mkdir -p "$CONF"
    : > "$CONF/.onboarded"; chmod 0644 "$CONF/.onboarded" 2>/dev/null || true
    rm -f "$CONF/.onboarding" 2>/dev/null || true
    "$NMCLI" con down "$AP_CON" >/dev/null 2>&1 || true
    "$NMCLI" con delete "$AP_CON" >/dev/null 2>&1 || true
    rm -f "$DROPIN" 2>/dev/null || true
    printf 'finalized\n'
}

cmd_status() {
    up=no
    "$NMCLI" -t -f NAME con show --active 2>/dev/null | grep -Fxq "$AP_CON" && up=yes
    leases=0
    L="/var/lib/NetworkManager/dnsmasq-$IFACE.leases"
    [ -f "$L" ] && leases="$(wc -l < "$L" 2>/dev/null | tr -d ' ')"
    printf 'ap_up=%s ap_ssid=%s clients=%s\n' "$up" "$(ap_ssid)" "$leases"
}

case "${1:-}" in
    up)       cmd_up ;;
    down)     cmd_down ;;
    status)   cmd_status ;;
    finalize) cmd_finalize ;;
    *)        echo "usage: $0 up|down|status|finalize" >&2; exit 2 ;;
esac
