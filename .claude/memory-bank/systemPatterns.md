# <� Patterns et R�gles Syst�me - PiSignage v0.8.0

## � R�GLES ABSOLUES (HARDCOD�ES)

### 1. MON R�LE
- **JE fais TOUT** : L'utilisateur ne doit pas avoir � ex�cuter de commandes
- **Automatisation compl�te** : Scripts et d�ploiements automatis�s
- **Validation syst�matique** : Toujours v�rifier le r�sultat

### 2. IP CORRECTE
- **TOUJOURS** : 192.168.1.103
- **JAMAIS** : 192.168.0.103 (ancienne IP erron�e)
- **V�rifier** : Toujours double-v�rifier l'IP dans les scripts

### 3. PROTOCOLE DE D�PLOIEMENT
```
Local � GitHub � Raspberry Pi � 2 tests Puppeteer minimum
```
- **JAMAIS** retourner avant validation compl�te
- **TOUJOURS** faire 2 tests Puppeteer minimum sur production
- **DOCUMENTER** chaque changement dans CLAUDE.md

### 4. CACHE NGINX
- **VIDER AVANT** chaque test
- **Commande compl�te** :
```bash
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/*
sudo systemctl restart nginx
```

### 5. DOCUMENTATION
- **Tout dans CLAUDE.md** : Chaque changement document�
- **Mise � jour imm�diate** : Pas d'attente

## =� Workflow obligatoire

1. **D�velopper localement** dans `/opt/pisignage`
2. **Tester en local** avec curl ou navigateur
3. **Push sur GitHub** avec tag v0.8.0
4. **D�ployer sur Raspberry Pi** via SSH/rsync
5. **Vider cache nginx** compl�tement
6. **2 tests Puppeteer minimum**
7. **Si �chec � r�p�ter** jusqu'au succ�s
8. **Mettre � jour CLAUDE.md**

## =� CE QU'IL NE FAUT JAMAIS FAIRE

### Versions
- **JAMAIS** cr�er de versions autres que v0.8.0
- **JAMAIS** utiliser v0.9.x ou v2.x.x
- **JAMAIS** m�langer les versions

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
- **JAMAIS** cr�er de branches autres que main
- **JAMAIS** garder d'anciennes versions

##  Conventions de codage

### PHP
```php
// Headers CORS toujours pr�sents
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

// Gestion d'erreurs syst�matique
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

# Toujours v�rifier les commandes
if ! command -v vlc &> /dev/null; then
    echo "VLC not installed"
    exit 1
fi

# Logs d�taill�s
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

## =' Patterns d'impl�mentation

### Upload de fichiers
1. V�rifier type MIME
2. Limiter taille (100MB max)
3. G�n�rer nom unique
4. D�placer vers `/media/`
5. Retourner chemin relatif

### Gestion playlists
1. Lire JSON existant
2. Valider structure
3. Merger avec nouveaux items
4. Sauvegarder atomiquement
5. Recharger VLC

### Captures d'�cran
1. V�rifier VLC actif
2. Appeler API HTTP VLC
3. Sauvegarder temporairement
4. Convertir si n�cessaire
5. Retourner base64 ou URL

## =� Standards de qualit�

### Performance
- **Temps de r�ponse API** : < 200ms
- **Chargement page** : < 1s
- **Upload fichier 10MB** : < 10s

### Fiabilit�
- **Uptime cible** : 99.9%
- **Recovery time** : < 30s
- **Logs rotation** : Journali�re

### S�curit�
- **Validation inputs** : Syst�matique
- **Escape outputs** : HTML, SQL, Shell
- **Permissions fichiers** : 755 dossiers, 644 fichiers
- **User process** : www-data (jamais root)

## = Patterns de d�bugging

### Commandes de diagnostic
```bash
# V�rifier services
systemctl status nginx php8.2-fpm

# V�rifier logs
tail -f /var/log/nginx/error.log
tail -f /var/log/php8.2-fpm.log

# V�rifier processus
ps aux | grep vlc
ps aux | grep php

# V�rifier ports
netstat -tlnp | grep :80

# V�rifier espace disque
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

## =� Patterns de d�ploiement

### D�ploiement atomique
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
# Si probl�me d�tect�
ssh pi@192.168.1.103 'mv /opt/pisignage /opt/pisignage.failed && mv /opt/pisignage.old /opt/pisignage'
ssh pi@192.168.1.103 'sudo systemctl restart nginx php8.2-fpm'
```

## � Commandes critiques m�moris�es

```bash
# SSH vers Pi
sshpass -p 'raspberry' ssh pi@192.168.1.103

# D�ploiement complet
/opt/pisignage/deploy-v080-to-production.sh

# Force push GitHub
git push --force origin main
git tag -f v0.8.0
git push --tags --force

# Vider tous les caches
sudo rm -rf /var/cache/nginx/* /tmp/nginx-cache/*
sudo systemctl restart nginx php8.2-fpm

# V�rification rapide
curl -s http://192.168.1.103 | grep -o "v0.8.0"
```