#!/bin/bash
# Auto-deploy to Raspberry Pi at 192.168.1.100

PI_IP="192.168.1.100"
echo "Checking Raspberry Pi at $PI_IP..."

# Test connectivity
if ping -c 1 $PI_IP &> /dev/null; then
    echo "✓ Pi is reachable"
    
    # Test SSH
    if nc -z -w2 $PI_IP 22 2>/dev/null; then
        echo "✓ SSH available - deploying..."
        
        # Package files
        cd /opt/pisignage
        tar czf /tmp/pisignage.tar.gz --exclude='.git' .
        
        # Deploy
        scp -o StrictHostKeyChecking=no /tmp/pisignage.tar.gz pi@$PI_IP:/tmp/
        ssh -o StrictHostKeyChecking=no pi@$PI_IP "sudo tar xzf /tmp/pisignage.tar.gz -C /opt/pisignage"
        
        echo "✓ Deployed successfully"
    else
        echo "⚠ SSH not enabled on Pi"
        echo "Enable SSH: sudo raspi-config > Interface Options > SSH"
    fi
else
    echo "✗ Cannot reach Pi at $PI_IP"
fi
