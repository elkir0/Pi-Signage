# 🔧 TECHNICAL - Guide Technique Pi Signage Digital v2.4.0

**Documentation technique complète de l'architecture, des modules et des outils**

## 🏗️ Architecture Générale

### Vue d'Ensemble du Système

```
┌─────────────────────────────────────────────────────────────┐
│                     Pi Signage Digital                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Display   │  │   Content   │  │ Monitoring  │         │
│  │   Manager   │  │    Sync     │  │   & Logs    │         │
│  │             │  │             │  │             │         │
│  │ LightDM +   │  │ rclone +    │  │ Glances +   │         │
│  │ Openbox +   │  │ Google      │  │ Watchdog +  │         │
│  │ VLC         │  │ Drive       │  │ Diagnostic  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                   Raspberry Pi OS Lite                     │
│              (Optimisé pour Digital Signage)               │
└─────────────────────────────────────────────────────────────┘
```

### Flux de Données

```
Google Drive → rclone → /opt/videos → VLC → HDMI Output
     ↑            ↑         ↑         ↑         ↑
     │            │         │         │         │
 Utilisateur   Cron Job  Watchdog  Display   Écran
   Upload     (6h auto)   Monitor   Manager
```

## 📦 Architecture Modulaire Détaillée

### Module 00 - Orchestrateur Principal

**Fichier :** `main_orchestrator.sh`

**Responsabilités :**
- Détection automatique du modèle Raspberry Pi
- Validation des prérequis système
- Coordination de l'installation des modules
- Gestion des erreurs et rollback partiel
- Génération du rapport d'installation

**Fonctions clés :**
```bash
detect_pi_model()      # Détection Pi 3/4/5 avec variants
check_internet()       # Validation connectivité
collect_configuration() # Interface utilisateur
execute_module()       # Lancement modules avec validation
```

**Configuration générée :**
```bash
# /etc/pi-signage/config.conf
GDRIVE_FOLDER="Signage"
GLANCES_PASSWORD="[hash]"
VIDEO_DIR="/opt/videos"
NEW_HOSTNAME="pi-signage"
PI_GENERATION="4"
PI_VARIANT="4GB"
```

### Module 01 - Configuration Système

**Fichier :** `01-system-config.sh`

**Responsabilités :**
- Configuration boot adaptée au modèle Pi
- Désactivation services non essentiels
- Optimisations GPU selon Pi 3/4/5
- Configuration timezone et hostname
- Création structure de répertoires

**Optimisations par modèle :**

| Paramètre | Pi 3/3B+ | Pi 4/5 | Justification |
|-----------|----------|--------|---------------|
| `gpu_mem` | 128MB | 256MB | Pi 4 a plus de RAM |
| `dtoverlay` | vc4-fkms-v3d | vc4-kms-v3d | Pi 4 support KMS complet |
| `max_framebuffers` | 2 | 2 | Stable pour tous |

**Services désactivés :**
- `bluetooth` : Non nécessaire pour signage
- `avahi-daemon` : Pas de découverte réseau
- `cups` : Pas d'impression
- `apt-daily` : Évite les mises à jour pendant fonctionnement

### Module 02 - Gestionnaire d'Affichage

**Fichier :** `02-display-manager.sh`

**Responsabilités :**
- Installation X11 + LightDM + Openbox
- Configuration auto-login utilisateur `signage`
- Mode kiosque (pas de barres, fenêtres)
- Scripts de configuration d'affichage

**Utilisateur signage :**
```bash
# Création utilisateur dédié
useradd -m -s /bin/bash signage
usermod -a -G video,audio,input,render,gpio signage
passwd -d signage  # Pas de mot de passe pour auto-login
```

**Configuration Openbox :**
```xml
<!-- Mode kiosque strict -->
<applications>
  <application name="vlc">
    <fullscreen>yes</fullscreen>
    <maximized>yes</maximized>
    <decor>no</decor>
    <focus>yes</focus>
    <layer>above</layer>
  </application>
</applications>
```

**Auto-démarrage :**
```bash
# ~/.config/openbox/autostart
xset s off              # Désactiver économiseur
xset -dpms              # Désactiver power management
unclutter -idle 1 &     # Masquer curseur
/opt/scripts/vlc-signage.sh &
```

### Module 03 - Configuration VLC/Chromium

**Fichiers :** `03-vlc-setup.sh` ou `03-chromium-kiosk.sh`

**Responsabilités :**
- Installation VLC + codecs
- Configuration mode kiosque
- Script de lecture intelligent
- Service systemd avec surveillance

**Configuration VLC (/home/signage/.config/vlc/vlcrc) :**
```ini
[main]
intf=dummy              # Pas d'interface graphique
fullscreen=1            # Plein écran
random=1                # Lecture aléatoire
loop=1                  # Boucle infinie
volume=256              # Volume maximum
disable-screensaver=1   # Empêcher mise en veille
audio-output=alsa       # Sortie audio ALSA
```

**Script VLC intelligent (/opt/scripts/vlc-signage.sh) :**
```bash
# Fonctionnalités clés :
- Détection automatique formats vidéo
- Surveillance des nouveaux fichiers
- Redémarrage automatique en cas d'erreur
- Message d'attente si pas de vidéos
- Gestion signaux système (SIGTERM)
```

**Service systemd :**
```ini
[Unit]
Description=VLC Digital Signage
After=graphical-session.target

[Service]
Type=simple
User=signage
ExecStart=/opt/scripts/vlc-signage.sh
Restart=always
RestartSec=10
```

### Module 04 - Synchronisation rclone

**Fichier :** `04-rclone-setup.sh`

**Responsabilités :**
- Installation rclone dernière version
- Scripts de configuration Google Drive
- Synchronisation intelligente
- Gestion des erreurs réseau

**Installation rclone :**
```bash
# Détection architecture automatique
case "$(uname -m)" in
  "armv7l"|"armv6l") arch="linux-arm" ;;
  "aarch64") arch="linux-arm64" ;;
  "x86_64") arch="linux-amd64" ;;
esac
wget "https://downloads.rclone.org/rclone-current-${arch}.zip"
```

**Script synchronisation (/opt/scripts/sync-videos.sh) :**
```bash
# Options rclone optimisées :
--transfers=2           # 2 transferts parallèles
--checkers=2           # 2 vérificateurs
--timeout=300s         # Timeout 5 minutes
--retries=3            # 3 tentatives
--size-only            # Comparaison par taille (rapide)
--exclude=".DS_Store"  # Exclure fichiers système
```

**Gestion des erreurs :**
- Test connectivité avant sync
- Vérification espace disque
- Redémarrage VLC si nouvelles vidéos
- Logs détaillés pour debugging

### Module 05 - Monitoring Glances

**Fichier :** `05-glances-setup.sh`

**Responsabilités :**
- Installation Glances via pip
- Configuration seuils d'alerte
- Interface web sécurisée
- Intégration avec surveillance système

**Installation :**
```bash
# Installation Python + Glances
apt-get install python3 python3-pip
python3 -m pip install glances[web]
```

**Configuration (/etc/glances/glances.conf) :**
```ini
[cpu]
user_warning=70        # Seuil CPU warning
user_critical=90       # Seuil CPU critique

[memory]  
warning=80             # Seuil mémoire warning
critical=95            # Seuil mémoire critique

[temperature]
warning=70             # Température warning (°C)
critical=80            # Température critique (°C)
```

**Authentification :**
```bash
# Création fichier .htpasswd avec htpasswd
echo "$GLANCES_PASSWORD" | htpasswd -i -c /etc/glances/.htpasswd admin
```

### Module 06 - Tâches Automatisées

**Fichier :** `06-cron-setup.sh`

**Responsabilités :**
- Configuration tâches cron
- Scripts de maintenance
- Surveillance système automatique
- Rotation des logs

**Tâches configurées :**

| Tâche | Fréquence | Script | Fonction |
|-------|-----------|---------|----------|
| Sync vidéos | `0 6,12,18,0 * * *` | `sync-videos.sh` | Synchronisation principale |
| Sync rapide | `30 * * * *` | `sync-videos.sh --quick` | Vérification horaire |
| Santé système | `15 * * * *` | `health-check.sh` | Surveillance services |
| Surveillance VLC | `*/5 * * * *` | `monitor-vlc.sh` | Contrôle VLC |
| Surveillance réseau | `*/10 * * * *` | `monitor-network.sh` | Test connectivité |
| Nettoyage logs | `0 2 * * *` | `cleanup-logs.sh` | Maintenance quotidienne |
| Rapport quotidien | `0 8 * * *` | `daily-report.sh` | Rapport de statut |
| Redémarrage | `0 3 * * 0` | `shutdown -r +1` | Maintenance hebdomadaire |

**Script surveillance VLC (/opt/scripts/monitor-vlc.sh) :**
```bash
# Vérifications :
1. Service vlc-signage actif ?
2. Processus VLC réellement en cours ?
3. Si service OK mais pas de processus → Restart
4. Log des actions pour traçabilité
```

### Module 07 - Services et Surveillance

**Fichier :** `07-services-setup.sh`

**Responsabilités :**
- Configuration target systemd personnalisé
- Service watchdog pour surveillance
- Script de récupération d'urgence
- Optimisation dépendances services

**Target pi-signage (/etc/systemd/system/pi-signage.target) :**
```ini
[Unit]
Description=Pi Signage System Target
Requires=graphical.target
After=graphical.target
AllowIsolate=yes
```

**Service Watchdog (/opt/scripts/pi-signage-watchdog.sh) :**
```bash
# Surveillance continue (30s) :
1. Vérification services critiques
2. Contrôle processus VLC
3. Test affichage X11
4. Surveillance mémoire
5. Actions correctives automatiques
```

**Script récupération d'urgence (/opt/scripts/emergency-recovery.sh) :**
```bash
# Séquence de récupération :
1. Arrêt tous services pi-signage
2. Kill processus VLC orphelins
3. Nettoyage cache mémoire
4. Vérification espace disque
5. Test connectivité + réparation réseau
6. Redémarrage services par ordre
```

### Module 08 - Outils de Diagnostic

**Fichier :** `08-diagnostic-tools.sh`

**Responsabilités :**
- Script diagnostic complet
- Outils spécialisés (VLC, réseau, système)
- Collecteur de logs pour support
- Interface interactive de maintenance

**Script principal (/opt/pi-signage-diag.sh) :**
```bash
# Vérifications complètes :
check_system_info()     # Infos système
check_services_status() # État services
check_processes()       # Processus critiques
check_display()         # X11 et affichage
check_videos()          # Vidéos et sync
check_network()         # Connectivité
check_system_resources() # CPU/RAM/Disk
check_logs()            # Erreurs récentes
check_configuration()   # Config files
```

**Collecteur de logs (/opt/scripts/collect-logs.sh) :**
```bash
# Archive complète pour support :
- Informations système
- Configuration Pi Signage
- Logs systemd (tous services)
- Logs application (/var/log/pi-signage/)
- Configuration réseau
- Tests de connectivité
- Anonymisation données sensibles
```

## 🔧 Fonctionnalités Avancées

### Système de Watchdog Intelligent

**Architecture :**
```
pi-signage-watchdog.service (Principal)
├── Surveillance services (30s)
│   ├── lightdm
│   ├── vlc-signage  
│   ├── glances
│   └── cron
├── Surveillance processus (30s)
│   ├── VLC réel vs service
│   ├── X11 Display :7
│   └── Utilisateur signage connecté
├── Surveillance ressources (30s)
│   ├── Mémoire > 95% → nettoyage cache
│   ├── CPU > 95% pendant 5min → alerte
│   └── Température > 80°C → actions
└── Actions correctives automatiques
    ├── Restart service individuel
    ├── Restart display manager
    ├── Nettoyage mémoire
    └── Récupération d'urgence si échec
```

### Gestion Multi-Modèles Pi

**Détection automatique :**
```bash
# /proc/cpuinfo analysis
detect_pi_model() {
  local model=$(grep "Model" /proc/cpuinfo | cut -d':' -f2 | xargs)
  case "$model" in
    *"Pi 4"*"8GB"*) PI_VARIANT="8GB"; GPU_MEM=256 ;;
    *"Pi 4"*"4GB"*) PI_VARIANT="4GB"; GPU_MEM=256 ;;
    *"Pi 4"*"2GB"*) PI_VARIANT="2GB"; GPU_MEM=128 ;;
    *"Pi 3"*"Plus"*) PI_VARIANT="3B+"; GPU_MEM=128 ;;
    *"Pi 5"*) PI_VARIANT="5"; GPU_MEM=512 ;;
  esac
}
```

**Optimisations spécifiques :**

| Configuration | Pi 3B+ | Pi 4 2GB | Pi 4 4GB+ | Pi 5 |
|---------------|--------|----------|-----------|------|
| `gpu_mem` | 128MB | 128MB | 256MB | 512MB |
| `dtoverlay` | vc4-fkms-v3d | vc4-kms-v3d | vc4-kms-v3d | vc4-kms-v3d |
| `max_framebuffers` | 2 | 2 | 2 | 2 |
| VLC threads | 2 | 4 | 4 | 8 |
| rclone transfers | 1 | 2 | 2 | 4 |

### Gestion Intelligente des Erreurs

**Niveaux d'escalade :**
```
1. WARN  → Log uniquement
2. ERROR → Action corrective simple (restart service)
3. CRITICAL → Action corrective complexe (restart display)
4. FATAL → Récupération d'urgence complète
```

**Actions automatiques :**
- **Service inactif** → `systemctl restart`
- **Processus zombie** → `kill + restart`
- **Mémoire saturée** → `drop_caches + restart VLC`
- **Disque plein** → `nettoyage automatique`
- **Réseau coupé** → `restart networking`
- **Affichage noir** → `restart lightdm`

### Synchronisation Optimisée

**Stratégie multi-niveaux :**
```bash
# Synchronisation principale (6h)
rclone sync --size-only --transfers=2 gdrive:Signage/ /opt/videos/

# Vérification rapide (1h)  
rclone check --size-only gdrive:Signage/ /opt/videos/

# Synchronisation différentielle
rclone sync --max-age=24h gdrive:Signage/ /opt/videos/
```

**Gestion intelligente des redémarrages VLC :**
```bash
# Seuls les changements déclenchent restart VLC :
- Nouveau fichier détecté
- Fichier supprimé
- Modification taille fichier
- NOT: modification metadata uniquement
```

## 📊 Monitoring et Observabilité

### Logs Structurés

**Hiérarchie des logs :**
```
/var/log/pi-signage/
├── setup.log              # Installation modules
├── vlc.log                 # VLC player
├── sync.log                # Synchronisation rclone
├── health.log              # Santé système
├── watchdog.log            # Surveillance
├── monitoring.log          # Tests automatiques
├── emergency.log           # Récupération urgence
├── temperature.log         # Température CPU
├── network-monitor.log     # Connectivité
└── daily-reports/          # Rapports quotidiens
    ├── report-2024-01-15.log
    └── report-2024-01-16.log
```

**Format standardisé :**
```
YYYY-MM-DD HH:MM:SS - [LEVEL] - [COMPONENT] - Message
2024-01-15 10:30:45 - [INFO] - [VLC] - Service démarré avec succès
2024-01-15 10:31:02 - [WARN] - [SYNC] - Google Drive non accessible, retry...
2024-01-15 10:35:15 - [ERROR] - [WATCHDOG] - Service lightdm inactif, redémarrage
```

### Métriques de Performance

**Collecte automatique :**
- **CPU Usage** : Moyenne, pics, par processus
- **Memory Usage** : RAM, swap, cache
- **Temperature** : CPU core temp
- **Disk I/O** : Lecture/écriture vidéos
- **Network** : Bande passante sync, latence
- **VLC Performance** : FPS, décrochages vidéo

**Historisation :**
```bash
# Rétention des métriques :
- Détaillées : 7 jours
- Moyennes horaires : 30 jours  
- Moyennes quotidiennes : 1 an
- Purge automatique via logrotate
```

## 🔐 Sécurité et Hardening

### Isolation des Services

**Utilisateur signage :**
```bash
# Permissions minimales :
- HOME : /home/signage (lecture/écriture)
- Videos : /opt/videos (lecture seule via sync)
- Configs : ~/.config/ (lecture/écriture)
- NO sudo access
- NO shell access (optionnel)
```

**Restrictions systemd :**
```ini
[Service]
NoNewPrivileges=yes     # Pas d'escalade privilèges
PrivateTmp=yes         # Tmp directory isolé
ProtectSystem=strict   # Système en lecture seule
ProtectHome=yes        # Autres homes inaccessibles
ReadWritePaths=/opt/videos /var/log/pi-signage
```

### Interface Web Sécurisée

**Glances hardening :**
```bash
# Authentification obligatoire
password_file=/etc/glances/.htpasswd

# Binding localhost uniquement (si proxy)
bind=127.0.0.1

# Ou binding spécifique réseau local
bind=0.0.0.0  # + firewall rules

# HTTPS avec certificat (optionnel)
certfile=/etc/ssl/glances.crt
keyfile=/etc/ssl/glances.key
```

### Mise à Jour Automatique Sécurisée

**Stratégie conservative :**
```bash
# Mises à jour sécurité uniquement
apt-get update
apt-get upgrade -y --with-new-pkgs \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"

# Exclusions critiques :
- kernel (risque incompatibilité)
- systemd (risque boot)
- rpi-update (firmware)
```

## 🚀 Optimisations de Performance

### Optimisations Boot

**Réduction temps de démarrage :**
```bash
# /boot/cmdline.txt
quiet                    # Pas de messages boot
logo.nologo             # Pas de logo
consoleblank=0          # Pas de screensaver console

# Services disabled
systemctl mask apt-daily.timer
systemctl mask apt-daily-upgrade.timer
systemctl mask man-db.timer
```

### Optimisations VLC

**Configuration performance :**
```ini
# Cache optimisé selon modèle Pi
file-caching=300        # Pi 3
file-caching=500        # Pi 4+

# Hardware acceleration
vout=gl                 # OpenGL si disponible
aout=alsa              # Audio ALSA direct

# Threading
threads=2              # Pi 3
threads=4              # Pi 4+
```

### Optimisations Réseau rclone

**Bande passante adaptative :**
```bash
# Pi 3 (WiFi potentiellement limité)
--transfers=1
--checkers=1
--bwlimit=10M

# Pi 4 (Ethernet Gigabit)
--transfers=2
--checkers=2
--bwlimit=50M
```

## 🧪 Tests et Validation

### Tests Automatisés

**Script de validation (/opt/scripts/validate-system.sh) :**
```bash
# Tests fonctionnels :
test_services_running()     # Tous services actifs
test_vlc_playback()        # VLC lit vraiment vidéos
test_display_output()      # Signal HDMI présent
test_sync_functionality()  # rclone fonctionne
test_monitoring_access()   # Glances accessible
test_watchdog_response()   # Watchdog réagit aux pannes
test_recovery_procedures() # Emergency recovery
```

### Tests de Charge

**Stress testing :**
```bash
# Test stabilité long terme
stress-ng --cpu 4 --timeout 300s
stress-ng --vm 2 --vm-bytes 80% --timeout 300s

# Test lecture vidéo continue
vlc --intf dummy --loop playlist.m3u &
iostat -x 1 3600  # Monitoring I/O 1h
```

### Métriques de Qualité

**SLA objectifs :**
- **Uptime** : > 99.5% (4h downtime/mois max)
- **Boot time** : < 60s jusqu'à affichage première vidéo
- **Sync time** : < 5min pour 1GB de vidéos
- **Recovery time** : < 2min après panne détectée
- **CPU usage** : < 30% moyenne lors lecture 1080p
- **Memory usage** : < 70% de la RAM disponible

## 📋 Maintenance Préventive

### Tâches Automatisées

**Maintenance quotidienne (2h00) :**
```bash
# Nettoyage logs anciens
find /var/log -name "*.log" -mtime +30 -delete
journalctl --vacuum-time=30d

# Vérification espace disque
df / | awk 'NR==2 {if($5+0 > 90) system("apt-get clean")}'

# Test intégrité système
fsck /dev/mmcblk0p2 -n  # Read-only check
```

**Maintenance hebdomadaire (dimanche 3h00) :**
```bash
# Redémarrage propre
sync && systemctl reboot

# Vérification après redémarrage (cron @reboot)
sleep 300  # Attendre stabilisation
/opt/scripts/validate-system.sh
```

**Maintenance mensuelle :**
```bash
# Mise à jour système
apt-get update && apt-get upgrade -y

# Vérification hardware
vcgencmd measure_temp
vcgencmd get_throttled

# Backup configuration
tar -czf /backup/pi-signage-config-$(date +%Y%m%d).tar.gz \
  /etc/pi-signage/ /opt/scripts/ /home/signage/.config/
```

### Indicateurs de Santé

**Métriques surveillance :**
```bash
# Température CPU
normal: < 60°C, warning: 60-75°C, critical: > 75°C

# Utilisation mémoire  
normal: < 70%, warning: 70-90%, critical: > 90%

# Espace disque
normal: < 80%, warning: 80-95%, critical: > 95%

# Load average
normal: < 2.0, warning: 2.0-4.0, critical: > 4.0
```

---

Ce guide technique fournit tous les détails nécessaires pour comprendre, maintenir et étendre le système Pi Signage Digital. Pour toute question spécifique ou contribution, référez-vous aux scripts sources qui contiennent des commentaires détaillés.