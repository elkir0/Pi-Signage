# PiSignage - Protocole de Déploiement Rigoureux

## 🎯 Informations de Connexion Raspberry Pi
```
IP: 192.168.1.103
SSH Login: pi
SSH Password: raspberry
Web Root: /opt/pisignage/web/
Web Server: nginx/1.22.1
Web User: www-data
```

## 📋 Protocole de Déploiement Étape par Étape

### 1️⃣ Test Local
```bash
# Tester le code localement
curl http://localhost/api/endpoint.php
```

### 2️⃣ Déploiement sur Raspberry Pi
```bash
# Copier le fichier vers /tmp d'abord
sshpass -p raspberry scp /opt/pisignage/web/path/file.php pi@192.168.1.103:/tmp/

# Déplacer avec les bonnes permissions
sshpass -p raspberry ssh pi@192.168.1.103 "sudo mv /tmp/file.php /opt/pisignage/web/path/ && sudo chown www-data:www-data /opt/pisignage/web/path/file.php"
```

### 3️⃣ Test sur Raspberry Pi
```bash
# Vérifier que l'API fonctionne
curl http://192.168.1.103/api/endpoint.php
```

### 4️⃣ Commit et Push GitHub
```bash
# Ajouter les changements
git add -A

# Commit avec message descriptif
git commit -m "🔧 Fix: [Description courte]

- Point 1
- Point 2
Tested on: Raspberry Pi 192.168.1.103"

# Push vers GitHub
git push origin main
```

## 🔄 Script de Déploiement Automatique

Créer `deploy.sh` pour automatiser :

```bash
#!/bin/bash
# deploy.sh - Script de déploiement PiSignage

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

if [ "$#" -ne 2 ]; then
    echo "Usage: ./deploy.sh <source_file> <dest_path>"
    exit 1
fi

SOURCE=$1
DEST=$2
FILENAME=$(basename $SOURCE)

echo "📤 Déploiement de $FILENAME vers Pi..."

# Copie vers /tmp
sshpass -p $PI_PASS scp $SOURCE $PI_USER@$PI_IP:/tmp/

# Déplacement avec permissions
sshpass -p $PI_PASS ssh $PI_USER@$PI_IP "sudo mv /tmp/$FILENAME $DEST && sudo chown www-data:www-data $DEST/$FILENAME"

echo "✅ Déploiement terminé!"
```

## 🧪 Tests Essentiels

### APIs à Tester après Déploiement
- `/api/stats.php` - Stats système
- `/api/player-control.php?action=status` - Statut du player
- `/api/system.php` - Infos système
- `/api/media.php` - Liste des médias
- `/api/playlist-simple.php` - Playlists

### Commande de Test Rapide
```bash
# Test toutes les APIs
for endpoint in stats player-control?action=status system media playlist-simple; do
    echo "Testing /api/$endpoint..."
    curl -s http://192.168.1.103/api/$endpoint | jq '.success'
done
```

## ⚠️ Points d'Attention

1. **TOUJOURS** tester localement avant de déployer
2. **TOUJOURS** utiliser les bonnes permissions (www-data:www-data)
3. **TOUJOURS** tester sur le Pi après déploiement
4. **TOUJOURS** commit avec un message descriptif
5. **JAMAIS** oublier de synchroniser avec GitHub

## 📝 Checklist de Déploiement

- [ ] Code testé localement
- [ ] Fichier copié vers Pi
- [ ] Permissions correctes appliquées
- [ ] API testée sur Pi
- [ ] Dashboard vérifié (pas d'erreurs console)
- [ ] Commit créé avec message descriptif
- [ ] Push vers GitHub effectué
- [ ] Documentation mise à jour si nécessaire

## 🔍 Debug en Cas d'Erreur

### Vérifier les logs
```bash
# Logs nginx
sshpass -p raspberry ssh pi@192.168.1.103 "sudo tail -f /var/log/nginx/error.log"

# Logs PHP
sshpass -p raspberry ssh pi@192.168.1.103 "sudo tail -f /var/log/php*.log"
```

### Vérifier les permissions
```bash
sshpass -p raspberry ssh pi@192.168.1.103 "ls -la /opt/pisignage/web/api/"
```

## 💾 Sauvegarde Avant Modification

```bash
# Sauvegarder un fichier avant modification
sshpass -p raspberry ssh pi@192.168.1.103 "sudo cp /opt/pisignage/web/api/file.php /opt/pisignage/web/api/file.php.backup"
```

---

**Note**: Ce protocole doit être suivi rigoureusement pour éviter les problèmes de déploiement et maintenir la cohérence entre le développement local, le Raspberry Pi de production et le repository GitHub.