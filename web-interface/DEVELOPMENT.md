# 🔧 Guide de Développement - Interface Web

Ce guide détaille comment développer et tester l'interface web de Pi Signage Digital.

## 🚀 Démarrage rapide

### Prérequis

- PHP 8.2+ avec extensions : json, curl, mbstring
- Git
- (Optionnel) Node.js 18+ pour le développement des assets

### Installation locale

```bash
# Cloner le repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/web-interface

# Copier la configuration
cp includes/config.template.php includes/config.php

# Éditer config.php avec vos paramètres
# - Remplacer {{WEB_ADMIN_PASSWORD_HASH}} par un hash généré
# - Ajuster les chemins si nécessaire

# Générer un hash de mot de passe pour les tests
php -r "echo password_hash('votre_mot_de_passe', PASSWORD_DEFAULT) . PHP_EOL;"
```

### Lancer le serveur de développement

```bash
# Depuis le répertoire web-interface
php -S localhost:8000 -t public/

# L'interface est accessible sur http://localhost:8000
```

## 📁 Structure du code

```
web-interface/
├── public/              # Point d'entrée web (DocumentRoot nginx)
│   ├── index.php       # Page de connexion
│   ├── dashboard.php   # Tableau de bord
│   ├── videos.php      # Gestion des vidéos
│   ├── settings.php    # Paramètres
│   └── logout.php      # Déconnexion
│
├── includes/           # Logique métier (non accessible directement)
│   ├── config.php      # Configuration (généré à l'installation)
│   ├── auth.php        # Gestion de l'authentification
│   ├── security.php    # Fonctions de sécurité (CSRF, sanitization)
│   └── functions.php   # Fonctions utilitaires
│
├── api/                # Endpoints API REST
│   ├── status.php      # GET /api/status - État système
│   ├── videos.php      # GET/POST/DELETE /api/videos
│   ├── control.php     # POST /api/control - Contrôle services
│   └── upload.php      # POST /api/upload - Upload vidéos
│
├── assets/             # Ressources statiques
│   ├── css/           # Styles
│   ├── js/            # Scripts client
│   └── images/        # Images et icônes
│
└── templates/          # Templates PHP réutilisables
    ├── header.php      # En-tête commun
    ├── footer.php      # Pied de page
    └── navigation.php  # Barre de navigation
```

## 🔐 Sécurité

### Authentification

Le système utilise une authentification simple mais sécurisée :

```php
// Connexion
if (validateCredentials($username, $password)) {
    loginUser($username);
}

// Protection des pages
requireAuth(); // Redirige vers login si non authentifié

// Déconnexion
logoutUser();
```

### Protection CSRF

Toutes les actions sensibles sont protégées :

```php
// Génération du token (dans les formulaires)
$csrf_token = generateCSRFToken();

// Validation (dans les handlers)
if (!validateCSRFToken($_POST['csrf_token'])) {
    die('CSRF validation failed');
}
```

### Validation des entrées

```php
// Toujours valider et sanitizer
$input = sanitizeInput($_POST['field']);
if (!isValidFilename($filename)) {
    die('Invalid filename');
}
```

## 🛠️ Patterns de développement

### Ajout d'une nouvelle page

1. Créer le fichier dans `public/`
2. Inclure la protection d'authentification
3. Utiliser les templates communs

```php
<?php
define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';

requireAuth();
setSecurityHeaders();

// Votre logique ici
?>
<!DOCTYPE html>
<html>
<head>
    <title>Nouvelle Page - Pi Signage</title>
</head>
<body>
    <?php include '../templates/navigation.php'; ?>
    
    <!-- Contenu -->
    
    <?php include '../templates/footer.php'; ?>
</body>
</html>
```

### Ajout d'un endpoint API

1. Créer le fichier dans `api/`
2. Vérifier l'authentification
3. Valider les entrées
4. Retourner du JSON

```php
<?php
define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';

// Vérifier auth
if (!isAuthenticated()) {
    http_response_code(401);
    exit(json_encode(['error' => 'Unauthorized']));
}

// Headers
setSecurityHeaders();
header('Content-Type: application/json');

// Logique
$data = ['status' => 'ok'];

// Réponse
echo json_encode($data);
```

## 🎨 Styles et JavaScript

### CSS

Les styles sont organisés par composant :

```
assets/css/
├── style.css        # Styles globaux
├── dashboard.css    # Styles du dashboard
├── videos.css       # Styles page vidéos
└── components.css   # Composants réutilisables
```

### JavaScript

Utilisation de vanilla JS pour la légèreté :

```javascript
// Exemple : Contrôle d'un service
async function controlService(action, service) {
    const response = await fetch('/api/control.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            csrf_token: csrfToken,
            action: action,
            service: service
        })
    });
    
    return response.json();
}
```

## 🧪 Tests

### Tests manuels essentiels

1. **Authentification**
   - [ ] Connexion valide
   - [ ] Connexion invalide
   - [ ] Déconnexion
   - [ ] Timeout de session

2. **CSRF**
   - [ ] Formulaires protégés
   - [ ] Requêtes API protégées

3. **Fonctionnalités**
   - [ ] Upload de vidéo
   - [ ] Suppression de vidéo
   - [ ] Contrôle des services
   - [ ] Affichage des stats

### Tests de sécurité

```bash
# Vérifier les headers
curl -I http://localhost:8000/

# Tester l'injection SQL (doit échouer)
curl -X POST http://localhost:8000/api/videos.php \
  -d "id=1' OR '1'='1"

# Tester sans auth (doit retourner 401)
curl http://localhost:8000/api/status.php
```

## 📦 Déploiement

Le déploiement est géré par le script d'installation :

1. Clone le code depuis GitHub
2. Génère `config.php` avec les mots de passe
3. Configure nginx et PHP-FPM
4. Applique les permissions sécurisées

Pour une mise à jour manuelle :

```bash
cd /var/www/pi-signage
sudo -u www-data git pull
# La config est préservée
```

## 🔄 Workflow de développement

1. **Créer une branche**
   ```bash
   git checkout -b feature/ma-fonctionnalite
   ```

2. **Développer et tester localement**
   ```bash
   php -S localhost:8000 -t public/
   ```

3. **Valider le code**
   - Pas de `var_dump()` ou `die()` oubliés
   - Validation des entrées
   - Protection CSRF
   - Headers de sécurité

4. **Commit et push**
   ```bash
   git add .
   git commit -m "feat: ajout de ma fonctionnalité"
   git push origin feature/ma-fonctionnalite
   ```

5. **Pull Request**
   - Description claire
   - Tests effectués
   - Captures d'écran si UI

## 💡 Tips & Tricks

### Debug en développement

```php
// Dans config.php pour le dev local
define('DEBUG_MODE', true);

// Dans le code
if (DEBUG_MODE) {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
}
```

### Simuler l'environnement Pi

```php
// Mock des fonctions système
function checkServiceStatus($service) {
    if (DEBUG_MODE) {
        return ['active' => true, 'status' => 'active'];
    }
    // Code réel...
}
```

### Base de données (futur)

Actuellement, pas de BDD. Si ajout futur :
- SQLite pour la simplicité
- PDO avec prepared statements
- Migrations versionnées

## 🐛 Débogage courant

### "Permission denied"
- Vérifier les permissions des fichiers
- S'assurer que PHP peut écrire dans `temp/`

### "CSRF token invalid"
- Vérifier que les sessions fonctionnent
- Cookie de session présent ?

### "Service control failed"
- Sur le Pi : vérifier sudoers
- En local : utiliser les mocks

## 📚 Ressources

- [PHP The Right Way](https://phptherightway.com/)
- [OWASP PHP Security](https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html)
- [MDN Web Docs](https://developer.mozilla.org/)

---

Pour toute question, ouvrez une issue sur GitHub !