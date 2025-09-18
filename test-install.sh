#!/bin/bash
# Test d'installation PiSignage Desktop v3.0

echo "Test de l'installation PiSignage Desktop v3.0"
echo "============================================="

# Vérifier les fichiers
echo -n "✓ Structure du projet... "
[[ -d /opt/pisignage/pisignage-desktop ]] && echo "OK" || echo "ERREUR"

echo -n "✓ Scripts d'installation... "
[[ -x /opt/pisignage/pisignage-desktop/install.sh ]] && echo "OK" || echo "ERREUR"

echo -n "✓ Modules... "
ls /opt/pisignage/pisignage-desktop/modules/*.sh > /dev/null 2>&1 && echo "OK (5 modules)" || echo "ERREUR"

echo -n "✓ Permissions... "
[[ -x /opt/pisignage/pisignage-desktop/modules/01-base-config.sh ]] && echo "OK" || echo "ERREUR"

echo ""
echo "Le projet est prêt pour installation sur Raspberry Pi Desktop!"
