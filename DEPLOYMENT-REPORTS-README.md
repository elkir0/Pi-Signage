# 📦 Rapports de Déploiement - Archive Historique

> **Note**: Ces rapports sont conservés pour historique mais concernent des versions antérieures

## Fichiers archivés

### Rapports de test et déploiement
1. **DEPLOYMENT-SUCCESS-REPORT.md** - Déploiement module Scheduler v0.8.5 (30 sept 2025)
2. **RASPBERRY_PI_DEPLOYMENT.md** - Guide déploiement v0.8.5
3. **docs/DEPLOYMENT-TEST-REPORT.md** - Tests v0.8.9 (oct 2025)

### Protocoles et procédures
1. **DEPLOYMENT_PROTOCOL.md** - Protocole de déploiement général
   - ⚠️ Contient credentials (192.168.1.103 / pi:raspberry)
   - Toujours utilisable pour procédures SCP/SSH

## Documentation actuelle

Pour les déploiements v0.8.9+ avec Trixie, consultez:

- **Installation standard** → `docs/INSTALL.md`
- **Upgrade Trixie** → `UPGRADE_TRIXIE.md`
- **Architecture** → `docs/ARCHITECTURE.md`
- **Troubleshooting** → `docs/TROUBLESHOOTING.md`

## Utilisation des rapports archivés

Ces rapports peuvent être utiles pour :
- Comprendre l'historique du développement
- Référence pour migrations de versions
- Exemples de procédures de test
- Debug de problèmes similaires

**Ne pas utiliser** comme référence principale pour v0.8.9+.

## Sécurité

⚠️ **DEPLOYMENT_PROTOCOL.md** contient des credentials par défaut :
- IP: 192.168.1.103
- User/Pass: pi/raspberry

Ces credentials sont des exemples et doivent être changés en production.

---

**Date d'archivage** : novembre 2025
**Version actuelle** : v0.8.9
**Raison** : Rapports spécifiques à versions antérieures
