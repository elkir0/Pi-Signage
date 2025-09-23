# 🏆 INTERFACE GOLDEN MASTER - PiSignage v0.8.0

## ⚠️ NE JAMAIS MODIFIER CETTE INTERFACE

**Date de validation : 23/09/2025 à 12:50**
**Validé par : L'utilisateur**
**Citation exacte : "tu fais en sorte qu'a l'avenir on conserve CETTE MISE EN PAGE, c'est exactement ce qu'il me faut."**

## 📸 Caractéristiques visuelles à préserver

### 🎨 Palette de couleurs
- **Background principal** : `linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)`
- **Couleur primaire** : `#4a9eff`
- **Couleur secondaire** : `#ff6b6b`
- **Couleur succès** : `#51cf66`
- **Glassmorphisme** : `rgba(255, 255, 255, 0.05)` avec `backdrop-filter: blur(10px)`

### 📐 Layout
- **Sidebar** : 280px de large, position fixe
- **Main content** : margin-left de 280px
- **Border radius** : 15px pour les cards, 10px pour les boutons
- **Padding cards** : 25px
- **Gap grids** : 25px

### 🎭 Effets visuels
- **Hover cards** : translateY(-5px) + shadow bleue
- **Boutons hover** : translateY(-2px) + shadow amplifiée
- **Nav item actif** : Animation pulse + barre latérale bleue
- **Transitions** : 0.3s ease sur tous les éléments interactifs

### 📱 Sections de navigation (dans l'ordre)
1. 📊 Dashboard
2. 📁 Médias
3. 🎵 Playlists
4. 📺 YouTube
5. ▶️ Lecteur (avec mode selector)
6. 📅 Programmation
7. 📸 Capture
8. ⚙️ Paramètres
9. 📋 Logs

## 🔒 Fichiers de référence

- **Interface en production** : `/opt/pisignage/web/index.php`
- **Copie de sauvegarde** : `/opt/pisignage/web/index-GOLDEN-MASTER.php`
- **Documentation** : `/opt/pisignage/CLAUDE.md`
- **Ce fichier** : `/opt/pisignage/INTERFACE-GOLDEN-MASTER.md`

## ⚙️ Fonctionnalités validées

### ✅ Dashboard
- Stats système en temps réel (CPU, RAM, Température)
- Contrôles VLC avec boutons ronds
- Bouton capture rapide

### ✅ Lecteur
- Sélecteur de mode (Plein écran / Fenêtré / Avec bandeau RSS)
- Contrôles VLC complets
- Sélection playlist et fichier unique
- Bouton capture rapide

### ✅ Médias
- Zone drag & drop
- Liste en grille avec cards
- Suppression individuelle

### ✅ YouTube
- Téléchargement avec qualité et compression
- Barre de progression animée
- Historique

### ✅ Capture
- Capture manuelle
- Auto-capture avec intervalle
- Preview en temps réel

## 🚫 Règles absolues

1. **NE JAMAIS** modifier le style CSS de base
2. **NE JAMAIS** changer la structure de la sidebar
3. **NE JAMAIS** modifier les couleurs du thème
4. **NE JAMAIS** supprimer les animations existantes
5. **TOUJOURS** se référer à `index-GOLDEN-MASTER.php` en cas de doute

## 📝 Note pour les développeurs futurs

Cette interface a été parfaitement validée par l'utilisateur. Toute modification de l'interface doit être faite dans un nouveau fichier, jamais dans celui-ci. Si vous devez ajouter des fonctionnalités, faites-le sans toucher au style visuel existant.

---

**GOLDEN MASTER v0.8.0 - 23/09/2025**