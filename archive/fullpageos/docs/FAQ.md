# ❓ FAQ - Foire Aux Questions

## Questions générales

### Q: Pourquoi FullPageOS plutôt que Raspberry Pi OS ?
**R:** Raspberry Pi OS Bookworm (2024) a un bug connu avec Chromium 139+ qui désactive l'accélération GPU, limitant les performances à 5-6 FPS. FullPageOS basé sur Bullseye fonctionne parfaitement avec 25-30+ FPS.

### Q: Quelle version de FullPageOS utiliser ?
**R:** Pour Pi 4, utilisez **FullPageOS Bullseye ARM64**. C'est la version la plus stable avec le meilleur support GPU.

### Q: Puis-je utiliser ce projet sur Pi 3 ?
**R:** Oui, mais les performances seront moindres (15-20 FPS). Utilisez FullPageOS Buster ARMHF pour Pi 3.

### Q: WiFi ou Ethernet ?
**R:** Ethernet est recommandé pour la stabilité, mais le WiFi fonctionne très bien pour la lecture vidéo locale.

## Installation

### Q: L'installation échoue avec "connection refused"
**R:** Vérifiez que :
- SSH est activé lors du flash
- Le Pi est sur le même réseau
- Les identifiants sont corrects (pi/palmer00)

### Q: Comment configurer le WiFi ?
**R:** Éditez `/boot/fullpageos-wpa-supplicant.txt` :
```bash
country=FR
network={
    ssid="VotreWiFi"
    psk="VotreMotDePasse"
}
```

### Q: Le script de déploiement ne fonctionne pas
**R:** Assurez-vous d'avoir installé `sshpass` :
```bash
sudo apt-get install sshpass
```

## Performances

### Q: J'ai toujours 5-6 FPS après installation
**R:** Exécutez le diagnostic GPU :
```bash
ssh pi@192.168.1.103
./diagnostic-gpu.sh
```
Vérifiez que le GPU est bien actif et non en mode SwiftShader.

### Q: La vidéo lag ou freeze
**R:** Causes possibles :
- Alimentation insuffisante (utilisez 5V 3A officielle)
- Température trop élevée (> 80°C)
- Résolution trop élevée (essayez 720p)

### Q: Comment optimiser pour 1080p ?
**R:** Dans `/boot/config.txt` :
```bash
gpu_mem=320  # Plus de mémoire GPU
gpu_freq=700  # Overclock GPU
over_voltage=4
```

## Affichage

### Q: Écran noir au démarrage
**R:** Dans `/boot/config.txt`, ajoutez :
```bash
hdmi_force_hotplug=1
hdmi_drive=2
config_hdmi_boost=4
```

### Q: Mauvaise résolution
**R:** Dans `/boot/fullpageos.txt` :
```bash
FULLPAGEOS_RESOLUTION="1920x1080"  # ou votre résolution
```

### Q: Pas de son
**R:** Forcez l'audio HDMI :
```bash
hdmi_drive=2  # dans /boot/config.txt
```

## Vidéos

### Q: Comment changer la vidéo ?
**R:** 3 méthodes :
1. Via maintenance.sh (option 4)
2. Éditer `/home/pi/video-player.html`
3. Utiliser une URL directe

### Q: Puis-je lire du YouTube ?
**R:** Oui, mais les performances peuvent varier. Utilisez youtube-dl pour télécharger localement :
```bash
yt-dlp -f mp4 [URL] -o /home/pi/video.mp4
```

### Q: Formats vidéo supportés ?
**R:** H.264 est optimal. Évitez H.265/HEVC (pas d'accélération hardware).

## Maintenance

### Q: Comment mettre à jour le système ?
**R:** Via maintenance.sh (option 5) ou :
```bash
ssh pi@192.168.1.103
sudo apt update && sudo apt upgrade -y
```

### Q: Comment voir les logs ?
**R:** 
```bash
# Logs FullPageOS
sudo journalctl -u fullpageos -f

# Logs Chromium
tail -f /home/pi/.cache/chromium/chrome_debug.log
```

### Q: Le Pi ne répond plus
**R:** Redémarrage forcé :
```bash
ssh pi@192.168.1.103
sudo reboot
```
Ou débranchez/rebranchez l'alimentation.

## Problèmes courants

### Q: "GPU process exited unexpectedly"
**R:** Chromium crash GPU. Solutions :
1. Nettoyer le cache : `rm -rf /home/pi/.cache/chromium`
2. Réduire gpu_mem à 128MB
3. Désactiver certains flags GPU

### Q: "Throttling detected"
**R:** Le Pi surchauffe ou manque de puissance :
- Utilisez une alimentation officielle 5V 3A
- Ajoutez un dissipateur/ventilateur
- Réduisez l'overclock

### Q: VNC ne fonctionne pas
**R:** FullPageOS utilise le port 5900 par défaut. Connectez-vous avec :
```
vnc://192.168.1.103:5900
```

## Avancé

### Q: Puis-je utiliser plusieurs écrans ?
**R:** Non recommandé sur Pi 4. Les performances chuteront drastiquement.

### Q: Comment automatiser plusieurs vidéos ?
**R:** Créez une playlist HTML5 ou utilisez un script bash avec rotation.

### Q: Puis-je contrôler à distance ?
**R:** Oui, via SSH, VNC, ou créez une API REST simple.

## Support

### Q: Où obtenir de l'aide ?
**R:** 
- [GitHub Issues](https://github.com/your-repo/issues)
- [FullPageOS Wiki](https://github.com/guysoft/FullPageOS/wiki)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

### Q: Comment contribuer ?
**R:** Fork le projet, créez une branche, et soumettez une Pull Request !

---

💡 **Astuce :** La plupart des problèmes se résolvent avec un redémarrage et une alimentation adéquate !