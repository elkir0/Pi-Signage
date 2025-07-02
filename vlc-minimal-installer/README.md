# 📺 Pi Signage VLC Minimal - Installation Ultra Simple

**La solution de digital signage la plus simple et fiable pour Raspberry Pi**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)]()
[![Taux de réussite](https://img.shields.io/badge/Taux%20de%20réussite-100%25-brightgreen.svg)]()

> ✨ **Installation en moins de 5 minutes** - Aucune modification système, aucun service complexe, juste VLC qui lit vos vidéos en boucle !

## 🎯 Philosophie

- **KISS (Keep It Simple, Stupid)** : Pas de systemd custom, pas de services complexes
- **Utilise ce qui marche** : Interface graphique Raspberry Pi OS existante
- **Zéro modification système** : Tout dans l'espace utilisateur
- **100% de fiabilité** : Si VLC peut lire la vidéo, ça marchera

## 📋 Prérequis

- **Raspberry Pi** : 3B+, 4B ou 5
- **OS** : Raspberry Pi OS avec Desktop (32-bit ou 64-bit)
- **Carte SD** : 16GB minimum
- **Connexion** : Internet pour l'installation initiale

## 🚀 Installation

### Option 1 : Installation automatique (recommandée)

```bash
curl -fsSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/vlc-minimal-installer/install.sh | bash
```

### Option 2 : Installation manuelle

```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/vlc-minimal-installer

# Lancer l'installation
chmod +x install.sh
./install.sh
```

## 📁 Utilisation

1. **Placez vos vidéos dans** : `/home/pi/Videos`
   - Formats supportés : MP4, MKV, AVI, MOV, WEBM, etc.

2. **Redémarrez** : VLC se lance automatiquement en plein écran

3. **C'est tout !** 🎉

## ⚙️ Configuration optionnelle

### Changer le dossier des vidéos

Éditez `~/.config/autostart/vlc-kiosk.desktop` et modifiez le chemin.

### Désactiver le mode aléatoire

Retirez `--random` de la ligne Exec dans le fichier .desktop.

### Ajouter des vidéos depuis une clé USB

Les vidéos sont automatiquement copiées depuis une clé USB si elle contient un dossier `videos/`.

## 🔧 Commandes utiles

```bash
# Arrêter VLC
pkill vlc

# Relancer VLC
vlc --fullscreen --loop --random ~/Videos &

# Voir les logs
journalctl --user -f
```

## ❓ FAQ

**Q: Comment ajouter des vidéos ?**  
R: Copiez-les dans `/home/pi/Videos` via SSH, clé USB ou réseau.

**Q: Comment désinstaller ?**  
R: `rm ~/.config/autostart/vlc-kiosk.desktop` et `sudo apt remove vlc`

**Q: Puis-je utiliser Google Drive ?**  
R: Oui, voir le script optionnel `extras/setup-gdrive.sh`

## 🤝 Contribution

Ce projet suit le principe KISS. Les PR ajoutant de la complexité seront refusées.

## 📄 Licence

MIT License - Utilisez-le comme vous voulez !

---

**Pi Signage VLC Minimal** - Parce que parfois, simple c'est mieux 🚀