# 📋 CLAUDE.md - Instructions de Maintenance PiSignage v0.8.1 GOLDEN

## 🎯 Mission Critique
Maintenir PiSignage v0.8.1 GOLDEN opérationnel avec VLC + Big Buck Bunny au démarrage.

## ⚙️ Configuration Actuelle (25/09/2025)
- **Version** : v0.8.1 GOLDEN
- **Player par défaut** : VLC (PAS MPV!)
- **Vidéo de démo** : Big Buck Bunny 720p
- **Interface** : Glassmorphisme v0.8.1
- **OS** : Raspberry Pi OS Bookworm avec Wayland

## 📂 Scripts Critiques

### Installation Complète
```bash
/opt/pisignage/install-golden.sh          # Script ONE-CLICK principal
/opt/pisignage/fix-v0.8.1-complete.sh     # Corrections VLC/Wayland/BBB
```

### Gestion des Players
```bash
/opt/pisignage/scripts/start-vlc-wayland.sh       # Lancement VLC optimisé
/opt/pisignage/scripts/player-manager-v0.8.1.sh   # Gestionnaire dual VLC/MPV
```

## 🚀 Commandes Importantes

### Après modifications
```bash
# TOUJOURS synchroniser avec GitHub
git add -A
git commit -m "🔧 Update v0.8.1 - [description]"
git push origin main
```

### Vérifications
```bash
# Vérifier VLC actif
pgrep -f vlc

# Vérifier version interface
curl -s http://192.168.1.103/ | grep v0.8

# Status des services
systemctl --user status pisignage-vlc
```

## 🐛 Problèmes Connus et Solutions

### VLC ne démarre pas
- Cause : Wayland/Permissions
- Solution : Exécuter `/opt/pisignage/fix-v0.8.1-complete.sh`

### Pas de vidéo au boot
- Vérifier : `/opt/pisignage/media/big_buck_bunny_720p.mp4` existe
- Vérifier : Config player = "vlc" dans `/opt/pisignage/config/player-config.json`

### Interface affiche v0.8.0
```bash
sudo sed -i "s/'version' => '0.8.0'/'version' => '0.8.1'/g" /opt/pisignage/web/index.php
```

## 📊 Configuration Wayland/Bookworm

### Packages Requis (ChatGPT Recommendations)
- raspberrypi-ffmpeg (peut ne pas exister)
- v4l-utils
- seatd
- libgl1-mesa-dri
- mesa-utils

### Variables d'Environnement
```bash
WAYLAND_DISPLAY=wayland-0
XDG_RUNTIME_DIR=/run/user/1000
```

### Options VLC pour Wayland
```bash
--vout=gles2 --fullscreen --loop --quiet
```

## 🔄 Workflow de Maintenance

1. **Toute modification** → Test local
2. **Test OK** → Commit Git
3. **Commit** → Push GitHub
4. **Documentation** → Mettre à jour ce fichier

## 🎯 Objectifs v0.8.1 GOLDEN

✅ VLC par défaut (pas MPV)
✅ Big Buck Bunny au démarrage
✅ Interface web v0.8.1
✅ Support Wayland/Bookworm
✅ Installation ONE-CLICK

## 📝 Notes Importantes

- **NE JAMAIS** revenir à MPV par défaut sans demande explicite
- **TOUJOURS** garder Big Buck Bunny comme vidéo de démonstration
- **MAINTENIR** la synchronisation GitHub après chaque changement validé
- **TESTER** le redémarrage après modifications système

## 🔗 Ressources

- GitHub : https://github.com/elkir0/Pi-Signage
- Interface : http://192.168.1.103/
- Raspberry Pi : 192.168.1.103 (pi/raspberry)

## 📅 Dernière Mise à Jour
25/09/2025 - v0.8.1 GOLDEN avec VLC/Wayland/BBB fonctionnel

---
*Ce fichier doit être maintenu à jour après chaque modification importante*