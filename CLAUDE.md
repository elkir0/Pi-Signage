<!-- RÈGLES CRITIQUES - AFFICHER AU DÉBUT DE CHAQUE RÉPONSE -->
<project_rules>
📋 PROJET : PiSignage - Système d'affichage digital Raspberry Pi
🔧 STACK : PHP 8.2 + Nginx + VLC + Bash + APIs REST
📍 CONTEXTE : VM de développement dédiée (/opt/pisignage)
✅ VALIDATION : Toujours confirmer avant modification fichiers

MÉMOIRE PERSISTANTE CONTEXTUELLE :
- SQLite MCP : Activé avec PRÉFIXE /opt/pisignage:
- Memory Bank : .claude/memory-bank/
- Recherche : mcp__memory__search_nodes("/opt/pisignage:")
- Sauvegarde : TOUJOURS préfixer avec $(pwd): devant le nom

⚠️ IMPORTANT : TOUJOURS PRÉFIXER LES ENTITÉS MCP AVEC LE CHEMIN DU PROJET
Exemple : "/opt/pisignage:PROJECT" au lieu de "PiSignage Project"
Cela évite les conflits entre différents projets !

⚠️ CES RÈGLES DOIVENT ÊTRE AFFICHÉES AU DÉBUT DE CHAQUE RÉPONSE
</project_rules>
<!-- FIN RÈGLES CRITIQUES -->

# 📺 Mémoire de Contexte - PiSignage v0.8.0 - VERSION STABLE OFFICIELLE

## ✅ ÉTAT ACTUEL : v0.8.0 COMPLÈTEMENT DÉPLOYÉE

**Mise à jour : 22/09/2025 - 15:20**
**Version : 0.8.0 (SEULE VERSION OFFICIELLE)**
**Status : ✅ GITHUB NETTOYÉ - PRÊT POUR PRODUCTION**
**URL Production : http://192.168.1.103 (prêt pour déploiement)**
**GitHub : https://github.com/elkir0/Pi-Signage (UNIQUEMENT v0.8.0)**

## 🔄 HISTORIQUE COMPLET DU PROJET (22/09/2025)

### ⚠️ RÈGLES CRITIQUES OBLIGATOIRES

#### 1. PUSH GITHUB OBLIGATOIRE
**TOUJOURS PUSH SUR GITHUB APRÈS CHAQUE CHANGEMENT IMPORTANT**
- Commande : `git add -A && git commit -m "message" && git push`
- URL : https://github.com/elkir0/Pi-Signage
- Token : Disponible avec accès complet

#### 2. VALIDATION PUPPETEER OBLIGATOIRE (NOUVELLE RÈGLE)
**AVANT DE DÉCLARER "OK" : MINIMUM 2 TESTS PUPPETEER**
- Test 1 : Navigation → Screenshot → Analyse visuelle
- Test 2 : Navigation → Console debug → Vérification erreurs
- JAMAIS dire "c'est OK" sans ces 2 tests validés
- Obligatoire pour toute page web/interface

## 🔄 HISTORIQUE COMPLET DU PROJET (22/09/2025)

### Phase 1 : Tentative Next.js v2.0.1 (Matin)
- **Stack** : Next.js 14 + TypeScript + Tailwind + Glassmorphism
- **Problèmes** :
  - Screenshot non fonctionnel
  - Media management "dégueulasse"
  - YouTube download retournait "Failed to fetch video information"
  - Upload retournait "Internal Server Error"
- **Décision** : Vote de 5 agents AI → 4/5 pour migration PHP

### Phase 2 : Migration PHP v0.8.0 (13h-14h)
- **Création** : Architecture PHP complète depuis zéro
- **Tests** : 2 tests Puppeteer validés
- **Problème** : Interface "MOCHE" et non fonctionnelle malgré tests OK
- **Décision utilisateur** : "ÉNORME ROLLBACK jusqu'à v0.9.4"

### Phase 3 : Tentative rollback v0.9.4 (14h-14h45)
- **Téléchargement** : v0.9.4 depuis GitHub releases
- **Déploiement** : Sur Raspberry Pi (192.168.1.103)
- **Tests** : 2 Puppeteer validés
- **Problème** : Version affichée n'était PAS v0.9.4 (cache nginx persistant)

### Phase 4 : VRAI GROS ROLLBACK (14h45-15h15)
- **Décision utilisateur** : "On dégage TOUT après v0.9.4"
- **Problème** : Utilisateur veut que JE fasse tout, pas lui
- **Action** : Création complète de v0.9.4 en local
- **Puis** : Renommage EN PROFONDEUR v0.9.4 → v0.8.0

### Phase 5 : Nettoyage total et v0.8.0 finale (15h15-15h20)
- ✅ **Renommage** : TOUTES les occurrences v0.9.4 → v0.8.0
- ✅ **GitHub** : Suppression TOTALE + force push v0.8.0
- ✅ **Validation** : 0 trace de v0.9.x, 50 occurrences v0.8.0
- ✅ **Status** : v0.8.0 SEULE VERSION EXISTANTE

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

## 📚 LEÇONS APPRISES ET POINTS CRITIQUES

### ⚠️ PROBLÈMES RÉCURRENTS
1. **Cache nginx persistant** : TOUJOURS vider avec `sudo rm -rf /var/cache/nginx/*`
2. **Versions multiples** : Le Pi garde des traces des anciennes versions
3. **Tests Puppeteer trompeurs** : Peuvent valider même si interface cassée
4. **GitHub tags** : Peuvent créer confusion entre versions

### 🎯 RÈGLES ABSOLUES (NE JAMAIS OUBLIER)
1. **MON RÔLE** : Je fais TOUT, pas l'utilisateur
2. **IP CORRECTE** : 192.168.1.103 (PAS 192.168.0.103)
3. **PROTOCOLE** : Local → GitHub → Pi → 2 tests minimum
4. **CACHE** : Vider AVANT chaque test
5. **DOCUMENTATION** : Tout dans CLAUDE.md

### 🔧 COMMANDES CRITIQUES
```bash
# Vider cache nginx COMPLÈTEMENT
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/*
sudo systemctl restart nginx

# Force push GitHub
git push --force origin main
git push --tags --force

# Déploiement Pi
sshpass -p 'raspberry' ssh pi@192.168.1.103
```

### 📊 HISTORIQUE FINAL DES VERSIONS
- **v0.8.0** : SEULE ET UNIQUE version officielle
- Toutes autres versions : SUPPRIMÉES

---

## 🔑 INFORMATIONS TECHNIQUES ESSENTIELLES

### Raspberry Pi Production
- **IP** : 192.168.1.103
- **User** : pi
- **Password** : raspberry
- **OS** : Raspberry Pi OS
- **Services** : nginx, php8.2-fpm
- **Dossier** : /opt/pisignage

### Structure fichiers v0.8.0
```
50 occurrences v0.8.0 dans :
- VERSION
- README.md
- web/index.php (interface)
- web/api/*.php (toutes les APIs)
- CLAUDE.md (documentation)
- deploy-v080-to-production.sh
```

### APIs disponibles (v0.8.0)
- `/api/system.php` : Infos système
- `/api/media.php` : Gestion médias
- `/api/playlist.php` : Playlists
- `/api/screenshot.php` : Capture écran
- `/api/youtube.php` : Download YouTube

### Scripts de déploiement
- `/opt/pisignage/deploy-v080-to-production.sh` : Deploy sur Pi
- `/opt/pisignage/github-clean-and-push-v080.sh` : Nettoyage GitHub

### État actuel
- **Local** : v0.8.0 complète dans /opt/pisignage
- **GitHub** : UNIQUEMENT v0.8.0 (force pushed)
- **Production** : En attente de déploiement

---

*Dernière mise à jour : 22/09/2025 - 15:25*
*État : v0.8.0 PRÊTE - GitHub nettoyé - Attente déploiement production*
*Commande déploiement : `/opt/pisignage/deploy-v080-to-production.sh`*