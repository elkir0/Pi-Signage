#!/bin/bash
# Script d'initialisation de la m�moire MCP contextualis�e par projet
# Ce script pr�fixe automatiquement les entit�s avec le chemin du projet

set -e

# D�tection automatique du r�pertoire du projet
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "=' Initialisation de la m�moire contextualis�e"
echo "=� Projet : $PROJECT_NAME"
echo "=� Chemin : $PROJECT_DIR"
echo ""

# V�rifier qu'on est bien dans le bon projet
if [ "$PROJECT_DIR" != "/opt/pisignage" ]; then
    echo "�  ATTENTION : Ce script est con�u pour /opt/pisignage"
    echo "    Vous �tes dans : $PROJECT_DIR"
    read -p "    Continuer quand m�me ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Fonction pour pr�fixer automatiquement
prefix_entity() {
    echo "${PROJECT_DIR}:$1"
}

echo "=� Recherche des entit�s existantes pour ce projet..."
echo ""
echo "Pour rechercher les entit�s de CE projet uniquement :"
echo "  mcp__memory__search_nodes(\"$PROJECT_DIR:\")"
echo ""
echo "Pour cr�er une nouvelle entit� pour CE projet :"
echo "  Nom : $(prefix_entity "NOM_ENTITE")"
echo ""

# Cr�er un fichier de commandes MCP pr�tes � l'emploi
MCP_COMMANDS_FILE="$PROJECT_DIR/.claude/mcp-commands.md"

cat > "$MCP_COMMANDS_FILE" << EOF
# = Commandes MCP pour $PROJECT_NAME

## Rechercher dans ce projet uniquement
\`\`\`javascript
mcp__memory__search_nodes("$PROJECT_DIR:")
\`\`\`

## Ouvrir les entit�s principales
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

## Cr�er une nouvelle entit�
\`\`\`javascript
mcp__memory__create_entities({
    entities: [{
        name: "$(prefix_entity "NOUVELLE_ENTITE")",
        entityType: "TYPE",
        observations: ["Description"]
    }]
})
\`\`\`

## � IMPORTANT
Toujours utiliser le pr�fixe : $PROJECT_DIR:
Cela garantit l'isolation entre projets !
EOF

echo " Fichier de commandes cr�� : $MCP_COMMANDS_FILE"
echo ""

# V�rifier si des entit�s existent d�j�
echo "= V�rification des entit�s existantes..."
echo ""
echo "Entit�s attendues pour ce projet :"
echo "  - $(prefix_entity "PROJECT")"
echo "  - $(prefix_entity "CONFIG")"
echo "  - $(prefix_entity "RULES")"
echo "  - $(prefix_entity "STATUS")"
echo "  - $(prefix_entity "ISSUES")"
echo ""

# Cr�er un alias pour faciliter les recherches
ALIAS_FILE="$PROJECT_DIR/.claude/search-alias.sh"
cat > "$ALIAS_FILE" << 'EOF'
#!/bin/bash
# Alias pour rechercher dans ce projet uniquement

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
echo "Recherche dans $PROJECT_DIR : $1"
echo "mcp__memory__search_nodes(\"$PROJECT_DIR:$1\")"
EOF
chmod +x "$ALIAS_FILE"

echo " Script de recherche cr�� : $ALIAS_FILE"
echo "   Usage : .claude/search-alias.sh TERME"
echo ""

# R�sum� final
echo "=� R�SUM� DE LA CONFIGURATION"
echo "=============================="
echo ""
echo " Projet : $PROJECT_NAME"
echo " Chemin : $PROJECT_DIR"
echo " Pr�fixe MCP : $PROJECT_DIR:"
echo " Commandes : $MCP_COMMANDS_FILE"
echo " Script recherche : $ALIAS_FILE"
echo ""
echo "�  RAPPEL IMPORTANT :"
echo "   Toujours pr�fixer les entit�s MCP avec : $PROJECT_DIR:"
echo "   Cela �vite les conflits entre vos diff�rents projets !"
echo ""
echo "=� Prochaine �tape :"
echo "   Utilisez les commandes dans $MCP_COMMANDS_FILE"
echo "   pour interagir avec la m�moire de CE projet uniquement"
echo ""
echo "( Initialisation termin�e !"