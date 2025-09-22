# =� Contexte Actif - PiSignage v0.8.0

## = �tat actuel (22/09/2025 - 15:25)

### Environnement de travail
- **Machine actuelle** : VM de d�veloppement Linux
- **R�pertoire de travail** : `/opt/pisignage`
- **Version active** : v0.8.0 (SEULE VERSION OFFICIELLE)
- **Plateforme** : Linux 6.12.43+deb13-amd64

### �tat du d�ploiement
-  **Local** : v0.8.0 compl�te dans `/opt/pisignage`
-  **GitHub** : UNIQUEMENT v0.8.0 (force pushed, nettoy�)
- � **Production (192.168.1.103)** : En attente de d�ploiement

### Derni�res actions effectu�es
1. **Rollback complet** de toutes versions > v0.8.0
2. **Nettoyage GitHub** : Suppression totale + force push v0.8.0
3. **Validation locale** : 50 occurrences v0.8.0 confirm�es
4. **Scripts pr�ts** : D�ploiement automatis� disponible

## <� Focus actuel

### Migration en cours
- **ACTUELLEMENT** : Migration du syst�me de m�moire vers architecture multi-fichiers MCP
- **Cr�ation** : Structure `.claude/memory-bank/` avec fichiers contextuels s�par�s
- **Objectif** : Am�liorer la persistance et l'organisation de la m�moire du projet

### Prochaine action imm�diate
- � Finir cr�ation des fichiers de contexte (progress.md)
- � Ajouter pattern r�cursif en haut de CLAUDE.md
- � Cr�er script de synchronisation
- � Initialiser MCP memory

## =' Probl�mes connus � r�soudre

### Production
1. **Cache nginx persistant** sur Raspberry Pi
   - Solution : Vider avec `sudo rm -rf /var/cache/nginx/*`

2. **Version incorrecte affich�e**
   - Cause : Anciens fichiers non supprim�s
   - Solution : D�ploiement complet v0.8.0

### Technique
1. **Upload limit�** dans certaines configurations
   - Workaround : Utiliser SCP pour gros fichiers

2. **YouTube download** peut �chouer
   - Solution : V�rifier yt-dlp � jour

## =� D�cisions r�centes

### Architecture
-  **Choix PHP** : Abandonn� Next.js pour PHP stable
-  **Version unique** : v0.8.0 seule version maintenue
-  **GitHub propre** : Une seule branche, un seul tag

### Process
-  **Automatisation** : Je fais tout, pas l'utilisateur
-  **Tests syst�matiques** : 2 Puppeteer minimum
-  **Documentation continue** : CLAUDE.md toujours � jour

## =� Commandes pr�tes � l'emploi

### D�ploiement imm�diat
```bash
# Option 1 : Script tout-en-un
/opt/pisignage/deploy-v080-to-production.sh

# Option 2 : Commandes manuelles
sshpass -p 'raspberry' rsync -avz --delete /opt/pisignage/ pi@192.168.1.103:/opt/pisignage/
sshpass -p 'raspberry' ssh pi@192.168.1.103 'sudo systemctl restart nginx php8.2-fpm'
```

### V�rification rapide
```bash
# Check version locale
cat /opt/pisignage/VERSION

# Check version production
sshpass -p 'raspberry' ssh pi@192.168.1.103 'cat /opt/pisignage/VERSION'

# Test API production
curl -s http://192.168.1.103/api/system.php | jq .version
```

## <� Historique de la session actuelle

### Ce qui a �t� tent� aujourd'hui
1. **Matin** : �chec Next.js v2.0.1
2. **13h** : Migration PHP v0.8.0
3. **14h** : Tentative rollback v0.9.4
4. **14h45** : VRAI rollback � renommage v0.8.0
5. **15h15** : Nettoyage GitHub total
6. **15h25** : �tat stable v0.8.0 pr�t
7. **MAINTENANT** : Migration syst�me m�moire vers MCP

### Le�ons apprises
- Cache nginx = ennemi principal
- Tests Puppeteer peuvent mentir
- Force push = seule solution propre
- v0.8.0 = version d�finitive

## =� Notes pour la prochaine session

### � faire en priorit�
1. Finir migration m�moire MCP
2. D�ployer v0.8.0 sur Pi
3. Valider avec 2 tests Puppeteer
4. Confirmer succ�s � l'utilisateur

### � ne pas oublier
- IP correcte : 192.168.1.103
- Vider cache avant tests
- Je fais tout moi-m�me
- Documenter dans CLAUDE.md

## = Acc�s et credentials

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
  VLC: Contr�le par scripts
```

---
*Contexte actif mis � jour : 22/09/2025 - Session de migration m�moire MCP*