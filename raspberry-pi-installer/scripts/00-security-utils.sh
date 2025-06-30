#!/usr/bin/env bash

# =============================================================================
# Module 00 - Fonctions Utilitaires de Sécurité
# Version: 2.0.0
# Description: Fonctions communes pour la sécurité et la gestion d'erreurs
# =============================================================================

# =============================================================================
# GESTION D'ERREURS ROBUSTE
# =============================================================================

# Fonction pour exécuter une commande avec retry et timeout
safe_execute() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-5}"
    local timeout="${4:-300}"  # 5 minutes par défaut
    
    local attempt=1
    
    while [[ $attempt -le $max_retries ]]; do
        echo "[SAFE_EXEC] Tentative $attempt/$max_retries: $cmd"
        
        if timeout "$timeout" bash -c "$cmd"; then
            echo "[SAFE_EXEC] Commande réussie"
            return 0
        fi
        
        local exit_code=$?
        echo "[SAFE_EXEC] Échec (code: $exit_code)"
        
        if [[ $attempt -lt $max_retries ]]; then
            echo "[SAFE_EXEC] Nouvelle tentative dans ${retry_delay}s..."
            sleep "$retry_delay"
        fi
        
        ((attempt++))
    done
    
    echo "[SAFE_EXEC] ERREUR: Commande échouée après $max_retries tentatives"
    return 1
}

# Fonction pour attendre qu'un service soit prêt
wait_for_service() {
    local service="$1"
    local max_wait="${2:-60}"  # 60 secondes par défaut
    local check_interval="${3:-2}"
    
    local elapsed=0
    
    echo "[WAIT] Attente du service: $service (max: ${max_wait}s)"
    
    while [[ $elapsed -lt $max_wait ]]; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo "[WAIT] Service $service actif après ${elapsed}s"
            return 0
        fi
        
        sleep "$check_interval"
        ((elapsed += check_interval))
    done
    
    echo "[WAIT] TIMEOUT: Service $service non actif après ${max_wait}s"
    return 1
}

# Fonction pour attendre qu'un processus soit prêt
wait_for_process() {
    local process_pattern="$1"
    local max_wait="${2:-60}"
    local check_interval="${3:-2}"
    
    local elapsed=0
    
    echo "[WAIT] Attente du processus: $process_pattern (max: ${max_wait}s)"
    
    while [[ $elapsed -lt $max_wait ]]; do
        if pgrep -f "$process_pattern" >/dev/null 2>&1; then
            echo "[WAIT] Processus trouvé après ${elapsed}s"
            return 0
        fi
        
        sleep "$check_interval"
        ((elapsed += check_interval))
    done
    
    echo "[WAIT] TIMEOUT: Processus non trouvé après ${max_wait}s"
    return 1
}

# =============================================================================
# CHIFFREMENT ET SÉCURITÉ
# =============================================================================

# Générer une clé de chiffrement basée sur l'ID machine
get_encryption_key() {
    local machine_id
    machine_id=$(cat /etc/machine-id 2>/dev/null || hostname | sha256sum | cut -d' ' -f1)
    echo "${machine_id:0:32}"  # 32 caractères pour AES-256
}

# Chiffrer un mot de passe
encrypt_password() {
    local password="$1"
    local key
    key=$(get_encryption_key)
    
    # Utiliser openssl pour chiffrer
    echo -n "$password" | openssl enc -aes-256-cbc -base64 -pbkdf2 -salt -pass "pass:$key" 2>/dev/null
}

# Déchiffrer un mot de passe
decrypt_password() {
    local encrypted="$1"
    local key
    key=$(get_encryption_key)
    
    # Utiliser openssl pour déchiffrer
    echo -n "$encrypted" | openssl enc -aes-256-cbc -base64 -d -pbkdf2 -salt -pass "pass:$key" 2>/dev/null
}

# Générer un token sécurisé
generate_secure_token() {
    local length="${1:-32}"
    openssl rand -hex "$length"
}

# Hacher un mot de passe avec salt
hash_password() {
    local password="$1"
    local salt="${2:-$(openssl rand -hex 16)}"
    
    # Utiliser SHA-512 avec salt
    local hash
    hash=$(echo -n "${salt}${password}" | sha512sum | cut -d' ' -f1)
    
    # Retourner salt:hash
    echo "${salt}:${hash}"
}

# Vérifier un mot de passe hashé
verify_password_hash() {
    local password="$1"
    local stored_hash="$2"
    
    # Extraire le salt et le hash
    local salt="${stored_hash%%:*}"
    local hash="${stored_hash#*:}"
    
    # Calculer le hash avec le même salt
    local computed_hash
    computed_hash=$(echo -n "${salt}${password}" | sha512sum | cut -d' ' -f1)
    
    # Comparer les hashs
    [[ "$computed_hash" == "$hash" ]]
}

# =============================================================================
# PERMISSIONS SÉCURISÉES
# =============================================================================

# Définir des permissions sécurisées pour un fichier
secure_file_permissions() {
    local file="$1"
    local owner="${2:-root}"
    local group="${3:-root}"
    local perms="${4:-600}"
    
    if [[ -f "$file" ]]; then
        chown "$owner:$group" "$file" || return 1
        chmod "$perms" "$file" || return 1
        echo "[PERMS] Permissions sécurisées appliquées: $file ($owner:$group $perms)"
        return 0
    else
        echo "[PERMS] ERREUR: Fichier non trouvé: $file"
        return 1
    fi
}

# Définir des permissions sécurisées pour un répertoire
secure_dir_permissions() {
    local dir="$1"
    local owner="${2:-root}"
    local group="${3:-root}"
    local perms="${4:-750}"
    
    if [[ -d "$dir" ]]; then
        chown -R "$owner:$group" "$dir" || return 1
        chmod "$perms" "$dir" || return 1
        # Permissions spéciales pour les sous-répertoires
        find "$dir" -type d -exec chmod "$perms" {} \; || return 1
        echo "[PERMS] Permissions sécurisées appliquées: $dir ($owner:$group $perms)"
        return 0
    else
        echo "[PERMS] ERREUR: Répertoire non trouvé: $dir"
        return 1
    fi
}

# =============================================================================
# VALIDATION ET SANITISATION
# =============================================================================

# Valider un nom d'utilisateur
validate_username() {
    local username="$1"
    
    # Vérifier longueur (3-32 caractères)
    if [[ ${#username} -lt 3 ]] || [[ ${#username} -gt 32 ]]; then
        return 1
    fi
    
    # Vérifier format (alphanumériques, underscore, tiret)
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Valider une URL
validate_url() {
    local url="$1"
    
    # Pattern pour URL HTTP/HTTPS
    local url_pattern='^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$'
    
    if [[ "$url" =~ $url_pattern ]]; then
        return 0
    else
        return 1
    fi
}

# Sanitiser un nom de fichier
sanitize_filename() {
    local filename="$1"
    
    # Remplacer les caractères dangereux
    filename="${filename//[^a-zA-Z0-9._-]/_}"
    
    # Supprimer les points au début
    filename="${filename#.}"
    
    # Limiter la longueur
    filename="${filename:0:255}"
    
    echo "$filename"
}

# =============================================================================
# CRÉATION SÉCURISÉE DE FICHIERS
# =============================================================================

# Créer un fichier temporaire sécurisé
create_secure_temp_file() {
    local prefix="${1:-pi-signage}"
    local temp_file
    
    # Utiliser mktemp avec template sécurisé
    temp_file=$(mktemp "/tmp/${prefix}-XXXXXX") || return 1
    
    # Appliquer permissions strictes
    chmod 600 "$temp_file"
    
    echo "$temp_file"
}

# Créer un répertoire temporaire sécurisé
create_secure_temp_dir() {
    local prefix="${1:-pi-signage}"
    local temp_dir
    
    # Utiliser mktemp avec template sécurisé
    temp_dir=$(mktemp -d "/tmp/${prefix}-XXXXXX") || return 1
    
    # Appliquer permissions strictes
    chmod 700 "$temp_dir"
    
    echo "$temp_dir"
}

# =============================================================================
# AUDIT ET LOGGING SÉCURISÉ
# =============================================================================

# Logger un événement de sécurité
log_security_event() {
    local event_type="$1"
    local message="$2"
    local user="${3:-$(whoami)}"
    # Gérer le cas où SSH_CLIENT n'est pas défini (execution locale)
    local ip="${4:-}"
    if [[ -z "$ip" ]] && [[ -n "${SSH_CLIENT:-}" ]]; then
        ip="${SSH_CLIENT%% *}"
    elif [[ -z "$ip" ]]; then
        ip="local"
    fi
    
    local log_file="/var/log/pi-signage/security.log"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Créer le répertoire de logs si nécessaire
    mkdir -p "$(dirname "$log_file")"
    
    # Format JSON pour faciliter le parsing
    local log_entry
    log_entry=$(cat <<EOF
{"timestamp":"$timestamp","event":"$event_type","user":"$user","ip":"$ip","message":"$message"}
EOF
)
    
    # Écrire dans le log avec permissions strictes
    echo "$log_entry" >> "$log_file"
    chmod 600 "$log_file"
}

# =============================================================================
# VÉRIFICATIONS DE SÉCURITÉ
# =============================================================================

# Vérifier si on est en environnement sécurisé
check_secure_environment() {
    local warnings=0
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        echo "[SEC] AVERTISSEMENT: Script non exécuté en tant que root"
        ((warnings++))
    fi
    
    # Vérifier les permissions du script
    local script_perms
    script_perms=$(stat -c %a "$0" 2>/dev/null || echo "000")
    if [[ "$script_perms" != "700" ]] && [[ "$script_perms" != "750" ]]; then
        echo "[SEC] AVERTISSEMENT: Permissions du script trop permissives: $script_perms"
        ((warnings++))
    fi
    
    # Vérifier umask
    local current_umask
    current_umask=$(umask)
    if [[ "$current_umask" != "0077" ]] && [[ "$current_umask" != "0027" ]]; then
        echo "[SEC] AVERTISSEMENT: umask trop permissif: $current_umask"
        umask 0027
    fi
    
    return $warnings
}

# =============================================================================
# EXPORT DES FONCTIONS
# =============================================================================

# Export pour utilisation dans d'autres scripts
export -f safe_execute
export -f wait_for_service
export -f wait_for_process
export -f encrypt_password
export -f decrypt_password
export -f generate_secure_token
export -f hash_password
export -f verify_password_hash
export -f secure_file_permissions
export -f secure_dir_permissions
export -f validate_username
export -f validate_url
export -f sanitize_filename
export -f create_secure_temp_file
export -f create_secure_temp_dir
export -f log_security_event
export -f check_secure_environment
export -f get_encryption_key