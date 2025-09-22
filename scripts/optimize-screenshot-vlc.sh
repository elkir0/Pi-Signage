#!/bin/bash
# PiSignage v0.8.0 - Optimisation Screenshot + VLC
# Configuration système pour capture d'écran pendant lecture VLC

set -e

LOG_FILE="/opt/pisignage/logs/screenshot-optimization.log"
CONFIG_DIR="/opt/pisignage/config"

# Couleurs pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_message "INFO: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

create_directories() {
    print_status "Création des répertoires de configuration..."

    mkdir -p "$CONFIG_DIR/vlc"
    mkdir -p "$CONFIG_DIR/screenshot"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "/dev/shm/pisignage-cache"

    # Permissions pour www-data
    sudo chown -R www-data:www-data "/dev/shm/pisignage-cache" 2>/dev/null || true
    sudo chmod 755 "/dev/shm/pisignage-cache" 2>/dev/null || true
}

configure_vlc_priority() {
    print_status "Configuration des priorités VLC pour capture concurrente..."

    cat > "$CONFIG_DIR/vlc/nice-config.sh" << 'EOF'
#!/bin/bash
# Configuration priorité VLC pour optimiser captures

# Priorité VLC réduite pendant capture
VLC_NICE_NORMAL=0
VLC_NICE_DURING_CAPTURE=5

# Priorité capture
CAPTURE_NICE=-5

# Fonction pour ajuster priorité VLC
adjust_vlc_priority() {
    local new_nice="$1"
    local vlc_pids=$(pgrep vlc 2>/dev/null || true)

    if [[ -n "$vlc_pids" ]]; then
        for pid in $vlc_pids; do
            sudo renice "$new_nice" -p "$pid" 2>/dev/null || true
        done
        echo "VLC priority adjusted to: $new_nice"
    fi
}

# Réduire priorité VLC avant capture
prepare_capture() {
    adjust_vlc_priority $VLC_NICE_DURING_CAPTURE
    sleep 0.1  # Petit délai pour stabilisation
}

# Restaurer priorité VLC après capture
restore_vlc() {
    adjust_vlc_priority $VLC_NICE_NORMAL
}
EOF

    chmod +x "$CONFIG_DIR/vlc/nice-config.sh"
}

optimize_gpu_memory_split() {
    print_status "Optimisation répartition mémoire GPU..."

    local config_file="/boot/config.txt"
    local firmware_file="/boot/firmware/config.txt"

    # Déterminer le bon fichier de config
    local target_config=""
    if [[ -f "$firmware_file" ]]; then
        target_config="$firmware_file"
    elif [[ -f "$config_file" ]]; then
        target_config="$config_file"
    else
        print_warning "Fichier config.txt non trouvé, configuration manuelle requise"
        return
    fi

    print_status "Configuration trouvée: $target_config"

    # Sauvegarde
    sudo cp "$target_config" "${target_config}.pisignage.backup"

    # Configuration optimisée pour VLC + Screenshot
    local gpu_mem="128"

    # Détecter le modèle de Pi
    local pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Unknown")

    case "$pi_model" in
        *"Raspberry Pi 4"*)
            gpu_mem="256"  # Pi 4 peut gérer plus de mémoire GPU
            ;;
        *"Raspberry Pi 3"*)
            gpu_mem="128"
            ;;
        *)
            gpu_mem="128"
            ;;
    esac

    print_status "Configuration GPU memory: ${gpu_mem}MB pour $pi_model"

    # Mettre à jour gpu_mem
    if sudo grep -q "^gpu_mem=" "$target_config"; then
        sudo sed -i "s/^gpu_mem=.*/gpu_mem=$gpu_mem/" "$target_config"
    else
        echo "gpu_mem=$gpu_mem" | sudo tee -a "$target_config"
    fi

    # Autres optimisations GPU
    local gpu_optimizations=(
        "dtoverlay=vc4-kms-v3d"
        "max_framebuffers=2"
        "dtparam=spi=on"
        "dtparam=i2c_arm=on"
    )

    for opt in "${gpu_optimizations[@]}"; do
        if ! sudo grep -q "^$opt" "$target_config"; then
            echo "$opt" | sudo tee -a "$target_config"
        fi
    done

    print_status "Configuration GPU mise à jour (redémarrage requis)"
}

configure_cpu_scaling() {
    print_status "Configuration du scaling CPU pour performance..."

    # Script de configuration du gouverneur CPU
    cat > "$CONFIG_DIR/cpu-performance.sh" << 'EOF'
#!/bin/bash
# Configuration CPU pour performance optimale

# Gouverneur performance pendant capture
set_performance_mode() {
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
}

# Gouverneur ondemand normal
set_normal_mode() {
    echo "ondemand" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
}

# Mode actuel
get_current_mode() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
}

case "$1" in
    performance)
        set_performance_mode
        echo "CPU mode: performance"
        ;;
    normal)
        set_normal_mode
        echo "CPU mode: ondemand"
        ;;
    status)
        echo "Current CPU governor: $(get_current_mode)"
        ;;
    *)
        echo "Usage: $0 {performance|normal|status}"
        ;;
esac
EOF

    chmod +x "$CONFIG_DIR/cpu-performance.sh"
}

create_screenshot_wrapper() {
    print_status "Création du wrapper de capture optimisé..."

    cat > "$CONFIG_DIR/screenshot/capture-wrapper.sh" << 'EOF'
#!/bin/bash
# Wrapper optimisé pour capture d'écran avec VLC
# Gère automatiquement les priorités et la performance

source /opt/pisignage/config/vlc/nice-config.sh 2>/dev/null || true

TEMP_CACHE="/dev/shm/pisignage-cache"
PERFORMANCE_LOG="/opt/pisignage/logs/screenshot-performance.log"

# Fonction de capture optimisée
optimized_capture() {
    local output_file="$1"
    local method="${2:-auto}"
    local start_time=$(date +%s%3N)

    # Log début capture
    echo "$(date '+%Y-%m-%d %H:%M:%S') - START capture: $method" >> "$PERFORMANCE_LOG"

    # 1. Préparer l'environnement
    prepare_capture 2>/dev/null || true

    # 2. Mode performance CPU temporaire
    /opt/pisignage/config/cpu-performance.sh performance 2>/dev/null || true

    # 3. Capture avec priorité haute
    local capture_success=false
    local capture_method=""

    case "$method" in
        raspi2png|auto)
            if command -v raspi2png >/dev/null 2>&1; then
                nice -n -5 raspi2png -p "$output_file" 2>/dev/null && capture_success=true && capture_method="raspi2png"
            fi
            ;;&
        scrot)
            if [[ "$capture_success" != "true" ]] && command -v scrot >/dev/null 2>&1; then
                nice -n -5 scrot -z "$output_file" 2>/dev/null && capture_success=true && capture_method="scrot"
            fi
            ;;&
        fbgrab)
            if [[ "$capture_success" != "true" ]] && command -v fbgrab >/dev/null 2>&1; then
                nice -n -5 fbgrab "$output_file" 2>/dev/null && capture_success=true && capture_method="fbgrab"
            fi
            ;;&
    esac

    # 4. Restaurer environnement normal
    restore_vlc 2>/dev/null || true
    /opt/pisignage/config/cpu-performance.sh normal 2>/dev/null || true

    # 5. Log résultat
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    if [[ "$capture_success" == "true" ]] && [[ -f "$output_file" ]]; then
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $capture_method, ${duration}ms, ${file_size}B" >> "$PERFORMANCE_LOG"
        echo "$output_file"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: $method, ${duration}ms" >> "$PERFORMANCE_LOG"
        return 1
    fi
}

# Fonction de capture rapide en cache
quick_capture() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local temp_file="$TEMP_CACHE/quick_${timestamp}.png"

    optimized_capture "$temp_file" raspi2png
}

# Interface ligne de commande
case "$1" in
    capture)
        optimized_capture "$2" "$3"
        ;;
    quick)
        quick_capture
        ;;
    test)
        echo "Test de performance capture..."
        for i in {1..5}; do
            echo "Test $i/5..."
            if quick_capture; then
                echo "✅ Test $i réussi"
            else
                echo "❌ Test $i échoué"
            fi
            sleep 1
        done
        ;;
    *)
        echo "Usage: $0 {capture <file> [method]|quick|test}"
        echo "Methods: raspi2png, scrot, fbgrab, auto"
        ;;
esac
EOF

    chmod +x "$CONFIG_DIR/screenshot/capture-wrapper.sh"
}

configure_systemd_limits() {
    print_status "Configuration des limites systemd pour performance..."

    # Configuration pour le service pisignage
    sudo mkdir -p /etc/systemd/system/pisignage.service.d/

    cat > /tmp/pisignage-limits.conf << 'EOF'
[Service]
# Limites optimisées pour PiSignage
LimitNOFILE=65536
LimitNPROC=32768
Nice=-5
CPUSchedulingPolicy=1
CPUSchedulingPriority=50

# Variables d'environnement pour performance
Environment="GPU_MEM_THRESHOLD=50"
Environment="SCREENSHOT_CACHE_SIZE=100"
Environment="VLC_CACHE_SIZE=2000"
EOF

    sudo mv /tmp/pisignage-limits.conf /etc/systemd/system/pisignage.service.d/

    # Recharger systemd
    sudo systemctl daemon-reload 2>/dev/null || true
}

optimize_system_swappiness() {
    print_status "Optimisation swappiness système..."

    # Réduire swappiness pour éviter le swap pendant captures
    echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-pisignage-performance.conf

    # Appliquer immédiatement
    sudo sysctl vm.swappiness=10 2>/dev/null || true
}

create_monitoring_script() {
    print_status "Création du script de monitoring performance..."

    cat > "$CONFIG_DIR/screenshot/monitor-performance.sh" << 'EOF'
#!/bin/bash
# Monitoring performance capture + VLC

PERFORMANCE_LOG="/opt/pisignage/logs/screenshot-performance.log"

show_recent_performance() {
    echo "🏆 PERFORMANCE RÉCENTE (10 dernières captures):"
    echo "============================================="

    if [[ -f "$PERFORMANCE_LOG" ]]; then
        tail -n 20 "$PERFORMANCE_LOG" | grep "SUCCESS" | tail -n 10 | while read line; do
            local timestamp=$(echo "$line" | cut -d' ' -f1-2)
            local method=$(echo "$line" | cut -d':' -f3 | cut -d',' -f1 | tr -d ' ')
            local duration=$(echo "$line" | cut -d',' -f2 | tr -d ' ')
            local size=$(echo "$line" | cut -d',' -f3 | tr -d ' ')

            printf "%-19s %-10s %8s %10s\n" "$timestamp" "$method" "$duration" "$size"
        done
    else
        echo "Aucune donnée de performance disponible"
    fi
}

show_system_status() {
    echo ""
    echo "🖥️ ÉTAT SYSTÈME:"
    echo "================"

    # CPU
    local cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
    local cpu_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
    echo "CPU: ${cpu_freq}Hz, Gouverneur: $cpu_gov"

    # GPU Memory
    local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null || echo "gpu=N/A")
    echo "GPU Memory: $gpu_mem"

    # Température
    local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    echo "Température: $temp"

    # VLC Status
    local vlc_pids=$(pgrep vlc 2>/dev/null | wc -l)
    echo "VLC processus: $vlc_pids"

    # Cache utilisé
    if [[ -d "/dev/shm/pisignage-cache" ]]; then
        local cache_size=$(du -sh /dev/shm/pisignage-cache 2>/dev/null | cut -f1 || echo "N/A")
        echo "Cache screenshot: $cache_size"
    fi
}

show_capture_methods() {
    echo ""
    echo "🔧 MÉTHODES DE CAPTURE DISPONIBLES:"
    echo "=================================="

    command -v raspi2png >/dev/null 2>&1 && echo "✅ raspi2png (OPTIMAL pour RPi)" || echo "❌ raspi2png"
    command -v scrot >/dev/null 2>&1 && echo "✅ scrot" || echo "❌ scrot"
    command -v fbgrab >/dev/null 2>&1 && echo "✅ fbgrab" || echo "❌ fbgrab"
    command -v import >/dev/null 2>&1 && echo "✅ ImageMagick import" || echo "❌ ImageMagick import"
}

case "$1" in
    performance)
        show_recent_performance
        ;;
    system)
        show_system_status
        ;;
    methods)
        show_capture_methods
        ;;
    all|*)
        show_recent_performance
        show_system_status
        show_capture_methods
        ;;
esac
EOF

    chmod +x "$CONFIG_DIR/screenshot/monitor-performance.sh"
}

show_optimization_summary() {
    cat << 'EOF'

🚀 OPTIMISATIONS SYSTÈME APPLIQUÉES:
===================================

📊 Performance:
  • CPU scaling configuré (performance temporaire)
  • GPU memory optimisée selon modèle Pi
  • Swappiness réduite (10)
  • Cache haute performance /dev/shm

🎯 VLC + Screenshot:
  • Priorités dynamiques (VLC nice +5 pendant capture)
  • Capture avec priorité haute (nice -5)
  • Restauration automatique des priorités

🔧 Scripts créés:
  • /opt/pisignage/config/vlc/nice-config.sh
  • /opt/pisignage/config/cpu-performance.sh
  • /opt/pisignage/config/screenshot/capture-wrapper.sh
  • /opt/pisignage/config/screenshot/monitor-performance.sh

📈 Monitoring:
  • Performance log: /opt/pisignage/logs/screenshot-performance.log
  • Commande: /opt/pisignage/config/screenshot/monitor-performance.sh

🔄 Usage optimisé:
  # Capture optimisée manuelle
  /opt/pisignage/config/screenshot/capture-wrapper.sh capture /tmp/test.png

  # Capture rapide en cache
  /opt/pisignage/config/screenshot/capture-wrapper.sh quick

  # Test performance
  /opt/pisignage/config/screenshot/capture-wrapper.sh test

⚠️ IMPORTANT:
Si gpu_mem a été modifié, REDÉMARRER le système:
  sudo reboot

EOF
}

# Exécution principale
main() {
    print_status "=== Optimisation Screenshot + VLC pour PiSignage v0.8.0 ==="

    create_directories
    configure_vlc_priority
    optimize_gpu_memory_split
    configure_cpu_scaling
    create_screenshot_wrapper
    configure_systemd_limits
    optimize_system_swappiness
    create_monitoring_script

    show_optimization_summary

    print_status "Optimisations système terminées!"
}

main "$@"