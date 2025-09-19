#!/bin/bash

echo "=== CONNEXION AUTOMATIQUE ET VIDEO ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Login automatically on tty1
echo "Connexion sur tty1..."
sudo chvt 1

# Create auto-login script
cat > /tmp/auto-video.sh << 'SCRIPT'
#!/bin/bash
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Wait for X
sleep 3

# Launch video
cvlc --fullscreen --loop --intf dummy /opt/videos/light-video.mp4 &
SCRIPT

chmod +x /tmp/auto-video.sh

# Execute on tty1 as pi user
sudo -u pi bash -c 'export DISPLAY=:0; /tmp/auto-video.sh' &

echo ""
echo "Si vous voyez toujours l'écran de login:"
echo "Connectez-vous manuellement:"
echo "  Username: pi"
echo "  Password: palmer00"
echo ""
echo "Puis la vidéo se lancera automatiquement."

# Alternative: Restart lightdm with autologin forced
echo ""
echo "Forçage de l'autologin..."
sudo sed -i 's/#autologin-user=/autologin-user=pi/' /etc/lightdm/lightdm.conf 2>/dev/null
sudo bash -c 'echo "autologin-user=pi" >> /etc/lightdm/lightdm.conf'
sudo bash -c 'echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf'
sudo systemctl restart lightdm

EOF