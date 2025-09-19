#!/bin/bash

# Script de sauvegarde PiSignage
# Version: 1.0

BACKUP_DIR="/opt/pisignage/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/opt/pisignage/logs/backup.log"

# Création du répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

# Fonction de logging
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Sauvegarde de la configuration
backup_config() {
    log_message "Sauvegarde de la configuration..."
    
    config_backup="$BACKUP_DIR/config_$DATE.tar.gz"
    tar -czf "$config_backup" -C /opt/pisignage config/
    
    if [ $? -eq 0 ]; then
        log_message "Configuration sauvegardée: $config_backup"
    else
        log_message "Erreur lors de la sauvegarde de la configuration"
        return 1
    fi
}

# Sauvegarde des médias
backup_media() {
    log_message "Sauvegarde des médias..."
    
    media_backup="$BACKUP_DIR/media_$DATE.tar.gz"
    tar -czf "$media_backup" -C /opt/pisignage media/
    
    if [ $? -eq 0 ]; then
        log_message "Médias sauvegardés: $media_backup"
    else
        log_message "Erreur lors de la sauvegarde des médias"
        return 1
    fi
}

# Sauvegarde de l'interface web
backup_web() {
    log_message "Sauvegarde de l'interface web..."
    
    web_backup="$BACKUP_DIR/web_$DATE.tar.gz"
    tar -czf "$web_backup" -C /opt/pisignage web/
    
    if [ $? -eq 0 ]; then
        log_message "Interface web sauvegardée: $web_backup"
    else
        log_message "Erreur lors de la sauvegarde de l'interface web"
        return 1
    fi
}

# Sauvegarde complète
backup_full() {
    log_message "Sauvegarde complète du système..."
    
    full_backup="$BACKUP_DIR/pisignage_full_$DATE.tar.gz"
    tar -czf "$full_backup" \
        --exclude="/opt/pisignage/logs/*" \
        --exclude="/opt/pisignage/backups/*" \
        -C /opt pisignage/
    
    if [ $? -eq 0 ]; then
        log_message "Sauvegarde complète créée: $full_backup"
    else
        log_message "Erreur lors de la sauvegarde complète"
        return 1
    fi
}

# Nettoyage des anciennes sauvegardes
cleanup_old_backups() {
    log_message "Nettoyage des anciennes sauvegardes..."
    
    # Suppression des sauvegardes de plus de 30 jours
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
    
    log_message "Nettoyage terminé"
}

# Restauration
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo "Usage: $0 restore <fichier_sauvegarde>"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_message "Erreur: Fichier de sauvegarde introuvable: $backup_file"
        exit 1
    fi
    
    log_message "Restauration depuis: $backup_file"
    
    # Sauvegarde de sécurité avant restauration
    backup_full
    
    # Restauration
    tar -xzf "$backup_file" -C /opt/
    
    if [ $? -eq 0 ]; then
        log_message "Restauration réussie"
        systemctl restart pisignage
    else
        log_message "Erreur lors de la restauration"
        exit 1
    fi
}

# Menu principal
case "$1" in
    config)
        backup_config
        ;;
    media)
        backup_media
        ;;
    web)
        backup_web
        ;;
    full)
        backup_full
        cleanup_old_backups
        ;;
    restore)
        restore_backup "$2"
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    *)
        echo "Usage: $0 {config|media|web|full|restore|cleanup}"
        echo "  config  - Sauvegarde de la configuration uniquement"
        echo "  media   - Sauvegarde des médias uniquement"
        echo "  web     - Sauvegarde de l'interface web uniquement"
        echo "  full    - Sauvegarde complète du système"
        echo "  restore <fichier> - Restauration depuis une sauvegarde"
        echo "  cleanup - Suppression des anciennes sauvegardes"
        exit 1
        ;;
esac