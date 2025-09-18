# 🖥️ PiSignage Desktop v3.0

**Solution d'affichage numérique optimisée pour Raspberry Pi OS Desktop**

[![Version](https://img.shields.io/badge/Version-3.0.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%20OS%20Desktop-red.svg)]()

## 📌 Introduction

PiSignage Desktop est une solution complète d'affichage numérique conçue pour exploiter pleinement les capacités de Raspberry Pi OS Desktop. Version 3.0 = refactoring complet pour performances optimales.

## ⚡ Installation Rapide

```bash
# Installation one-liner
curl -sSL https://raw.githubusercontent.com/elkir0/pisignage-desktop/main/quick-install.sh | bash

# OU installation manuelle
git clone https://github.com/elkir0/pisignage-desktop.git
cd pisignage-desktop
./install.sh
```

## 🎯 Utilisation

Interface web: `http://[IP-RASPBERRY]/`
- User: admin
- Pass: admin

Commandes:
```bash
pisignage-player {start|stop|restart|status}
pisignage-service {start|stop|status|logs}
pisignage-monitor  # Monitoring temps réel
```

## 📊 Performances

- **60 FPS** en Full HD (vs 3-4 FPS sur Lite)
- Installation en **5-10 minutes**
- **5 modules** simplifiés (vs 11 avant)

## 🔧 Dépannage

```bash
# Status complet
pisignage-service status

# Logs
sudo journalctl -u pisignage -f

# Redémarrage
sudo systemctl restart pisignage
```

## 📝 Licence

MIT License

---
**PiSignage Desktop v3.0** - Simple. Puissant. Performant.
