# 🚀 Guide d'installation Pi Signage Digital v2.4.2

## 📋 Prérequis

### Matériel
- **Raspberry Pi** : 3B+, 4B (2GB minimum recommandé) ou 5
- **Carte SD** : 32GB minimum (Classe 10 ou supérieure)
- **Alimentation** : Officielle Raspberry Pi recommandée
- **Écran** : HDMI (ou environnement VM avec Xvfb)

### Logiciel
- **OS** : Raspberry Pi OS Lite 64-bit (Bookworm) - Dernière version
- **Connexion** : Internet stable (Ethernet ou WiFi)
- **Accès** : SSH activé ou clavier/écran

## 🔧 Installation rapide

### 1. Préparer le Raspberry Pi

```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer git si nécessaire
sudo apt install -y git
```

### 2. Télécharger Pi Signage

```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts

# Rendre les scripts exécutables
chmod +x *.sh
```

### 3. Lancer l'installation

```bash
# Lancer le script d'installation principal
sudo ./main_orchestrator.sh
```

### 4. Suivre l'assistant

L'installation vous guidera pour :

1. **Choisir le mode d'affichage** :
   - **VLC Classic** : Stabilité maximale, tous formats vidéo
   - **Chromium Kiosk** : Moderne et léger, support HTML5

2. **Sélectionner les modules** :
   - Installation complète (recommandé)
   - Installation personnalisée

3. **Configurer les paramètres** :
   - Nom du dossier Google Drive
   - Mot de passe interface web
   - Mot de passe monitoring Glances
   - Hostname du Raspberry Pi

### 5. Configuration Google Drive (optionnel)

Si vous avez choisi le module de synchronisation :

```bash
# Configurer Google Drive après l'installation
sudo /opt/scripts/setup-gdrive.sh
```

### 6. Redémarrer

```bash
sudo reboot
```

## 🖥️ Installation sur VM/Headless

Pour les tests sur machine virtuelle (QEMU, UTM, VirtualBox) :

```bash
# L'installation détecte automatiquement l'environnement VM
# et installe Xvfb pour le support headless
sudo ./main_orchestrator.sh

# Le mode VM est activé automatiquement si détecté
```

## 🌐 Accès aux interfaces

Après l'installation et le redémarrage :

### Interface web de gestion
- **URL** : `http://[IP_DU_PI]/`
- **Utilisateur** : `admin`
- **Mot de passe** : Celui défini lors de l'installation

### Monitoring Glances
- **URL** : `http://[IP_DU_PI]:61208`
- **Utilisateur** : `admin`
- **Mot de passe** : Celui défini lors de l'installation

### Player HTML5 (mode Chromium uniquement)
- **URL** : `http://[IP_DU_PI]:8888/player.html`

## 📹 Ajouter des vidéos

### Via l'interface web
1. Connectez-vous à l'interface web
2. Allez dans "Gestion des vidéos"
3. Uploadez vos vidéos ou téléchargez depuis YouTube

### Via Google Drive
1. Créez un dossier "Signage" dans votre Google Drive
2. Ajoutez vos vidéos (MP4, AVI, MKV, MOV, WMV)
3. La synchronisation se fait automatiquement toutes les 6h

### Manuellement
```bash
# Copier des vidéos directement
sudo cp /chemin/vers/video.mp4 /opt/videos/
sudo chown www-data:www-data /opt/videos/*
```

## 🔍 Vérification de l'installation

```bash
# Vérifier l'état des services
sudo pi-signage status

# Diagnostic complet
sudo pi-signage-diag

# Logs en temps réel
sudo journalctl -f
```

## ❓ Problèmes courants

### Erreur "readonly variable"
```bash
# Nettoyer l'environnement
unset LOG_FILE CONFIG_FILE
sudo ./main_orchestrator.sh
```

### Services non démarrés
```bash
# Redémarrer tous les services
sudo pi-signage restart

# Vérifier un service spécifique
sudo systemctl status vlc-signage
```

### Interface web inaccessible
```bash
# Vérifier nginx et PHP
sudo systemctl status nginx
sudo systemctl status php8.2-fpm

# Vérifier les permissions
ls -la /var/www/pi-signage/
```

## 📚 Documentation complète

- [Guide technique détaillé](raspberry-pi-installer/docs/README.md)
- [Guide de dépannage](raspberry-pi-installer/docs/troubleshooting.md)
- [Documentation interface web](web-interface/README.md)

## 🆘 Support

Si vous rencontrez des problèmes :

1. Consultez le [guide de dépannage](raspberry-pi-installer/docs/troubleshooting.md)
2. Exécutez le diagnostic : `sudo pi-signage-diag`
3. Créez une [issue sur GitHub](https://github.com/elkir0/Pi-Signage/issues)

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.