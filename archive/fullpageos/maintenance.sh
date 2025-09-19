#!/bin/bash

# Script de maintenance pour FullPageOS
# Usage: ./maintenance.sh [IP_DU_PI]

PI_HOST="${1:-192.168.1.103}"
PI_USER="pi"
PI_PASS="palmer00"

echo "================================"
echo "  MAINTENANCE FULLPAGEOS"
echo "  Pi: $PI_HOST"
echo "================================"
echo ""

# Menu principal
while true; do
    echo "Choisissez une option:"
    echo "1) Vérifier le statut"
    echo "2) Redémarrer Chromium"
    echo "3) Voir les logs"
    echo "4) Changer l'URL de la vidéo"
    echo "5) Mettre à jour le système"
    echo "6) Test de performance"
    echo "7) Nettoyer le cache"
    echo "8) Redémarrer le Pi"
    echo "9) Quitter"
    echo ""
    read -p "Option: " choice

    case $choice in
        1)
            echo "Vérification du statut..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST << 'ENDSSH'
            echo "=== CHROMIUM ==="
            ps aux | grep chromium | head -2
            echo ""
            echo "=== GPU ==="
            vcgencmd measure_temp
            vcgencmd get_throttled
            echo ""
            echo "=== MÉMOIRE ==="
            free -h
            echo ""
            echo "=== UPTIME ==="
            uptime
ENDSSH
            ;;
            
        2)
            echo "Redémarrage de Chromium..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST << 'ENDSSH'
            sudo systemctl restart fullpageos
            echo "✓ Service FullPageOS redémarré"
ENDSSH
            ;;
            
        3)
            echo "Logs FullPageOS (Ctrl+C pour quitter)..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST "sudo journalctl -u fullpageos -f"
            ;;
            
        4)
            echo "Nouvelle URL de vidéo:"
            read -p "URL: " new_url
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST << ENDSSH
            # Mettre à jour la page HTML
            sed -i "s|<source src=\".*\" type|<source src=\"$new_url\" type|" /home/pi/video-player.html
            echo "✓ URL mise à jour"
            # Redémarrer pour appliquer
            sudo systemctl restart fullpageos
ENDSSH
            ;;
            
        5)
            echo "Mise à jour du système..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST << 'ENDSSH'
            sudo apt update
            sudo apt upgrade -y
            echo "✓ Système mis à jour"
ENDSSH
            ;;
            
        6)
            echo "Test de performance..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST "./test-performance.sh"
            ;;
            
        7)
            echo "Nettoyage du cache..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST << 'ENDSSH'
            rm -rf /home/pi/.cache/chromium
            rm -rf /tmp/*
            echo "✓ Cache nettoyé"
ENDSSH
            ;;
            
        8)
            echo "Redémarrage du Pi..."
            sshpass -p "$PI_PASS" ssh $PI_USER@$PI_HOST "sudo reboot"
            echo "✓ Pi en cours de redémarrage"
            break
            ;;
            
        9)
            echo "Au revoir!"
            exit 0
            ;;
            
        *)
            echo "Option invalide"
            ;;
    esac
    
    echo ""
    echo "Appuyez sur Entrée pour continuer..."
    read
    clear
done