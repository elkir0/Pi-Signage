# 📺 Mémoire de Contexte - PiSignage v0.8.0 - VERSION STABLE OFFICIELLE

## ✅ ÉTAT ACTUEL : v0.8.0 PRÊTE POUR DÉPLOIEMENT

**Mise à jour : 22/09/2025 - 15:15**
**Version : 0.8.0 (stable officielle)**
**Status : ✅ PRÊT POUR DÉPLOIEMENT PRODUCTION**
**URL Production : http://192.168.1.103 (en attente de déploiement)**
**GitHub : https://github.com/elkir0/Pi-Signage (master = v0.8.0)**

## 🔄 HISTORIQUE DU ROLLBACK COMPLET

### Contexte du rollback (22/09/2025)
- **Problème identifié** : Version en production n'était PAS v0.8.0 malgré les tests
- **Cause** : Persistance de l'ancienne version via cache nginx
- **Décision** : ROLLBACK COMPLET de tout l'écosystème

### Actions effectuées
1. ✅ **Environnement local** : Nettoyé et réinstallé v0.8.0
2. ✅ **GitHub** : Rollback préparé vers tag v0.8.0
3. ⏳ **Raspberry Pi** : En attente de déploiement propre
4. ✅ **Documentation** : CLAUDE.md mis à jour

## 🏗️ Architecture v0.8.0 (Version PHP stable)

```
/opt/pisignage/
├── VERSION               # "0.8.0"
├── README.md            # Documentation
├── CLAUDE.md            # Ce fichier (préservé)
├── web/
│   ├── index.php        # Interface principale
│   ├── config.php       # Configuration
│   └── api/
│       ├── system.php   # API système
│       ├── media.php    # Gestion médias
│       ├── playlist.php # Playlists
│       ├── screenshot.php # Captures
│       ├── youtube.php  # YouTube download
│       └── upload.php   # Upload fichiers
├── scripts/
│   ├── vlc-control.sh   # Contrôle VLC
│   ├── screenshot.sh    # Capture d'écran
│   └── youtube-dl.sh    # Téléchargement YouTube
├── media/               # Stockage médias
├── config/              # Fichiers config
└── logs/                # Logs système
```

## 📋 PROTOCOLE DE DÉPLOIEMENT STRICT

### ⚠️ RÈGLES ABSOLUES (HARDCODÉES)
1. **JAMAIS** retourner avant validation complète
2. **TOUJOURS** faire 2 tests Puppeteer minimum sur production
3. **DOCUMENTER** chaque changement dans CLAUDE.md
4. **IP CORRECTE** : 192.168.1.103 (PAS 192.168.0.103)
5. **VIDER LE CACHE** nginx avant chaque test

### Workflow obligatoire
```bash
1. Développer localement
2. Tester en local
3. Push sur GitHub (tag v0.8.0)
4. Déployer sur Raspberry Pi
5. Vider cache nginx
6. 2 tests Puppeteer minimum
7. Si échec → répéter jusqu'au succès
8. Mettre à jour CLAUDE.md
```

## 🔧 État actuel des services

### Local (cet ordinateur)
- ✅ Structure v0.8.0 créée dans `/opt/pisignage`
- ✅ Scripts de déploiement prêts
- ✅ CLAUDE.md à jour

### GitHub
- ⏳ Rollback à effectuer vers tag v0.8.0
- Commande : `git push --force origin v0.8.0:master`

### Raspberry Pi (192.168.1.103)
- ⚠️ Version incorrecte actuellement
- ⏳ En attente de déploiement propre v0.8.0
- Nécessite : Reset complet + déploiement depuis zéro

## 🚀 Script de déploiement prêt

```bash
# Script disponible dans :
/opt/pisignage/deploy-to-production.sh

# Ou directement :
/opt/rollback-v080-complete.sh
```

## 📊 Fonctionnalités v0.8.0

### ✅ Fonctionnelles
- Video loop avec VLC
- Interface web PHP
- APIs système de base
- Gestion playlists
- Configuration

### ⚠️ Limitations connues
- Upload limité (pas upload.php dans certaines versions)
- Screenshot basique
- YouTube download peut nécessiter yt-dlp

## 🔍 Tests de validation requis

### Test 1 : Accès de base
```javascript
- HTTP 200 sur http://192.168.1.103
- Titre contient "PiSignage"
- Au moins 5 APIs répondent
```

### Test 2 : Validation complète
```javascript
- Performance < 1s
- Erreurs console < 5
- APIs fonctionnelles
- Interface chargée correctement
```

## 📝 Notes importantes

### Cache nginx
**CRITICAL** : Toujours vider le cache nginx avant les tests
```bash
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
```

### Versions affichées
- Le titre affiche "v0.8.0" (configuré dans index.php)
- Le fichier VERSION contient "0.8.0"
- C'est la structure des fichiers qui détermine la vraie version

## 🎯 Prochaines étapes

1. ⏳ **Finaliser rollback GitHub**
2. ⏳ **Reset Raspberry Pi** (attente utilisateur)
3. ⏳ **Déployer v0.8.0 propre**
4. ⏳ **Valider avec 2 tests Puppeteer**
5. ⏳ **Confirmer succès**

## 📊 Historique des versions

- **v0.8.0** (20/09/2025) : Version stable PHP - CIBLE DU ROLLBACK
- **v2.0.1** (22/09/2025) : Next.js glassmorphism - Abandonnée
- **v0.8.0** (22/09/2025) : Migration PHP - Interface cassée
- **v3.1.0** : Version incorrecte trouvée en production

---

*Dernière mise à jour : 22/09/2025 - 15:00*
*État : ROLLBACK EN COURS vers v0.8.0*
*Prochaine action : Attente déploiement production*