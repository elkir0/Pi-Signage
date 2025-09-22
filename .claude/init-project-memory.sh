#!/bin/bash
# Script d'initialisation de la mémoire MCP contextualisée par projet
# Ce script préfixe automatiquement les entités avec le chemin du projet

set -e

# Détection automatique du répertoire du projet
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "=' Initialisation de la mémoire contextualisée"
echo "=Í Projet : $PROJECT_NAME"
echo "=Â Chemin : $PROJECT_DIR"
echo ""

# Vérifier qu'on est bien dans le bon projet
if [ "$PROJECT_DIR" != "/opt/pisignage" ]; then
    echo "   ATTENTION : Ce script est conçu pour /opt/pisignage"
    echo "    Vous êtes dans : $PROJECT_DIR"
    read -p "    Continuer quand même ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Fonction pour préfixer automatiquement
prefix_entity() {
    echo "${PROJECT_DIR}:$1"
}

echo "=Ê Recherche des entités existantes pour ce projet..."
echo ""
echo "Pour rechercher les entités de CE projet uniquement :"
echo "  mcp__memory__search_nodes(\"$PROJECT_DIR:\")"
echo ""
echo "Pour créer une nouvelle entité pour CE projet :"
echo "  Nom : $(prefix_entity "NOM_ENTITE")"
echo ""

# Créer un fichier de commandes MCP prêtes à l'emploi
MCP_COMMANDS_FILE="$PROJECT_DIR/.claude/mcp-commands.md"

cat > "$MCP_COMMANDS_FILE" << EOF
# = Commandes MCP pour $PROJECT_NAME

## Rechercher dans ce projet uniquement
\`\`\`javascript
mcp__memory__search_nodes("$PROJECT_DIR:")
\`\`\`

## Ouvrir les entités principales
\`\`\`javascript
mcp__memory__open_nodes([
    "$(prefix_entity "PROJECT")",
    "$(prefix_entity "CONFIG")",
    "$(prefix_entity "RULES")",
    "$(prefix_entity "STATUS")",
    "$(prefix_entity "ISSUES")"
])
\`\`\`

## Ajouter une observation
\`\`\`javascript
mcp__memory__add_observations({
    observations: [{
        entityName: "$(prefix_entity "STATUS")",
        contents: ["Nouvelle observation ici"]
    }]
})
\`\`\`

## Créer une nouvelle entité
\`\`\`javascript
mcp__memory__create_entities({
    entities: [{
        name: "$(prefix_entity "NOUVELLE_ENTITE")",
        entityType: "TYPE",
        observations: ["Description"]
    }]
})
\`\`\`

##   IMPORTANT
Toujours utiliser le préfixe : $PROJECT_DIR:
Cela garantit l'isolation entre projets !
EOF

echo " Fichier de commandes créé : $MCP_COMMANDS_FILE"
echo ""

# Vérifier si des entités existent déjà
echo "= Vérification des entités existantes..."
echo ""
echo "Entités attendues pour ce projet :"
echo "  - $(prefix_entity "PROJECT")"
echo "  - $(prefix_entity "CONFIG")"
echo "  - $(prefix_entity "RULES")"
echo "  - $(prefix_entity "STATUS")"
echo "  - $(prefix_entity "ISSUES")"
echo ""

# Créer un alias pour faciliter les recherches
ALIAS_FILE="$PROJECT_DIR/.claude/search-alias.sh"
cat > "$ALIAS_FILE" << 'EOF'
#!/bin/bash
# Alias pour rechercher dans ce projet uniquement

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
echo "Recherche dans $PROJECT_DIR : $1"
echo "mcp__memory__search_nodes(\"$PROJECT_DIR:$1\")"
EOF
chmod +x "$ALIAS_FILE"

echo " Script de recherche créé : $ALIAS_FILE"
echo "   Usage : .claude/search-alias.sh TERME"
echo ""

# Résumé final
echo "=Ë RÉSUMÉ DE LA CONFIGURATION"
echo "=============================="
echo ""
echo " Projet : $PROJECT_NAME"
echo " Chemin : $PROJECT_DIR"
echo " Préfixe MCP : $PROJECT_DIR:"
echo " Commandes : $MCP_COMMANDS_FILE"
echo " Script recherche : $ALIAS_FILE"
echo ""
echo "   RAPPEL IMPORTANT :"
echo "   Toujours préfixer les entités MCP avec : $PROJECT_DIR:"
echo "   Cela évite les conflits entre vos différents projets !"
echo ""
echo "=¡ Prochaine étape :"
echo "   Utilisez les commandes dans $MCP_COMMANDS_FILE"
echo "   pour interagir avec la mémoire de CE projet uniquement"
echo ""
echo "( Initialisation terminée !"