#!/bin/bash

# Moteur de gestion de playlist RÉEL pour VLC
# Gère vidéos, images, durées d'affichage et playlists

MEDIA_DIR="/opt/pisignage/media"
PLAYLIST_FILE="/opt/pisignage/config/current_playlist.m3u"
CONFIG_FILE="/opt/pisignage/config/playlists.json"
DEFAULT_IMAGE_DURATION=10  # Durée par défaut pour les images en secondes
LOGS_DIR="/opt/pisignage/logs"

# Fonction pour créer une playlist par défaut si aucune n'existe
create_default_playlist() {
    echo "Création de la playlist par défaut..."
    
    # Créer une playlist M3U avec tous les médias disponibles
    echo "#EXTM3U" > "$PLAYLIST_FILE"
    echo "#PLAYLIST:Défaut" >> "$PLAYLIST_FILE"
    
    # Ajouter toutes les vidéos
    for ext in mp4 avi mkv mov webm; do
        for video in "$MEDIA_DIR"/*."$ext"; do
            if [ -f "$video" ]; then
            # Obtenir la durée de la vidéo
            duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video" 2>/dev/null | cut -d. -f1)
            if [ -z "$duration" ]; then duration=0; fi
            
                echo "#EXTINF:$duration,$(basename "$video")" >> "$PLAYLIST_FILE"
                echo "file://$video" >> "$PLAYLIST_FILE"
            fi
        done
    done
    
    # Ajouter toutes les images avec durée configurée
    for ext in jpg jpeg png gif bmp; do
        for image in "$MEDIA_DIR"/*."$ext"; do
            if [ -f "$image" ]; then
                echo "#EXTINF:$DEFAULT_IMAGE_DURATION,$(basename "$image")" >> "$PLAYLIST_FILE"
                echo "file://$image" >> "$PLAYLIST_FILE"
            fi
        done
    done
    
    # Si aucun média, ajouter un placeholder
    if [ $(wc -l < "$PLAYLIST_FILE") -eq 2 ]; then
        echo "⚠️ Aucun média trouvé dans $MEDIA_DIR"
        return 1
    fi
    
    echo "✅ Playlist par défaut créée avec $(grep -c "^file://" "$PLAYLIST_FILE") médias"
}

# Fonction pour créer une playlist depuis JSON
create_playlist_from_json() {
    local playlist_id="$1"
    
    if [ -z "$playlist_id" ]; then
        echo "❌ ID de playlist requis"
        return 1
    fi
    
    # Extraire la playlist depuis le JSON
    playlist_data=$(jq -r ".playlists[] | select(.id == \"$playlist_id\")" "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$playlist_data" ]; then
        echo "❌ Playlist $playlist_id introuvable"
        return 1
    fi
    
    # Récupérer les paramètres
    name=$(echo "$playlist_data" | jq -r '.name // "Sans nom"')
    loop=$(echo "$playlist_data" | jq -r '.settings.loop // true')
    shuffle=$(echo "$playlist_data" | jq -r '.settings.shuffle // false')
    image_duration=$(echo "$playlist_data" | jq -r '.settings.image_duration // 10')
    
    echo "📋 Création playlist: $name"
    
    # Créer le fichier M3U
    echo "#EXTM3U" > "$PLAYLIST_FILE"
    echo "#PLAYLIST:$name" >> "$PLAYLIST_FILE"
    echo "#EXTLOOP:$loop" >> "$PLAYLIST_FILE"
    echo "#EXTSHUFFLE:$shuffle" >> "$PLAYLIST_FILE"
    
    # Ajouter les médias
    echo "$playlist_data" | jq -r '.items[]? // .videos[]?' | while read -r media; do
        if [ -z "$media" ]; then continue; fi
        
        media_path="$MEDIA_DIR/$media"
        
        if [ ! -f "$media_path" ]; then
            echo "⚠️ Média introuvable: $media"
            continue
        fi
        
        # Déterminer le type et la durée
        case "${media##*.}" in
            mp4|avi|mkv|mov|webm)
                # Vidéo - obtenir la durée réelle
                duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$media_path" 2>/dev/null | cut -d. -f1)
                if [ -z "$duration" ]; then duration=0; fi
                ;;
            jpg|jpeg|png|gif|bmp)
                # Image - utiliser la durée configurée
                duration=$image_duration
                ;;
            *)
                echo "⚠️ Type non supporté: $media"
                continue
                ;;
        esac
        
        echo "#EXTINF:$duration,$media" >> "$PLAYLIST_FILE"
        echo "file://$media_path" >> "$PLAYLIST_FILE"
    done
    
    # Vérifier qu'il y a des médias
    if [ $(grep -c "^file://" "$PLAYLIST_FILE") -eq 0 ]; then
        echo "❌ Playlist vide, création de la playlist par défaut"
        create_default_playlist
        return 1
    fi
    
    echo "✅ Playlist créée avec $(grep -c "^file://" "$PLAYLIST_FILE") médias"
}

# Fonction pour lancer VLC avec la playlist
start_vlc_with_playlist() {
    local playlist="$1"
    local options=""
    
    # Lire les options depuis la playlist
    if grep -q "#EXTLOOP:true" "$playlist" 2>/dev/null; then
        options="$options --loop"
    fi
    
    if grep -q "#EXTSHUFFLE:true" "$playlist" 2>/dev/null; then
        options="$options --random"
    fi
    
    # Arrêter VLC s'il tourne
    pkill -9 vlc 2>/dev/null
    sleep 1
    
    # Options VLC pour gérer les images
    # --image-duration : durée d'affichage des images
    # --no-video-title-show : pas de titre
    # --fullscreen : plein écran
    
    echo "🎬 Démarrage VLC avec playlist..."
    
    # Lancer VLC avec la playlist
    cvlc \
        --intf dummy \
        --no-video-title-show \
        --fullscreen \
        --image-duration=$DEFAULT_IMAGE_DURATION \
        --playlist-tree \
        $options \
        "$playlist" \
        > "$LOGS_DIR/vlc.log" 2>&1 &
    
    local pid=$!
    echo $pid > /tmp/vlc.pid
    
    sleep 2
    
    if ps -p $pid > /dev/null; then
        echo "✅ VLC démarré (PID: $pid)"
        return 0
    else
        echo "❌ Échec du démarrage VLC"
        return 1
    fi
}

# Fonction pour obtenir la playlist active
get_active_playlist() {
    if [ -f "$CONFIG_FILE" ]; then
        active=$(jq -r '.active_playlist // "default"' "$CONFIG_FILE")
        if [ "$active" != "null" ] && [ "$active" != "default" ]; then
            echo "$active"
        else
            echo "default"
        fi
    else
        echo "default"
    fi
}

# Fonction pour définir la playlist active
set_active_playlist() {
    local playlist_id="$1"
    
    if [ -f "$CONFIG_FILE" ]; then
        # Mettre à jour le JSON
        jq ".active_playlist = \"$playlist_id\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ Playlist active: $playlist_id"
    fi
}

# Fonction principale
main() {
    local action="${1:-status}"
    local playlist_id="${2:-}"
    
    case "$action" in
        start)
            # Démarrer avec la playlist active ou par défaut
            if [ -z "$playlist_id" ]; then
                playlist_id=$(get_active_playlist)
            fi
            
            if [ "$playlist_id" = "default" ]; then
                create_default_playlist
            else
                create_playlist_from_json "$playlist_id"
            fi
            
            if [ -f "$PLAYLIST_FILE" ]; then
                start_vlc_with_playlist "$PLAYLIST_FILE"
                set_active_playlist "$playlist_id"
            else
                echo "❌ Impossible de créer la playlist"
                exit 1
            fi
            ;;
            
        stop)
            echo "⏹️ Arrêt de VLC..."
            if [ -f /tmp/vlc.pid ]; then
                kill $(cat /tmp/vlc.pid) 2>/dev/null
                rm /tmp/vlc.pid
            fi
            pkill -9 vlc 2>/dev/null
            echo "✅ VLC arrêté"
            ;;
            
        restart)
            $0 stop
            sleep 2
            $0 start "$playlist_id"
            ;;
            
        status)
            if pgrep -x vlc > /dev/null; then
                pid=$(pgrep -x vlc | head -1)
                active=$(get_active_playlist)
                media_count=$(grep -c "^file://" "$PLAYLIST_FILE" 2>/dev/null || echo 0)
                echo "▶️ VLC en lecture"
                echo "📋 Playlist active: $active"
                echo "📁 Médias: $media_count"
                echo "🔧 PID: $pid"
            else
                echo "⏸️ VLC arrêté"
            fi
            ;;
            
        refresh)
            # Recharger la playlist sans redémarrer VLC
            echo "🔄 Rafraîchissement de la playlist..."
            playlist_id=$(get_active_playlist)
            
            if [ "$playlist_id" = "default" ]; then
                create_default_playlist
            else
                create_playlist_from_json "$playlist_id"
            fi
            
            # Envoyer la nouvelle playlist à VLC via telnet/http si configuré
            echo "✅ Playlist mise à jour"
            ;;
            
        list)
            # Lister les playlists disponibles
            echo "📋 Playlists disponibles:"
            echo "  - default (Tous les médias)"
            if [ -f "$CONFIG_FILE" ]; then
                jq -r '.playlists[] | "  - \(.id): \(.name)"' "$CONFIG_FILE" 2>/dev/null
            fi
            ;;
            
        *)
            echo "Usage: $0 {start|stop|restart|status|refresh|list} [playlist_id]"
            echo ""
            echo "Actions:"
            echo "  start [id]  - Démarrer VLC avec une playlist"
            echo "  stop        - Arrêter VLC"
            echo "  restart     - Redémarrer VLC"
            echo "  status      - Afficher le statut"
            echo "  refresh     - Recharger la playlist"
            echo "  list        - Lister les playlists"
            exit 1
            ;;
    esac
}

# Exécuter
main "$@"