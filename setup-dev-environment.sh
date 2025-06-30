#!/usr/bin/env bash

# =============================================================================
# Pi Signage - Script de Configuration d'Environnement de Développement
# Version: 1.0.0
# Description: Configure un environnement de développement complet pour CodeX
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly PROJECT_NAME="Pi-Signage"
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly DEV_USER="${USER:-developer}"
readonly DEV_HOME="${HOME:-/home/$DEV_USER}"
readonly PROJECT_DIR="$DEV_HOME/workspace/$PROJECT_NAME"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Bannière
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        Pi Signage - Configuration Environnement Dev          ║"
    echo "║                      Pour CodeX OpenAI                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "Ce script va configurer :"
    echo "  • Environnement de développement complet"
    echo "  • Outils et dépendances"
    echo "  • Structure de projet"
    echo "  • Configuration Git"
    echo "  • Environnement de test"
    echo
}

# Vérifier l'OS
check_os() {
    log_info "Vérification du système d'exploitation..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "OS détecté: $PRETTY_NAME"
        
        if [[ "$ID" != "debian" ]] && [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "raspbian" ]]; then
            log_warning "OS non testé. Debian/Ubuntu/Raspbian recommandé."
            read -p "Continuer quand même? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        log_error "Impossible de détecter l'OS"
        exit 1
    fi
}

# Installer les dépendances de développement
install_dev_dependencies() {
    log_info "Installation des dépendances de développement..."
    
    # Mise à jour du système
    sudo apt-get update
    
    # Outils de développement de base
    local dev_packages=(
        "git"
        "curl"
        "wget"
        "vim"
        "nano"
        "htop"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    # Outils de développement Bash
    dev_packages+=(
        "shellcheck"          # Linter pour Bash
        "bash-completion"
        "jq"                  # Manipulation JSON
        "tree"                # Visualisation arborescence
        "ncdu"                # Analyse disque
        "tmux"                # Terminal multiplexer
        "screen"
    )
    
    # Outils de développement PHP
    dev_packages+=(
        "php8.2-cli"
        "php8.2-common"
        "php8.2-curl"
        "php8.2-mbstring"
        "php8.2-xml"
        "php8.2-zip"
        "php8.2-sqlite3"      # Pour tests unitaires
        "php8.2-xdebug"       # Débogage PHP
        "composer"            # Gestionnaire de paquets PHP
    )
    
    # Outils de test et debug
    dev_packages+=(
        "strace"
        "tcpdump"
        "net-tools"
        "dnsutils"
        "telnet"
        "nmap"
        "iotop"
        "sysstat"
    )
    
    # Installation
    sudo apt-get install -y "${dev_packages[@]}"
    
    log_success "Dépendances de développement installées"
}

# Installer les outils spécifiques au projet
install_project_tools() {
    log_info "Installation des outils spécifiques au projet..."
    
    # Docker (pour tests en conteneur)
    if ! command -v docker &> /dev/null; then
        log_info "Installation de Docker..."
        curl -fsSL https://get.docker.com | sudo bash
        sudo usermod -aG docker "$DEV_USER"
        log_success "Docker installé"
    fi
    
    # Node.js et npm (pour outils JS éventuels)
    if ! command -v node &> /dev/null; then
        log_info "Installation de Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        log_success "Node.js installé"
    fi
    
    # Python et pip (pour yt-dlp et autres outils Python)
    sudo apt-get install -y python3-pip python3-venv
    
    # Installer yt-dlp globalement
    sudo pip3 install --break-system-packages yt-dlp
    
    # VS Code Server (optionnel)
    if [[ ! -d "$DEV_HOME/.vscode-server" ]]; then
        log_info "Préparation pour VS Code Remote Development..."
        mkdir -p "$DEV_HOME/.vscode-server"
    fi
}

# Configurer l'environnement de développement
setup_dev_environment() {
    log_info "Configuration de l'environnement de développement..."
    
    # Créer la structure de workspace
    mkdir -p "$DEV_HOME/workspace"
    mkdir -p "$DEV_HOME/tools"
    mkdir -p "$DEV_HOME/logs"
    
    # Cloner le projet
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_info "Clonage du repository..."
        git clone "$GITHUB_REPO" "$PROJECT_DIR"
    else
        log_info "Mise à jour du repository..."
        cd "$PROJECT_DIR"
        git pull origin main
    fi
    
    # Configuration Git
    cd "$PROJECT_DIR"
    git config --local user.name "CodeX Developer"
    git config --local user.email "codex@openai.local"
    
    # Créer les branches de développement
    git checkout -b development 2>/dev/null || git checkout development
    git checkout -b feature/codex-workspace 2>/dev/null || git checkout feature/codex-workspace
    
    log_success "Environnement de développement configuré"
}

# Créer les scripts utilitaires
create_utility_scripts() {
    log_info "Création des scripts utilitaires..."
    
    # Script de test rapide
    cat > "$PROJECT_DIR/test-quick.sh" << 'EOF'
#!/bin/bash
# Test rapide des composants principaux

echo "=== Test Rapide Pi Signage ==="

# Test syntaxe Bash
echo -n "Vérification syntaxe Bash... "
find . -name "*.sh" -type f -exec bash -n {} \; && echo "OK" || echo "ERREUR"

# Test syntaxe PHP
echo -n "Vérification syntaxe PHP... "
find web-interface -name "*.php" -type f -exec php -l {} \; > /dev/null 2>&1 && echo "OK" || echo "ERREUR"

# Test ShellCheck
if command -v shellcheck &> /dev/null; then
    echo "Analyse ShellCheck..."
    shellcheck raspberry-pi-installer/scripts/*.sh || true
fi

echo "=== Test terminé ==="
EOF
    chmod +x "$PROJECT_DIR/test-quick.sh"
    
    # Script de build
    cat > "$PROJECT_DIR/build-dev.sh" << 'EOF'
#!/bin/bash
# Build de développement

echo "=== Build de développement ==="

# Créer un package de test
mkdir -p build
tar -czf build/pi-signage-dev-$(date +%Y%m%d-%H%M%S).tar.gz \
    --exclude='.git' \
    --exclude='build' \
    --exclude='*.log' \
    raspberry-pi-installer/ web-interface/

echo "Package créé dans build/"
ls -lh build/
EOF
    chmod +x "$PROJECT_DIR/build-dev.sh"
    
    # Script de lancement local
    cat > "$PROJECT_DIR/run-local.sh" << 'EOF'
#!/bin/bash
# Lancer l'interface web localement pour tests

echo "=== Démarrage serveur PHP local ==="
echo "Interface disponible sur: http://localhost:8000"
echo "Ctrl+C pour arrêter"

cd web-interface/public
php -S localhost:8000
EOF
    chmod +x "$PROJECT_DIR/run-local.sh"
    
    log_success "Scripts utilitaires créés"
}

# Créer l'environnement de test Docker
create_docker_test_env() {
    log_info "Création de l'environnement de test Docker..."
    
    # Dockerfile pour tests
    cat > "$PROJECT_DIR/Dockerfile.test" << 'EOF'
FROM debian:12

# Installation des dépendances de base
RUN apt-get update && apt-get install -y \
    sudo \
    systemd \
    nginx \
    php8.2-fpm \
    php8.2-cli \
    git \
    curl \
    ffmpeg \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copier le projet
COPY . /opt/pi-signage-dev

# Configuration
WORKDIR /opt/pi-signage-dev

# Script d'entrée
CMD ["/bin/bash"]
EOF
    
    # Docker Compose pour environnement complet
    cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  pi-signage-dev:
    build:
      context: .
      dockerfile: Dockerfile.test
    container_name: pi-signage-dev
    volumes:
      - .:/opt/pi-signage-dev
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    privileged: true
    ports:
      - "8080:80"      # Nginx
      - "8888:8888"    # Player Chromium
      - "61208:61208"  # Glances
    environment:
      - DISPLAY_MODE=chromium
    command: /sbin/init

  # Base de données pour tests
  test-db:
    image: mariadb:latest
    container_name: pi-signage-test-db
    environment:
      MYSQL_ROOT_PASSWORD: testpass
      MYSQL_DATABASE: pi_signage_test
    ports:
      - "3306:3306"
EOF
    
    log_success "Environnement Docker créé"
}

# Créer la documentation de développement
create_dev_documentation() {
    log_info "Création de la documentation de développement..."
    
    cat > "$PROJECT_DIR/DEVELOPMENT.md" << 'EOF'
# Guide de Développement Pi Signage

## Structure du Projet

```
Pi-Signage/
├── raspberry-pi-installer/     # Scripts d'installation
│   ├── scripts/               # Modules d'installation
│   └── docs/                  # Documentation
├── web-interface/             # Interface web PHP
│   ├── public/               # Point d'entrée web
│   ├── includes/             # Logique métier
│   └── assets/               # CSS/JS/Images
└── tests/                     # Tests (à créer)
```

## Commandes de Développement

### Tests rapides
```bash
./test-quick.sh              # Vérification syntaxe
./build-dev.sh              # Créer un package
./run-local.sh              # Lancer interface web locale
```

### Docker
```bash
docker-compose up -d         # Démarrer environnement
docker exec -it pi-signage-dev bash  # Accéder au conteneur
docker-compose down          # Arrêter
```

### Git Workflow
```bash
git checkout development     # Branche de dev
git checkout -b feature/xxx  # Nouvelle fonctionnalité
git add .
git commit -m "feat: description"
git push origin feature/xxx
```

## Standards de Code

### Bash
- ShellCheck clean (shellcheck script.sh)
- Variables en MAJUSCULES pour constantes
- set -euo pipefail en début de script
- Fonctions avec préfixe selon contexte

### PHP
- PSR-12 pour le style
- Validation des entrées
- Échappement des sorties
- Gestion d'erreurs appropriée

## Tests

### Unitaires (à implémenter)
```bash
cd tests
./run-unit-tests.sh
```

### Intégration
```bash
cd tests
./run-integration-tests.sh
```

## Debugging

### Logs
- Installation: /var/log/pi-signage-setup.log
- PHP: /var/log/pi-signage/php-error.log
- Services: journalctl -u service-name

### Outils
- strace pour syscalls
- tcpdump pour réseau
- xdebug pour PHP
EOF
    
    # Créer un fichier de configuration VS Code
    mkdir -p "$PROJECT_DIR/.vscode"
    cat > "$PROJECT_DIR/.vscode/settings.json" << 'EOF'
{
    "files.associations": {
        "*.sh": "shellscript"
    },
    "shellcheck.enable": true,
    "php.validate.enable": true,
    "editor.formatOnSave": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
EOF
    
    log_success "Documentation de développement créée"
}

# Configurer les alias et helpers
setup_dev_aliases() {
    log_info "Configuration des alias de développement..."
    
    # Créer un fichier d'alias pour le projet
    cat > "$PROJECT_DIR/.dev-aliases" << 'EOF'
# Pi Signage Development Aliases

# Navigation rapide
alias cdpi="cd $PROJECT_DIR"
alias cdweb="cd $PROJECT_DIR/web-interface"
alias cdscripts="cd $PROJECT_DIR/raspberry-pi-installer/scripts"

# Git shortcuts
alias gs="git status"
alias gd="git diff"
alias gc="git commit -m"
alias gp="git push"
alias gl="git log --oneline -10"

# Tests
alias test-bash="find . -name '*.sh' -type f -exec bash -n {} \;"
alias test-php="find web-interface -name '*.php' -type f -exec php -l {} \;"
alias test-quick="./test-quick.sh"

# Logs
alias logs-php="tail -f /var/log/pi-signage/php-error.log"
alias logs-nginx="tail -f /var/log/nginx/pi-signage-error.log"

# Docker
alias dcu="docker-compose up -d"
alias dcd="docker-compose down"
alias dcl="docker-compose logs -f"
alias dce="docker exec -it pi-signage-dev bash"

# Utilitaires
alias clean-logs="find . -name '*.log' -type f -delete"
alias show-tree="tree -I 'node_modules|vendor|.git'"
EOF
    
    # Ajouter au bashrc si pas déjà présent
    if ! grep -q "Pi Signage Development" "$DEV_HOME/.bashrc"; then
        echo "" >> "$DEV_HOME/.bashrc"
        echo "# Pi Signage Development" >> "$DEV_HOME/.bashrc"
        echo "if [ -f $PROJECT_DIR/.dev-aliases ]; then" >> "$DEV_HOME/.bashrc"
        echo "    . $PROJECT_DIR/.dev-aliases" >> "$DEV_HOME/.bashrc"
        echo "fi" >> "$DEV_HOME/.bashrc"
    fi
    
    log_success "Alias de développement configurés"
}

# Résumé final
show_summary() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Configuration Terminée avec Succès !                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "📁 Projet cloné dans: $PROJECT_DIR"
    echo
    echo "🔧 Outils installés:"
    echo "  • ShellCheck (linter Bash)"
    echo "  • PHP 8.2 avec XDebug"
    echo "  • Docker et Docker Compose"
    echo "  • yt-dlp"
    echo
    echo "📝 Scripts utilitaires créés:"
    echo "  • test-quick.sh    - Tests rapides"
    echo "  • build-dev.sh     - Build de développement"
    echo "  • run-local.sh     - Serveur PHP local"
    echo
    echo "🚀 Pour commencer:"
    echo "  cd $PROJECT_DIR"
    echo "  ./test-quick.sh    # Vérifier l'installation"
    echo "  ./run-local.sh     # Lancer l'interface web"
    echo
    echo "📚 Documentation:"
    echo "  • DEVELOPMENT.md   - Guide de développement"
    echo "  • .dev-aliases     - Alias pratiques"
    echo
    echo -e "${YELLOW}⚠️  N'oubliez pas de recharger votre shell:${NC}"
    echo "  source ~/.bashrc"
    echo
}

# Main
main() {
    show_banner
    
    # Demander confirmation
    read -p "Voulez-vous configurer l'environnement de développement? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        log_info "Configuration annulée"
        exit 0
    fi
    
    # Exécuter les étapes
    check_os
    install_dev_dependencies
    install_project_tools
    setup_dev_environment
    create_utility_scripts
    create_docker_test_env
    create_dev_documentation
    setup_dev_aliases
    
    # Résumé
    show_summary
}

# Exécution
main "$@"