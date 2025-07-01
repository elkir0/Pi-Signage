# Pi Signage Digital - Version LITE

## 🎯 Objectif

Version simplifiée et minimale de Pi Signage pour Raspberry Pi OS Lite, sans modifications agressives du système.

## ✨ Caractéristiques

- **Minimal** : Seulement les modifications essentielles
- **Simple** : Pas de display manager (LightDM), démarrage direct en X11
- **Léger** : ~200MB de RAM utilisée
- **Stable** : Pas de modifications de config.txt risquées
- **Rapide** : Boot en ~30 secondes

## 📋 Prérequis

- Raspberry Pi 3B+ ou supérieur
- Raspberry Pi OS Lite (32 ou 64 bits)
- Carte SD 8GB minimum
- Connexion internet pour l'installation

## 🚀 Installation

```bash
# 1. Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# 2. Télécharger Pi Signage
cd ~
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer

# 3. Lancer l'installation LITE
sudo ./install-lite.sh
```

## 🎬 Utilisation

### Ajout de vidéos

```bash
# Copier vos vidéos
sudo cp *.mp4 /opt/videos/

# Ou via l'interface web
http://[IP-DU-PI]/
```

### Commandes utiles

```bash
# Voir les logs
tail -f /var/log/vlc-signage.log

# Redémarrer le player
sudo systemctl restart getty@tty1

# Test manuel
sudo -u signage startx
```

## 🔧 Configuration

### Changer le mode d'affichage

```bash
# Pour VLC
echo "vlc" | sudo tee /etc/pi-signage/display-mode.conf

# Pour Chromium
echo "chromium" | sudo tee /etc/pi-signage/display-mode.conf

# Redémarrer
sudo reboot
```

### Résolution d'écran

La résolution est détectée automatiquement. Pour forcer une résolution :

```bash
# Éditer /boot/config.txt
sudo nano /boot/config.txt

# Ajouter (exemple pour 1080p)
hdmi_group=2
hdmi_mode=82
```

## 🐛 Dépannage

### Écran noir

1. Vérifier la connexion HDMI
2. Vérifier les logs : `cat /tmp/pi-signage-x11.log`
3. Tester manuellement : `sudo -u signage startx`

### Pas de son

```bash
# Tester le son
speaker-test -t wav -c 2

# Configurer la sortie audio
sudo raspi-config
# Advanced Options > Audio
```

### Interface web inaccessible

```bash
# Vérifier nginx
sudo systemctl status nginx
sudo systemctl restart nginx
```

## 📊 Performances

Sur Raspberry Pi 4 :
- Boot complet : ~30 secondes
- RAM utilisée : ~200MB (VLC) / ~250MB (Chromium)
- CPU au repos : ~5-10%
- Température : ~45°C

## ⚙️ Différences avec la version complète

| Fonctionnalité | Version LITE | Version Complète |
|----------------|--------------|------------------|
| Display Manager | ❌ Non (startx direct) | ✅ LightDM |
| Overclocking | ❌ Non | ✅ Optimisations |
| Services désactivés | Minimal | Agressif |
| Boot time | ~30s | ~45s |
| RAM usage | ~200MB | ~350MB |
| Complexité | Simple | Avancée |

## 🔄 Mise à jour

```bash
cd ~/Pi-Signage
git pull origin main
cd raspberry-pi-installer
sudo ./install-lite.sh
```

## 🆘 Support

- Issues GitHub : https://github.com/elkir0/Pi-Signage/issues
- Logs : `/var/log/pi-signage-setup.log`