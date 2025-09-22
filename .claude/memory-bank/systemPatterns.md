# <¯ Patterns et Règles Système - PiSignage v0.8.0

##   RÈGLES ABSOLUES (HARDCODÉES)

### 1. MON RÔLE
- **JE fais TOUT** : L'utilisateur ne doit pas avoir à exécuter de commandes
- **Automatisation complète** : Scripts et déploiements automatisés
- **Validation systématique** : Toujours vérifier le résultat

### 2. IP CORRECTE
- **TOUJOURS** : 192.168.1.103
- **JAMAIS** : 192.168.0.103 (ancienne IP erronée)
- **Vérifier** : Toujours double-vérifier l'IP dans les scripts

### 3. PROTOCOLE DE DÉPLOIEMENT
```
Local ’ GitHub ’ Raspberry Pi ’ 2 tests Puppeteer minimum
```
- **JAMAIS** retourner avant validation complète
- **TOUJOURS** faire 2 tests Puppeteer minimum sur production
- **DOCUMENTER** chaque changement dans CLAUDE.md

### 4. CACHE NGINX
- **VIDER AVANT** chaque test
- **Commande complète** :
```bash
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/*
sudo systemctl restart nginx
```

### 5. DOCUMENTATION
- **Tout dans CLAUDE.md** : Chaque changement documenté
- **Mise à jour immédiate** : Pas d'attente

## =Ë Workflow obligatoire

1. **Développer localement** dans `/opt/pisignage`
2. **Tester en local** avec curl ou navigateur
3. **Push sur GitHub** avec tag v0.8.0
4. **Déployer sur Raspberry Pi** via SSH/rsync
5. **Vider cache nginx** complètement
6. **2 tests Puppeteer minimum**
7. **Si échec ’ répéter** jusqu'au succès
8. **Mettre à jour CLAUDE.md**

## =« CE QU'IL NE FAUT JAMAIS FAIRE

### Versions
- **JAMAIS** créer de versions autres que v0.8.0
- **JAMAIS** utiliser v0.9.x ou v2.x.x
- **JAMAIS** mélanger les versions

### Cache
- **JAMAIS** oublier de vider le cache nginx
- **JAMAIS** faire confiance au cache navigateur
- **JAMAIS** tester sans restart nginx

### Tests
- **JAMAIS** valider avec moins de 2 tests Puppeteer
- **JAMAIS** ignorer les erreurs console
- **JAMAIS** accepter une performance > 1s

### GitHub
- **JAMAIS** push sans tag v0.8.0
- **JAMAIS** créer de branches autres que main
- **JAMAIS** garder d'anciennes versions

##  Conventions de codage

### PHP
```php
// Headers CORS toujours présents
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

// Gestion d'erreurs systématique
try {
    // Code
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}

// Version toujours v0.8.0
define('VERSION', '0.8.0');
```

### Bash Scripts
```bash
#!/bin/bash
set -e  # Exit on error
set -u  # Exit on undefined variable

# Toujours vérifier les commandes
if ! command -v vlc &> /dev/null; then
    echo "VLC not installed"
    exit 1
fi

# Logs détaillés
echo "[$(date)] Action en cours..."
```

### Structure API
```json
{
  "success": true,
  "data": {},
  "version": "0.8.0",
  "timestamp": "2025-09-22T15:00:00Z"
}
```

## =' Patterns d'implémentation

### Upload de fichiers
1. Vérifier type MIME
2. Limiter taille (100MB max)
3. Générer nom unique
4. Déplacer vers `/media/`
5. Retourner chemin relatif

### Gestion playlists
1. Lire JSON existant
2. Valider structure
3. Merger avec nouveaux items
4. Sauvegarder atomiquement
5. Recharger VLC

### Captures d'écran
1. Vérifier VLC actif
2. Appeler API HTTP VLC
3. Sauvegarder temporairement
4. Convertir si nécessaire
5. Retourner base64 ou URL

## =Ê Standards de qualité

### Performance
- **Temps de réponse API** : < 200ms
- **Chargement page** : < 1s
- **Upload fichier 10MB** : < 10s

### Fiabilité
- **Uptime cible** : 99.9%
- **Recovery time** : < 30s
- **Logs rotation** : Journalière

### Sécurité
- **Validation inputs** : Systématique
- **Escape outputs** : HTML, SQL, Shell
- **Permissions fichiers** : 755 dossiers, 644 fichiers
- **User process** : www-data (jamais root)

## = Patterns de débugging

### Commandes de diagnostic
```bash
# Vérifier services
systemctl status nginx php8.2-fpm

# Vérifier logs
tail -f /var/log/nginx/error.log
tail -f /var/log/php8.2-fpm.log

# Vérifier processus
ps aux | grep vlc
ps aux | grep php

# Vérifier ports
netstat -tlnp | grep :80

# Vérifier espace disque
df -h /opt/pisignage
```

### Tests de validation
```bash
# Test API local
curl -I http://localhost/api/system.php

# Test API production
curl -I http://192.168.1.103/api/system.php

# Test version
curl http://192.168.1.103/api/system.php | jq .version
```

## =€ Patterns de déploiement

### Déploiement atomique
```bash
# 1. Backup actuel
ssh pi@192.168.1.103 'cp -r /opt/pisignage /opt/pisignage.backup'

# 2. Sync nouveaux fichiers
rsync -avz --delete /opt/pisignage/ pi@192.168.1.103:/opt/pisignage.tmp/

# 3. Switch atomique
ssh pi@192.168.1.103 'mv /opt/pisignage /opt/pisignage.old && mv /opt/pisignage.tmp /opt/pisignage'

# 4. Restart services
ssh pi@192.168.1.103 'sudo systemctl restart nginx php8.2-fpm'
```

### Rollback rapide
```bash
# Si problème détecté
ssh pi@192.168.1.103 'mv /opt/pisignage /opt/pisignage.failed && mv /opt/pisignage.old /opt/pisignage'
ssh pi@192.168.1.103 'sudo systemctl restart nginx php8.2-fpm'
```

## ¡ Commandes critiques mémorisées

```bash
# SSH vers Pi
sshpass -p 'raspberry' ssh pi@192.168.1.103

# Déploiement complet
/opt/pisignage/deploy-v080-to-production.sh

# Force push GitHub
git push --force origin main
git tag -f v0.8.0
git push --tags --force

# Vider tous les caches
sudo rm -rf /var/cache/nginx/* /tmp/nginx-cache/*
sudo systemctl restart nginx php8.2-fpm

# Vérification rapide
curl -s http://192.168.1.103 | grep -o "v0.8.0"
```