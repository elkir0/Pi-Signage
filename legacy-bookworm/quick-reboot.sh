#!/bin/bash

echo "=== REDEMARRAGE AVEC NOUVELLE CONFIG ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 "sudo reboot" 2>/dev/null

echo "Pi en cours de redémarrage..."
echo "Attendez 60 secondes puis vérifiez votre TV"
echo ""
echo "La vidéo devrait maintenant se lancer automatiquement!"
echo ""
echo "Si l'écran de login apparaît encore:"
echo "  Username: pi"
echo "  Password: palmer00"