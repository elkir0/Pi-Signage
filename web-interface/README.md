# Pi Signage - Interface Web

Interface web de gestion pour Pi Signage Digital.

## Structure

```
web-interface/
├── public/              # Fichiers accessibles publiquement
│   ├── index.php       # Page de connexion
│   ├── dashboard.php   # Tableau de bord principal
│   ├── videos.php      # Gestion des vidéos
│   ├── settings.php    # Paramètres
│   └── logout.php      # Déconnexion
├── includes/           # Fichiers PHP inclus (non accessibles directement)
│   ├── config.php      # Configuration (généré à l'installation)
│   ├── functions.php   # Fonctions utilitaires
│   ├── auth.php        # Gestion de l'authentification
│   └── security.php    # Fonctions de sécurité
├── api/                # Points d'accès API
│   ├── status.php      # Statut du système
│   ├── videos.php      # Gestion des vidéos
│   ├── control.php     # Contrôle des services
│   └── upload.php      # Upload de vidéos
├── assets/             # Ressources statiques
│   ├── css/           # Styles
│   ├── js/            # Scripts JavaScript
│   └── images/        # Images
├── config/             # Templates de configuration
│   └── config.template.php
└── templates/          # Templates HTML réutilisables
    ├── header.php
    ├── footer.php
    └── navigation.php
```

## Installation

L'interface web est automatiquement déployée par le script d'installation Pi Signage.
Le script:
1. Clone ce répertoire depuis GitHub
2. Configure les permissions appropriées
3. Génère le fichier de configuration avec les mots de passe
4. Configure nginx et PHP-FPM

## Sécurité

- Authentification requise pour toutes les pages sauf la connexion
- Protection CSRF sur tous les formulaires
- Headers de sécurité HTTP
- Validation stricte des entrées
- Permissions restrictives sur les fichiers

## Configuration

Le fichier `includes/config.php` est généré automatiquement lors de l'installation avec:
- Les chemins système
- Les mots de passe hashés
- Les paramètres de connexion aux services

## Développement

Pour tester localement:
```bash
php -S localhost:8000 -t public/
```

## Dépendances

- PHP 8.2+
- Extensions PHP: json, curl, mbstring
- Nginx (en production)
- Accès sudo pour le contrôle des services