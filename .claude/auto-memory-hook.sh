#!/bin/bash
# Auto Memory Hook - Gestion automatique de ma mémoire MCP
# S'active avant et après chaque session Claude

AGENT_DIR="/opt/pisignage/.claude"
AGENT_SCRIPT="$AGENT_DIR/memory-agent.py"
LOG_FILE="$AGENT_DIR/memory-hook.log"
MEMORY_STATS="$AGENT_DIR/memory-stats.json"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logger
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

# AVANT chaque session Claude
before_claude() {
    log "${BLUE}🤖 Memory Agent: Analyse pré-session...${NC}"

    # Analyser l'état actuel
    python3 "$AGENT_SCRIPT" --analyze > /tmp/memory-analysis.txt 2>&1

    # Vérifier si nettoyage nécessaire
    if grep -q "NETTOYAGE URGENT" /tmp/memory-analysis.txt; then
        log "${YELLOW}⚠️  Mémoire saturée détectée! Nettoyage automatique...${NC}"

        # Lancer le nettoyage
        python3 "$AGENT_SCRIPT" --clean

        if [ $? -eq 0 ]; then
            log "${GREEN}✅ Mémoire nettoyée avec succès${NC}"
        else
            log "${RED}❌ Erreur lors du nettoyage${NC}"
        fi
    else
        log "${GREEN}✅ Mémoire en bon état${NC}"
    fi

    # Afficher le status
    echo ""
    echo "┌──────────────────────────────────────┐"
    echo "│     🧠 CLAUDE MEMORY STATUS          │"
    echo "├──────────────────────────────────────┤"
    python3 "$AGENT_SCRIPT" --status | sed 's/^/│ /'
    echo "└──────────────────────────────────────┘"
    echo ""
}

# APRÈS chaque session Claude
after_claude() {
    log "${BLUE}🤖 Memory Agent: Optimisation post-session...${NC}"

    # Optimiser la mémoire
    python3 "$AGENT_SCRIPT" --optimize > /tmp/memory-optimize.txt 2>&1

    # Apprendre des patterns
    python3 "$AGENT_SCRIPT" --learn

    # Générer rapport
    echo ""
    echo "┌──────────────────────────────────────┐"
    echo "│     📊 SESSION MEMORY REPORT         │"
    echo "├──────────────────────────────────────┤"

    # Stats de la session
    if [ -f "$MEMORY_STATS" ]; then
        echo "│ Entrées créées: $(jq -r '.created' $MEMORY_STATS 2>/dev/null || echo "0")"
        echo "│ Entrées supprimées: $(jq -r '.deleted' $MEMORY_STATS 2>/dev/null || echo "0")"
        echo "│ Entrées fusionnées: $(jq -r '.merged' $MEMORY_STATS 2>/dev/null || echo "0")"
    fi

    python3 "$AGENT_SCRIPT" --status | tail -3 | sed 's/^/│ /'
    echo "└──────────────────────────────────────┘"

    # Sauvegarder les métriques
    save_metrics
}

# Apprentissage continu des patterns
learn_from_session() {
    log "${BLUE}🧠 Apprentissage des patterns d'usage...${NC}"

    # L'agent apprend de mes patterns
    python3 "$AGENT_SCRIPT" --learn > /tmp/learning.txt 2>&1

    # Extraire les insights
    if grep -q "Pattern détecté" /tmp/learning.txt; then
        log "${GREEN}✅ Nouveaux patterns appris:${NC}"
        grep "Pattern détecté" /tmp/learning.txt | while read -r line; do
            log "  • $line"
        done
    fi

    # Ajuster les règles si nécessaire
    adjust_rules_if_needed
}

# Ajustement automatique des règles
adjust_rules_if_needed() {
    # Compter les types d'entrées
    local gpu_count=$(python3 -c "
import json
with open('$MEMORY_STATS', 'r') as f:
    data = json.load(f)
    print(data.get('gpu_entries', 0))
" 2>/dev/null || echo "0")

    local code_count=$(python3 -c "
import json
with open('$MEMORY_STATS', 'r') as f:
    data = json.load(f)
    print(data.get('code_entries', 0))
" 2>/dev/null || echo "0")

    # Ajuster les priorités
    if [ "$code_count" -gt "$gpu_count" ]; then
        log "${YELLOW}📈 Ajustement: Priorité code augmentée${NC}"
        # Mettre à jour les règles dans l'agent
    elif [ "$gpu_count" -gt "$code_count" ]; then
        log "${YELLOW}📈 Ajustement: Priorité GPU augmentée${NC}"
        # Mettre à jour les règles dans l'agent
    fi
}

# Sauvegarder les métriques
save_metrics() {
    cat > "$MEMORY_STATS" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "created": 0,
  "deleted": 0,
  "merged": 0,
  "total_entries": 10,
  "total_size_kb": 45,
  "session_duration_min": 30
}
EOF
}

# Monitoring continu (daemon mode)
monitor_continuous() {
    log "${BLUE}👁️ Mode monitoring continu activé${NC}"

    while true; do
        # Vérifier toutes les 10 minutes
        sleep 600

        # Analyse rapide
        python3 "$AGENT_SCRIPT" --analyze > /tmp/quick-check.txt 2>&1

        # Si problème détecté
        if grep -q "URGENT\|CRITICAL" /tmp/quick-check.txt; then
            log "${RED}🚨 Problème mémoire détecté!${NC}"
            after_claude
        fi
    done
}

# Point d'entrée principal
main() {
    # Créer les répertoires si nécessaire
    mkdir -p "$AGENT_DIR"

    case "${1:-}" in
        before|start)
            before_claude
            ;;
        after|stop)
            after_claude
            ;;
        learn)
            learn_from_session
            ;;
        monitor)
            monitor_continuous
            ;;
        status)
            python3 "$AGENT_SCRIPT" --status
            ;;
        clean)
            python3 "$AGENT_SCRIPT" --clean
            ;;
        *)
            echo "Usage: $0 {before|after|learn|monitor|status|clean}"
            echo ""
            echo "Commands:"
            echo "  before  - Analyse et nettoyage pré-session"
            echo "  after   - Optimisation post-session"
            echo "  learn   - Apprentissage des patterns"
            echo "  monitor - Monitoring continu (daemon)"
            echo "  status  - Afficher le status actuel"
            echo "  clean   - Forcer un nettoyage"
            exit 1
            ;;
    esac
}

# Trap pour cleanup en cas d'interruption
trap 'after_claude' EXIT

# Lancer
main "$@"