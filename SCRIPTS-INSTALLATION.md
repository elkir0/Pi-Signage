# 🛠️ PiSignage v0.8.1 GOLDEN - Scripts d'Installation

**Collection complète des scripts pour installer et gérer PiSignage facilement**

---

## 📦 Scripts Disponibles

### 🚀 **Scripts d'Installation Principaux**

#### 1. `install-pisignage-v0.8.1-golden.sh` ⭐ (PRINCIPAL)
**Le script d'installation ONE-CLICK complet**
- ✅ Installation complète automatique
- ✅ Déploiement depuis GitHub
- ✅ Configuration PHP 8.2 + Nginx
- ✅ Support MPV/VLC dual-player
- ✅ Services systemd intégrés
- ✅ Tests de validation automatiques
- ✅ Rapport de succès détaillé

**Usage:**
```bash
sudo ./install-pisignage-v0.8.1-golden.sh
```

#### 2. `quick-install.sh` ⚡
**Installation ultra-rapide avec téléchargement automatique**
- ✅ Télécharge l'installeur depuis GitHub
- ✅ Lance l'installation automatiquement
- ✅ Idéal pour installation à distance

**Usage:**
```bash
sudo ./quick-install.sh
```

**Ou directement:**
```bash
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash
```

---

### 🔍 **Scripts de Validation et Test**

#### 3. `validate-installation.sh` ✅
**Validation complète post-installation**
- ✅ Test de tous les services système
- ✅ Vérification des fichiers critiques
- ✅ Contrôle des permissions
- ✅ Test des lecteurs vidéo
- ✅ Validation de l'interface web
- ✅ Rapport détaillé avec recommandations

**Usage:**
```bash
./validate-installation.sh
```

#### 4. `test-installer.sh` 🧪
**Test de l'installeur avant utilisation**
- ✅ Vérification syntaxe bash
- ✅ Test des fonctions principales
- ✅ Contrôle de l'intégrité
- ✅ Validation des variables

**Usage:**
```bash
./test-installer.sh
```

---

### 📚 **Documentation Complète**

#### 5. `README-INSTALLATION.md` 📖
**Guide complet d'installation et d'utilisation**
- 📋 Instructions détaillées étape par étape
- 📋 Prérequis système
- 📋 Structure des fichiers
- 📋 Résolution de problèmes
- 📋 Commandes de contrôle

#### 6. `INSTALL-INSTRUCTIONS.md` 📋
**Instructions rapides et références**
- 🎯 Commandes essentielles
- 🎯 Fonctionnalités principales
- 🎯 Support et dépannage
- 🎯 Mise à jour

---

## 🎯 Scénarios d'Usage

### 🆕 **Première Installation**
```bash
# Option 1: Installation locale
cd /opt/pisignage
sudo ./install-pisignage-v0.8.1-golden.sh

# Option 2: Installation directe depuis Internet
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash

# Option 3: Quick install
sudo ./quick-install.sh
```

### 🔧 **Validation après Installation**
```bash
# Test complet de l'installation
./validate-installation.sh

# Test spécifique des lecteurs vidéo
./scripts/player-manager.sh test

# Vérification des services
sudo systemctl status pisignage nginx php8.2-fpm
```

### 🔄 **Mise à Jour ou Réinstallation**
```bash
# L'installeur est idempotent - relancez-le simplement
sudo ./install-pisignage-v0.8.1-golden.sh

# Vos médias et configurations seront préservés automatiquement
```

### 🐛 **Dépannage**
```bash
# Test de l'installeur avant utilisation
./test-installer.sh

# Validation complète du système
./validate-installation.sh

# Logs d'installation
tail -f /var/log/pisignage-install.log

# Logs système
sudo journalctl -f -u pisignage
```

---

## ⚡ **Installation Express (Recommandée)**

**Pour une installation ultra-rapide en une seule commande:**

```bash
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash
```

**Cette commande fait TOUT automatiquement:**
1. ✅ Télécharge l'installeur
2. ✅ Vérifie les prérequis
3. ✅ Installe tous les composants
4. ✅ Configure le système
5. ✅ Lance les tests de validation
6. ✅ Affiche le rapport de succès

---

## 🔧 **Scripts de Gestion (Déjà Existants)**

Ces scripts font partie du projet et sont automatiquement installés:

- `scripts/player-manager.sh` - Gestionnaire intelligent MPV/VLC
- `scripts/display-monitor.sh` - Monitoring système temps réel
- `start-pisignage.sh` - Démarrage rapide des services

---

## 📊 **Résumé des Fichiers**

```
Installation Scripts:
├── 🚀 install-pisignage-v0.8.1-golden.sh  (23KB) - Installeur principal
├── ⚡ quick-install.sh                     (4KB)  - Installation rapide
├── ✅ validate-installation.sh             (12KB) - Validation complète
├── 🧪 test-installer.sh                   (5KB)  - Test de l'installeur
├── 📖 README-INSTALLATION.md              (8KB)  - Guide complet
├── 📋 INSTALL-INSTRUCTIONS.md             (6KB)  - Instructions rapides
└── 📄 SCRIPTS-INSTALLATION.md             (CE FICHIER)

Tous les scripts sont:
✅ Testés et validés
✅ Robustes et idempotents
✅ Avec gestion d'erreur complète
✅ Documentation intégrée
✅ Compatible Raspberry Pi OS Bookworm
```

---

## 🎉 **Démarrage Immédiat**

**Prêt à installer PiSignage v0.8.1 GOLDEN ? Choisissez votre méthode préférée:**

### 🥇 **Méthode Recommandée (Internet):**
```bash
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash
```

### 🥈 **Méthode Locale:**
```bash
cd /opt/pisignage
sudo ./install-pisignage-v0.8.1-golden.sh
```

### 🥉 **Méthode Quick Install:**
```bash
sudo ./quick-install.sh
```

**Dans tous les cas, l'installation sera automatique et vous obtiendrez:**
- 🌐 Interface web accessible sur http://localhost/
- 🎬 Lecteurs vidéo MPV/VLC configurés
- ⚙️ Services systemd activés
- 📊 Monitoring temps réel
- 🎨 Interface glassmorphisme 9 sections

---

**🚀 Votre affichage dynamique PiSignage sera opérationnel en quelques minutes !**