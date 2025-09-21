#!/bin/bash

echo "=== Configuration VNC pour Raspberry Pi ==="
echo ""
echo "Les credentials VNC peuvent être :"
echo ""
echo "Option 1 - Authentification Unix (la plus probable) :"
echo "  Username: pi"
echo "  Password: palmer00"
echo ""
echo "Option 2 - Si VNC demande juste un mot de passe :"
echo "  Password: raspberry (ou palmer00)"
echo ""

# SSH command to set VNC password
sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'
echo "=== Configuration du mot de passe VNC ==="

# Create VNC password file for RealVNC
mkdir -p ~/.vnc
echo raspberry | vncpasswd -f > ~/.vnc/passwd 2>/dev/null
chmod 600 ~/.vnc/passwd 2>/dev/null

# Try to configure RealVNC authentication
sudo bash -c 'echo "Authentication=Unix" > /etc/vnc/config.d/common.custom' 2>/dev/null

# Check x11vnc alternative
if command -v x11vnc > /dev/null; then
    echo "x11vnc is installed as alternative"
    # Create password for x11vnc
    x11vnc -storepasswd raspberry ~/.vnc/passwd 2>/dev/null
fi

# Restart VNC
sudo systemctl restart vncserver-x11-serviced 2>/dev/null

echo ""
echo "=== Configuration terminée ==="
echo "IP: $(hostname -I | cut -d' ' -f1)"
echo "Port: 5900"
echo ""
echo "Essayez ces identifiants dans votre client VNC:"
echo "1. Username: pi / Password: palmer00"
echo "2. Username: (vide) / Password: raspberry"
echo "3. Username: pi / Password: raspberry"

EOF