# 🤝 Contribution à Pi-Signage

Merci de votre intérêt pour contribuer à Pi-Signage !

## Comment Contribuer

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## Guidelines

- Testez sur un vrai Raspberry Pi 4
- Documentez vos changements
- Suivez le style de code existant
- Mettez à jour la documentation si nécessaire

## Tests

Avant de soumettre :
```bash
# Tester l'installation
sudo ./install.sh

# Vérifier les performances
/opt/pisignage/scripts/vlc-control.sh benchmark

# Tester l'interface web
curl http://localhost/api/system.php
```

## Rapport de Bugs

Utilisez les issues GitHub avec :
- Description claire du problème
- Étapes pour reproduire
- Version de Pi-Signage
- Modèle de Raspberry Pi
- Logs pertinents
