#!/bin/bash

# Revenir au driver FKMS qui fonctionnait
echo "⚠️  Revert temporaire au driver FKMS"

# Remplacer vc4-kms-v3d par vc4-fkms-v3d
sudo sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/g' /boot/config.txt

echo "✅ Driver reverted to FKMS"
echo "Configuration actuelle:"
grep dtoverlay /boot/config.txt | grep vc4

echo ""
echo "⚠️  Redémarrage nécessaire"