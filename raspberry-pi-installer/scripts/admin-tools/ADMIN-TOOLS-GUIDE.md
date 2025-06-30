# Pi Signage - Guide des Outils d'Administration

Version 2.3.0

## Vue d'ensemble

Pi Signage fournit une suite complète d'outils d'administration pour gérer, diagnostiquer et maintenir votre système d'affichage numérique. Ces outils sont conçus pour simplifier les tâches courantes et résoudre rapidement les problèmes.

## Installation des outils

Les scripts d'administration sont installés automatiquement lors de l'installation de Pi Signage. Ils sont disponibles dans :
- `/opt/scripts/admin-tools/` - Scripts principaux
- Liens symboliques dans `/usr/local/bin/` pour un accès global

## Outils disponibles

### 1. pi-signage - Contrôle principal

**Description :** Script de contrôle centralisé pour gérer tous les services Pi Signage.

**Usage :**
```bash
sudo pi-signage [commande]
```

**Commandes disponibles :**
- `status` - Afficher l'état de tous les services
- `start` - Démarrer tous les services
- `stop` - Arrêter tous les services
- `restart` - Redémarrer tous les services
- `emergency` - Mode de récupération d'urgence
- `help` - Afficher l'aide

**Exemples :**
```bash
# Vérifier l'état du système
sudo pi-signage status

# Redémarrer après un problème
sudo pi-signage restart

# Mode urgence si le système ne répond plus
sudo pi-signage emergency
```

### 2. pi-signage-diag - Diagnostic système

**Description :** Effectue un diagnostic complet du système et génère un rapport détaillé.

**Usage :**
```bash
sudo pi-signage-diag
```

**Points vérifiés :**
- Informations système (modèle Pi, OS, kernel)
- Ressources (CPU, RAM, disque, température)
- État des services
- Permissions des fichiers
- Connectivité réseau
- Analyse des logs
- Tests spécifiques selon le mode (VLC/Chromium)

**Sortie :**
- Affichage coloré avec indicateurs visuels
- Rapport sauvegardé dans `/tmp/pi-signage-diagnostic-*.log`
- Code de sortie : 0 si OK, 1 si erreurs détectées

### 3. pi-signage-tools - Menu interactif

**Description :** Interface menu interactive pour accéder facilement à toutes les fonctions d'administration.

**Usage :**
```bash
sudo pi-signage-tools
```

**Menus disponibles :**
1. État des services
2. Contrôle des services
3. Diagnostic système
4. Gestion des vidéos
5. Sécurité et mots de passe
6. Monitoring et logs
7. Maintenance
8. Informations système
9. Aide et documentation

**Navigation :**
- Utilisez les numéros pour sélectionner une option
- 0 pour revenir au menu précédent ou quitter

### 4. pi-signage-repair - Réparation automatique

**Description :** Tente de réparer automatiquement les problèmes courants du système.

**Usage :**
```bash
sudo pi-signage-repair
```

**Réparations effectuées :**
- Correction des permissions des fichiers et répertoires
- Redémarrage des services inactifs
- Nettoyage des fichiers temporaires et locks
- Vérification et création des répertoires manquants
- Libération d'espace disque si nécessaire
- Tests de validation après réparation

**Log :** `/var/log/pi-signage/repair-*.log`

### 5. pi-signage-logs - Collecte de logs

**Description :** Collecte tous les logs pertinents dans une archive pour le support technique.

**Usage :**
```bash
sudo pi-signage-logs
```

**Informations collectées :**
- Informations système complètes
- Logs de tous les services
- Configuration (sans mots de passe)
- Liste des vidéos
- Rapport de diagnostic
- Logs des 7 derniers jours

**Sortie :** Archive tar.gz dans `/tmp/pi-signage-logs-*.tar.gz`

**Pour envoyer au support :**
```bash
# Transférer via SCP
scp pi@[IP-RASPBERRY]:/tmp/pi-signage-logs-*.tar.gz .

# Ou copier sur clé USB
cp /tmp/pi-signage-logs-*.tar.gz /media/usb/
```

### 6. sync-videos.sh - Synchronisation Google Drive

**Description :** Synchronise les vidéos depuis un dossier Google Drive configuré.

**Usage :**
```bash
sudo sync-videos.sh [options]
```

**Options :**
- `-d, --dry-run` - Mode simulation (affiche les changements sans les appliquer)
- `-v, --verbose` - Mode verbeux
- `-f, --force` - Force la synchronisation même si une autre est en cours
- `--delete` - Supprime les fichiers locaux qui n'existent plus sur Drive
- `-h, --help` - Affiche l'aide

**Configuration requise :**
- rclone installé et configuré avec un remote "gdrive"
- Dossier "Signage" créé sur Google Drive (ou autre nom configuré)

**Exemples :**
```bash
# Synchronisation normale
sudo sync-videos.sh

# Mode test pour voir ce qui sera synchronisé
sudo sync-videos.sh --dry-run

# Synchronisation avec suppression des fichiers obsolètes
sudo sync-videos.sh --delete
```

### 7. test-gdrive.sh - Test Google Drive

**Description :** Teste et diagnostique la connexion Google Drive pour identifier les problèmes.

**Usage :**
```bash
sudo test-gdrive.sh [options]
```

**Options :**
- `-v, --verbose` - Mode verbeux
- `-h, --help` - Affiche l'aide

**Tests effectués :**
1. Installation de rclone
2. Configuration rclone
3. Connexion à Google Drive
4. Vérification des quotas
5. Accès au dossier de synchronisation
6. Test de lecture/écriture
7. Test de bande passante
8. Configuration réseau

**Utilisation typique :**
```bash
# Lancer le test complet
sudo test-gdrive.sh

# Mode verbeux pour plus de détails
sudo test-gdrive.sh -v
```

## Utilisation recommandée

### Routine quotidienne
1. Vérifier l'état : `sudo pi-signage status`
2. Si problème : `sudo pi-signage-diag`
3. Si erreurs : `sudo pi-signage-repair`

### Gestion des vidéos
1. Tester la connexion : `sudo test-gdrive.sh`
2. Synchroniser : `sudo sync-videos.sh`
3. Vérifier : Utiliser le menu `pi-signage-tools` > Gestion des vidéos

### En cas de problème
1. Diagnostic rapide : `sudo pi-signage-diag`
2. Réparation auto : `sudo pi-signage-repair`
3. Si persiste : `sudo pi-signage emergency`
4. Pour le support : `sudo pi-signage-logs`

### Maintenance régulière
- Hebdomadaire : Vérifier les logs et l'espace disque
- Mensuelle : Nettoyer les anciens logs via `pi-signage-tools`
- Trimestrielle : Mise à jour du système et des outils

## Intégration avec cron

Pour automatiser certaines tâches :

```bash
# Synchronisation automatique toutes les heures
0 * * * * /opt/scripts/admin-tools/sync-videos.sh > /dev/null 2>&1

# Diagnostic quotidien
0 3 * * * /opt/scripts/admin-tools/pi-signage-diag > /var/log/pi-signage/daily-diag.log 2>&1

# Nettoyage hebdomadaire
0 2 * * 0 find /var/log/pi-signage -type f -mtime +30 -delete
```

## Résolution de problèmes courants

### Le service ne démarre pas
```bash
sudo pi-signage-diag          # Identifier le problème
sudo pi-signage-repair        # Tenter la réparation
sudo pi-signage restart       # Redémarrer les services
```

### Vidéos non synchronisées
```bash
sudo test-gdrive.sh           # Vérifier la connexion
sudo sync-videos.sh --dry-run # Tester la synchronisation
sudo sync-videos.sh -v        # Synchroniser en mode verbeux
```

### Système lent ou instable
```bash
sudo pi-signage-tools         # Menu > Monitoring > Statistiques système
sudo pi-signage-repair        # Nettoyer et optimiser
```

### Collecter des informations pour le support
```bash
sudo pi-signage-logs          # Créer l'archive de support
# Envoyer le fichier /tmp/pi-signage-logs-*.tar.gz
```

## Sécurité

- Tous les scripts nécessitent les privilèges root (sudo)
- Les mots de passe ne sont jamais inclus dans les logs
- Les permissions sont vérifiées et corrigées automatiquement
- Les fichiers de configuration sensibles sont protégés

## Personnalisation

Les scripts utilisent le fichier de configuration `/etc/pi-signage/config.conf`. Vous pouvez personnaliser :
- `GDRIVE_FOLDER_NAME` - Nom du dossier Google Drive
- `VIDEO_DIR` - Répertoire local des vidéos
- `LOG_DIR` - Répertoire des logs

## Support

En cas de problème non résolu :
1. Exécutez `sudo pi-signage-logs`
2. Récupérez l'archive générée
3. Contactez le support avec l'archive et une description du problème

## Changelog

### Version 2.3.0
- Ajout de tous les outils d'administration
- Support des modes VLC et Chromium
- Diagnostic amélioré
- Réparation automatique
- Intégration Google Drive complète

---

Documentation maintenue à jour sur : https://github.com/ElKiRo/Pi-Signage