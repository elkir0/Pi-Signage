# 🤝 Guide de Contribution - Pi Signage Digital

Merci de votre intérêt pour contribuer à Pi Signage Digital ! Ce guide vous aidera à démarrer.

## 📋 Table des matières

1. [Code de conduite](#code-de-conduite)
2. [Comment contribuer](#comment-contribuer)
3. [Environnement de développement](#environnement-de-développement)
4. [Structure du projet](#structure-du-projet)
5. [Standards de code](#standards-de-code)
6. [Process de contribution](#process-de-contribution)
7. [Tests](#tests)

## 📜 Code de conduite

En participant à ce projet, vous acceptez de respecter notre code de conduite :

- **Soyez respectueux** : Traitez tout le monde avec respect
- **Soyez constructif** : Focalisez-vous sur ce qui est meilleur pour la communauté
- **Soyez inclusif** : Accueillez les nouveaux contributeurs
- **Soyez professionnel** : Évitez les attaques personnelles

## 🚀 Comment contribuer

### 1. Signaler des bugs

- Vérifiez que le bug n'a pas déjà été signalé
- Ouvrez une issue avec le template "Bug Report"
- Incluez :
  - Description claire du problème
  - Étapes pour reproduire
  - Comportement attendu vs observé
  - Logs pertinents
  - Version de Pi Signage et modèle de Raspberry Pi

### 2. Proposer des améliorations

- Ouvrez une issue avec le template "Feature Request"
- Décrivez clairement la fonctionnalité
- Expliquez pourquoi elle serait utile
- Proposez une implémentation si possible

### 3. Soumettre du code

- Fork le repository
- Créez une branche descriptive
- Faites vos modifications
- Testez votre code
- Soumettez une Pull Request

## 💻 Environnement de développement

### Prérequis

```bash
# Pour le développement des scripts Bash
- Bash 4.0+
- ShellCheck pour la validation

# Pour l'interface web
- PHP 8.2+
- Composer (optionnel)
- Node.js 18+ (pour les assets)

# Outils recommandés
- Visual Studio Code
- Extensions : Bash IDE, PHP Intelephense
```

### Configuration locale

1. **Cloner le repository**
   ```bash
   git clone https://github.com/elkir0/Pi-Signage.git
   cd Pi-Signage
   ```

2. **Tester l'interface web localement**
   ```bash
   cd web-interface
   php -S localhost:8000 -t public/
   ```

3. **Valider les scripts Bash**
   ```bash
   # Installer ShellCheck
   sudo apt install shellcheck
   
   # Valider un script
   shellcheck raspberry-pi-installer/scripts/*.sh
   ```

## 📁 Structure du projet

```
Pi-Signage/
├── raspberry-pi-installer/      # Scripts d'installation
│   ├── scripts/                # Modules d'installation
│   │   ├── 00-security-utils.sh  # IMPORTANT: Module de sécurité
│   │   ├── 01-system-config.sh
│   │   └── ...
│   ├── docs/                   # Documentation
│   └── install.sh             # Point d'entrée
│
├── web-interface/             # Interface web (PHP)
│   ├── public/               # Fichiers publics
│   ├── includes/             # Logique PHP
│   │   ├── security.php      # IMPORTANT: Fonctions de sécurité
│   │   └── ...
│   ├── api/                  # Endpoints API
│   └── assets/               # CSS, JS, images
│
└── docs/                      # Documentation globale
```

### Fichiers importants

- `00-security-utils.sh` : Ne JAMAIS compromettre la sécurité
- `includes/security.php` : Toute modification doit être revue
- `config.template.php` : Template de configuration

## 📝 Standards de code

### Scripts Bash

```bash
#!/usr/bin/env bash
# =============================================================================
# Nom du module - Description
# Version: X.Y.Z
# =============================================================================

set -euo pipefail  # Toujours utiliser

# Constantes en MAJUSCULES
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fonctions avec documentation
# Description: Fait quelque chose d'utile
# Arguments: $1 - description
# Retour: 0 succès, 1 échec
function_name() {
    local arg1="$1"
    # Code ici
}

# Logging cohérent
log_info "Message"
log_error "Erreur"

# Gestion d'erreurs
if ! command; then
    log_error "Échec de command"
    return 1
fi
```

### Code PHP

```php
<?php
/**
 * Description du fichier
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    die('Direct access not allowed');
}

// Typage strict
declare(strict_types=1);

// Validation des entrées
$input = filter_input(INPUT_POST, 'field', FILTER_SANITIZE_STRING);

// Utiliser les fonctions de sécurité
$sanitized = sanitizeInput($input);
if (!validateCSRFToken($token)) {
    die('CSRF validation failed');
}
```

### Sécurité obligatoire

1. **Jamais de mots de passe en clair**
2. **Toujours valider les entrées**
3. **Permissions restrictives (600/640/750)**
4. **Utiliser les fonctions du module de sécurité**

## 🔄 Process de contribution

### 1. Créer une branche

```bash
# Pour une fonctionnalité
git checkout -b feature/nom-de-la-fonctionnalite

# Pour un bug
git checkout -b fix/description-du-bug

# Pour la documentation
git checkout -b docs/description
```

### 2. Commits

Format des messages de commit :

```
type(scope): description courte

Description détaillée si nécessaire.

Fixes #123
```

Types :
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation
- `style`: Formatage
- `refactor`: Refactoring
- `test`: Tests
- `chore`: Maintenance

### 3. Pull Request

- Titre clair et descriptif
- Description détaillée des changements
- Référencer les issues liées
- S'assurer que tous les tests passent
- Demander une review

Template de PR :

```markdown
## Description
Brève description des changements

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle fonctionnalité
- [ ] Breaking change
- [ ] Documentation

## Checklist
- [ ] Mon code suit les standards du projet
- [ ] J'ai testé mes changements
- [ ] J'ai mis à jour la documentation
- [ ] J'ai vérifié la sécurité

## Tests effectués
Décrire les tests effectués

## Issues liées
Fixes #XXX
```

## 🧪 Tests

### Scripts Bash

```bash
# Test basique
bash -n script.sh  # Vérification syntaxe

# Avec ShellCheck
shellcheck script.sh

# Test d'exécution (sur un Pi de test)
sudo ./script.sh --test
```

### Interface web

```bash
# Tests manuels minimum
1. Connexion/déconnexion
2. Upload de vidéo
3. Contrôle des services
4. Vérification CSRF
```

### Checklist sécurité

Avant chaque PR :

- [ ] Pas de mots de passe en clair
- [ ] Permissions fichiers correctes
- [ ] Validation des entrées
- [ ] Pas de fonctions PHP dangereuses
- [ ] Headers de sécurité présents

## 🎯 Domaines prioritaires

Nous recherchons particulièrement de l'aide pour :

1. **🔐 Sécurité** : Audit et améliorations
2. **🌍 Internationalisation** : Traductions
3. **📱 Interface responsive** : Support mobile
4. **🧪 Tests automatisés** : Framework de tests
5. **📚 Documentation** : Tutoriels et guides

## 💬 Communication

- **Issues GitHub** : Pour les bugs et fonctionnalités
- **Discussions** : Pour les questions générales
- **Pull Requests** : Pour les contributions de code

## 🙏 Remerciements

Chaque contribution compte ! Que ce soit :
- 🐛 Signaler un bug
- 📝 Améliorer la documentation
- 💻 Écrire du code
- 💡 Proposer des idées
- 👥 Aider d'autres utilisateurs

Merci de rendre Pi Signage Digital meilleur ! 🚀