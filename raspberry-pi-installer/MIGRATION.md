# Guide de Migration - Interface Web v2

## Changements principaux

### Avant (v1)
- Le script `09-web-interface.sh` créait tous les fichiers PHP avec des commandes `cat`
- Difficile à maintenir et à faire évoluer
- Code mélangé avec la logique d'installation

### Après (v2)
- L'interface web est maintenue séparément dans `/web-interface/`
- Le script `09-web-interface-v2.sh` clone le code depuis GitHub
- Plus facile à maintenir, tester et faire évoluer

## Structure du projet

```
Pi-Signage/
├── raspberry-pi-installer/
│   └── scripts/
│       ├── 09-web-interface.sh      # Ancienne version (deprecated)
│       └── 09-web-interface-v2.sh   # Nouvelle version
└── web-interface/                    # Code de l'interface web
    ├── public/                       # Fichiers accessibles publiquement
    ├── includes/                     # Logique PHP
    ├── api/                          # Points d'accès API
    ├── assets/                       # CSS, JS, images
    └── templates/                    # Templates réutilisables
```

## Migration

### Pour utiliser la nouvelle version

1. **Remplacer le script dans votre installation**
   ```bash
   # Option 1 : Renommer simplement
   mv 09-web-interface-v2.sh 09-web-interface.sh
   
   # Option 2 : Modifier main_orchestrator.sh pour utiliser v2
   ```

2. **Le nouveau script va automatiquement**
   - Cloner l'interface web depuis GitHub
   - Configurer les permissions
   - Générer le fichier de configuration avec les mots de passe

### Avantages

1. **Maintenance facilitée**
   - Modifications directes dans les fichiers PHP
   - Tests locaux possibles
   - Versioning Git approprié

2. **Mises à jour simplifiées**
   - Script de mise à jour automatique inclus
   - `update-web-interface.sh` met à jour depuis GitHub

3. **Développement amélioré**
   - Structure claire et modulaire
   - Séparation des responsabilités
   - Plus facile à contribuer

## Scripts de mise à jour

Le nouveau système inclut deux scripts de mise à jour :

```bash
# Mise à jour de yt-dlp
/opt/scripts/update-ytdlp.sh

# Mise à jour de l'interface web depuis GitHub
/opt/scripts/update-web-interface.sh
# Utiliser --full pour réinstaller la configuration
```

Ces scripts sont exécutés automatiquement chaque semaine via cron.

## Développement local

Pour tester l'interface web localement :

```bash
cd web-interface
php -S localhost:8000 -t public/
```

## Notes importantes

- Le fichier `includes/config.php` est généré à l'installation
- Les mots de passe sont toujours hashés/chiffrés
- La sécurité reste identique à la v1
- Compatible avec la même infrastructure (nginx, PHP-FPM)