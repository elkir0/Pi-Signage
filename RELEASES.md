# 📦 Notes de versions Pi Signage Digital

## Version 2.4.1 (1er janvier 2025)

### 🎯 Points clés
- **Version LITE** pour Raspberry Pi OS Lite
- Corrections de stabilité au démarrage
- Scripts de réparation d'urgence

### 🆕 Nouveautés
- `install-lite.sh` : Installation minimale sans modifications système agressives
- Module de démarrage progressif pour éviter les blocages
- Scripts de diagnostic et réparation boot

### 🐛 Corrections
- Écran noir sur Raspberry Pi OS Lite (suppression de dtoverlay problématique)
- Blocage au démarrage (systemd-tmpfiles-setup)
- Conflits de services au boot

### 💡 Recommandations
- Utiliser `install-lite.sh` pour Raspberry Pi OS Lite
- Version standard pour Raspberry Pi OS Desktop

---

## Version 2.4.0 (1er janvier 2025)

### 🎯 Points clés
- Support audio complet
- Gestion de playlist avancée
- Logo personnalisé intégré

### 🆕 Nouveautés principales
- Configuration audio HDMI/Jack
- Page de gestion de playlist (drag & drop)
- API player.php complète
- Logo Pi Signage dans toute l'interface
- Scripts utilitaires audio

### 🐛 Corrections majeures
- Format MP4 forcé pour YouTube
- Mise à jour automatique playlist
- Token JavaScript corrigé

---

## Version 2.3.0 (31 décembre 2024)

### 🎯 Points clés
- Mode Chromium Kiosk
- Installation modulaire
- Support VM/Headless

### 🆕 Nouveautés
- Alternative légère à VLC avec Chromium
- Player HTML5 avec WebSocket
- Détection automatique VM
- Installation par modules

---

## Version 2.2.0 (30 décembre 2024)

### 🎯 Points clés
- Interface web moderne
- Téléchargement YouTube
- Sécurité renforcée

### 🆕 Nouveautés
- Interface web PHP complète
- Intégration yt-dlp
- Chiffrement des mots de passe
- Scripts d'administration

---

## Version 2.1.0 (29 décembre 2024)

### 🎯 Points clés
- Refonte complète architecture
- Support multi-Pi
- Documentation étendue

### 🆕 Nouveautés
- Scripts modulaires
- Support Pi 3B+/4B/5
- Mode diagnostique
- Watchdog amélioré

---

## Version 2.0.0 (28 décembre 2024)

### 🎯 Points clés
- Première version publique
- Installation automatisée
- Interface basique

### 🆕 Fonctionnalités de base
- VLC en mode kiosque
- Sync Google Drive
- Monitoring Glances
- Scripts de maintenance