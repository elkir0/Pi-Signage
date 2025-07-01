# Guide de dépannage dpkg pour Pi Signage

## Vue d'ensemble

Les erreurs dpkg sont courantes sur Raspberry Pi, particulièrement après :
- Une interruption pendant une installation
- Une coupure de courant pendant une mise à jour
- Un manque d'espace disque temporaire
- Des conflits de verrouillage entre processus

## Erreurs courantes

### 1. "dpkg was interrupted, you must manually run..."

**Symptômes** :
```
E: dpkg was interrupted, you must manually run 'sudo dpkg --configure -a' to correct the problem.
```

**Solution automatique** :
```bash
cd ~/Pi-Signage/raspberry-pi-installer/scripts
./dpkg-health-check.sh --auto
```

**Solution manuelle** :
```bash
sudo dpkg --configure -a
sudo apt-get update --fix-missing
sudo apt-get install -f
```

### 2. Verrous dpkg bloqués

**Symptômes** :
```
E: Could not get lock /var/lib/dpkg/lock-frontend
E: Unable to acquire the dpkg frontend lock
```

**Solution** :
```bash
# Vérifier les processus bloqués
ps aux | grep -E "dpkg|apt"

# Si aucun processus critique, nettoyer
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock

# Reconfigurer
sudo dpkg --configure -a
```

### 3. Espace disque insuffisant

**Symptômes** :
```
E: No space left on device
```

**Solution** :
```bash
# Vérifier l'espace
df -h

# Nettoyer
sudo apt-get clean
sudo apt-get autoremove -y
sudo rm -rf /var/cache/apt/archives/*.deb
```

## Script de vérification automatique

Le script `dpkg-health-check.sh` vérifie automatiquement :
- Les processus dpkg/apt en cours
- Les verrous actifs
- Les paquets non configurés
- L'intégrité de la base de données dpkg
- L'espace disque disponible

### Utilisation

```bash
# Vérification simple
./dpkg-health-check.sh

# Réparation automatique
./dpkg-health-check.sh --auto
```

## Intégration dans l'installation

Le script principal `main_orchestrator.sh` :
1. Charge les fonctions de sécurité au démarrage
2. Vérifie l'état de dpkg avant toute installation
3. Répare automatiquement si nécessaire
4. Continue l'installation normalement

## Prévention

Pour éviter ces problèmes :

1. **Ne jamais interrompre** une installation ou mise à jour
2. **Utiliser un onduleur** pour les installations critiques
3. **Vérifier l'espace disque** avant installation (minimum 5GB)
4. **Une seule instance** d'apt/dpkg à la fois

## Logs et diagnostic

Les logs d'installation sont dans :
- `/var/log/pi-signage-setup.log` : Log principal d'installation
- `/var/log/dpkg.log` : Log système dpkg
- `/var/log/apt/` : Logs détaillés apt

Pour un diagnostic complet :
```bash
# Voir les dernières erreurs
tail -50 /var/log/pi-signage-setup.log | grep -E "ERROR|dpkg|apt"

# Vérifier l'état détaillé
dpkg --audit
apt-get check
```

## Support

Si les problèmes persistent après réparation automatique :
1. Redémarrer le Raspberry Pi
2. Exécuter `./dpkg-health-check.sh --auto`
3. Si échec, poster les logs sur GitHub Issues