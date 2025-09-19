# API PiSignage

Cette API REST permet de contrôler le système PiSignage à distance.

## Endpoints disponibles

### GET /api/control.php?action=status
Retourne l'état du système d'affichage

### GET /api/control.php?action=player&command={start|stop|restart}
Contrôle le lecteur multimédia

### GET /api/control.php?action=media
Liste tous les fichiers médias disponibles

### POST /api/control.php?action=play&file={filename}
Lance la lecture d'un fichier spécifique

## Format de réponse
Toutes les réponses sont au format JSON avec les champs suivants :
- `success`: boolean - Succès de l'opération
- `message`: string - Message descriptif
- `data`: object - Données supplémentaires (optionnel)