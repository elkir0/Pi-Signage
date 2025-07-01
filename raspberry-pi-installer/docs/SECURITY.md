# 🔐 Guide de Sécurité - Pi Signage Digital v2.4.0

Ce document détaille les mesures de sécurité implémentées dans Pi Signage Digital v2.4.0 et les bonnes pratiques à suivre.

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Module de sécurité centralisé](#module-de-sécurité-centralisé)
3. [Chiffrement des données](#chiffrement-des-données)
4. [Gestion des permissions](#gestion-des-permissions)
5. [Sécurité de l'interface web](#sécurité-de-linterface-web)
6. [Bonnes pratiques](#bonnes-pratiques)
7. [Audit et monitoring](#audit-et-monitoring)

## 🎯 Vue d'ensemble

Pi Signage Digital v2.4.0 intègre une architecture de sécurité multicouche :

- **Chiffrement** : AES-256-CBC pour les mots de passe stockés
- **Hachage** : SHA-512 avec salt pour l'authentification
- **Permissions** : Modèle restrictif (600/640/750)
- **Validation** : Entrées strictement validées
- **Journalisation** : Audit complet des événements de sécurité

## 🛡️ Module de sécurité centralisé

Le fichier `00-security-utils.sh` fournit des fonctions de sécurité réutilisables :

### Fonctions principales

```bash
# Chiffrement/déchiffrement de mot de passe
encrypt_password "mon_mot_de_passe"
decrypt_password "$PASSWORD_ENCRYPTED"

# Hachage de mot de passe
hash_password "mot_de_passe_utilisateur"

# Permissions sécurisées
secure_file_permissions "/path/to/file" "owner" "group" "600"
secure_dir_permissions "/path/to/dir" "owner" "group" "750"

# Exécution sécurisée avec retry
safe_execute "commande" 3 10  # 3 essais, 10s entre chaque

# Validation des entrées
validate_username "john_doe"
validate_path "/opt/videos"
```

### Architecture

```
┌─────────────────────────────────────┐
│      Module de Sécurité Central     │
│        (00-security-utils.sh)       │
├─────────────────────────────────────┤
│ • Chiffrement AES-256-CBC           │
│ • Hachage SHA-512 + Salt            │
│ • Gestion des permissions           │
│ • Validation des entrées            │
│ • Journalisation de sécurité        │
└─────────────────────────────────────┘
            ↓ Utilisé par ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Script 01    │ │ Script 02    │ │ Script 03    │
│ Config sys.  │ │ Display mgr  │ │ VLC setup    │
└──────────────┘ └──────────────┘ └──────────────┘
```

## 🔐 Chiffrement des données

### Mots de passe système

Les mots de passe sont chiffrés avec AES-256-CBC :

```bash
# Chiffrement
ENCRYPTED=$(encrypt_password "MonMotDePasse123!")

# Stockage sécurisé dans /etc/pi-signage/config.conf
GLANCES_PASSWORD_ENCRYPTED="$ENCRYPTED"
```

### Clé de chiffrement

- Générée automatiquement à l'installation
- Stockée dans `/etc/pi-signage/.encryption.key`
- Permissions : 600 (root uniquement)
- Unique par installation

### Mots de passe web

L'interface web utilise SHA-512 avec salt pour harmonisation avec bash :

```php
// Format : salt:hash
define('ADMIN_PASSWORD_HASH', 'a1b2c3d4:e5f6g7h8i9j0...');

// Vérification
$stored_parts = explode(':', ADMIN_PASSWORD_HASH, 2);
$salt = $stored_parts[0];
$stored_hash = $stored_parts[1];
$input_hash = hash('sha512', $salt . $password);
if (hash_equals($stored_hash, $input_hash)) {
    // Authentifié
}
```

## 🔒 Gestion des permissions

### Hiérarchie des permissions

| Type | Permissions | Usage |
|------|-------------|-------|
| Config sensible | 600 | Fichiers de configuration avec mots de passe |
| Config normale | 640 | Fichiers de configuration standards |
| Scripts root | 700 | Scripts exécutables par root uniquement |
| Répertoires système | 750 | Répertoires avec accès restreint |
| Web files | 640 | Fichiers PHP (www-data:www-data) |

### Exemples pratiques

```bash
# Configuration avec mot de passe
/etc/pi-signage/config.conf         # 600 root:root
/etc/pi-signage/.encryption.key     # 600 root:root

# Scripts système
/opt/scripts/vlc-signage.sh         # 750 root:root
/opt/scripts/backup-restore.sh      # 700 root:root

# Interface web
/var/www/pi-signage/includes/       # 750 www-data:www-data
/var/www/pi-signage/includes/config.php # 640 www-data:www-data
```

## 🌐 Sécurité de l'interface web

### Protection contre les attaques

1. **CSRF (Cross-Site Request Forgery)**
   ```php
   // Génération du token
   $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
   
   // Validation
   if (!hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
       die('CSRF token validation failed');
   }
   ```

2. **Headers de sécurité HTTP**
   ```php
   header('X-Content-Type-Options: nosniff');
   header('X-Frame-Options: DENY');
   header('X-XSS-Protection: 1; mode=block');
   header('Content-Security-Policy: default-src \'self\'');
   ```

3. **Rate limiting**
   ```php
   // Maximum 5 tentatives de connexion par 5 minutes
   if (!checkRateLimit('login_' . $ip, 5, 300)) {
       die('Too many login attempts');
   }
   ```

### Configuration PHP sécurisée

```ini
; Désactivation des fonctions dangereuses
; Note: exec n'est plus désactivé pour permettre yt-dlp
disable_functions = passthru,system,proc_open,popen,eval

; Protection des sessions
session.cookie_httponly = 1
session.use_only_cookies = 1
session.cookie_samesite = Strict

; Masquage des informations
expose_php = Off
display_errors = Off
```

### Authentification

- Utilisateur unique : `admin`
- Mot de passe hashé avec SHA-512 + salt
- Session régénérée après connexion
- Timeout de session : 30 minutes
- Vérification de l'IP (optionnel)
- Protection CSRF sur tous les formulaires

## 📝 Bonnes pratiques

### Lors de l'installation

1. **Choisir des mots de passe forts**
   - Minimum 8 caractères pour l'interface web
   - Minimum 6 caractères pour Glances
   - Utiliser des caractères variés
   - Éviter les mots de dictionnaire

2. **Limiter l'accès réseau**
   ```bash
   # Firewall UFW (si installé)
   sudo ufw allow from 192.168.1.0/24 to any port 80      # Interface web
   sudo ufw allow from 192.168.1.0/24 to any port 61208   # Glances
   sudo ufw allow from 192.168.1.0/24 to any port 8888    # Player Chromium
   sudo ufw deny 8889  # WebSocket local uniquement
   ```

3. **Sauvegarder la clé de chiffrement**
   ```bash
   sudo cp /etc/pi-signage/.encryption.key /media/usb/backup/
   ```

### En production

1. **Mises à jour régulières**
   ```bash
   # Système
   sudo apt update && sudo apt upgrade
   
   # Pi Signage
   sudo /opt/scripts/update-web-interface.sh        # --full pour reinitialiser
   ```

2. **Monitoring des logs**
   ```bash
   # Logs de sécurité
   sudo tail -f /var/log/pi-signage/security.log
   
   # Logs d'accès web
   sudo tail -f /var/log/nginx/pi-signage-access.log
   ```

3. **Rotation des mots de passe**
   ```bash
   # Glances
   sudo /opt/scripts/glances-password.sh
   
   # Interface web
   sudo /opt/scripts/util-change-web-password.sh
   ```

## 📊 Audit et monitoring

### Événements journalisés

Le système journalise automatiquement :

- Tentatives de connexion (succès/échec)
- Modifications de configuration
- Opérations sensibles (redémarrage services, etc.)
- Erreurs de sécurité

### Format des logs

```
[2024-01-20 15:30:45] SECURITY [LOGIN_SUCCESS] IP:192.168.1.100 User:admin
[2024-01-20 15:31:02] SECURITY [SERVICE_RESTART] Service:vlc-signage User:admin
[2024-01-20 15:45:23] SECURITY [CONFIG_MODIFIED] File:/etc/pi-signage/config.conf
[2024-01-20 15:50:12] SECURITY [YOUTUBE_DOWNLOAD] URL:youtube.com/watch?v=... User:admin
[2024-01-20 15:55:30] SECURITY [PLAYLIST_UPDATED] Action:reorder User:admin
```

### Commandes d'audit

```bash
# Vérifier les permissions
sudo pi-signage-diag --security

# Analyser les tentatives de connexion
grep "LOGIN_FAILED" /var/log/pi-signage/security.log | tail -20

# Vérifier l'intégrité des fichiers
sudo find /opt/scripts -type f -exec sha256sum {} \; > checksums.txt
```

## 🚨 En cas de compromission

1. **Isoler le système**
   ```bash
   sudo systemctl stop nginx
   sudo systemctl stop glances
   ```

2. **Analyser les logs**
   ```bash
   sudo grep -E "(LOGIN_|SECURITY_)" /var/log/pi-signage/*.log
   ```

3. **Réinitialiser les mots de passe**
   ```bash
   # Régénérer la clé de chiffrement
   sudo rm /etc/pi-signage/.encryption.key
   sudo /opt/scripts/00-security-utils.sh --regenerate-key
   ```

4. **Restaurer depuis une sauvegarde**
   ```bash
   sudo /opt/scripts/backup-restore.sh restore
   ```

## 🔍 Vérifications de sécurité

### Check-list post-installation

- [ ] Tous les mots de passe sont forts
- [ ] Les permissions des fichiers sont correctes
- [ ] L'interface web est accessible uniquement en interne
- [ ] Les services inutiles sont désactivés
- [ ] Les logs sont actifs et accessibles
- [ ] Une sauvegarde de la clé de chiffrement existe
- [ ] Le wrapper yt-dlp a les bonnes permissions (755)
- [ ] L'audio est configuré si nécessaire

### Script de vérification

```bash
#!/bin/bash
# Vérifier la sécurité de l'installation

echo "=== Vérification de sécurité Pi Signage ==="

# Permissions
echo -n "Permissions config.conf: "
stat -c %a /etc/pi-signage/config.conf

echo -n "Permissions clé de chiffrement: "
stat -c %a /etc/pi-signage/.encryption.key

# Services
echo -n "Service SSH: "
systemctl is-active ssh || echo "Désactivé (OK)"

# Ports ouverts
echo "Ports en écoute:"
sudo netstat -tlnp | grep -E "(80|61208|8080)"
```

## 📄 Sécurité spécifique v2.4.0

### Wrapper yt-dlp

Le wrapper `/usr/local/bin/yt-dlp` permet l'exécution contrôlée :

```bash
#!/bin/bash
# Wrapper sécurisé pour yt-dlp
# Limite les options et force le format MP4

exec /usr/local/bin/yt-dlp \
    --format "best[ext=mp4]/best" \
    --merge-output-format mp4 \
    "$@"
```

### Configuration audio

Le script `util-configure-audio.sh` modifie les paramètres système :
- Vérification des droits root
- Validation des entrées (sortie 1 ou 2)
- Journalisation des changements

## 📚 Ressources supplémentaires

- [OWASP Security Guidelines](https://owasp.org/)
- [Raspberry Pi Security Guide](https://www.raspberrypi.org/documentation/configuration/security.md)
- [PHP Security Best Practices](https://www.php.net/manual/en/security.php)

---

**Note** : Ce guide est maintenu à jour avec chaque version. Pour des questions de sécurité spécifiques, ouvrez une issue privée sur GitHub.