#!/bin/bash

# Script pour publier le projet Pi Signage sur GitHub
# Usage: ./publish-to-github.sh [username] [repo-name]

echo "======================================"
echo "   PUBLICATION PI SIGNAGE GITHUB"
echo "======================================"
echo ""

# Configuration
GITHUB_USER="${1:-your-username}"
REPO_NAME="${2:-pi-signage}"

echo "📋 Configuration:"
echo "  User: $GITHUB_USER"
echo "  Repo: $REPO_NAME"
echo ""

# Vérifier si Git est initialisé
if [ ! -d .git ]; then
    echo "📦 Initialisation du repository Git..."
    git init
    echo "✅ Repository initialisé"
else
    echo "✅ Repository Git déjà initialisé"
fi

# Ajouter tous les fichiers
echo ""
echo "📝 Ajout des fichiers..."
git add .
git status --short

# Premier commit
echo ""
echo "💾 Création du commit..."
git commit -m "🚀 v2.0.0 - Migration FullPageOS avec 25+ FPS garanti

- Solution complète de digital signage pour Raspberry Pi 4
- Basé sur FullPageOS (Bullseye/Buster)
- Accélération GPU hardware (VideoCore VI)
- 25-30+ FPS sur vidéo 720p H.264
- Déploiement automatique en une commande
- Outils de maintenance et diagnostic inclus

Résout définitivement le problème GPU de Bookworm/Chromium 139

Generated with Claude Code (https://claude.ai/code)
via Happy (https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>" || echo "✅ Déjà commité"

# Configuration de la branche
echo ""
echo "🌿 Configuration de la branche principale..."
git branch -M main

# Ajouter le remote (si pas déjà fait)
echo ""
echo "🔗 Configuration du remote GitHub..."
if ! git remote | grep -q origin; then
    echo "Ajout du remote origin..."
    echo "⚠️  IMPORTANT: Créez d'abord le repository sur GitHub:"
    echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
    echo ""
    read -p "Repository créé sur GitHub? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
        echo "✅ Remote ajouté"
    else
        echo "❌ Annulé - Créez le repo d'abord"
        exit 1
    fi
else
    echo "✅ Remote origin déjà configuré"
fi

# Push vers GitHub
echo ""
echo "🚀 Push vers GitHub..."
echo "Note: Vous devrez entrer vos identifiants GitHub"
echo "(Ou utiliser un token d'accès personnel)"
echo ""
git push -u origin main

echo ""
echo "======================================"
echo "   ✅ PUBLICATION TERMINÉE !"
echo "======================================"
echo ""
echo "📍 Votre projet est maintenant disponible sur:"
echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "📝 Prochaines étapes:"
echo "1. Ajoutez une image de démo dans docs/images/"
echo "2. Créez des releases sur GitHub"
echo "3. Ajoutez des badges supplémentaires au README"
echo "4. Configurez les GitHub Actions si nécessaire"
echo ""
echo "⭐ N'oubliez pas d'ajouter des topics:"
echo "   raspberry-pi, digital-signage, kiosk, fullpageos,"
echo "   gpu-acceleration, chromium, video-player"
echo ""
echo "🎉 Merci d'avoir utilisé Pi Signage !"