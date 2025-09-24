# 🧹 ANALYSE DE NETTOYAGE GITHUB - PiSignage v0.8.0

## 📊 STATISTIQUES ACTUELLES
- **Images/Screenshots**: 18 fichiers
- **Tests JavaScript**: 35 fichiers
- **Interfaces web**: 5 versions d'index.php
- **Scripts Shell**: 81 scripts (!!)
- **État**: CHAOS TOTAL - Nettoyage urgent requis

## 🗑️ FICHIERS À SUPPRIMER

### Screenshots inutiles
```
/screenshots/*.png  # Tous les vieux screenshots
/tmp/*.png         # Screenshots temporaires
*.png / *.jpg      # Screenshots de test à la racine
```

### Tests obsolètes (test-*.js)
```
test-production-*.js    # Anciens tests
test-puppeteer-*.js     # Tests puppeteer obsolètes
test-final-*.js         # Tests finaux obsolètes
test-improved-*.js      # Anciennes améliorations
test-user-*.js          # Tests utilisateur obsolètes
test-modern-*.js        # Tests interface moderne obsolète
```

### Interfaces web obsolètes
```
web/index_old.php           # Ancienne version
web/index_modern.php        # Version moderne obsolète
web/index-modern.php        # Doublon
web/index-GOLDEN-MASTER.php # Backup (à conserver?)
```

### Scripts shell obsolètes
```
deploy-to-production.sh     # Ancien déploiement
github-clean-and-push-*.sh  # Anciens scripts GitHub
rollback-*.sh               # Scripts rollback obsolètes
deploy-v*.sh                # Anciennes versions deploy
test-*.sh                   # Scripts de test obsolètes
```

## ✅ FICHIERS À CONSERVER

### Core Application
```
web/
├── index.php              # Interface principale ACTUELLE
├── config.php             # Configuration
└── api/                   # APIs REST
    ├── media.php
    ├── playlist.php
    ├── system.php
    ├── upload.php
    ├── youtube.php
    ├── youtube-simple.php # Version simplifiée
    ├── screenshot.php
    └── player.php
```

### Scripts essentiels
```
scripts/
├── vlc-control.sh         # Contrôle VLC
├── screenshot.sh          # Capture d'écran
└── install-screenshot.sh  # Installation capture

install-ytdlp.sh           # Installation YouTube
install-pisignage-bullseye.sh # Installation complète
fix-php-limits.sh          # Fix limites PHP
```

### Configuration
```
config/
├── nginx-site.conf        # Config nginx
├── playlists.json         # Playlists
└── settings.json          # Paramètres

CLAUDE.md                  # Documentation projet
README.md                  # Documentation publique
VERSION                    # Version actuelle
```

### Tests à conserver (récents et utiles)
```
test-validation-final.js       # Test validation complète
test-media-fixes.js            # Test corrections media
test-playlist-functions.js    # Test playlists
test-youtube-download.js      # Test YouTube
test-improvements-validation.js # Test améliorations récentes
```

## 🏗️ STRUCTURE PROPOSÉE APRÈS NETTOYAGE

```
/opt/pisignage/
├── README.md                  # Documentation principale
├── CLAUDE.md                  # Instructions spécifiques
├── VERSION                    # v0.8.0
├── LICENSE                    # Licence du projet
│
├── web/                       # Application web
│   ├── index.php             # Interface unique
│   ├── config.php
│   ├── favicon.ico
│   └── api/                  # APIs REST
│       └── [8 fichiers API]
│
├── scripts/                   # Scripts système
│   ├── vlc-control.sh
│   ├── screenshot.sh
│   └── install/              # Scripts installation
│       ├── install-ytdlp.sh
│       └── install-screenshot.sh
│
├── config/                    # Configuration
│   ├── nginx-site.conf
│   └── systemd/
│       └── pisignage.service
│
├── media/                     # Fichiers média
│   └── .gitkeep
│
├── logs/                      # Logs système
│   └── .gitkeep
│
├── docs/                      # Documentation
│   ├── INSTALL.md
│   ├── API.md
│   └── TROUBLESHOOTING.md
│
├── tests/                     # Tests validés
│   ├── validation-final.js
│   ├── media-test.js
│   ├── playlist-test.js
│   └── youtube-test.js
│
└── install.sh                 # Script installation principal
```

## 🎯 PLAN D'ACTION

1. **Créer une branche de nettoyage**
   ```bash
   git checkout -b cleanup-repository
   ```

2. **Supprimer les fichiers obsolètes** (liste ci-dessus)

3. **Réorganiser la structure**
   - Déplacer les tests dans `/tests/`
   - Déplacer les scripts d'installation dans `/scripts/install/`
   - Créer `/docs/` pour la documentation

4. **Mettre à jour le script de déploiement**

5. **Créer un .gitignore propre**

6. **Documenter clairement**
   - README.md : Pour les utilisateurs
   - CLAUDE.md : Pour le développement
   - docs/API.md : Documentation API

## ⚠️ RISQUES ET PRÉCAUTIONS

- **Backup complet avant nettoyage**
- **Vérifier les dépendances** entre fichiers
- **Tester après nettoyage** sur Pi de test
- **Garder une branche de sauvegarde**

## 📝 NOTES

- Beaucoup de scripts semblent être des doublons ou des versions obsolètes
- Les tests sont éparpillés et non organisés
- Plusieurs versions de l'interface web coexistent
- Manque de documentation claire sur quoi utiliser

## 🤝 VALIDATION REQUISE

**Ce plan nécessite validation avant exécution**
- [ ] Validation de la liste des suppressions
- [ ] Validation de la nouvelle structure
- [ ] Confirmation du backup
- [ ] Go pour le nettoyage