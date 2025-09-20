#!/bin/bash

echo "═══════════════════════════════════════════════════════════"
echo "     📦 Préparation de la mise à jour GitHub v4.0"
echo "═══════════════════════════════════════════════════════════"

# Nettoyer les anciens fichiers non nécessaires
echo "🧹 Nettoyage des fichiers obsolètes..."
mkdir -p /opt/pisignage/archive
mv /opt/pisignage/*REPORT*.md /opt/pisignage/archive/ 2>/dev/null
mv /opt/pisignage/deploy-*.sh /opt/pisignage/archive/ 2>/dev/null
mv /opt/pisignage/fix-*.sh /opt/pisignage/archive/ 2>/dev/null

# Fichiers essentiels pour GitHub
echo ""
echo "📋 Fichiers essentiels pour GitHub:"
echo ""
echo "Core:"
echo "  • README.md                     - Documentation principale"
echo "  • install-complete-system.sh    - Script installation"
echo "  • SOLUTION_25FPS_FINALE.md     - Documentation technique"
echo ""
echo "Scripts:"
echo "  • scripts/vlc-control.sh        - Contrôle VLC"
echo ""
echo "Web:"
echo "  • web/index.php                 - Interface web"
echo "  • web/api/*.php                 - APIs REST"
echo ""

# Commandes Git
echo "═══════════════════════════════════════════════════════════"
echo "📝 Commandes Git à exécuter:"
echo "═══════════════════════════════════════════════════════════"
cat << 'GITCMD'

# 1. Initialiser ou mettre à jour le repo
git init
git remote add origin https://github.com/VOTRE_USERNAME/pisignage.git

# 2. Ajouter les fichiers
git add README.md
git add install-complete-system.sh
git add SOLUTION_25FPS_FINALE.md
git add scripts/vlc-control.sh
git add web/index.php
git add web/api/*.php

# 3. Commit
git commit -m "feat: 🚀 PiSignage v4.0 - 30+ FPS avec 7% CPU!

- Lecture vidéo fluide 30+ FPS
- Performance optimale: 7% CPU seulement
- Interface web 7 onglets complète
- APIs REST pour gestion vidéos
- Installation one-click
- Boot to video automatique
- Compatible Raspberry Pi 4

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"

# 4. Push
git push -u origin main

GITCMD

echo ""
echo "✅ Script de préparation créé!"
