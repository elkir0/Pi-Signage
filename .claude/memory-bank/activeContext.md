# =Í Contexte Actif - PiSignage v0.8.0

## = État actuel (22/09/2025 - 15:25)

### Environnement de travail
- **Machine actuelle** : VM de développement Linux
- **Répertoire de travail** : `/opt/pisignage`
- **Version active** : v0.8.0 (SEULE VERSION OFFICIELLE)
- **Plateforme** : Linux 6.12.43+deb13-amd64

### État du déploiement
-  **Local** : v0.8.0 complète dans `/opt/pisignage`
-  **GitHub** : UNIQUEMENT v0.8.0 (force pushed, nettoyé)
- ó **Production (192.168.1.103)** : En attente de déploiement

### Dernières actions effectuées
1. **Rollback complet** de toutes versions > v0.8.0
2. **Nettoyage GitHub** : Suppression totale + force push v0.8.0
3. **Validation locale** : 50 occurrences v0.8.0 confirmées
4. **Scripts prêts** : Déploiement automatisé disponible

## <¯ Focus actuel

### Migration en cours
- **ACTUELLEMENT** : Migration du système de mémoire vers architecture multi-fichiers MCP
- **Création** : Structure `.claude/memory-bank/` avec fichiers contextuels séparés
- **Objectif** : Améliorer la persistance et l'organisation de la mémoire du projet

### Prochaine action immédiate
- ó Finir création des fichiers de contexte (progress.md)
- ó Ajouter pattern récursif en haut de CLAUDE.md
- ó Créer script de synchronisation
- ó Initialiser MCP memory

## =' Problèmes connus à résoudre

### Production
1. **Cache nginx persistant** sur Raspberry Pi
   - Solution : Vider avec `sudo rm -rf /var/cache/nginx/*`

2. **Version incorrecte affichée**
   - Cause : Anciens fichiers non supprimés
   - Solution : Déploiement complet v0.8.0

### Technique
1. **Upload limité** dans certaines configurations
   - Workaround : Utiliser SCP pour gros fichiers

2. **YouTube download** peut échouer
   - Solution : Vérifier yt-dlp à jour

## =Ê Décisions récentes

### Architecture
-  **Choix PHP** : Abandonné Next.js pour PHP stable
-  **Version unique** : v0.8.0 seule version maintenue
-  **GitHub propre** : Une seule branche, un seul tag

### Process
-  **Automatisation** : Je fais tout, pas l'utilisateur
-  **Tests systématiques** : 2 Puppeteer minimum
-  **Documentation continue** : CLAUDE.md toujours à jour

## =€ Commandes prêtes à l'emploi

### Déploiement immédiat
```bash
# Option 1 : Script tout-en-un
/opt/pisignage/deploy-v080-to-production.sh

# Option 2 : Commandes manuelles
sshpass -p 'raspberry' rsync -avz --delete /opt/pisignage/ pi@192.168.1.103:/opt/pisignage/
sshpass -p 'raspberry' ssh pi@192.168.1.103 'sudo systemctl restart nginx php8.2-fpm'
```

### Vérification rapide
```bash
# Check version locale
cat /opt/pisignage/VERSION

# Check version production
sshpass -p 'raspberry' ssh pi@192.168.1.103 'cat /opt/pisignage/VERSION'

# Test API production
curl -s http://192.168.1.103/api/system.php | jq .version
```

## <¬ Historique de la session actuelle

### Ce qui a été tenté aujourd'hui
1. **Matin** : Échec Next.js v2.0.1
2. **13h** : Migration PHP v0.8.0
3. **14h** : Tentative rollback v0.9.4
4. **14h45** : VRAI rollback ’ renommage v0.8.0
5. **15h15** : Nettoyage GitHub total
6. **15h25** : État stable v0.8.0 prêt
7. **MAINTENANT** : Migration système mémoire vers MCP

### Leçons apprises
- Cache nginx = ennemi principal
- Tests Puppeteer peuvent mentir
- Force push = seule solution propre
- v0.8.0 = version définitive

## =Ý Notes pour la prochaine session

### À faire en priorité
1. Finir migration mémoire MCP
2. Déployer v0.8.0 sur Pi
3. Valider avec 2 tests Puppeteer
4. Confirmer succès à l'utilisateur

### À ne pas oublier
- IP correcte : 192.168.1.103
- Vider cache avant tests
- Je fais tout moi-même
- Documenter dans CLAUDE.md

## = Accès et credentials

```yaml
Production:
  IP: 192.168.1.103
  User: pi
  Password: raspberry

GitHub:
  Repo: https://github.com/elkir0/Pi-Signage
  Branch: main
  Tag: v0.8.0

Services:
  Nginx: Port 80
  PHP: 8.2-fpm
  VLC: Contrôle par scripts
```

---
*Contexte actif mis à jour : 22/09/2025 - Session de migration mémoire MCP*