# 🔧 Guide de dépannage - VLC Minimal

## VLC ne démarre pas automatiquement

### Symptôme
Après redémarrage, VLC ne se lance pas en plein écran.

### Solutions

1. **Vérifier le fichier autostart**
```bash
cat ~/.config/autostart/vlc-kiosk.desktop
# Doit contenir une ligne Exec avec le chemin vers vos vidéos
```

2. **Vérifier les permissions**
```bash
chmod +x ~/.config/autostart/vlc-kiosk.desktop
```

3. **Tester manuellement**
```bash
vlc --intf dummy --fullscreen --loop --random ~/Videos
```

## Écran noir au démarrage

### Symptôme
VLC démarre mais affiche un écran noir.

### Solutions

1. **Vérifier la présence de vidéos**
```bash
ls ~/Videos
# Doit lister au moins une vidéo
```

2. **Vérifier les formats**
VLC devrait lire tous les formats, mais préférez MP4/MKV.

3. **Réinstaller les codecs**
```bash
sudo apt-get install vlc-plugin-base
```

## Pas de son

### Solutions

1. **Vérifier le volume système**
```bash
alsamixer
# Appuyer sur F6 pour choisir la sortie audio
```

2. **Forcer la sortie HDMI**
```bash
sudo raspi-config
# Advanced Options > Audio > Force HDMI
```

## VLC consomme trop de ressources

### Solutions

1. **Réduire la qualité des vidéos**
- Convertir en 720p au lieu de 1080p
- Utiliser H.264 comme codec

2. **Désactiver les effets**
Ajouter à vlcrc :
```
[core] video-filter=
[core] audio-filter=
```

## Impossible d'importer depuis USB

### Symptôme
Le script ne trouve pas la clé USB.

### Solutions

1. **Vérifier le montage**
```bash
ls /media/pi/
# Doit lister votre clé USB
```

2. **Monter manuellement**
```bash
sudo mkdir -p /media/usb
sudo mount /dev/sda1 /media/usb
```

## L'économiseur d'écran se réactive

### Solutions

1. **Réappliquer la désactivation**
```bash
xset s off -dpms
```

2. **Vérifier au démarrage**
Ajouter à ~/.bashrc :
```bash
export DISPLAY=:0
xset s off -dpms
```

## Questions fréquentes

**Q: Puis-je utiliser des vidéos YouTube ?**
R: Non, VLC ne peut lire que des fichiers locaux. Téléchargez d'abord avec yt-dlp.

**Q: Comment changer l'ordre de lecture ?**
R: Retirez `--random` du fichier .desktop pour une lecture séquentielle.

**Q: Puis-je programmer des plages horaires ?**
R: Utilisez cron pour démarrer/arrêter VLC :
```bash
# Démarrer à 8h
0 8 * * * /home/pi/pi-signage-control.sh start
# Arrêter à 20h
0 20 * * * /home/pi/pi-signage-control.sh stop
```