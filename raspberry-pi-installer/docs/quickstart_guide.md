# 🚀 QUICKSTART - Pi Signage Digital v2.4.0

**Installation rapide en 4 étapes - 10 minutes chrono**

## ⚡ Installation Express

### Étape 1 : Préparation (5 min)

1. **Flasher la carte SD :**
   - [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
   - **OS :** Raspberry Pi OS Lite 64-bit
   - **Options avancées :** Activer SSH, configurer WiFi si nécessaire

2. **Premier boot :**
   ```bash
   # Se connecter en SSH ou directement
   ssh pi@[IP_DU_PI]
   
   # Mise à jour rapide
   sudo apt update && sudo apt upgrade -y
   ```

### Étape 2 : Installation (2 min)

```bash
# Télécharger et lancer l'installation
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts
chmod +x *.sh
sudo ./install.sh
```

**Configuration demandée :**
- Mode d'affichage : `VLC Classic` ou `Chromium Kiosk`
- Nom dossier Google Drive : `Signage` (ou votre choix)
- Mot de passe interface web : `minimum 8 caractères`
- Mot de passe Glances : `minimum 6 caractères`
- Hostname du Pi : `pi-signage` (ou votre choix)

### Étape 3 : Google Drive (2 min)

```bash
# Après l'installation automatique
sudo /opt/scripts/setup-gdrive.sh
```

**Instructions à l'écran :**
1. Choisir "n" pour nouveau remote
2. Nom : `gdrive`
3. Storage : `drive` (Google Drive)
4. Suivre le lien d'authentification
5. Coller le code d'autorisation
6. Configurer comme "Full access"

### Étape 4 : Finalisation (1 min)

```bash
# Test de configuration
sudo /opt/scripts/test-gdrive.sh

# Redémarrage
sudo reboot
```

## ✅ Vérification Post-Installation

**Après redémarrage (2-3 minutes) :**

1. **Vérifier les services :**
   ```bash
   sudo pi-signage status
   ```

2. **Interfaces web :**
   - Interface de gestion : `http://[IP_DU_PI]/`
     - Login : `admin` / `[votre_mot_de_passe_web]`
   - Monitoring Glances : `http://[IP_DU_PI]:61208`
     - Login : `admin` / `[votre_mot_de_passe_glances]`
   - Player HTML5 (mode Chromium) : `http://[IP_DU_PI]:8888`

3. **Diagnostic complet :**
   ```bash
   sudo pi-signage-diag
   ```

## 📹 Ajouter des Vidéos

1. **Google Drive :**
   - Créer dossier "Signage" dans votre Drive
   - Ajouter vidéos (.mp4, .avi, .mkv, .mov)

2. **Synchronisation :**
   ```bash
   # Manuelle (immédiate)
   sudo /opt/scripts/sync-videos.sh
   
   # Automatique (toutes les 6h)
   # Configurée automatiquement
   ```

## 🔧 Commandes Essentielles

```bash
# Contrôle général
sudo pi-signage status          # État services
sudo pi-signage restart         # Redémarrer tout
sudo pi-signage emergency       # Récupération urgence

# Diagnostic
sudo pi-signage-diag           # Diagnostic complet
sudo pi-signage-tools          # Menu interactif

# Audio (nouveau v2.4.0)
sudo /opt/scripts/util-configure-audio.sh  # Configuration audio
sudo /opt/scripts/util-test-audio.sh      # Test audio

# Maintenance
sudo pi-signage-repair         # Réparation auto
sudo /opt/scripts/sync-videos.sh # Sync manuelle
```

## 🆘 Dépannage Rapide

**Écran noir :**
```bash
sudo systemctl restart lightdm
```

**VLC ne démarre pas :**
```bash
sudo systemctl restart vlc-signage
```

**Chromium ne démarre pas :**
```bash
sudo systemctl restart chromium-kiosk
```

**Pas de son dans les vidéos :**
```bash
sudo /opt/scripts/util-configure-audio.sh
```

**Pas de vidéos :**
```bash
sudo /opt/scripts/test-gdrive.sh
sudo /opt/scripts/sync-videos.sh
```

**Problème général :**
```bash
sudo pi-signage emergency
```

## 📋 Checklist Installation

- [ ] Raspberry Pi OS Lite 64-bit installé
- [ ] WiFi/Ethernet configuré et fonctionnel
- [ ] Script d'installation téléchargé et exécuté
- [ ] Configuration utilisateur complétée
- [ ] Google Drive configuré et testé
- [ ] Redémarrage effectué
- [ ] Services vérifiés avec `sudo pi-signage status`
- [ ] Interface Glances accessible
- [ ] Diagnostic `sudo pi-signage-diag` OK
- [ ] Vidéos ajoutées dans Google Drive
- [ ] Synchronisation testée
- [ ] Interface web accessible sur port 80
- [ ] Audio configuré si nécessaire

## 🎯 Résultat Attendu

**Après installation réussie :**
- Écran affiche automatiquement les vidéos en boucle
- Interface web de monitoring accessible
- Synchronisation automatique toutes les 6h
- Surveillance et récupération automatiques
- Maintenance automatisée

**Temps total : ~10 minutes + temps téléchargement**

---

## 📱 Installation Multi-Écrans

**Pour plusieurs Pi :**

1. **Nommage différencié :**
   ```bash
   # Pi 1 : pi-signage-hall
   # Pi 2 : pi-signage-bureau  
   # Pi 3 : pi-signage-atelier
   ```

2. **Dossiers Google Drive séparés :**
   ```
   Google Drive/
   ├── Signage-Hall/
   ├── Signage-Bureau/
   └── Signage-Atelier/
   ```

3. **Monitoring centralisé :**
   ```bash
   # Noter les IP de chaque Pi
   http://[IP_PI_1]:61208
   http://[IP_PI_2]:61208
   http://[IP_PI_3]:61208
   ```

## 🔗 Liens Utiles

- **Documentation complète :** [README.md](README.md)
- **Guide technique :** [technical_guide.md](technical_guide.md)
- **Guide de sécurité :** [SECURITY.md](SECURITY.md)
- **Dépannage :** [troubleshooting.md](troubleshooting.md)
- **Raspberry Pi Imager :** https://www.raspberrypi.org/software/
- **Google Drive :** https://drive.google.com

---

**🎉 Votre système Pi Signage v2.4.0 est prêt ! Profitez de votre digital signage professionnel avec support audio complet.**