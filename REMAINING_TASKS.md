# Tâches restantes Pi Signage v2.4.9

## À faire immédiatement

### 1. Commit et Push
```bash
cd "/Users/anthony/PROJETS/Pi signage Digital"
./do-commit.sh
```

### 2. Vérifier sur GitHub
- Le répertoire `patches/` doit avoir disparu
- Le fichier `quick-install.sh` doit être à la racine
- Les modifications dans :
  - `raspberry-pi-installer/scripts/01-system-config.sh` (ligne 300)
  - `raspberry-pi-installer/scripts/09-web-interface-v2.sh` (ajout proxy Glances)

### 3. Installation fraîche
Sur le Raspberry Pi avec Bookworm neuf :
```bash
wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/quick-install.sh
chmod +x quick-install.sh
./quick-install.sh
```

## Points à vérifier après installation

1. **Services actifs** :
   - nginx
   - php8.2-fpm
   - glances
   - chromium-kiosk

2. **Accès web** :
   - Interface : http://[IP]/
   - Glances : http://[IP]:61208/

3. **Logs** :
   - Vérifier que `/var/log/pi-signage/` appartient à `pi:pi`
   - Vérifier que chromium.log se remplit

4. **Performance vidéo** :
   - Uploader une vidéo MP4 1080p
   - Vérifier les FPS (devraient être fluides)

## Si problèmes persistent

1. Vérifier gpu_mem :
   ```bash
   vcgencmd get_mem gpu
   ```
   Doit retourner 128

2. Vérifier codec H264 :
   ```bash
   vcgencmd codec_enabled H264
   ```
   Doit retourner "enabled"

3. Si Chromium ne démarre pas :
   ```bash
   sudo journalctl -u chromium-kiosk -f
   ```

## Résumé des corrections v2.4.9
- ✅ Permissions logs pi:pi
- ✅ Proxy Glances dans nginx
- ✅ Wrappers verbose intégrés
- ✅ GPU mem 128 configuré
- ✅ Tous les patches supprimés
- ✅ Installation simplifiée