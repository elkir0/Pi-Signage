#!/bin/bash

echo "=================================================="
echo "NETTOYAGE GITHUB ET PUSH v0.8.0"
echo "=================================================="
echo ""

# 1. Cloner le repo
echo "1. Clonage du repository GitHub..."
cd /tmp
rm -rf pi-signage-clean
git clone https://github.com/elkir0/Pi-Signage.git pi-signage-clean

if [ $? -ne 0 ]; then
    echo "   ❌ Erreur de clonage"
    exit 1
fi

cd pi-signage-clean
echo "   ✅ Repository cloné"

# 2. Supprimer TOUT et recréer depuis v0.8.0
echo ""
echo "2. Suppression de tout le contenu existant..."
# Garder .git
find . -not -path './.git*' -not -name '.' -exec rm -rf {} + 2>/dev/null

echo "   ✅ Contenu supprimé"

# 3. Copier v0.8.0 propre
echo ""
echo "3. Copie de v0.8.0..."
cp -r /opt/pisignage/* . 2>/dev/null
# Supprimer les scripts de déploiement du repo
rm -f github-clean-and-push-v080.sh
rm -f deploy-v080-to-production.sh
rm -f /opt/rollback-*.sh

echo "   ✅ v0.8.0 copiée"

# 4. Créer .gitignore approprié
echo ""
echo "4. Création du .gitignore..."
cat > .gitignore << 'GITIGNORE'
# Logs
*.log
logs/
npm-debug.log*

# Dependencies
node_modules/
vendor/

# IDE
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Build
dist/
build/

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Directory for instrumented libs
lib-cov

# Coverage directory
coverage/
*.lcov

# Grunt intermediate storage
.grunt

# Bower dependency directory
bower_components

# Compiled files
*.com
*.class
*.dll
*.exe
*.o
*.so

# Packages
*.7z
*.dmg
*.gz
*.iso
*.jar
*.rar
*.tar
*.zip

# OS generated
Thumbs.db
.DS_Store
desktop.ini

# Temporary
*.tmp
*.temp
.cache/

# Config files with secrets
config.local.php
secrets.php

# Media files (too large)
media/*.mp4
media/*.avi
media/*.mkv
media/*.mov

# Backup files
*.backup
*.bak
*~

# Deploy scripts (local only)
deploy-*.sh
rollback-*.sh
github-*.sh
GITIGNORE

echo "   ✅ .gitignore créé"

# 5. Ajouter tout au git
echo ""
echo "5. Ajout des fichiers à git..."
git add -A
git status

# 6. Commit
echo ""
echo "6. Commit de v0.8.0..."
git commit -m "🔄 Reset complet vers v0.8.0 - Version stable officielle

- Suppression de toutes les versions antérieures
- Version PHP stable et fonctionnelle
- Interface complète avec toutes les APIs
- Documentation mise à jour
- Nettoyage de l'historique

Version: 0.8.0
Type: Stable Release"

# 7. Supprimer les tags existants
echo ""
echo "7. Suppression des anciens tags..."
# Lister tous les tags
git tag -l | while read tag; do
    echo "   Suppression du tag: $tag"
    git tag -d $tag
    git push origin --delete $tag 2>/dev/null
done

# 8. Créer nouveau tag v0.8.0
echo ""
echo "8. Création du tag v0.8.0..."
git tag -a v0.8.0 -m "Version 0.8.0 - Stable Release"

# 9. Force push
echo ""
echo "9. Push vers GitHub (force)..."
echo "   ⚠️ Ceci va REMPLACER tout le contenu sur GitHub"
echo ""
read -p "Continuer ? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push --force origin master
    git push --tags
    echo "   ✅ Push effectué"
else
    echo "   ❌ Push annulé"
fi

echo ""
echo "=================================================="
echo "✅ TERMINÉ"
echo "=================================================="
echo ""
echo "État GitHub :"
echo "  - Master : v0.8.0 uniquement"
echo "  - Tags : v0.8.0 uniquement"
echo "  - Historique : Nettoyé"
echo ""