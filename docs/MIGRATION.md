# Guide de migration vers PiSignage Desktop v3.0

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Changements majeurs](#-changements-majeurs)
- [Préparation de la migration](#-préparation-de-la-migration)
- [Sauvegarde des données](#-sauvegarde-des-données)
- [Processus de migration](#-processus-de-migration)
- [Post-migration](#-post-migration)
- [Résolution de problèmes](#-résolution-de-problèmes)
- [Rollback d'urgence](#-rollback-durgence)

## 🎯 Vue d'ensemble

⚠️ **ATTENTION : PiSignage Desktop v3.0 représente une réécriture complète incompatible avec les versions précédentes.**

### Pourquoi migrer ?

- **Architecture moderne** : Base sur Raspberry Pi OS Desktop avec intégration native
- **Performance améliorée** : Player HTML5 avec accélération GPU
- **Interface responsive** : Compatible mobile, tablette et desktop
- **API REST complète** : Contrôle programmatique avancé
- **Synchronisation cloud** : Google Drive, Dropbox, OneDrive
- **Maintenance simplifiée** : Installation modulaire et diagnostics automatiques

### Niveau de difficulté

| Migration depuis | Difficulté | Temps estimé | Automatisation |
|------------------|------------|--------------|----------------|
| **v2.1.x** | 🟨 Moyenne | 2-3 heures | Partielle |
| **v2.0.x** | 🟨 Moyenne | 2-4 heures | Partielle |
| **v1.x.x** | 🟥 Difficile | 4-6 heures | Manuelle |
| **PiSignage Lite** | 🟥 Difficile | 3-5 heures | Manuelle |

## 🔄 Changements majeurs

### Architecture technique

#### Avant (v2.x)
```
/home/pi/pisignage/
├── player/          # Player custom
├── config/          # Configuration INI
├── media/           # Médias mélangés
├── scripts/         # Scripts bash basiques
└── web/             # Interface Apache/PHP 7
```

#### Après (v3.0)
```
/opt/pisignage/
├── videos/          # Vidéos organisées
├── images/          # Images séparées
├── playlists/       # Playlists JSON
├── web/             # Interface nginx/PHP 8.2
├── scripts/         # Scripts modulaires
├── config/          # Configuration JSON
└── logs/            # Logs centralisés
```

### Services système

| Composant | v2.x | v3.0 |
|-----------|------|------|
| **Web server** | Apache | nginx |
| **PHP** | 7.4 | 8.2+ |
| **Player** | VLC + scripts | Chromium + HTML5 |
| **Services** | Scripts init.d | systemd natif |
| **Configuration** | Fichiers INI | JSON |
| **API** | Basique | REST complète |

### Interface utilisateur

| Fonctionnalité | v2.x | v3.0 |
|----------------|------|------|
| **Interface** | Desktop uniquement | Responsive |
| **Upload** | Formulaire basique | Glisser-déposer |
| **Playlists** | Fichiers texte | Interface graphique |
| **Contrôles** | Commandes SSH | Web + API + SSH |
| **Monitoring** | Logs manuels | Dashboard temps réel |

## 🛠️ Préparation de la migration

### Vérification du système actuel

```bash
# Identifier la version actuelle
cat /home/pi/pisignage/VERSION 2>/dev/null || echo "Version inconnue"

# Lister les médias
find /home/pi/pisignage -name "*.mp4" -o -name "*.jpg" -o -name "*.png" | wc -l

# Vérifier l'espace disque
df -h

# Status des services actuels
ps aux | grep -E "(vlc|apache|lighttpd)"
```

### Prérequis pour v3.0

```bash
# Vérifier la version du système
cat /etc/os-release

# Requis : Raspberry Pi OS Desktop Bookworm+
# Architecture : ARM64 recommandée
uname -m

# Mémoire minimale
free -h | grep Mem
# Requis : 2GB minimum, 4GB recommandé

# Vérifier GPU
vcgencmd get_mem gpu
# Requis : sera configuré à 128MB
```

### Planification de la migration

#### Créer un planning

1. **Phase préparatoire** (30 minutes)
   - Inventaire des médias
   - Sauvegarde complète
   - Test du nouveau système

2. **Migration effective** (1-2 heures)
   - Arrêt de l'ancien système
   - Sauvegarde finale
   - Installation v3.0
   - Restauration des médias

3. **Validation et tests** (30-60 minutes)
   - Vérification des fonctionnalités
   - Tests de lecture
   - Configuration fine

4. **Mise en service** (15 minutes)
   - Activation des services
   - Validation finale
   - Documentation des changements

## 💾 Sauvegarde des données

### Script de sauvegarde automatique

```bash
#!/bin/bash
# backup-v2-to-v3.sh - Sauvegarde avant migration v3.0

BACKUP_DIR="/home/pi/backup-migration-$(date +%Y%m%d-%H%M)"
OLD_PISIGNAGE="/home/pi/pisignage"

echo "=== Sauvegarde PiSignage v2.x pour migration v3.0 ==="
echo "Répertoire de sauvegarde: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# 1. Médias (priorité absolue)
echo "Sauvegarde des médias..."
mkdir -p "$BACKUP_DIR/media"
if [ -d "$OLD_PISIGNAGE/media" ]; then
    cp -r "$OLD_PISIGNAGE/media"/* "$BACKUP_DIR/media/" 2>/dev/null
fi

# Autres emplacements possibles
find "$OLD_PISIGNAGE" -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \
    -o -name "*.jpg" -o -name "*.png" -o -name "*.gif" | \
    while read file; do
        cp "$file" "$BACKUP_DIR/media/" 2>/dev/null
    done

# 2. Configuration
echo "Sauvegarde de la configuration..."
mkdir -p "$BACKUP_DIR/config"
find "$OLD_PISIGNAGE" -name "*.conf" -o -name "*.cfg" -o -name "*.ini" | \
    xargs -I {} cp {} "$BACKUP_DIR/config/" 2>/dev/null

# 3. Playlists (si existantes)
echo "Sauvegarde des playlists..."
find "$OLD_PISIGNAGE" -name "*playlist*" -o -name "*.m3u" | \
    xargs -I {} cp {} "$BACKUP_DIR/config/" 2>/dev/null

# 4. Scripts personnalisés
echo "Sauvegarde des scripts..."
find "$OLD_PISIGNAGE" -name "*.sh" -type f | \
    xargs -I {} cp {} "$BACKUP_DIR/config/" 2>/dev/null

# 5. Logs (derniers jours)
echo "Sauvegarde des logs récents..."
mkdir -p "$BACKUP_DIR/logs"
find /var/log -name "*pisignage*" -mtime -7 | \
    xargs -I {} cp {} "$BACKUP_DIR/logs/" 2>/dev/null

# 6. Configuration système
echo "Sauvegarde de la configuration système..."
cp /boot/config.txt "$BACKUP_DIR/config/boot-config.txt" 2>/dev/null
cp /etc/fstab "$BACKUP_DIR/config/fstab.backup" 2>/dev/null

# 7. Inventaire des médias
echo "Création de l'inventaire..."
cat > "$BACKUP_DIR/inventory.txt" << EOF
=== Inventaire PiSignage v2.x - $(date) ===

Médias trouvés:
$(find "$BACKUP_DIR/media" -type f | sort)

Nombre total de fichiers:
Vidéos: $(find "$BACKUP_DIR/media" -name "*.mp4" -o -name "*.avi" -o -name "*.mov" | wc -l)
Images: $(find "$BACKUP_DIR/media" -name "*.jpg" -o -name "*.png" -o -name "*.gif" | wc -l)

Taille totale: $(du -sh "$BACKUP_DIR/media" | cut -f1)

Configuration sauvegardée:
$(ls -la "$BACKUP_DIR/config/")
EOF

# 8. Compression de sauvegarde
echo "Compression de la sauvegarde..."
cd /home/pi
tar -czf "pisignage-v2-backup-$(date +%Y%m%d-%H%M).tar.gz" \
    "$(basename "$BACKUP_DIR")"

echo "=== Sauvegarde terminée ==="
echo "Archive: pisignage-v2-backup-$(date +%Y%m%d-%H%M).tar.gz"
echo "Dossier: $BACKUP_DIR"
echo ""
echo "Vérifiez le contenu avant de continuer la migration!"
ls -la "$BACKUP_DIR/media/"
```

### Exécution de la sauvegarde

```bash
# Rendre le script exécutable
chmod +x backup-v2-to-v3.sh

# Exécuter la sauvegarde
./backup-v2-to-v3.sh

# Vérifier la sauvegarde
ls -la pisignage-v2-backup-*.tar.gz
cat backup-migration-*/inventory.txt
```

### Sauvegarde vers stockage externe

```bash
# Copie vers clé USB
sudo mkdir /media/usb
sudo mount /dev/sda1 /media/usb
cp pisignage-v2-backup-*.tar.gz /media/usb/

# Copie vers réseau
scp pisignage-v2-backup-*.tar.gz user@server:/backups/

# Upload vers cloud (si rclone configuré)
rclone copy pisignage-v2-backup-*.tar.gz gdrive:backups/
```

## 🚀 Processus de migration

### Étape 1 : Arrêt de l'ancien système

```bash
# Arrêter tous les services PiSignage v2.x
sudo systemctl stop pisignage 2>/dev/null || true
sudo service pisignage stop 2>/dev/null || true
pkill -f pisignage 2>/dev/null || true
pkill vlc 2>/dev/null || true

# Arrêter les services web
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop lighttpd 2>/dev/null || true

# Vérifier qu'aucun processus ne fonctionne
ps aux | grep -E "(pisignage|vlc)" | grep -v grep
```

### Étape 2 : Sauvegarde finale

```bash
# Sauvegarde finale des médias actifs
mkdir -p /tmp/final-backup
cp -r /home/pi/pisignage/media/* /tmp/final-backup/ 2>/dev/null || true

# Synchroniser le disque
sync
```

### Étape 3 : Nettoyage de l'ancien système

```bash
# Désinstaller l'ancienne version (optionnel)
sudo systemctl disable pisignage 2>/dev/null || true
sudo rm -f /etc/systemd/system/pisignage.service
sudo systemctl daemon-reload

# Nettoyer les anciens scripts autostart (optionnel)
rm -f ~/.config/autostart/pisignage.desktop 2>/dev/null

echo "Ancien système arrêté - prêt pour v3.0"
```

### Étape 4 : Installation PiSignage v3.0

```bash
# Mise à jour système
sudo apt update && sudo apt upgrade -y

# Télécharger PiSignage v3.0
cd /tmp
wget https://github.com/yourusername/pisignage-desktop/archive/v3.0.0.tar.gz
tar -xzf v3.0.0.tar.gz
cd pisignage-desktop-3.0.0

# Installation avec logs détaillés
VERBOSE=true ./install.sh

# Ou installation modulaire si préférée
sudo ./modules/01-base-config.sh
sudo ./modules/02-web-interface.sh
sudo ./modules/03-media-player.sh
sudo ./modules/04-sync-optional.sh  # Optionnel
sudo ./modules/05-services.sh
```

### Étape 5 : Restauration des médias

```bash
# Créer les répertoires de destination
sudo mkdir -p /opt/pisignage/videos
sudo mkdir -p /opt/pisignage/images

# Script de restauration intelligent
cat > restore-media.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/pi/backup-migration-$(date +%Y%m%d)*/media"
VIDEO_DEST="/opt/pisignage/videos"
IMAGE_DEST="/opt/pisignage/images"

echo "Restauration des médias depuis $BACKUP_DIR"

# Copier les vidéos
find $BACKUP_DIR -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" \) | \
while read file; do
    echo "Copie vidéo: $(basename "$file")"
    sudo cp "$file" "$VIDEO_DEST/"
done

# Copier les images
find $BACKUP_DIR -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.svg" \) | \
while read file; do
    echo "Copie image: $(basename "$file")"
    sudo cp "$file" "$IMAGE_DEST/"
done

# Corriger les permissions
sudo chown -R pisignage:pisignage /opt/pisignage/videos/
sudo chown -R pisignage:pisignage /opt/pisignage/images/
sudo chmod 644 /opt/pisignage/videos/*
sudo chmod 644 /opt/pisignage/images/*

echo "Restauration terminée!"
echo "Vidéos: $(ls /opt/pisignage/videos/ | wc -l) fichiers"
echo "Images: $(ls /opt/pisignage/images/ | wc -l) fichiers"
EOF

chmod +x restore-media.sh
./restore-media.sh
```

### Étape 6 : Reconfiguration

```bash
# Configurer un hostname si nécessaire
sudo hostnamectl set-hostname pisignage-001

# Vérifier la configuration GPU
grep gpu_mem /boot/firmware/config.txt
# Doit contenir: gpu_mem=128

# Configurer le player pour les médias importés
pisignage-admin restart

# Créer une playlist basique avec tous les médias
cat > /tmp/playlist-migration.json << 'EOF'
{
    "name": "Migration v2.x",
    "active": true,
    "loop": true,
    "shuffle": false,
    "items": []
}
EOF

# Ajouter automatiquement tous les médias à la playlist
python3 << 'EOF'
import json
import os

playlist_file = "/tmp/playlist-migration.json"
videos_dir = "/opt/pisignage/videos"
images_dir = "/opt/pisignage/images"

# Charger la playlist
with open(playlist_file, 'r') as f:
    playlist = json.load(f)

# Ajouter les vidéos
order = 1
for video in sorted(os.listdir(videos_dir)):
    if video.lower().endswith(('.mp4', '.avi', '.mov', '.mkv', '.webm')):
        playlist['items'].append({
            "type": "video",
            "filename": video,
            "duration": 60,  # Durée par défaut
            "order": order
        })
        order += 1

# Ajouter les images
for image in sorted(os.listdir(images_dir)):
    if image.lower().endswith(('.jpg', '.jpeg', '.png', '.gif')):
        playlist['items'].append({
            "type": "image", 
            "filename": image,
            "duration": 10,  # Durée par défaut
            "order": order
        })
        order += 1

# Sauvegarder
with open("/opt/pisignage/playlists/migration.json", 'w') as f:
    json.dump(playlist, f, indent=2)

print(f"Playlist créée avec {len(playlist['items'])} éléments")
EOF

sudo chown pisignage:pisignage /opt/pisignage/playlists/migration.json
```

## ✅ Post-migration

### Validation du système

```bash
# Vérifier les services
pisignage-admin status

# Tester l'interface web
curl -I http://localhost/
curl http://localhost/api/v1/endpoints.php?action=system_info | jq

# Tester le player
pisignage play
sleep 5
pisignage status
```

### Tests fonctionnels

```bash
# Test de lecture vidéo
pisignage play --file=/opt/pisignage/videos/test.mp4

# Test interface admin
firefox http://localhost/admin.html

# Test API
curl -X POST http://localhost/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"player_control","action":"pause"}'
```

### Configuration avancée

```bash
# Configurer la synchronisation cloud (si nécessaire)
rclone config

# Activer les services automatiques
sudo systemctl enable pisignage.service
sudo systemctl enable pisignage-watchdog.timer

# Configurer l'autostart
cp /opt/pisignage/templates/autostart.desktop.template \
   ~/.config/autostart/pisignage.desktop
```

### Documentation des changements

```bash
# Créer un rapport de migration
cat > /home/pi/migration-report.txt << EOF
=== Rapport de migration PiSignage v3.0 ===
Date: $(date)

Médias migrés:
- Vidéos: $(ls /opt/pisignage/videos/ | wc -l)
- Images: $(ls /opt/pisignage/images/ | wc -l)

Services actifs:
$(systemctl is-active pisignage.service)
$(systemctl is-active nginx.service)

Configuration:
- Interface web: http://$(hostname -I | cut -d' ' -f1)/
- Admin: http://$(hostname -I | cut -d' ' -f1)/admin.html

Sauvegarde v2.x disponible dans:
$(ls -la ~/pisignage-v2-backup-*.tar.gz)
EOF

cat /home/pi/migration-report.txt
```

## 🛠️ Résolution de problèmes

### Problèmes de médias

#### Médias non trouvés après migration

```bash
# Vérifier l'emplacement des sauvegardes
find /home/pi -name "*backup*" -type d

# Re-exécuter la restauration
find /home/pi/backup-migration-*/media -type f \( -name "*.mp4" -o -name "*.jpg" \) | \
while read file; do
    echo "Restauration: $file"
    sudo cp "$file" /opt/pisignage/videos/ 2>/dev/null || \
    sudo cp "$file" /opt/pisignage/images/ 2>/dev/null
done

sudo chown -R pisignage:pisignage /opt/pisignage/videos/ /opt/pisignage/images/
```

#### Formats non supportés

```bash
# Lister les formats problématiques
find /opt/pisignage -name "*.avi" -o -name "*.flv" -o -name "*.wmv"

# Conversion avec ffmpeg (si installé)
sudo apt install ffmpeg
for file in /opt/pisignage/videos/*.avi; do
    if [ -f "$file" ]; then
        ffmpeg -i "$file" -c:v libx264 -c:a aac "${file%.avi}.mp4"
        rm "$file"
    fi
done
```

### Problèmes de services

#### Services ne démarrent pas

```bash
# Diagnostic complet
pisignage-admin diagnose

# Logs détaillés
journalctl -u pisignage.service -f
journalctl -u nginx.service -f

# Réinstallation des services
sudo /opt/pisignage/modules/05-services.sh
```

#### Interface web inaccessible

```bash
# Vérifier nginx
sudo systemctl status nginx
sudo nginx -t

# Vérifier PHP-FPM
sudo systemctl status php8.2-fpm

# Reconfiguration
sudo /opt/pisignage/modules/02-web-interface.sh
```

### Problèmes de performance

#### Player instable

```bash
# Vérifier configuration GPU
vcgencmd get_mem gpu
grep gpu_mem /boot/firmware/config.txt

# Optimiser si nécessaire
echo 'gpu_mem=256' | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

#### Mémoire insuffisante

```bash
# Vérifier usage mémoire
free -h
htop

# Optimiser swap
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=1024
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## 🔄 Rollback d'urgence

### Conditions de rollback

Effectuer un rollback si :
- Les médias principaux ne fonctionnent pas
- L'interface est inaccessible après 30 minutes
- Des corruptions de données sont détectées
- Des problèmes de performance critiques

### Procédure de rollback

```bash
#!/bin/bash
# rollback-to-v2.sh - Rollback d'urgence vers v2.x

echo "=== ROLLBACK D'URGENCE VERS V2.X ==="
echo "⚠️  Cette opération va supprimer PiSignage v3.0!"
read -p "Continuer? (y/N): " confirm

if [[ $confirm != "y" ]]; then
    echo "Rollback annulé"
    exit 1
fi

# 1. Arrêter v3.0
sudo systemctl stop pisignage.service nginx.service
sudo systemctl disable pisignage.service

# 2. Sauvegarder les médias v3.0 ajoutés
mkdir -p /tmp/v3-media-backup
cp -r /opt/pisignage/videos/* /tmp/v3-media-backup/ 2>/dev/null
cp -r /opt/pisignage/images/* /tmp/v3-media-backup/ 2>/dev/null

# 3. Supprimer v3.0
sudo rm -rf /opt/pisignage
sudo rm -f /etc/nginx/sites-enabled/pisignage
sudo rm -f /etc/systemd/system/pisignage*

# 4. Restaurer v2.x depuis sauvegarde
BACKUP_FILE=$(ls ~/pisignage-v2-backup-*.tar.gz | head -1)
if [ -f "$BACKUP_FILE" ]; then
    echo "Restauration depuis: $BACKUP_FILE"
    cd /home/pi
    tar -xzf "$BACKUP_FILE"
    
    # Restaurer les médias
    BACKUP_DIR=$(ls -d backup-migration-* | head -1)
    mkdir -p /home/pi/pisignage/media
    cp -r "$BACKUP_DIR/media"/* /home/pi/pisignage/media/
    
    echo "Rollback terminé - Redémarrage requis"
    echo "Médias v3.0 sauvegardés dans /tmp/v3-media-backup/"
else
    echo "❌ ERREUR: Sauvegarde v2.x introuvable!"
    echo "Recovery manuel requis"
fi
```

### Recovery manuel

Si le rollback automatique échoue :

```bash
# 1. Récupérer les médias essentiels
mkdir -p /home/pi/media-recovery
find /tmp -name "*.mp4" -o -name "*.jpg" | xargs -I {} cp {} /home/pi/media-recovery/

# 2. Installation propre v2.x (si archives disponibles)
# Télécharger depuis GitHub releases
wget https://github.com/yourusername/pisignage-desktop/archive/v2.1.0.tar.gz

# 3. Contact support
# Documenter le problème et contacter l'équipe de support
echo "Problème de migration - Contact support requis" > /home/pi/RECOVERY_NEEDED.txt
```

## 📞 Support et ressources

### Checklist finale

- [ ] Sauvegarde complète réalisée
- [ ] Médias restaurés et fonctionnels
- [ ] Interface web accessible
- [ ] Player fonctionne correctement
- [ ] Services automatiques activés
- [ ] Configuration documentée
- [ ] Tests de validation réussis

### Ressources utiles

- **Documentation complète** : [README.md](README.md)
- **Installation** : [INSTALL.md](INSTALL.md)
- **Guide utilisateur** : [USER_GUIDE.md](USER_GUIDE.md)
- **API** : [API.md](API.md)
- **Changelog** : [CHANGELOG.md](CHANGELOG.md)

### Contact support

- **GitHub Issues** : https://github.com/yourusername/pisignage-desktop/issues
- **Documentation** : https://github.com/yourusername/pisignage-desktop/wiki
- **Communauté** : https://github.com/yourusername/pisignage-desktop/discussions

---

*Ce guide de migration vous accompagne dans la transition vers PiSignage Desktop v3.0. En cas de difficulté, n'hésitez pas à contacter le support.*