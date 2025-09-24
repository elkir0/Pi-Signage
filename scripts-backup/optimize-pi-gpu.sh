#!/bin/bash

# Script d'optimisation GPU pour Raspberry Pi
# Améliore les performances vidéo

echo "🔧 Optimisation GPU Raspberry Pi pour PiSignage..."

# Backup config actuelle
sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)

# Fonction pour mettre à jour ou ajouter une config
update_config() {
    local key=$1
    local value=$2

    if grep -q "^$key=" /boot/config.txt; then
        sudo sed -i "s/^$key=.*/$key=$value/" /boot/config.txt
        echo "✓ Mis à jour: $key=$value"
    else
        echo "$key=$value" | sudo tee -a /boot/config.txt > /dev/null
        echo "✓ Ajouté: $key=$value"
    fi
}

# Optimisations GPU pour vidéo
update_config "gpu_mem" "256"                    # Augmenter mémoire GPU
update_config "gpu_freq" "500"                   # Fréquence GPU optimale
update_config "hdmi_force_hotplug" "1"          # Forcer sortie HDMI
update_config "hdmi_drive" "2"                   # Mode HDMI complet
update_config "config_hdmi_boost" "4"           # Boost signal HDMI
update_config "disable_overscan" "1"            # Désactiver overscan

# Pour Pi 4 spécifiquement
if grep -q "Pi 4" /proc/device-tree/model 2>/dev/null; then
    echo "🔧 Optimisations spécifiques Pi 4..."
    update_config "dtoverlay" "vc4-kms-v3d"     # Full KMS pour Pi 4
    update_config "max_framebuffers" "2"        # Double buffering
    update_config "arm_boost" "1"               # Boost CPU
    update_config "over_voltage" "2"            # Légère surtension stable
fi

# Optimisations codec vidéo
update_config "decode_MPG2" "0x00000000"       # License MPG2 si disponible
update_config "decode_WVC1" "0x00000000"       # License WVC1 si disponible
update_config "disable_pvt" "1"                # Désactiver limiteur température
update_config "temp_limit" "85"                # Limite température

echo ""
echo "📊 Configuration appliquée:"
echo "=========================="
grep -E "gpu_mem|gpu_freq|dtoverlay|hdmi" /boot/config.txt | grep -v "^#"
echo ""
echo "⚠️  REDÉMARRAGE REQUIS pour appliquer les changements"
echo ""

# Proposer installation omxplayer si pas installé
if ! command -v omxplayer &> /dev/null; then
    echo "💡 OMXPlayer non installé (lecteur vidéo optimisé Pi)"
    echo "   Installation recommandée: sudo apt install omxplayer"
fi

echo "✅ Optimisation GPU terminée!"