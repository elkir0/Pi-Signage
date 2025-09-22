#!/bin/bash
# Alias pour rechercher dans ce projet uniquement

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
echo "Recherche dans $PROJECT_DIR : $1"
echo "mcp__memory__search_nodes(\"$PROJECT_DIR:$1\")"
