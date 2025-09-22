#!/bin/bash
# Synchronisation automatique de la mémoire PiSignage v0.8.0

echo "= Synchronisation de la mémoire PiSignage..."
echo "=Å Date : $(date '+%Y-%m-%d %H:%M:%S')"

# Variables
MEMORY_DIR="/opt/pisignage/.claude/memory-bank"
PROJECT_DIR="/opt/pisignage"
DATE=$(date +%Y%m%d-%H%M%S)

# Vérifier que le dossier memory-bank existe
if [ ! -d "$MEMORY_DIR" ]; then
    echo "L Erreur : Le dossier $MEMORY_DIR n'existe pas"
    exit 1
fi

# Créer un checkpoint de sauvegarde
echo "=¾ Création d'un checkpoint de sauvegarde..."
CHECKPOINT_MSG="Checkpoint PiSignage v0.8.0 - $DATE
- Project: PiSignage Digital Signage
- Version: 0.8.0
- Stack: PHP 8.2 + Nginx + VLC
- Status: $(cat $PROJECT_DIR/VERSION 2>/dev/null || echo 'Unknown')
- Files: $(find $PROJECT_DIR -type f -name "*.php" 2>/dev/null | wc -l) PHP files
- Memory files: $(ls -1 $MEMORY_DIR/*.md 2>/dev/null | wc -l) context files"

echo "$CHECKPOINT_MSG"

# Créer un index consolidé de tous les contextes
echo ""
echo "=Ú Consolidation des contextes..."
INDEX_FILE="$MEMORY_DIR/.index-complet.md"

{
    echo "# =Â Index Complet - Mémoire PiSignage v0.8.0"
    echo "Généré le : $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    for file in "$MEMORY_DIR"/*.md; do
        if [ -f "$file" ] && [ "$(basename "$file")" != ".index-complet.md" ]; then
            filename=$(basename "$file" .md)
            echo "---"
            echo "## =Ä $filename"
            echo ""
            cat "$file"
            echo ""
        fi
    done
} > "$INDEX_FILE.tmp"

# Remplacer l'index atomiquement
mv "$INDEX_FILE.tmp" "$INDEX_FILE"

# Statistiques
echo ""
echo " Mémoire synchronisée avec succès"
echo "=Ê Statistiques :"
echo "  - Fichiers de contexte : $(ls -1 $MEMORY_DIR/*.md 2>/dev/null | grep -v ".index" | wc -l)"
echo "  - Taille totale : $(du -sh $MEMORY_DIR 2>/dev/null | cut -f1)"
echo "  - Index consolidé : $(wc -l < "$INDEX_FILE" 2>/dev/null || echo "0") lignes"

echo ""
echo "=Â Fichiers de contexte disponibles :"
for file in "$MEMORY_DIR"/*.md; do
    if [ -f "$file" ] && [ "$(basename "$file")" != ".index-complet.md" ]; then
        size=$(du -h "$file" 2>/dev/null | cut -f1)
        lines=$(wc -l < "$file" 2>/dev/null)
        echo "  - $(basename "$file") : $size ($lines lignes)"
    fi
done

echo ""
echo "=¡ Pour charger dans MCP, utilisez :"
echo "  mcp__memory__create_entities avec le contenu des fichiers"
echo "  mcp__memory__search_nodes pour rechercher"
echo ""
echo "( Synchronisation terminée !"