# Guide utilisateur PiSignage Desktop v3.0

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Premier démarrage](#-premier-démarrage)
- [Interface web principale](#-interface-web-principale)
- [Interface d'administration](#-interface-dadministration)
- [Gestion des médias](#-gestion-des-médias)
- [Création de playlists](#-création-de-playlists)
- [Contrôle du player](#-contrôle-du-player)
- [Synchronisation cloud](#-synchronisation-cloud)
- [Contrôle à distance](#-contrôle-à-distance)
- [Sauvegarde et restauration](#-sauvegarde-et-restauration)
- [Personnalisation](#-personnalisation)
- [Dépannage utilisateur](#-dépannage-utilisateur)

## 🎯 Vue d'ensemble

PiSignage Desktop v3.0 transforme votre Raspberry Pi en une solution d'affichage dynamique professionnelle. Ce guide vous accompagne dans l'utilisation quotidienne de toutes les fonctionnalités.

### Concepts clés

- **Player** : Module de lecture des médias en plein écran
- **Playlist** : Liste ordonnée de médias à diffuser
- **Interface web** : Panneau de contrôle accessible via navigateur
- **API REST** : Interface programmable pour le contrôle à distance
- **Synchronisation** : Mise à jour automatique des contenus via cloud

### Architecture simplifiée

```
┌─────────────────────────────────────────┐
│              Écran d'affichage          │
│  ┌─────────────────────────────────┐    │
│  │         Player HTML5            │    │
│  │    (Lecture vidéos/images)      │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
                    ↑
                    │
┌─────────────────────────────────────────┐
│            Raspberry Pi                 │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ Interface   │  │   Stockage      │   │
│  │ Web Admin   │  │   Médias        │   │
│  └─────────────┘  └─────────────────┘   │
│           ↕                ↕            │
│    ┌─────────────┐  ┌─────────────────┐ │
│    │     API     │  │ Synchronisation │ │
│    │    REST     │  │     Cloud       │ │
│    └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────┘
```

## 🚀 Premier démarrage

### Accès initial

Après l'installation, votre PiSignage est accessible via :

```bash
# Interface locale (sur le Raspberry Pi)
http://localhost/
http://localhost/admin.html

# Interface réseau (depuis un autre appareil)
http://IP-DU-RASPBERRY/
http://IP-DU-RASPBERRY/admin.html

# Exemples
http://192.168.1.100/
http://192.168.1.100/admin.html
```

### Configuration initiale

1. **Vérifier l'adresse IP**
   ```bash
   # Sur le Raspberry Pi
   hostname -I
   # Résultat: 192.168.1.100
   ```

2. **Test de connexion**
   ```bash
   # Depuis un autre appareil sur le réseau
   ping 192.168.1.100
   curl http://192.168.1.100/api/health.php
   ```

3. **Premier accès à l'interface**
   - Ouvrir un navigateur web
   - Aller à `http://IP-DU-RASPBERRY/admin.html`
   - Vérifier que l'interface se charge correctement

### Ajout du premier média

```bash
# Méthode 1: Via interface web
# 1. Aller sur http://IP-DU-RASPBERRY/admin.html
# 2. Cliquer sur "Ajouter des médias"
# 3. Sélectionner fichiers depuis votre ordinateur
# 4. Cliquer "Upload"

# Méthode 2: Via copie directe (USB, SSH)
# Copier vos fichiers vidéo sur le Raspberry Pi
sudo cp /media/usb/mes-videos/*.mp4 /opt/pisignage/videos/
sudo chown -R pisignage:pisignage /opt/pisignage/videos/
```

## 🌐 Interface web principale

### Page d'accueil (Player)

L'interface principale (`http://IP-DU-RASPBERRY/`) affiche le player en mode plein écran.

#### Contrôles tactiles/souris

| Zone | Action | Résultat |
|------|---------|-----------|
| **Clic gauche** | Play/Pause | Basculer lecture/pause |
| **Clic droit** | Menu contextuel | Options avancées |
| **Double-clic** | Plein écran | Basculer mode fenêtré |
| **Molette** | Volume | Ajuster le volume |
| **Glisser** | Progression | Avancer/reculer dans la vidéo |

#### Raccourcis clavier

| Touche | Action |
|--------|---------|
| `Espace` | Play/Pause |
| `→` | Média suivant |
| `←` | Média précédent |
| `F` | Plein écran |
| `M` | Muet/Son |
| `+/-` | Volume +/- |
| `ESC` | Quitter plein écran |
| `R` | Redémarrer playlist |
| `S` | Arrêter |

### Interface responsive

L'interface s'adapte automatiquement à la taille de l'écran :

```css
/* Desktop (1920x1080+) */
- Player plein écran
- Contrôles discrets
- Interface admin complète

/* Tablette (768-1920px) */
- Player redimensionné
- Contrôles adaptés
- Interface admin simplifiée

/* Mobile (320-768px) */
- Player responsive
- Contrôles tactiles
- Interface admin mobile
```

## ⚙️ Interface d'administration

### Vue d'ensemble du dashboard

```
┌─────────────────────────────────────────────────────────────┐
│                    PiSignage Admin v3.0                    │
├─────────────────────────────────────────────────────────────┤
│  [📊 Dashboard] [📁 Médias] [📝 Playlists] [⚙️ Config]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Status système        Médias                               │
│  ┌─────────────────┐   ┌─────────────────────────────────┐   │
│  │ 🟢 En ligne     │   │ Vidéos: 12 fichiers            │   │
│  │ 📊 CPU: 15%     │   │ Images: 8 fichiers             │   │
│  │ 💾 RAM: 45%     │   │ Playlists: 3 actives           │   │
│  │ 🌡️ Temp: 42°C   │   │ Espace: 2.3 GB utilisés       │   │
│  └─────────────────┘   └─────────────────────────────────┘   │
│                                                             │
│  Player actuel         Synchronisation                      │
│  ┌─────────────────┐   ┌─────────────────────────────────┐   │
│  │ ▶️ En lecture   │   │ 🔄 Dernière sync: 10:30        │   │
│  │ 📹 video1.mp4   │   │ ☁️ Google Drive: Connecté      │   │
│  │ ⏱️ 2:45 / 5:30   │   │ 📤 Upload: Auto               │   │
│  │ 🔁 Loop activé  │   │ 📥 Download: Auto              │   │
│  └─────────────────┘   └─────────────────────────────────┘   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [▶️ Play] [⏸️ Pause] [⏹️ Stop] [⏭️ Suivant] [🔄 Redémarrer] │
└─────────────────────────────────────────────────────────────┘
```

### Onglet Dashboard

Le dashboard principal affiche :

#### Status système
- **État des services** : Statut en temps réel
- **Ressources** : CPU, RAM, température
- **Réseau** : Connectivité et bande passante
- **Stockage** : Espace disponible

#### Player actuel
- **Média en cours** : Nom et progression
- **Mode de lecture** : Loop, shuffle, playlist
- **Contrôles rapides** : Play, pause, stop, suivant

#### Logs récents
- **Événements système** : Démarrages, erreurs
- **Actions utilisateur** : Upload, changements config
- **Synchronisation** : Status cloud, erreurs

### Onglet Médias

#### Liste des fichiers

```html
┌─────────────────────────────────────────────────────────────┐
│                     Gestion des médias                     │
├─────────────────────────────────────────────────────────────┤
│ [📤 Upload] [📁 Dossier] [🔄 Actualiser] [🗑️ Nettoyer]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Vidéos (12 fichiers - 2.1 GB)                              │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑️ presentation.mp4    │ 156 MB │ 2024-09-18 │ [▶️][🗑️] │ │
│ │ ☑️ pub-produit.mp4     │ 89 MB  │ 2024-09-17 │ [▶️][🗑️] │ │
│ │ ☑️ actualites.mp4      │ 234 MB │ 2024-09-16 │ [▶️][🗑️] │ │
│ │ ☐ maintenance.mp4     │ 45 MB  │ 2024-09-15 │ [▶️][🗑️] │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Images (8 fichiers - 24 MB)                                │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑️ logo-entreprise.jpg │ 2.1 MB │ 2024-09-18 │ [👁️][🗑️] │ │
│ │ ☑️ promo-septembre.png │ 3.8 MB │ 2024-09-17 │ [👁️][🗑️] │ │
│ │ ☐ horaires.jpg        │ 1.2 MB │ 2024-09-15 │ [👁️][🗑️] │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### Actions disponibles

- **📤 Upload** : Ajouter nouveaux fichiers
- **▶️ Lire** : Test immédiat du média
- **👁️ Aperçu** : Prévisualisation image
- **🗑️ Supprimer** : Retirer définitivement
- **✏️ Renommer** : Modifier le nom
- **📊 Propriétés** : Détails techniques

#### Upload de médias

```javascript
// Interface d'upload
┌─────────────────────────────────────┐
│        Upload de médias             │
├─────────────────────────────────────┤
│                                     │
│  Glisser-déposer vos fichiers ici  │
│              ou                     │
│     [📁 Sélectionner fichiers]      │
│                                     │
│  Formats supportés:                 │
│  • Vidéos: MP4, WebM, AVI, MOV     │
│  • Images: JPG, PNG, GIF, SVG      │
│  • Taille max: 500 MB par fichier  │
│                                     │
├─────────────────────────────────────┤
│ File 1: presentation.mp4 [████████] │
│ File 2: logo.jpg        [██████   ] │
│                                     │
│ [⏸️ Pause] [❌ Annuler] [✅ Terminer] │
└─────────────────────────────────────┘
```

## 📝 Création de playlists

### Onglet Playlists

#### Interface de gestion

```html
┌─────────────────────────────────────────────────────────────┐
│                   Gestion des playlists                    │
├─────────────────────────────────────────────────────────────┤
│ [➕ Nouvelle] [📝 Modifier] [🗑️ Supprimer] [▶️ Activer]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Playlists disponibles                                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 🟢 Playlist Principale      │ 5 médias │ [▶️][✏️][🗑️]   │ │
│ │ ⚪ Promotion Septembre      │ 3 médias │ [▶️][✏️][🗑️]   │ │
│ │ ⚪ Actualités Quotidiennes  │ 8 médias │ [▶️][✏️][🗑️]   │ │
│ │ ⚪ Mode Maintenance         │ 1 média  │ [▶️][✏️][🗑️]   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Playlist active: Playlist Principale                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. presentation.mp4     │ 30s │ ↑ ↓ [🗑️]              │ │
│ │ 2. logo-entreprise.jpg  │ 10s │ ↑ ↓ [🗑️]              │ │
│ │ 3. pub-produit.mp4      │ 45s │ ↑ ↓ [🗑️]              │ │
│ │ 4. promo-septembre.png  │ 15s │ ↑ ↓ [🗑️]              │ │
│ │ 5. actualites.mp4       │ 60s │ ↑ ↓ [🗑️]              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Durée totale: 2m 40s │ Loop: ☑️ │ Shuffle: ☐             │
└─────────────────────────────────────────────────────────────┘
```

### Création d'une nouvelle playlist

#### Étape 1 : Informations de base

```html
┌─────────────────────────────────────┐
│      Nouvelle playlist              │
├─────────────────────────────────────┤
│                                     │
│ Nom: [Promotion Octobre______]      │
│                                     │
│ Description:                        │
│ [Contenus promotionnels pour   ]    │
│ [le mois d'octobre 2024        ]    │
│                                     │
│ Options:                            │
│ ☑️ Lecture en boucle               │
│ ☐ Lecture aléatoire                │
│ ☑️ Transition automatique          │
│                                     │
│ Durée par défaut (images): [10] sec │
│                                     │
│        [Annuler] [Suivant]          │
└─────────────────────────────────────┘
```

#### Étape 2 : Sélection des médias

```html
┌─────────────────────────────────────────────────────────────┐
│              Sélection des médias                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Médias disponibles              Playlist en cours           │
│ ┌─────────────────────────┐    ┌─────────────────────────┐  │
│ │ ☐ presentation.mp4      │    │ 1. logo-octobre.jpg     │  │
│ │ ☑️ logo-octobre.jpg     │ →  │ 2. promo-produit.mp4    │  │
│ │ ☑️ promo-produit.mp4    │    │ 3. offre-speciale.png   │  │
│ │ ☑️ offre-speciale.png   │    │                         │  │
│ │ ☐ actualites.mp4        │    │ Durée totale: 1m 25s    │  │
│ │ ☐ maintenance.mp4       │    │                         │  │
│ └─────────────────────────┘    └─────────────────────────┘  │
│                                                             │
│ [Tout sélectionner] [Tout désélectionner] [Prévisualiser]  │
│                                                             │
│                 [Précédent] [Créer playlist]               │
└─────────────────────────────────────────────────────────────┘
```

#### Étape 3 : Configuration avancée

```html
┌─────────────────────────────────────────────────────────────┐
│             Configuration avancée                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Planning de diffusion                                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑️ Activer planning                                     │ │
│ │                                                         │ │
│ │ Jours: [L][M][M][J][V][S][D]                           │ │
│ │ Heure début: [08:30]  Heure fin: [18:00]              │ │
│ │                                                         │ │
│ │ ☐ Exceptions:                                          │ │
│ │   • Jours fériés                                       │ │
│ │   • Vacances scolaires                                 │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Transitions                                                 │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Type: [Fondu]                                          │ │
│ │ Durée: [1.0] secondes                                  │ │
│ │                                                         │ │
│ │ ☑️ Afficher titre des médias                           │ │
│ │ ☑️ Afficher horloge                                    │ │
│ │ ☐ Afficher météo                                      │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│              [Précédent] [Créer et activer]                │
└─────────────────────────────────────────────────────────────┘
```

### Types de playlists

#### Playlist simple
- Liste séquentielle de médias
- Durée fixe ou automatique
- Lecture en boucle

#### Playlist programmée
- Activation selon planning horaire
- Jours de la semaine configurables
- Gestion des exceptions

#### Playlist dynamique
- Mise à jour automatique
- Filtres par tags/dossiers
- Synchronisation cloud

#### Playlist urgente
- Priorité maximale
- Activation immédiate
- Arrêt automatique programmé

## 🎮 Contrôle du player

### Commandes locales (SSH/Terminal)

```bash
# Commandes de base
pisignage play          # Démarrer la lecture
pisignage pause         # Mettre en pause
pisignage stop          # Arrêter complètement
pisignage next          # Média suivant
pisignage previous      # Média précédent
pisignage restart       # Redémarrer le player

# Gestion des playlists
pisignage playlist list                    # Lister les playlists
pisignage playlist activate "Nom Playlist" # Activer une playlist
pisignage playlist current                 # Playlist active

# Informations
pisignage status        # Status détaillé
pisignage info          # Informations système
pisignage list          # Liste des médias
pisignage version       # Version du système

# Configuration
pisignage config show               # Afficher configuration
pisignage config set volume 0.8    # Définir volume
pisignage config set loop true     # Activer le loop
```

### API REST

#### Endpoints de contrôle

```bash
# Base URL
API_BASE="http://192.168.1.100/api"

# Contrôle basique
curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"play"}'

curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"pause"}'

curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"next"}'

# Contrôle avec paramètres
curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"volume","value":0.8}'

curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"seek","value":30}'

# Changement de playlist
curl -X POST $API_BASE/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"playlist","name":"Promotion Octobre"}'
```

#### Récupération d'informations

```bash
# Status player
curl -X GET $API_BASE/status.php | jq

# Liste des médias
curl -X GET $API_BASE/videos.php | jq

# Liste des playlists
curl -X GET $API_BASE/playlists.php | jq

# Health check
curl -X GET $API_BASE/health.php | jq

# Configuration
curl -X GET $API_BASE/config.php | jq
```

### Interface mobile

L'interface s'adapte automatiquement aux appareils mobiles :

```html
┌─────────────────────────────┐
│       PiSignage Control     │
├─────────────────────────────┤
│                             │
│  Status: ▶️ En lecture      │
│  Média: presentation.mp4    │
│  Temps: 2:45 / 5:30        │
│                             │
│  ████████████████░░░░░      │
│                             │
│ ┌─────┐ ┌─────┐ ┌─────┐     │
│ │ ⏮️  │ │ ⏸️  │ │ ⏭️  │     │
│ └─────┘ └─────┘ └─────┘     │
│                             │
│ Volume: ████████░░ 80%      │
│                             │
│ Playlist: Principale        │
│ [📝 Changer playlist]       │
│                             │
│ [⚙️ Options] [📊 Status]    │
└─────────────────────────────┘
```

## ☁️ Synchronisation cloud

### Configuration initiale

#### Google Drive

```bash
# Configuration interactive
rclone config

# Sélections pour Google Drive:
# n) New remote
# name> gdrive
# Type of storage> drive
# Google Application Client Id> (vide)
# Google Application Client Secret> (vide)
# Scope> drive
# Use auto config> Y (si interface graphique) / N (si SSH)
# Configure this as a team drive> N
```

#### Dropbox

```bash
# Configuration Dropbox
rclone config

# Sélections pour Dropbox:
# n) New remote  
# name> dropbox
# Type of storage> dropbox
# Dropbox App Client Id> (vide)
# Dropbox App Client Secret> (vide)
# Use auto config> Y/N selon contexte
```

### Scripts de synchronisation

#### Configuration automatique

```bash
# Configuration du service de sync
pisignage-sync config

# Interface interactive:
# 1. Provider: Google Drive / Dropbox / OneDrive
# 2. Dossier distant: pisignage-content/
# 3. Synchronisation: Bidirectionnelle / Upload only / Download only
# 4. Planning: Toutes les 15min / 1h / Manual
# 5. Conflits: Conserver local / Conserver distant / Renommer
```

#### Commandes manuelles

```bash
# Upload vers cloud
pisignage-sync upload
pisignage-sync upload --dry-run    # Simulation

# Download depuis cloud
pisignage-sync download
pisignage-sync download --force    # Forcer écrasement

# Synchronisation bidirectionnelle
pisignage-sync sync
pisignage-sync sync --verbose      # Mode détaillé

# Status et informations
pisignage-sync status
pisignage-sync list-remote         # Contenu distant
pisignage-sync conflicts           # Conflits détectés
```

### Organisation cloud

#### Structure recommandée

```
Google Drive/pisignage-content/
├── videos/
│   ├── promotions/
│   │   ├── promo-septembre.mp4
│   │   └── promo-octobre.mp4
│   ├── institutionnel/
│   │   ├── presentation-entreprise.mp4
│   │   └── equipe.mp4
│   └── actualites/
│       ├── news-semaine1.mp4
│       └── news-semaine2.mp4
├── images/
│   ├── logos/
│   │   ├── logo-principal.png
│   │   └── logo-partenaires.jpg
│   └── affiches/
│       ├── horaires.jpg
│       └── tarifs.png
├── playlists/
│   ├── principale.json
│   ├── promotion.json
│   └── maintenance.json
└── config/
    ├── player-settings.json
    └── schedule.json
```

#### Gestion des versions

```bash
# Versionning automatique
pisignage-sync config versioning true

# Sauvegarde avant sync
pisignage-sync backup

# Restauration version précédente
pisignage-sync restore --version="2024-09-18-10:30"

# Nettoyage anciennes versions
pisignage-sync cleanup --keep-days=30
```

### Synchronisation automatique

#### Configuration cron

```bash
# Édition des tâches automatiques
crontab -e

# Exemples de planification:
# Sync toutes les 15 minutes
*/15 * * * * /usr/local/bin/pisignage-sync sync

# Upload quotidien à 2h du matin
0 2 * * * /usr/local/bin/pisignage-sync upload

# Download avant ouverture (8h)
0 8 * * 1-5 /usr/local/bin/pisignage-sync download

# Backup hebdomadaire (dimanche 3h)
0 3 * * 0 /usr/local/bin/pisignage-sync backup
```

#### Service systemd

```bash
# Activer la synchronisation automatique
sudo systemctl enable pisignage-sync.timer
sudo systemctl start pisignage-sync.timer

# Status du service
systemctl status pisignage-sync.timer
systemctl status pisignage-sync.service

# Logs
journalctl -u pisignage-sync.service -f
```

## 📱 Contrôle à distance

### Applications mobiles

#### Interface web mobile

L'interface web standard s'adapte automatiquement aux mobiles :

```
📱 Interface mobile optimisée:
- Contrôles tactiles larges
- Interface responsive
- Swipe pour navigation
- Affichage portrait/paysage
```

#### Contrôle via SSH

```bash
# Connexion SSH depuis mobile
# Applications recommandées:
# - Termius (iOS/Android)
# - JuiceSSH (Android)
# - Prompt (iOS)

# Commandes courtes pour mobile
alias p='pisignage'
alias ps='pisignage status'
alias pn='pisignage next'
alias pp='pisignage pause'
```

### Intégrations externes

#### Home Assistant

```yaml
# configuration.yaml
rest_command:
  pisignage_play:
    url: "http://192.168.1.100/api/control.php"
    method: POST
    payload: '{"action":"play"}'
    content_type: 'application/json'
    
  pisignage_pause:
    url: "http://192.168.1.100/api/control.php"  
    method: POST
    payload: '{"action":"pause"}'
    content_type: 'application/json'

# automation.yaml
automation:
  - alias: "PiSignage Auto Start"
    trigger:
      platform: time
      at: "08:00:00"
    action:
      service: rest_command.pisignage_play
```

#### Node-RED

```javascript
// Flow Node-RED pour contrôle PiSignage
[
    {
        "id": "pisignage-control",
        "type": "http request",
        "method": "POST",
        "url": "http://192.168.1.100/api/control.php",
        "payload": "{\"action\":\"{{action}}\"}",
        "headers": {
            "Content-Type": "application/json"
        }
    }
]
```

#### Scripts PowerShell (Windows)

```powershell
# Fonctions de contrôle PiSignage
function PiSignage-Play {
    $body = @{action="play"} | ConvertTo-Json
    Invoke-RestMethod -Uri "http://192.168.1.100/api/control.php" -Method POST -Body $body -ContentType "application/json"
}

function PiSignage-Status {
    Invoke-RestMethod -Uri "http://192.168.1.100/api/status.php" -Method GET
}

# Utilisation
PiSignage-Play
PiSignage-Status
```

## 💾 Sauvegarde et restauration

### Sauvegarde automatique

#### Configuration

```bash
# Configuration sauvegarde automatique
pisignage-admin backup config

# Options:
# - Fréquence: Quotidienne / Hebdomadaire / Mensuelle
# - Destination: Local / Cloud / NAS
# - Rétention: 7 jours / 30 jours / 90 jours
# - Compression: Activée / Désactivée
```

#### Types de sauvegarde

```bash
# Sauvegarde complète
pisignage-admin backup full
# Inclut: médias, configuration, playlists, logs

# Sauvegarde configuration uniquement
pisignage-admin backup config-only
# Inclut: paramètres, playlists (sans médias)

# Sauvegarde médias uniquement  
pisignage-admin backup media-only
# Inclut: vidéos, images (sans configuration)

# Sauvegarde incrémentale
pisignage-admin backup incremental
# Inclut: changements depuis dernière sauvegarde
```

### Sauvegarde manuelle

```bash
# Création sauvegarde manuelle
sudo tar -czf pisignage-backup-$(date +%Y%m%d-%H%M).tar.gz \
  /opt/pisignage/config/ \
  /opt/pisignage/videos/ \
  /opt/pisignage/images/ \
  /opt/pisignage/playlists/ \
  /etc/nginx/sites-available/pisignage

# Sauvegarde vers cloud
rclone copy pisignage-backup-*.tar.gz gdrive:backups/pisignage/

# Sauvegarde vers NAS
scp pisignage-backup-*.tar.gz user@nas.local:/volume1/backups/
```

### Restauration

#### Restauration complète

```bash
# Arrêter les services
sudo systemctl stop pisignage.service nginx.service

# Restaurer depuis sauvegarde
sudo tar -xzf pisignage-backup-20240918-1430.tar.gz -C /

# Restaurer permissions
sudo chown -R pisignage:pisignage /opt/pisignage/
sudo chown -R www-data:www-data /opt/pisignage/web/

# Redémarrer services
sudo systemctl start nginx.service pisignage.service
```

#### Restauration sélective

```bash
# Restaurer configuration uniquement
sudo tar -xzf backup.tar.gz /opt/pisignage/config/

# Restaurer médias uniquement
sudo tar -xzf backup.tar.gz /opt/pisignage/videos/ /opt/pisignage/images/

# Restaurer playlists uniquement
sudo tar -xzf backup.tar.gz /opt/pisignage/playlists/
```

## 🎨 Personnalisation

### Thèmes et apparence

#### Configuration du player

```json
// /opt/pisignage/config/player.json
{
    "appearance": {
        "theme": "dark",
        "backgroundColor": "#000000",
        "textColor": "#ffffff",
        "accentColor": "#007bff"
    },
    "overlay": {
        "showTitle": true,
        "showClock": true,
        "showProgress": false,
        "position": "bottom-right"
    },
    "transitions": {
        "type": "fade",
        "duration": 1000,
        "easing": "ease-in-out"
    }
}
```

#### Personnalisation CSS

```css
/* /opt/pisignage/web/assets/css/custom.css */

/* Player principal */
.player-container {
    background: linear-gradient(45deg, #1e3c72, #2a5298);
    border-radius: 8px;
}

/* Interface admin */
.admin-header {
    background-color: #343a40;
    color: #ffffff;
}

.btn-primary {
    background-color: #007bff;
    border-color: #007bff;
}

/* Responsive mobile */
@media (max-width: 768px) {
    .player-controls {
        font-size: 1.2em;
        padding: 15px;
    }
}
```

### Widgets et overlays

#### Horloge

```javascript
// Configuration horloge
{
    "clock": {
        "enabled": true,
        "format": "HH:mm:ss",
        "position": "top-right",
        "style": {
            "fontSize": "24px",
            "color": "#ffffff",
            "backgroundColor": "rgba(0,0,0,0.5)"
        }
    }
}
```

#### Météo

```javascript
// Configuration météo (nécessite API key)
{
    "weather": {
        "enabled": true,
        "apiKey": "votre-api-key",
        "city": "Paris",
        "units": "metric",
        "position": "top-left",
        "updateInterval": 600000
    }
}
```

#### Ticker de défilement

```javascript
// Configuration ticker RSS
{
    "ticker": {
        "enabled": true,
        "sources": [
            "https://example.com/rss.xml"
        ],
        "speed": 50,
        "position": "bottom",
        "maxItems": 10
    }
}
```

### Personnalisation logo

```bash
# Remplacer le logo principal
sudo cp mon-logo.png /opt/pisignage/web/assets/img/logo.png

# Logo pour interface admin
sudo cp logo-admin.png /opt/pisignage/web/assets/img/logo-admin.png

# Favicon
sudo cp favicon.ico /opt/pisignage/web/favicon.ico

# Permissions
sudo chown www-data:www-data /opt/pisignage/web/assets/img/*
```

## 🛠️ Dépannage utilisateur

### Problèmes courants

#### Le player ne démarre pas

**Symptoms** : Écran noir, pas de vidéo
**Solutions** :

```bash
# 1. Vérifier les services
pisignage-admin status

# 2. Redémarrer le player
pisignage restart

# 3. Vérifier les médias
ls -la /opt/pisignage/videos/

# 4. Tester un média spécifique
pisignage play --file=/opt/pisignage/videos/test.mp4
```

#### Interface web inaccessible

**Symptoms** : Erreur de connexion, page blanche
**Solutions** :

```bash
# 1. Vérifier connectivité réseau
ping 192.168.1.100

# 2. Tester depuis le Pi
curl http://localhost/admin.html

# 3. Vérifier le firewall
sudo ufw status

# 4. Redémarrer nginx
sudo systemctl restart nginx
```

#### Vidéo saccadée ou plantage

**Symptoms** : Lecture instable, freeze
**Solutions** :

```bash
# 1. Vérifier ressources système
htop
free -h

# 2. Vérifier température
vcgencmd measure_temp

# 3. Optimiser configuration GPU
grep gpu_mem /boot/firmware/config.txt

# 4. Utiliser codec H.264 uniquement
pisignage config set preferred_codec h264
```

### Diagnostics automatiques

```bash
# Script de diagnostic complet
pisignage-admin diagnose

# Résultat exemple:
# ✅ Services: OK
# ✅ Réseau: OK  
# ✅ GPU: OK (128MB)
# ❌ Température: Attention (65°C)
# ✅ Stockage: OK (15% utilisé)
# ❌ Codecs: H.265 non supporté
```

### Support et communauté

#### Logs utiles pour support

```bash
# Récupérer logs pour support
pisignage-admin collect-logs

# Génère: pisignage-logs-20240918-1430.tar.gz
# Contient: logs système, configuration, diagnostic
```

#### Réinitialisation d'urgence

```bash
# Reset configuration (conserve médias)
pisignage-admin reset config

# Reset complet (garde sauvegarde)
pisignage-admin factory-reset

# Reset avec confirmation
pisignage-admin factory-reset --confirm --backup
```

---

*Ce guide utilisateur complet vous accompagne dans l'utilisation quotidienne de PiSignage Desktop v3.0. Pour des questions techniques avancées, consultez la documentation API ou contactez le support.*