#!/bin/sh
# Zaforge — re-déclenche la détection EDID/HPD des connecteurs HDMI (ROOT requis).
#
# POURQUOI ROOT : écrire "detect" dans /sys/class/drm/cardN-HDMI-A-*/status force le
# noyau à relire l'EDID de la TV via I2C/DDC. Ce sysfs n'est inscriptible QUE par root.
# Les services audio tournent en 'pi' (session PipeWire) et ne peuvent donc PAS le faire
# eux-mêmes → ils appellent ce helper via sudo (sudoers, sans argument).
#
# Indispensable au cas « TV en veille / pas prête au boot » : sans cette relecture,
# l'EDID reste vide, l'ELD audio est invalide, et le pilote vc4-hdmi REFUSE l'audio
# (erreur -524 ENOTSUPP). Couvre AUSSI le hotplug (TV rallumée/rebranchée plus tard).
#
# INVARIANT SÉCURITÉ : root:root 0755, sans argument (grant sudoers à chemin fixe).
# Idempotent, silencieux, jamais d'échec fatal (ne casse jamais l'appelant).
set -u

for s in /sys/class/drm/card*-HDMI-A-*/status; do
    [ -e "$s" ] || continue
    # Re-détecte chaque connecteur HDMI (connecté ou non : un "detect" sur un port
    # vide est inoffensif et permet de capter une TV qui vient d'être branchée).
    echo detect > "$s" 2>/dev/null || true
done

exit 0
