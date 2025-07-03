# Configuration du démarrage automatique en mode kiosk sur Raspberry Pi OS Bookworm Desktop

## Vue d'ensemble des changements majeurs dans Bookworm

Raspberry Pi OS Bookworm (2023-2024) introduit des changements architecturaux significatifs qui impactent directement la configuration du mode kiosk :

**Wayland devient le système de fenêtrage par défaut** sur les modèles récents, remplaçant X11. Le compositeur **labwc** (depuis octobre 2024) a remplacé Wayfire comme gestionnaire par défaut. Cette transition s'applique différemment selon le matériel : Raspberry Pi 5 et Pi 4 (2GB+) utilisent Wayland par défaut, tandis que les Pi 3 et modèles antérieurs restent sur X11 avec Openbox.

## 1. Configuration de l'autologin sur Bookworm Desktop

### Méthode recommandée via raspi-config

La méthode la plus simple reste l'utilisation de raspi-config, qui gère automatiquement les différences entre les systèmes :

```bash
sudo raspi-config
```

Navigation : **1 System Options** → **S5 Boot / Auto Login** → **B4 Desktop Autologin**

Cette commande peut aussi être scriptée :
```bash
sudo raspi-config nonint do_boot_behaviour B4
```

### Configuration manuelle de LightDM

Pour une configuration manuelle, modifiez `/etc/lightdm/lightdm.conf` :

```ini
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
# Pour Wayland (Pi 4/5)
autologin-session=LXDE-pi-labwc
# Pour X11 (Pi 3 et antérieurs)
# autologin-session=LXDE-pi-x
```

Complétez avec la configuration systemd pour getty :
```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
EOF
```

## 2. Différences critiques entre X11 et Wayland pour le mode kiosk

### Détection du système actif

```bash
# Depuis une session graphique
echo $XDG_SESSION_TYPE  # Retourne "x11" ou "wayland"

# Vérification des variables d'environnement
echo $WAYLAND_DISPLAY   # Non vide si Wayland
echo $DISPLAY          # Non vide si X11
```

### Configuration spécifique Wayland (labwc)

Pour Wayland, le fichier de configuration principal est `/etc/xdg/labwc/autostart` :

```bash
#!/bin/sh
# Désactiver les composants desktop non nécessaires
/usr/bin/kanshi &
/usr/bin/lxsession-xdg-autostart &

# Lancer Chromium en mode kiosk
chromium-browser --start-maximized --start-fullscreen --kiosk \
  --noerrdialogs --disable-infobars --no-first-run \
  --ozone-platform=wayland --enable-features=OverlayScrollbar \
  https://votre-url.com
```

### Configuration spécifique X11

Pour X11, utilisez `/etc/xdg/lxsession/LXDE-pi/autostart` :

```bash
@xset s noblank
@xset s off
@xset -dpms
@unclutter -idle 0.5 -root
@chromium-browser --kiosk --start-maximized \
  --noerrdialogs --disable-infobars --no-first-run \
  https://votre-url.com
```

## 3. Script d'installation complet pour Pi Signage Digital

### Script principal d'installation

```bash
#!/bin/bash
# install-kiosk-bookworm.sh

set -e

# Variables
KIOSK_URL="${1:-https://example.com}"
KIOSK_USER="pi"

# Détection du système
detect_display_system() {
    if command -v labwc >/dev/null 2>&1; then
        echo "wayland-labwc"
    elif command -v wayfire >/dev/null 2>&1; then
        echo "wayland-wayfire"
    else
        echo "x11"
    fi
}

DISPLAY_SYSTEM=$(detect_display_system)
echo "Système détecté: $DISPLAY_SYSTEM"

# Configuration autologin
echo "Configuration de l'autologin..."
sudo raspi-config nonint do_boot_behaviour B4

# Installation des dépendances
sudo apt update
sudo apt install -y chromium-browser unclutter

# Création du script de démarrage kiosk
cat > /home/$KIOSK_USER/kiosk.sh << 'EOF'
#!/bin/bash

# Attendre que le système soit prêt
sleep 5

# Nettoyer les préférences Chromium
CHROME_PREFS="$HOME/.config/chromium/Default/Preferences"
if [ -f "$CHROME_PREFS" ]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$CHROME_PREFS"
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$CHROME_PREFS"
fi

# Déterminer les options selon le système
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    PLATFORM_FLAGS="--ozone-platform=wayland --start-maximized"
else
    PLATFORM_FLAGS=""
    # Configuration X11
    xset s off
    xset s noblank
    xset -dpms
    unclutter -idle 0.5 -root &
fi

# Lancer Chromium
chromium-browser \
  --kiosk \
  --start-fullscreen \
  --noerrdialogs \
  --disable-infobars \
  --disable-translate \
  --no-first-run \
  --disable-features=TranslateUI \
  --disable-restore-session-state \
  --disable-session-crashed-bubble \
  --disable-component-extensions-with-background-pages \
  --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 \
  --incognito \
  --user-data-dir=/tmp/chromium-kiosk \
  $PLATFORM_FLAGS \
  "KIOSK_URL_PLACEHOLDER"
EOF

# Remplacer l'URL dans le script
sed -i "s|KIOSK_URL_PLACEHOLDER|$KIOSK_URL|g" /home/$KIOSK_USER/kiosk.sh
chmod +x /home/$KIOSK_USER/kiosk.sh

# Configuration selon le système
if [[ "$DISPLAY_SYSTEM" == "wayland"* ]]; then
    configure_wayland_kiosk
else
    configure_x11_kiosk
fi

echo "Installation terminée. Redémarrage nécessaire."
```

### Fonction de configuration Wayland

```bash
configure_wayland_kiosk() {
    # Configuration pour labwc
    if [[ "$DISPLAY_SYSTEM" == "wayland-labwc" ]]; then
        sudo mkdir -p /etc/xdg/labwc
        sudo tee /etc/xdg/labwc/autostart << EOF
#!/bin/sh
/usr/bin/kanshi &
/usr/bin/lxsession-xdg-autostart &
/home/$KIOSK_USER/kiosk.sh &
EOF
        sudo chmod +x /etc/xdg/labwc/autostart
    
    # Configuration pour wayfire (versions antérieures)
    elif [[ "$DISPLAY_SYSTEM" == "wayland-wayfire" ]]; then
        mkdir -p /home/$KIOSK_USER/.config
        cat > /home/$KIOSK_USER/.config/wayfire.ini << EOF
[core]
plugins = autostart

[autostart]
autostart_wf_shell = false
panel = false
background = false
screensaver = false
dpms = false
kiosk = /home/$KIOSK_USER/kiosk.sh

[idle]
screensaver_timeout = 0
dpms_timeout = 0
EOF
        chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.config/wayfire.ini
    fi
}
```

### Fonction de configuration X11

```bash
configure_x11_kiosk() {
    # Configuration autostart LXDE
    sudo mkdir -p /etc/xdg/lxsession/LXDE-pi
    sudo tee /etc/xdg/lxsession/LXDE-pi/autostart << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@point-rpi
@/home/$KIOSK_USER/kiosk.sh
EOF
}
```

## 4. Service SystemD pour une meilleure fiabilité

### Service utilisateur (recommandé)

Créez `~/.config/systemd/user/kiosk.service` :

```ini
[Unit]
Description=Chromium Kiosk Mode
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/home/pi/kiosk.sh
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=default.target
```

Activation :
```bash
systemctl --user enable kiosk.service
sudo loginctl enable-linger pi
```

## 5. Gestion des permissions et de l'utilisateur

### Configuration des permissions essentielles

```bash
# Ajouter l'utilisateur aux groupes nécessaires
sudo usermod -a -G video,audio,input,tty,seat pi

# Configuration seatd pour Wayland
sudo apt install -y seatd
sudo systemctl enable --now seatd

# Permissions udev
sudo tee /etc/udev/rules.d/99-kiosk.rules << 'EOF'
SUBSYSTEM=="input", GROUP="input", MODE="0664"
SUBSYSTEM=="drm", GROUP="video", MODE="0664"
SUBSYSTEM=="seat", GROUP="seat", MODE="0664"
EOF

sudo udevadm control --reload-rules
```

## 6. Résolution des problèmes courants

### Écran noir au démarrage

**Cause principale** : Problème de configuration Wayland ou permissions manquantes

**Solution** :
```bash
# Vérifier le statut seatd
sudo systemctl status seatd

# Forcer la configuration HDMI
echo "hdmi_force_hotplug=1" | sudo tee -a /boot/firmware/config.txt
echo "hdmi_group=2" | sudo tee -a /boot/firmware/config.txt
echo "hdmi_mode=82" | sudo tee -a /boot/firmware/config.txt
```

### Chromium n'apparaît que sur quelques pixels

**Solution spécifique Wayland** : L'ordre des flags est critique
```bash
# CORRECT - start-maximized AVANT start-fullscreen
chromium-browser --start-maximized --start-fullscreen --kiosk

# INCORRECT
chromium-browser --kiosk --start-fullscreen --start-maximized
```

### Problèmes de permissions

```bash
# Script de diagnostic
#!/bin/bash
echo "=== Diagnostic Permissions Kiosk ==="
echo "Utilisateur: $(whoami)"
echo "Groupes: $(groups)"
echo "Seatd actif: $(systemctl is-active seatd)"
echo "Session type: $XDG_SESSION_TYPE"
ls -la ~/.Xauthority 2>/dev/null || echo "Pas de .Xauthority"
```

## 7. Script de surveillance et redémarrage automatique

```bash
#!/bin/bash
# /home/pi/kiosk-watchdog.sh

KIOSK_SCRIPT="/home/pi/kiosk.sh"
LOG_FILE="/var/log/kiosk-watchdog.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

while true; do
    if ! pgrep -f "chromium-browser.*--kiosk" > /dev/null; then
        log "Chromium kiosk non détecté, redémarrage..."
        
        # Tuer les processus résiduels
        pkill -f chromium-browser
        sleep 2
        
        # Nettoyer et redémarrer
        rm -rf /tmp/chromium-kiosk
        $KIOSK_SCRIPT &
        
        log "Kiosk redémarré"
    fi
    
    sleep 30
done
```

## 8. Configuration optimisée pour le digital signage

### Désactivation complète des popups et notifications

```bash
# Préférences Chromium pour digital signage
mkdir -p ~/.config/chromium/Default
cat > ~/.config/chromium/Default/Preferences << 'EOF'
{
  "profile": {
    "default_content_setting_values": {
      "notifications": 2,
      "popups": 2,
      "geolocation": 2,
      "media_stream": 2,
      "plugins": 1,
      "automatic_downloads": 1
    }
  }
}
EOF
```

### Optimisation GPU

```bash
# Configuration GPU dans /boot/firmware/config.txt
gpu_mem=128
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Flags Chromium pour accélération matérielle
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--enable-accelerated-video-decode
```

## Script final unifié pour Pi Signage Digital

```bash
#!/bin/bash
# setup-pi-signage-bookworm.sh

set -e

SIGNAGE_URL="${1:-https://pisignage.com/dashboard}"

# Fonction principale d'installation
install_pi_signage() {
    echo "Installation Pi Signage Digital pour Bookworm..."
    
    # Mise à jour système
    sudo apt update && sudo apt upgrade -y
    
    # Installation dépendances
    sudo apt install -y chromium-browser unclutter seatd
    
    # Configuration autologin
    sudo raspi-config nonint do_boot_behaviour B4
    
    # Détection automatique du système
    if [ -f /usr/bin/labwc ] || [ -f /usr/bin/wayfire ]; then
        echo "Configuration pour Wayland détectée"
        setup_wayland_signage
    else
        echo "Configuration pour X11 détectée"
        setup_x11_signage
    fi
    
    # Configuration des permissions
    setup_permissions
    
    # Installation du watchdog
    setup_watchdog
    
    echo "Installation terminée. Redémarrage dans 10 secondes..."
    sleep 10
    sudo reboot
}

# Lancer l'installation
install_pi_signage
```

## Points clés pour Pi Signage Digital

### 1. Détection automatique du système d'affichage
- Détecter si le système utilise X11, Wayfire ou labwc
- Adapter la configuration en conséquence

### 2. Configuration différenciée selon le système
- **X11** : Utiliser `/etc/xdg/lxsession/LXDE-pi/autostart`
- **Wayfire** : Configurer via `~/.config/wayfire.ini`
- **labwc** : Utiliser `/etc/xdg/labwc/autostart`

### 3. Ordre critique des flags Chromium pour Wayland
- `--start-maximized` DOIT précéder `--start-fullscreen`
- Ajouter `--ozone-platform=wayland` pour Wayland

### 4. Gestion des permissions
- Installation et activation de `seatd` pour Wayland
- Ajout de l'utilisateur aux groupes appropriés
- Configuration des règles udev

### 5. Utilisation de raspi-config pour l'autologin
- Méthode la plus fiable et compatible
- Gère automatiquement les différences entre systèmes

Cette documentation technique complète couvre tous les aspects de la configuration d'un mode kiosk sur Raspberry Pi OS Bookworm, avec une attention particulière aux différences entre X11 et Wayland, les méthodes de configuration automatique, et la résolution des problèmes courants spécifiques à cette version.