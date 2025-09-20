#!/bin/bash

##############################################################################
# PiSignage Screenshot Script
# Version: 3.1.0
# Date: 2025-09-19
# 
# Description: Capture d'écran pour l'interface web PiSignage
# Usage: ./screenshot.sh [output_file]
##############################################################################

set -e

# Configuration
SCREENSHOT_DIR="/opt/pisignage/web/assets/screenshots"
DEFAULT_FILENAME="current_display.png"
MAX_AGE=30  # Secondes avant de régénérer une capture
QUALITY=80  # Qualité JPEG (si conversion nécessaire)

# Créer le dossier si nécessaire
mkdir -p "$SCREENSHOT_DIR"

# Paramètres
OUTPUT_FILE="${1:-$SCREENSHOT_DIR/$DEFAULT_FILENAME}"
TEMP_FILE="/tmp/pisignage_screenshot_$$.png"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Fonction de nettoyage
cleanup() {
    [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# Vérifier si une capture récente existe déjà
if [ -f "$OUTPUT_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$OUTPUT_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt "$MAX_AGE" ]; then
        log "Screenshot récent existe déjà (${AGE}s), utilisation du cache"
        echo "$OUTPUT_FILE"
        exit 0
    fi
fi

log "Capture d'écran en cours..."

# Méthode 1: raspi2png (Raspberry Pi optimisé)
if command -v raspi2png >/dev/null 2>&1; then
    log "Utilisation de raspi2png"
    if raspi2png "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "Capture réussie avec raspi2png: $OUTPUT_FILE"
        echo "$OUTPUT_FILE"
        exit 0
    else
        log "Échec de raspi2png, essai de la méthode suivante"
    fi
fi

# Méthode 2: scrot (outil universel)
if command -v scrot >/dev/null 2>&1; then
    log "Utilisation de scrot"
    if scrot "$TEMP_FILE" -q "$QUALITY" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "Capture réussie avec scrot: $OUTPUT_FILE"
        echo "$OUTPUT_FILE"
        exit 0
    else
        log "Échec de scrot, essai de la méthode suivante"
    fi
fi

# Méthode 3: import (ImageMagick)
if command -v import >/dev/null 2>&1; then
    log "Utilisation d'ImageMagick import"
    if import -window root "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "Capture réussie avec import: $OUTPUT_FILE"
        echo "$OUTPUT_FILE"
        exit 0
    else
        log "Échec d'import, essai de la méthode suivante"
    fi
fi

# Méthode 4: gnome-screenshot
if command -v gnome-screenshot >/dev/null 2>&1; then
    log "Utilisation de gnome-screenshot"
    if gnome-screenshot -f "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "Capture réussie avec gnome-screenshot: $OUTPUT_FILE"
        echo "$OUTPUT_FILE"
        exit 0
    else
        log "Échec de gnome-screenshot, essai de la méthode suivante"
    fi
fi

# Méthode 5: xwd + convert
if command -v xwd >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
    log "Utilisation de xwd + convert"
    if xwd -root | convert xwd:- "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        log "Capture réussie avec xwd+convert: $OUTPUT_FILE"
        echo "$OUTPUT_FILE"
        exit 0
    else
        log "Échec de xwd+convert"
    fi
fi

# Méthode 6: ffmpeg (capture vidéo frame)
if command -v ffmpeg >/dev/null 2>&1; then
    log "Utilisation de ffmpeg"
    # Essayer différents devices
    for device in ":0.0" "/dev/fb0"; do
        if ffmpeg -f x11grab -video_size 1920x1080 -i "$device" -frames:v 1 -q:v 2 "$TEMP_FILE" -y 2>/dev/null || \
           ffmpeg -f fbdev -i "$device" -frames:v 1 -q:v 2 "$TEMP_FILE" -y 2>/dev/null; then
            mv "$TEMP_FILE" "$OUTPUT_FILE"
            log "Capture réussie avec ffmpeg ($device): $OUTPUT_FILE"
            echo "$OUTPUT_FILE"
            exit 0
        fi
    done
    log "Échec de ffmpeg"
fi

# Si tout échoue, créer une image de placeholder
log "Aucune méthode de capture disponible, création d'un placeholder"

# Créer une image placeholder avec convert si disponible
if command -v convert >/dev/null 2>&1; then
    convert -size 800x600 xc:lightblue \
            -gravity center \
            -pointsize 24 \
            -fill darkblue \
            -annotate 0 "PiSignage Display\n\nCapture d'écran\nnon disponible\n\n$(date '+%Y-%m-%d %H:%M:%S')" \
            "$OUTPUT_FILE" 2>/dev/null || {
        # Si convert échoue aussi, créer un fichier texte
        echo "Screenshot not available - $(date)" > "${OUTPUT_FILE%.png}.txt"
        log "Placeholder texte créé: ${OUTPUT_FILE%.png}.txt"
        echo "${OUTPUT_FILE%.png}.txt"
        exit 1
    }
    log "Image placeholder créée: $OUTPUT_FILE"
    echo "$OUTPUT_FILE"
    exit 0
fi

# Dernière option: fichier texte
echo "Screenshot not available - $(date)" > "${OUTPUT_FILE%.png}.txt"
log "ERREUR: Impossible de créer une capture d'écran"
echo "${OUTPUT_FILE%.png}.txt"
exit 1