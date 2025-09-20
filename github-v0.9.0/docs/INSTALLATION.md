# 📦 Guide d'Installation Détaillé - Pi-Signage v0.9.0

## Prérequis Matériels

- **Raspberry Pi 4 Model B** (2GB RAM minimum, 4GB recommandé)
- Carte SD 16GB minimum (32GB recommandé) Class 10 ou supérieure
- Alimentation officielle 5V/3A
- Câble HDMI
- Écran compatible HDMI
- Connexion internet (Ethernet ou WiFi)

## Prérequis Logiciels

- **Raspberry Pi OS Bookworm Lite 64-bit** (OBLIGATOIRE)
  - Télécharger : https://www.raspberrypi.com/software/operating-systems/
  - Version testée : 2025-09-20

## Installation Étape par Étape

### 1. Préparation de la carte SD

```bash
# Sur votre ordinateur, flasher l'image avec Raspberry Pi Imager
# Configurer SSH et WiFi si nécessaire
```

### 2. Premier démarrage

```bash
# Connexion SSH (mot de passe par défaut: raspberry)
ssh pi@IP_RASPBERRY

# Changer le mot de passe
passwd

# Mise à jour système
sudo apt update && sudo apt upgrade -y
```

### 3. Installation Pi-Signage

#### Méthode 1 : Installation automatique (recommandée)
```bash
wget -O - https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh | sudo bash
```

#### Méthode 2 : Installation manuelle
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
chmod +x install.sh
sudo ./install.sh
```

### 4. Configuration post-installation

Le système est configuré automatiquement. Après redémarrage :
- La vidéo démarre automatiquement en plein écran
- L'interface web est accessible sur http://IP_RASPBERRY/

### 5. Vérification

```bash
# Vérifier le statut
/opt/pisignage/scripts/vlc-control.sh status

# Vérifier l'interface web
curl http://localhost/api/system.php
```

## Configuration Avancée

### Modification de la résolution

```bash
# Éditer /boot/firmware/config.txt
sudo nano /boot/firmware/config.txt

# Ajouter (exemple pour 1920x1080)
hdmi_group=2
hdmi_mode=82
```

### Ajout de vidéos

1. Via l'interface web : Upload dans l'onglet Médias
2. Via SSH : Copier dans /opt/pisignage/media/
3. Via USB : Script de synchronisation disponible

## Dépannage

Voir [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
