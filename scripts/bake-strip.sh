#!/bin/sh
# Zaforge — retire TOUT état par-device d'un rootfs AVANT de sceller l'image golden (Phase C1).
# À lancer dans le contexte de build (chroot, ou rootfs monté via un préfixe). Idempotent.
# Après ce strip + 1er boot, firstboot.sh régénère une identité UNIQUE par carte.
# Usage :  bake-strip.sh [ROOTFS_PREFIX]   (vide = système courant / chroot)
set -u
ROOT="${1:-}"
C="$ROOT/opt/pisignage/config"

# Secrets + identité applicative par-device.
rm -f "$C/agent.json" "$C/credentials.json" "$C/relay-proxy-secret" \
      "$C/.setup-admin-password" "$C/.provisioned" "$C/.onboarding" "$C/.onboarded" \
      "$C/wifi-networks.json" "$C/scheduler-state.json" 2>/dev/null || true
rm -rf "$C/relay" 2>/dev/null || true

# relay.json -> gabarit NON enrôlé.
printf '{\n  "relay_url": "https://relay.zaforge.com",\n  "enrollment_code": "",\n  "rebind": false\n}\n' > "$C/relay.json" 2>/dev/null || true
[ -f "$C/feature_flags" ] && sed -i 's/^ENABLE_RELAY=.*/ENABLE_RELAY=0/' "$C/feature_flags" 2>/dev/null || true

# Identité système (régénérées au 1er boot par RPi OS / firstboot).
rm -f "$ROOT"/etc/ssh/ssh_host_* 2>/dev/null || true
: > "$ROOT/etc/machine-id" 2>/dev/null || true
rm -f "$ROOT/var/lib/dbus/machine-id" 2>/dev/null || true

# Profils réseau du builder (le WiFi de build NE DOIT PAS fuiter dans l'image).
rm -f "$ROOT"/etc/NetworkManager/system-connections/* 2>/dev/null || true
rm -f "$ROOT/etc/NetworkManager/dnsmasq-shared.d/00-zaforge-captive.conf" 2>/dev/null || true

# Logs/historique du build.
rm -f "$ROOT"/opt/pisignage/logs/* 2>/dev/null || true
rm -f "$ROOT"/root/.bash_history "$ROOT"/home/pi/.bash_history 2>/dev/null || true

echo "bake-strip: per-device state removed (rootfs='${ROOT:-/}')"
