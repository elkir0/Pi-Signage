#!/bin/bash

# Module d'installation des composants multimédia
# Version: 1.0

MODULE_NAME="Media Components"
LOG_FILE="/opt/pisignage/logs/install-media.log"

echo "=== Installation du module: $MODULE_NAME ===" | tee -a "$LOG_FILE"

# Installation des lecteurs multimédia
install_media_players() {
    echo "Installation des lecteurs multimédia..." | tee -a "$LOG_FILE"
    
    apt-get install -y \
        omxplayer \
        vlc \
        mpv \
        feh \
        ffmpeg \
        imagemagick
    
    echo "Lecteurs multimédia installés" | tee -a "$LOG_FILE"
}

# Installation des codecs
install_codecs() {
    echo "Installation des codecs..." | tee -a "$LOG_FILE"
    
    apt-get install -y \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav
    
    echo "Codecs installés" | tee -a "$LOG_FILE"
}

# Configuration des médias
configure_media_system() {
    echo "Configuration du système multimédia..." | tee -a "$LOG_FILE"
    
    # Création du répertoire des médias
    mkdir -p /opt/pisignage/media/{videos,images,playlists}
    chmod 755 /opt/pisignage/media
    chmod 755 /opt/pisignage/media/*
    
    # Configuration des permissions pour les médias
    chown -R www-data:www-data /opt/pisignage/media
    
    echo "Configuration multimédia terminée" | tee -a "$LOG_FILE"
}

# Fonction principale
main() {
    install_media_players
    install_codecs
    configure_media_system
    echo "Module $MODULE_NAME installé avec succès" | tee -a "$LOG_FILE"
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi