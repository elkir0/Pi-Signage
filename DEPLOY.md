# Guide de Déploiement - PiSignage v0.8.9

## 🎯 Déploiement Rapide

### Prérequis

- Raspberry Pi accessible sur le réseau (actuellement: `192.168.1.105`)
- Accès SSH configuré (utilisateur `pi`, mot de passe `raspberry`)
- Git installé sur le Pi
- nginx et PHP configurés

### Étape 1: Configuration SSH (une fois)

```bash
# Depuis votre machine de développement:
ssh-copy-id pi@192.168.1.105
# Entrez le mot de passe: raspberry
```

### Étape 2: Déploiement Automatique

```bash
# Lancez le script de déploiement:
./deploy-to-pi.sh
```

Le script effectue automatiquement:
1. ✅ Connexion au Raspberry Pi
2. ✅ Synchronisation Git (`git pull origin main`)
3. ✅ Vérification des fichiers
4. ✅ Configuration des permissions
5. ✅ Rechargement nginx

### Étape 3: Vérification

Accédez au module Scheduler:
```
http://192.168.1.105/schedule.php
```

---

## 🔧 Déploiement Manuel

Si le script automatique ne fonctionne pas:

### 1. Connexion SSH

```bash
ssh pi@192.168.1.105
```

### 2. Mise à jour code

```bash
cd /opt/pisignage
git pull origin main
```

### 3. Vérification fichiers

```bash
ls -lh web/api/schedule.php
ls -lh web/schedule.php
ls -lh web/assets/js/schedule.js
ls -lh web/assets/css/components.css
```

### 4. Permissions data/

```bash
sudo chown -R www-data:www-data /opt/pisignage/data
sudo chmod 666 /opt/pisignage/data/schedules.json
```

### 5. Rechargement nginx

```bash
sudo systemctl reload nginx
```

---

## 🧪 Tests Post-Déploiement

### Test 1: Accès Interface

```bash
curl -I http://192.168.1.105/schedule.php
# Attendu: HTTP/1.1 200 OK
```

### Test 2: API Schedule

```bash
# Liste plannings (vide au départ):
curl http://192.168.1.105/api/schedule.php

# Attendu:
# {"success":true,"data":[],"count":0,"timestamp":"..."}
```

### Test 3: Tests Puppeteer

```bash
ssh pi@192.168.1.105
cd /opt/pisignage/tests
BASE_URL=http://localhost node schedule-test.js
```

Attendu: 25/25 tests passés ✅

---

## 📊 Vérification Module Scheduler

### Checklist Fonctionnalités:

Accédez à `http://192.168.1.105/schedule.php` et vérifiez:

- [ ] ✅ Page charge sans erreurs console
- [ ] ✅ Statistiques visibles (Actifs, Inactifs, En cours, À venir)
- [ ] ✅ Sélecteur de vue (Liste, Calendrier, Chronologie)
- [ ] ✅ État vide affiché si aucun planning
- [ ] ✅ Bouton "Nouveau Planning" ouvre modal
- [ ] ✅ Modal a 4 onglets (Général, Horaires, Récurrence, Avancé)
- [ ] ✅ Dropdown playlists chargé dynamiquement
- [ ] ✅ Sélecteur jours visuel fonctionne
- [ ] ✅ Sauvegarde planning fonctionne
- [ ] ✅ Planning apparaît dans la liste
- [ ] ✅ Toggle enable/disable fonctionne
- [ ] ✅ Édition planning fonctionne
- [ ] ✅ Duplication fonctionne
- [ ] ✅ Suppression avec confirmation fonctionne
- [ ] ✅ Détection conflits fonctionne

### Test Complet Création Planning:

1. Cliquer "➕ Nouveau Planning"
2. **Général**:
   - Nom: "Test Planning"
   - Playlist: Sélectionner une playlist
   - Description: "Test déploiement"
3. **Horaires**:
   - Début: 08:00
   - Fin: 17:00
4. **Récurrence**:
   - Type: Hebdomadaire
   - Jours: Lun, Mar, Mer, Jeu, Ven
5. **Avancé**:
   - Priorité: Normale
6. Cliquer "💾 Sauvegarder"
7. Vérifier le planning apparaît dans la liste

### Vérification Backend:

```bash
ssh pi@192.168.1.105
cat /opt/pisignage/data/schedules.json
```

Devrait afficher le planning créé en JSON.

---

## 🐛 Dépannage

### Problème: Page 404

```bash
# Vérifier nginx:
ssh pi@192.168.1.105 "sudo systemctl status nginx"

# Vérifier fichiers:
ssh pi@192.168.1.105 "ls -l /opt/pisignage/web/schedule.php"
```

### Problème: API retourne 500

```bash
# Vérifier logs PHP:
ssh pi@192.168.1.105 "sudo tail -50 /var/log/nginx/error.log"

# Vérifier permissions:
ssh pi@192.168.1.105 "ls -ld /opt/pisignage/data /opt/pisignage/data/schedules.json"
```

### Problème: Modal ne s'ouvre pas

Ouvrir console navigateur (F12) et chercher erreurs JavaScript.

Vérifier que `schedule.js` est bien chargé:
```
http://192.168.1.105/assets/js/schedule.js
```

### Problème: Playlists non chargées

Vérifier API playlists:
```bash
curl http://192.168.1.105/api/playlists.php
```

### Problème: Plannings non sauvegardés

1. Vérifier permissions fichier JSON:
```bash
ssh pi@192.168.1.105 "sudo chmod 666 /opt/pisignage/data/schedules.json"
```

2. Vérifier propriétaire:
```bash
ssh pi@192.168.1.105 "sudo chown www-data:www-data /opt/pisignage/data/schedules.json"
```

---

## 📋 Checklist Déploiement Production

### Avant déploiement:

- [ ] ✅ Code testé localement
- [ ] ✅ Tests Puppeteer passent 100%
- [ ] ✅ Git commit avec message descriptif
- [ ] ✅ Git push origin main
- [ ] ✅ ROADMAP.md mis à jour
- [ ] ✅ Documentation complète

### Pendant déploiement:

- [ ] ✅ Connexion SSH établie
- [ ] ✅ Git pull réussi
- [ ] ✅ Fichiers vérifiés présents
- [ ] ✅ Permissions configurées
- [ ] ✅ nginx rechargé sans erreurs

### Après déploiement:

- [ ] ✅ Page accessible (200 OK)
- [ ] ✅ API fonctionne
- [ ] ✅ Tests Puppeteer passent sur Pi
- [ ] ✅ Tests manuels UI/UX OK
- [ ] ✅ Aucune erreur console
- [ ] ✅ Logs nginx propres

---

## 🔄 Mise à Jour

Pour déployer des modifications futures:

```bash
# 1. Sur machine dev:
git add .
git commit -m "Description changements"
git push origin main

# 2. Déployer:
./deploy-to-pi.sh

# 3. Tester:
# Accéder http://192.168.1.105/schedule.php
```

---

## 📞 Support

En cas de problème:

1. **Vérifier logs**:
   - nginx: `/var/log/nginx/error.log`
   - Application: Console navigateur (F12)

2. **Tester API manuellement**:
   ```bash
   curl -v http://192.168.1.105/api/schedule.php
   ```

3. **Redémarrer services si nécessaire**:
   ```bash
   ssh pi@192.168.1.105 "sudo systemctl restart nginx"
   ```

---

## 📊 Architecture Déployée

```
Raspberry Pi (192.168.1.105)
└── /opt/pisignage/
    ├── web/
    │   ├── schedule.php                 (Interface UI)
    │   ├── api/
    │   │   └── schedule.php             (API REST)
    │   └── assets/
    │       ├── js/
    │       │   └── schedule.js          (Frontend logic)
    │       └── css/
    │           └── components.css       (Styles)
    ├── data/
    │   └── schedules.json               (Stockage)
    └── tests/
        └── schedule-test.js             (Tests Puppeteer)
```

---

## ✅ État Actuel

- **Version**: PiSignage v0.8.9
- **Architecture**: VLC-Exclusive, Modular MPA
- **Modules**: 9/9 implémentés et testés (100%)
- **Authentication**: Activée sur toutes les pages
- **Git**: Synchronisé avec GitHub (elkir0/Pi-Signage)
- **IP Production**: 192.168.1.105
- **Statut**: PRODUCTION-READY ✅

---

**Document créé**: 30 Septembre 2025
**Dernière mise à jour**: 1 Octobre 2025 (v0.8.9)
