# 🔒 Guide de Sécurité - Pi Signage Web Interface

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Configuration Sécurisée](#configuration-sécurisée)
3. [Authentification et Sessions](#authentification-et-sessions)
4. [Protection des Données](#protection-des-données)
5. [Sécurité Réseau](#sécurité-réseau)
6. [Bonnes Pratiques](#bonnes-pratiques)
7. [Checklist de Sécurité](#checklist-de-sécurité)

## 🎯 Vue d'ensemble

Pi Signage Web Interface a été conçu avec la sécurité à l'esprit, mais nécessite une configuration appropriée pour être pleinement sécurisé. Ce guide couvre les aspects essentiels de la sécurisation de votre installation.

### Principes de sécurité appliqués

- **Défense en profondeur** : Plusieurs couches de sécurité
- **Principe du moindre privilège** : Permissions minimales nécessaires
- **Validation stricte** : Toutes les entrées utilisateur sont validées
- **Journalisation** : Audit trail complet des actions

## 🔐 Configuration Sécurisée

### 1. Changement des identifiants par défaut

**CRITIQUE** : Changez immédiatement les identifiants par défaut après l'installation.

```bash
# Via l'interface web
1. Connexion avec les identifiants par défaut
2. Aller dans Paramètres > Sécurité
3. Changer le mot de passe

# Via la ligne de commande
sudo nano /etc/pi-signage/config.conf
# Modifier WEB_ADMIN_PASSWORD
```

### 2. Permissions fichiers

```bash
# Vérifier les permissions
sudo find /var/www/pi-signage -type f -exec chmod 644 {} \;
sudo find /var/www/pi-signage -type d -exec chmod 755 {} \;
sudo chmod -R 775 /var/www/pi-signage/temp

# Configuration sensible
sudo chmod 600 /etc/pi-signage/config.conf
sudo chown root:root /etc/pi-signage/config.conf
```

### 3. Configuration PHP sécurisée

Éditer `/etc/php/8.2/fpm/pool.d/pi-signage.conf` :

```ini
; Désactiver les fonctions dangereuses
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source

; Masquer la version PHP
php_admin_flag[expose_php] = off

; Limiter l'accès aux fichiers
php_admin_value[open_basedir] = /var/www/pi-signage:/tmp:/opt/videos:/var/log/pi-signage

; Sessions sécurisées
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.cookie_secure] = 1  ; Si HTTPS
php_admin_value[session.use_only_cookies] = 1
php_admin_value[session.cookie_samesite] = Strict
```

### 4. Configuration nginx sécurisée

Ajouter dans `/etc/nginx/sites-available/pi-signage` :

```nginx
# Headers de sécurité
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;

# Masquer la version nginx
server_tokens off;

# Limiter les méthodes HTTP
if ($request_method !~ ^(GET|HEAD|POST|DELETE)$) {
    return 405;
}

# Protection contre le clickjacking
add_header X-Frame-Options SAMEORIGIN;

# Limite de taille des requêtes
client_body_buffer_size 1K;
client_header_buffer_size 1k;
large_client_header_buffers 2 1k;

# Timeout
client_body_timeout 10;
client_header_timeout 10;
send_timeout 10;

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;

location /index.php {
    limit_req zone=login burst=5 nodelay;
    # ... reste de la config
}

location /api/ {
    limit_req zone=api burst=20 nodelay;
    # ... reste de la config
}
```

## 🔑 Authentification et Sessions

### 1. Mots de passe forts

Exigences recommandées :
- Minimum 12 caractères
- Mélange majuscules, minuscules, chiffres, symboles
- Pas de mots du dictionnaire
- Unique pour Pi Signage

### 2. Gestion des sessions

```php
// Configuration recommandée dans config.php
ini_set('session.gc_maxlifetime', 3600);  // 1 heure
ini_set('session.cookie_lifetime', 0);     // Session cookie
ini_set('session.regenerate_id', 1);       // Régénérer l'ID
```

### 3. Protection contre le brute force

Le système inclut :
- Rate limiting sur les tentatives de connexion
- Journalisation des échecs de connexion
- Possibilité de bloquer des IP (avec fail2ban)

Configuration fail2ban recommandée :

```ini
# /etc/fail2ban/jail.local
[pi-signage-web]
enabled = true
port = http,https
filter = pi-signage-web
logpath = /var/log/nginx/pi-signage-access.log
maxretry = 5
bantime = 3600

# /etc/fail2ban/filter.d/pi-signage-web.conf
[Definition]
failregex = ^<HOST> .* "POST /index\.php.*" 401
ignoreregex =
```

## 🛡️ Protection des Données

### 1. Chiffrement des communications (HTTPS)

**Fortement recommandé** pour toute installation exposée sur le réseau.

#### Certificat Let's Encrypt (domaine public)
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d votre-domaine.com
```

#### Certificat auto-signé (réseau local)
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/pi-signage.key \
    -out /etc/ssl/certs/pi-signage.crt \
    -subj "/C=FR/ST=State/L=City/O=Organization/CN=pi-signage.local"

# Configuration nginx
server {
    listen 443 ssl http2;
    ssl_certificate /etc/ssl/certs/pi-signage.crt;
    ssl_certificate_key /etc/ssl/private/pi-signage.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    # ... reste de la config
}
```

### 2. Protection des vidéos

```nginx
# Empêcher l'accès direct aux vidéos
location /opt/videos {
    internal;
    alias /opt/videos;
}

# Servir les vidéos via PHP avec vérification d'auth
location /video/ {
    rewrite ^/video/(.*)$ /serve-video.php?file=$1 last;
}
```

### 3. Sanitisation des données

Toutes les entrées utilisateur sont filtrées :
- `htmlspecialchars()` pour l'affichage
- `filter_var()` pour les URLs
- `realpath()` pour les chemins fichiers
- Prepared statements pour SQL (si utilisé)

## 🌐 Sécurité Réseau

### 1. Firewall (UFW)

```bash
# Installation et configuration de base
sudo apt install ufw

# Règles recommandées
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH (si utilisé)
sudo ufw allow 22/tcp

# HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Glances (si nécessaire)
sudo ufw allow 61208/tcp

# Activer le firewall
sudo ufw enable
```

### 2. Restriction d'accès par IP

Pour limiter l'accès au réseau local uniquement :

```nginx
# Dans nginx
location / {
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    allow 127.0.0.1;
    deny all;
}
```

### 3. VPN pour accès distant

Pour un accès distant sécurisé, utilisez un VPN plutôt que d'exposer l'interface sur Internet.

```bash
# Installation WireGuard (exemple)
sudo apt install wireguard
# Configuration selon votre setup réseau
```

## 📋 Bonnes Pratiques

### 1. Mises à jour régulières

```bash
# Script de mise à jour automatique
cat > /etc/cron.weekly/pi-signage-updates << 'EOF'
#!/bin/bash
# Mise à jour sécurité
apt-get update
apt-get upgrade -y --with-new-pkgs

# Mise à jour yt-dlp
yt-dlp -U

# Redémarrage des services
systemctl restart nginx
systemctl restart php8.2-fpm
EOF

chmod +x /etc/cron.weekly/pi-signage-updates
```

### 2. Sauvegardes

```bash
# Script de sauvegarde
cat > /usr/local/bin/backup-pi-signage << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/pi-signage"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Sauvegarde config
tar -czf "$BACKUP_DIR/config-$DATE.tar.gz" \
    /etc/pi-signage/ \
    /etc/nginx/sites-available/pi-signage \
    /etc/php/8.2/fpm/pool.d/pi-signage.conf

# Sauvegarde web
tar -czf "$BACKUP_DIR/web-$DATE.tar.gz" \
    /var/www/pi-signage/ \
    --exclude=/var/www/pi-signage/temp/*

# Garder seulement 30 jours
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x /usr/local/bin/backup-pi-signage

# Cron quotidien
echo "0 2 * * * root /usr/local/bin/backup-pi-signage" > /etc/cron.d/pi-signage-backup
```

### 3. Monitoring de sécurité

```bash
# Installation d'outils de monitoring
sudo apt install -y logwatch aide

# Configuration AIDE (détection d'intrusion)
sudo aideinit
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Vérification quotidienne
echo "0 5 * * * root /usr/bin/aide --check | mail -s 'AIDE Report' admin@example.com" > /etc/cron.d/aide-check
```

### 4. Journalisation

Tous les événements importants sont journalisés :
- Connexions/Déconnexions
- Téléchargements de vidéos
- Actions d'administration
- Erreurs système

```bash
# Centraliser les logs
cat > /etc/rsyslog.d/30-pi-signage.conf << 'EOF'
# Pi Signage logs
if $programname == 'pi-signage' then /var/log/pi-signage/syslog.log
& stop
EOF

systemctl restart rsyslog
```

## ✅ Checklist de Sécurité

### Installation initiale
- [ ] Mot de passe par défaut changé
- [ ] Permissions fichiers vérifiées
- [ ] Configuration PHP durcie
- [ ] Headers de sécurité nginx configurés

### Configuration réseau
- [ ] HTTPS activé (si applicable)
- [ ] Firewall configuré
- [ ] Accès limité au réseau local (si applicable)
- [ ] SSH sécurisé (clés uniquement)

### Maintenance continue
- [ ] Mises à jour automatiques configurées
- [ ] Sauvegardes automatiques en place
- [ ] Monitoring des logs actif
- [ ] Fail2ban configuré

### Audit régulier
- [ ] Revue des logs mensuelle
- [ ] Test de restauration des sauvegardes
- [ ] Scan de vulnérabilités
- [ ] Mise à jour de la documentation

## 🚨 Réponse aux Incidents

### En cas de compromission suspectée

1. **Isoler le système**
   ```bash
   sudo ufw deny from any
   ```

2. **Préserver les preuves**
   ```bash
   sudo tar -czf /tmp/incident-$(date +%Y%m%d).tar.gz /var/log/
   ```

3. **Analyser les logs**
   ```bash
   grep -r "DELETE\|DROP\|INSERT" /var/log/nginx/
   tail -n 1000 /var/log/pi-signage/*.log
   ```

4. **Réinitialiser si nécessaire**
   - Restaurer depuis une sauvegarde propre
   - Changer tous les mots de passe
   - Mettre à jour tous les composants

## 📞 Support Sécurité

Pour signaler une vulnérabilité :
1. **NE PAS** créer une issue publique
2. Envoyer un email à : security@votre-domaine.com
3. Inclure :
   - Description détaillée
   - Étapes de reproduction
   - Impact potentiel
   - Solution suggérée (si applicable)

---

La sécurité est un processus continu. Restez vigilant et maintenez votre système à jour.