#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║              PiSignage - Synchronisation Multi-Environnements         ║
# ║                  Dev (local) ↔ GitHub ↔ Production (Pi)              ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Configuration
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"
PI_DIR="/opt/pisignage"
LOCAL_DIR="/opt/pisignage"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# Menu principal
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                 PiSignage - Gestionnaire de Synchronisation           ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "1) 📤 Push Local → GitHub → Pi (déploiement complet)"
    echo "2) 📥 Pull GitHub → Local + Pi (récupération)"
    echo "3) 🔄 Sync bidirectionnel (merge intelligent)"
    echo "4) 📊 Status (voir l'état des 3 environnements)"
    echo "5) 🚀 Deploy to Pi only (local → Pi direct)"
    echo "6) 🔧 Setup Git on Pi (configuration initiale)"
    echo "7) 📝 Commit local changes"
    echo "0) ❌ Quitter"
    echo ""
    read -p "Choisissez une option: " choice
}

# 1. Push complet: Local → GitHub → Pi
push_all() {
    log_step "Push Local → GitHub → Pi"

    # Vérifier les changements locaux
    if [[ -n $(git status --porcelain) ]]; then
        log_warn "Changements locaux détectés"
        echo "Fichiers modifiés:"
        git status --short
        echo ""
        read -p "Message de commit: " commit_msg

        git add -A
        git commit -m "$commit_msg

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

        log_info "Commit créé"
    fi

    # Push vers GitHub
    log_info "Push vers GitHub..."
    if git push origin main; then
        log_info "Push GitHub réussi"
    else
        log_error "Échec du push GitHub"
        return 1
    fi

    # Déployer sur le Pi
    log_info "Déploiement sur le Pi..."
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'ENDSSH'
cd /opt/pisignage
if [ -d .git ]; then
    git pull origin main
else
    # Si pas de Git, télécharger les fichiers principaux
    wget -q -O install.sh https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
    wget -q -O web/api/screenshot.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/screenshot.php
    wget -q -O web/index.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/index.php
fi
echo "Synchronisation Pi terminée"
ENDSSH

    log_info "✅ Synchronisation complète terminée"
}

# 2. Pull: GitHub → Local + Pi
pull_all() {
    log_step "Pull GitHub → Local + Pi"

    # Pull local
    log_info "Pull local depuis GitHub..."
    git pull origin main

    # Pull sur le Pi
    log_info "Pull sur le Pi..."
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'ENDSSH'
cd /opt/pisignage
if [ -d .git ]; then
    git pull origin main
else
    echo "Git non configuré sur le Pi"
fi
ENDSSH

    log_info "✅ Pull terminé"
}

# 3. Sync bidirectionnel
sync_all() {
    log_step "Synchronisation bidirectionnelle"

    # Sauvegarder les changements locaux
    git stash

    # Pull les derniers changements
    git pull origin main --rebase

    # Réappliquer les changements locaux
    git stash pop || true

    # Si conflits, les résoudre
    if [[ -n $(git diff --name-only --diff-filter=U) ]]; then
        log_warn "Conflits détectés. Résolution manuelle nécessaire."
        git status
    else
        log_info "Synchronisation réussie"
    fi
}

# 4. Status des 3 environnements
show_status() {
    log_step "Status des environnements"

    echo -e "${BLUE}LOCAL (Dev):${NC}"
    git status --short
    git log --oneline -5
    echo ""

    echo -e "${BLUE}GITHUB:${NC}"
    git fetch origin
    git log origin/main --oneline -5
    echo ""

    echo -e "${BLUE}RASPBERRY PI:${NC}"
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'ENDSSH'
cd /opt/pisignage 2>/dev/null
if [ -d .git ]; then
    git status --short
    git log --oneline -5
else
    echo "Git non configuré"
    ls -la | head -10
fi
ENDSSH
}

# 5. Deploy direct Local → Pi
deploy_to_pi() {
    log_step "Déploiement direct Local → Pi"

    # Synchronisation avec rsync
    log_info "Synchronisation des fichiers..."
    rsync -avz --progress \
        --exclude '.git' \
        --exclude 'node_modules' \
        --exclude '*.log' \
        --exclude '*.png' \
        --exclude '*.mp4' \
        -e "sshpass -p '$PI_PASS' ssh -o StrictHostKeyChecking=no" \
        $LOCAL_DIR/ $PI_USER@$PI_HOST:$PI_DIR/

    # Corriger les permissions
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'ENDSSH'
sudo chown -R pi:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo systemctl restart nginx php8.2-fpm
ENDSSH

    log_info "✅ Déploiement terminé"
}

# 6. Setup Git sur le Pi
setup_git_on_pi() {
    log_step "Configuration Git sur le Raspberry Pi"

    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'ENDSSH'
cd /opt/pisignage
if [ ! -d .git ]; then
    git init
    git remote add origin https://github.com/elkir0/Pi-Signage.git
    git fetch origin
    git reset --hard origin/main
    echo "Git configuré avec succès"
else
    echo "Git déjà configuré"
fi
git config --global user.name "PiSignage Bot"
git config --global user.email "pi@pisignage.local"
ENDSSH

    log_info "✅ Git configuré sur le Pi"
}

# 7. Commit local
commit_local() {
    log_step "Commit des changements locaux"

    git status --short
    echo ""
    read -p "Message de commit: " commit_msg

    git add -A
    git commit -m "$commit_msg

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

    log_info "Commit créé localement"
    read -p "Pusher vers GitHub ? (o/n): " push_choice

    if [[ $push_choice == "o" ]]; then
        push_all
    fi
}

# Vérifications initiales
check_requirements() {
    # Vérifier Git
    if ! command -v git &> /dev/null; then
        log_error "Git n'est pas installé"
        exit 1
    fi

    # Vérifier sshpass
    if ! command -v sshpass &> /dev/null; then
        log_warn "sshpass n'est pas installé. Installation..."
        sudo apt-get install -y sshpass
    fi

    # Vérifier rsync
    if ! command -v rsync &> /dev/null; then
        log_warn "rsync n'est pas installé. Installation..."
        sudo apt-get install -y rsync
    fi

    # Vérifier que nous sommes dans le bon dossier
    if [[ ! -f "$LOCAL_DIR/install.sh" ]]; then
        log_error "Ce script doit être exécuté depuis $LOCAL_DIR"
        exit 1
    fi
}

# Main loop
main() {
    check_requirements

    while true; do
        show_menu

        case $choice in
            1) push_all ;;
            2) pull_all ;;
            3) sync_all ;;
            4) show_status ;;
            5) deploy_to_pi ;;
            6) setup_git_on_pi ;;
            7) commit_local ;;
            0) echo "Au revoir !"; exit 0 ;;
            *) log_error "Option invalide" ;;
        esac

        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
    done
}

# Exécution
cd $LOCAL_DIR
main