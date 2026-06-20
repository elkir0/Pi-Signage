# PiSignage - Système d'Authentification

## Identifiants par Défaut

**IMPORTANT**: Changez ces identifiants après la première installation!

```
Utilisateur: admin
Mot de passe: signage2025
```

## Première Connexion

1. Accédez à l'interface web: `http://[IP_DU_PI]/`
2. Vous serez redirigé vers la page de connexion
3. Utilisez les identifiants par défaut ci-dessus
4. **Changez immédiatement le mot de passe** dans Paramètres > Sécurité

## Changer le Mot de Passe

1. Connectez-vous à l'interface
2. Allez dans **Paramètres** (⚙️)
3. Section **Sécurité** (🔒)
4. Remplissez le formulaire:
   - Ancien mot de passe
   - Nouveau mot de passe (minimum 6 caractères)
   - Confirmer le nouveau mot de passe
5. Cliquez sur **Changer le mot de passe**

## Déconnexion

- Utilisez le bouton **Déconnexion** (🚪) dans le menu de navigation
- Ou allez directement sur `/login.php?logout=1`

## Sécurité

### Fichier de Credentials

Les credentials sont stockés dans:
```
/opt/pisignage/config/credentials.json
```

**Permissions**: `-rw------- (600)` - Lecture/Écriture pour www-data uniquement

**Format**:
```json
{
    "username": "admin",
    "password": "$2y$10$..."  // Hash bcrypt
}
```

### Hash du Mot de Passe

- Algorithme: **bcrypt** (PASSWORD_BCRYPT)
- Aucun mot de passe en clair n'est stocké
- Utilise `password_hash()` et `password_verify()` de PHP

## Réinitialisation du Mot de Passe

Si vous avez oublié le mot de passe, connectez-vous en SSH au Raspberry Pi:

```bash
ssh pi@[IP_DU_PI]
sudo rm /opt/pisignage/config/credentials.json
sudo systemctl restart nginx
```

Le fichier sera recréé avec les identifiants par défaut au prochain accès.

## Sessions

- Les sessions utilisent le système PHP natif
- Durée de vie: Configuration PHP par défaut (généralement 24 minutes d'inactivité)
- Cookie de session: `PHPSESSID`

## API et Authentification

Toutes les pages et API endpoints vérifient l'authentification sauf:
- `/login.php`
- Ressources statiques (CSS, JS, images)

**API Endpoints Protégés** (tous nécessitent authentification):
- `/api/system.php` - Informations système
- `/api/player.php` - Contrôle lecteur VLC
- `/api/media.php` - Gestion médias
- `/api/playlist-simple.php` - Gestion playlists
- `/api/screenshot.php` - Captures d'écran
- `/api/youtube.php` - Téléchargement YouTube
- `/api/logs.php` - Logs système
- `/api/scheduler.php` - Planification
- `/api/kiosk.php` - Mode kiosk (Trixie uniquement)

Exemple de vérification dans une page:
```php
<?php
require_once 'includes/auth.php';
requireAuth(); // Redirige vers login si non authentifié
?>
```

## Développement

### Fonctions Disponibles (includes/auth.php)

```php
// Vérifier si l'utilisateur est authentifié
if (isAuthenticated()) {
    // Utilisateur connecté
}

// Forcer l'authentification (redirection automatique)
requireAuth();

// Vérifier les credentials
if (verifyLogin($username, $password)) {
    // Login réussi
}

// Changer le mot de passe
$result = updatePassword($oldPassword, $newPassword);

// Déconnexion
logout();
```

### Ajouter une Page Protégée

```php
<?php
require_once 'includes/auth.php';
requireAuth(); // Cette ligne protège la page
include 'includes/header.php';
?>

<!-- Votre contenu ici -->

<?php include 'includes/footer.php'; ?>
```

## Troubleshooting

### "Authentication required" dans l'API

Vérifiez que la session est bien démarrée et que le cookie PHPSESSID est envoyé.

### Redirection infinie vers /login.php

1. Vérifiez les permissions de `/opt/pisignage/config/`
2. Vérifiez que credentials.json existe et est lisible par www-data
3. Vérifiez les logs PHP: `sudo tail -f /var/log/nginx/error.log`

### Mot de passe refusé après changement

Le fichier credentials.json peut être corrompu. Supprimez-le et reconnectez-vous avec les identifiants par défaut.

---

**Dernière mise à jour**: 2025-11-09
**Version PiSignage**: 0.8.9
