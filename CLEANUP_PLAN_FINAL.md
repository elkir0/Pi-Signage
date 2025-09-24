# 🧹 PLAN DE NETTOYAGE FINAL - PiSignage v0.8.0

## ⚠️ AVERTISSEMENT
- **Backup créé** : `/tmp/pisignage-backup-20250924-1640.tar.gz` (333MB)
- **93 scripts modifiés récemment** - Prudence extrême requise
- **index-GOLDEN-MASTER.php** : À CONSERVER comme référence

## 📊 DÉCISIONS FINALES

### ✅ FICHIERS À CONSERVER ABSOLUMENT

#### Web Interface
```bash
web/index.php                    # Interface actuelle AVEC toutes les corrections
web/index-GOLDEN-MASTER.php      # Référence validée par l'utilisateur (BACKUP)
web/config.php                   # Configuration
web/favicon.ico                  # Favicon
web/api/*.php                    # TOUTES les APIs (8 fichiers)
```

#### Scripts Essentiels (confirmés)
```bash
# Installation et déploiement
install-pisignage-bullseye.sh   # Script principal d'installation
deploy-v080-to-production.sh    # Déploiement production actuel
fix-php-limits.sh               # Fix limites PHP
install-ytdlp.sh                # Installation YouTube

# Scripts VLC actifs
scripts/vlc-control.sh          # Contrôle VLC principal
scripts/vlc-config-optimizer.sh # Optimisation config
scripts/vlc-monitor.sh          # Monitoring VLC

# Scripts système
scripts/screenshot.sh           # Capture d'écran
scripts/install-screenshot.sh   # Installation capture
```

#### Tests Validés (6 fichiers)
```bash
test-validation-final.js         # Validation complète
test-media-fixes.js             # Tests media
test-playlist-functions.js      # Tests playlists
test-youtube-download.js        # Tests YouTube
test-youtube-validation.js      # Validation YouTube
test-improvements-validation.js  # Dernières améliorations
```

#### Documentation
```bash
README.md                       # Documentation publique
CLAUDE.md                       # Documentation développement
VERSION                         # Version actuelle
LICENSE                         # Licence (à créer)
```

### 🗑️ FICHIERS À SUPPRIMER

#### Interfaces Web Obsolètes
```bash
web/index_old.php              # Ancienne version
web/index_modern.php           # Version moderne obsolète
web/index_modern.php           # Doublon
# GARDER: web/index-GOLDEN-MASTER.php comme référence !
```

#### Tests Obsolètes (29 fichiers)
```bash
test-production-*.js           # Anciens tests production
test-puppeteer-*.js           # Tests puppeteer obsolètes
test-final-compatible.js       # Ancien test
test-final-signage.js         # Ancien test
test-improved-*.js            # Anciennes améliorations
test-user-*.js               # Tests utilisateur obsolètes
test-modern-*.js             # Tests interface obsolète
test-upload-*.js             # Anciens tests upload
test-nav.js                  # Test navigation simple
test-console-*.js            # Tests console obsolètes
test-apis-simple.js          # Test API simple
test-all-*.js                # Anciens tests complets
test-functions-*.js          # Tests fonctions obsolètes
test-pisignage-*.js          # Anciens tests généraux
test-delete-real.js          # Test suppression
test-edit-modal-debug.js     # Debug modal
```

#### Scripts Shell Obsolètes
```bash
# Scripts de déploiement obsolètes
deploy-complete*.sh
deploy-fresh*.sh
deploy-bullseye*.sh
rollback*.sh
github-clean-and-push*.sh

# Scripts Chromium inutilisés
chromium-*.sh
start-chromium-*.sh

# Scripts GPU obsolètes
gpu-*.sh
optimize-gpu*.sh
monitor-fps.sh

# Doublons et tests
test-*.sh
quick-test-*.sh
validate-*.sh
```

#### Screenshots et Images
```bash
screenshots/*.png              # Tous les screenshots
*.png                         # Screenshots à la racine
*.jpg                         # Images de test
# SAUF : web/favicon.ico
```

### 📁 NOUVELLE STRUCTURE

```
/opt/pisignage/
├── README.md
├── CLAUDE.md
├── VERSION
├── LICENSE
├── .gitignore
│
├── web/                      # Application Web
│   ├── index.php            # Interface principale
│   ├── config.php           # Configuration
│   ├── favicon.ico          # Favicon
│   ├── api/                 # APIs REST (8 fichiers)
│   └── backups/             # Sauvegardes
│       └── index-GOLDEN-MASTER.php
│
├── scripts/                  # Scripts Système
│   ├── vlc-control.sh       # Contrôle VLC
│   ├── screenshot.sh        # Capture écran
│   └── install/             # Scripts installation
│       ├── install-pisignage-bullseye.sh
│       ├── install-ytdlp.sh
│       └── install-screenshot.sh
│
├── config/                   # Configuration
│   ├── nginx-site.conf      # Config nginx
│   ├── systemd/             # Services systemd
│   └── playlists.json       # Playlists
│
├── media/                    # Fichiers média
│   └── .gitkeep
│
├── logs/                     # Logs
│   └── .gitkeep
│
├── tests/                    # Tests validés
│   ├── validation-final.js
│   ├── media-fixes.js
│   ├── playlist-functions.js
│   ├── youtube-download.js
│   ├── youtube-validation.js
│   └── improvements-validation.js
│
├── docs/                     # Documentation
│   ├── API.md               # Doc API
│   ├── INSTALL.md           # Guide installation
│   └── TROUBLESHOOTING.md   # Dépannage
│
├── deploy.sh                 # Script déploiement principal
└── fix-php-limits.sh        # Fixes critiques
```

### 🎯 COMMANDES DE NETTOYAGE

```bash
# 1. Créer branche de nettoyage
git checkout -b cleanup-repository

# 2. Créer la nouvelle structure
mkdir -p web/backups scripts/install config/systemd tests docs

# 3. Déplacer les fichiers à conserver
mv web/index-GOLDEN-MASTER.php web/backups/
mv test-validation-final.js tests/validation-final.js
# ... etc

# 4. Supprimer les fichiers obsolètes
rm -f web/index_old.php web/index_modern.php
rm -f test-production-*.js test-puppeteer-*.js
# ... etc

# 5. Créer .gitignore
cat > .gitignore << EOF
# Logs
logs/
*.log

# Media files
media/*.mp4
media/*.jpg
media/*.png

# Temp files
*.tmp
*.swp
.DS_Store

# Config local
config/local.json

# Node modules
node_modules/

# Backup files
*.backup
*.bak
EOF

# 6. Commit et push
git add -A
git commit -m "🧹 MAJOR: Repository cleanup and reorganization

- Removed 29 obsolete test files
- Removed duplicate index.php versions
- Reorganized scripts into categories
- Created proper directory structure
- Kept GOLDEN-MASTER as reference
- Preserved 6 validated tests
- Added comprehensive .gitignore

Repository is now clean and organized!"
```

## ⚠️ VALIDATION REQUISE

**AVANT d'exécuter ce nettoyage :**
1. ✅ Backup complet créé
2. ⚡ Confirmer la suppression des 29 tests obsolètes
3. ⚡ Confirmer la suppression des scripts shell obsolètes
4. ⚡ Valider la nouvelle structure
5. ⚡ GO/NO-GO pour exécution ?

**Ce nettoyage va supprimer ~60% des fichiers du repository !**