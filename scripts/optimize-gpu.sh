#!/bin/bash

# Optimisation GPU pour PiSignage - Basé sur rapport technique
# Active l'accélération hardware pour 30+ FPS en 720p

echo "🚀 Optimisation GPU Raspberry Pi pour 30+ FPS"

# Backup config actuelle
sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d)

# Supprimer anciennes entrées GPU
sudo sed -i '/^gpu_mem=/d' /boot/config.txt
sudo sed -i '/^dtoverlay=vc4/d' /boot/config.txt
sudo sed -i '/^gpu_freq=/d' /boot/config.txt
sudo sed -i '/^over_voltage=/d' /boot/config.txt
sudo sed -i '/^arm_freq=/d' /boot/config.txt

# Ajouter configuration optimale selon rapport
cat << EOF | sudo tee -a /boot/config.txt

# === PiSignage GPU Optimisations ===
# Mémoire GPU pour décodage HD
gpu_mem=256

# Driver KMS moderne (pas FKMS legacy!)
dtoverlay=vc4-kms-v3d

# Fréquence GPU boostée pour 30+ FPS
gpu_freq=600

# Overclocking sûr pour signage 24/7
# (désactivé par défaut, décommenter si dissipateur installé)
#over_voltage=2
#arm_freq=1800

# Support HDMI avancé
hdmi_enable_4kp60=1
EOF

echo "✅ Configuration GPU optimisée"
echo ""
echo "📊 Nouvelle configuration :"
grep -E "gpu_mem|dtoverlay|gpu_freq" /boot/config.txt | tail -3
echo ""
echo "⚠️  Redémarrage nécessaire pour appliquer les changements"