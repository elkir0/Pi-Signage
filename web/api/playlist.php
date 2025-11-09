<?php
/**
 * PiSignage Playlist API
 * Gestion de la playlist pour le Chromium Player HTML5
 *
 * Endpoints:
 * - GET  /api/playlist           - Récupérer la playlist actuelle
 * - PUT  /api/playlist           - Mettre à jour la playlist
 * - POST /api/playlist/validate  - Valider la structure de la playlist
 * - POST /api/playlist/refresh   - Notifier le player de recharger
 * - POST /api/playlist/upload    - Upload un média (optionnel)
 */

header('Content-Type: application/json');

// Configuration
define('PLAYLIST_FILE', '/opt/pisignage/content/playlist.json');
define('MEDIA_DIR', '/opt/pisignage/content/');
define('ADMIN_TOKEN_FILE', '/opt/pisignage/config/admin_token');

// Fonction utilitaire pour les réponses JSON
function jsonResponse($success, $data = null, $message = '', $code = 200) {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    exit;
}

// Vérification du token admin pour les opérations d'écriture
function requireAdminToken() {
    if (!file_exists(ADMIN_TOKEN_FILE)) {
        error_log('[PiSignage Playlist API] WARNING: No admin token file found. Running in permissive mode.');
        return; // Mode permissif
    }

    $expectedToken = trim(file_get_contents(ADMIN_TOKEN_FILE));
    $providedToken = $_SERVER['HTTP_X_ADMIN_TOKEN'] ?? '';

    if ($providedToken !== $expectedToken) {
        jsonResponse(false, null, 'Unauthorized: Invalid admin token', 401);
    }
}

// Validation de la structure de la playlist
function validatePlaylist($playlist) {
    $errors = [];

    if (!isset($playlist['version']) || !is_numeric($playlist['version'])) {
        $errors[] = 'Missing or invalid version field';
    }

    if (!isset($playlist['items']) || !is_array($playlist['items'])) {
        $errors[] = 'Missing or invalid items array';
    } else {
        foreach ($playlist['items'] as $index => $item) {
            if (!isset($item['url']) || empty($item['url'])) {
                $errors[] = "Item $index: Missing URL";
            }

            // Valider le format de l'URL
            if (isset($item['url'])) {
                $url = $item['url'];
                if (!filter_var($url, FILTER_VALIDATE_URL) &&
                    !preg_match('/^file:\/\/\//', $url)) {
                    $errors[] = "Item $index: Invalid URL format: $url";
                }
            }

            // Valider les booléens
            if (isset($item['mute']) && !is_bool($item['mute'])) {
                $errors[] = "Item $index: 'mute' must be boolean";
            }
            if (isset($item['loop']) && !is_bool($item['loop'])) {
                $errors[] = "Item $index: 'loop' must be boolean";
            }

            // Valider fit
            if (isset($item['fit']) && !in_array($item['fit'], ['contain', 'cover'])) {
                $errors[] = "Item $index: 'fit' must be 'contain' or 'cover'";
            }

            // Valider duration
            if (isset($item['duration']) && !is_numeric($item['duration'])) {
                $errors[] = "Item $index: 'duration' must be numeric";
            }
        }
    }

    if (!isset($playlist['autoLoop']) || !is_bool($playlist['autoLoop'])) {
        $errors[] = 'Missing or invalid autoLoop field';
    }

    if (!isset($playlist['autoplay']) || !is_bool($playlist['autoplay'])) {
        $errors[] = 'Missing or invalid autoplay field';
    }

    return [
        'valid' => empty($errors),
        'errors' => $errors
    ];
}

// Vérifier l'accessibilité des URLs
function checkUrlAccessibility($url) {
    if (preg_match('/^file:\/\/\/(.+)$/', $url, $matches)) {
        // Fichier local
        $filePath = '/' . $matches[1];
        return [
            'accessible' => file_exists($filePath),
            'message' => file_exists($filePath) ? 'File exists' : 'File not found'
        ];
    } elseif (preg_match('/^https?:\/\//', $url)) {
        // URL HTTP/HTTPS - HEAD request
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_NOBODY, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [
            'accessible' => ($httpCode >= 200 && $httpCode < 400),
            'message' => "HTTP $httpCode"
        ];
    }

    return [
        'accessible' => false,
        'message' => 'Unknown URL scheme'
    ];
}

// Router selon la méthode HTTP et le PATH_INFO
$method = $_SERVER['REQUEST_METHOD'];
$pathInfo = $_SERVER['PATH_INFO'] ?? '';

switch ("$method:$pathInfo") {

    // GET /api/playlist - Récupérer la playlist
    case 'GET:':
    case 'GET:/':
        if (!file_exists(PLAYLIST_FILE)) {
            jsonResponse(false, null, 'Playlist file not found', 404);
        }

        $playlist = json_decode(file_get_contents(PLAYLIST_FILE), true);
        if ($playlist === null) {
            jsonResponse(false, null, 'Invalid JSON in playlist file', 500);
        }

        jsonResponse(true, $playlist, 'Playlist retrieved successfully');
        break;

    // PUT /api/playlist - Mettre à jour la playlist
    case 'PUT:':
    case 'PUT:/':
        requireAdminToken();

        $input = file_get_contents('php://input');
        $playlist = json_decode($input, true);

        if ($playlist === null) {
            jsonResponse(false, null, 'Invalid JSON in request body', 400);
        }

        // Valider la structure
        $validation = validatePlaylist($playlist);
        if (!$validation['valid']) {
            jsonResponse(false, ['errors' => $validation['errors']],
                        'Playlist validation failed', 400);
        }

        // Créer le répertoire si nécessaire
        $dir = dirname(PLAYLIST_FILE);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        // Sauvegarder
        $result = file_put_contents(PLAYLIST_FILE, json_encode($playlist, JSON_PRETTY_PRINT));

        if ($result === false) {
            jsonResponse(false, null, 'Failed to write playlist file', 500);
        }

        jsonResponse(true, $playlist, 'Playlist updated successfully');
        break;

    // POST /api/playlist/validate - Valider la playlist
    case 'POST:/validate':
        $input = file_get_contents('php://input');
        $playlist = json_decode($input, true);

        if ($playlist === null) {
            jsonResponse(false, null, 'Invalid JSON in request body', 400);
        }

        // Validation de structure
        $validation = validatePlaylist($playlist);
        if (!$validation['valid']) {
            jsonResponse(false, ['errors' => $validation['errors']],
                        'Playlist structure invalid', 400);
        }

        // Vérifier l'accessibilité des URLs
        $urlChecks = [];
        foreach ($playlist['items'] as $index => $item) {
            $check = checkUrlAccessibility($item['url']);
            $urlChecks[] = [
                'index' => $index,
                'url' => $item['url'],
                'accessible' => $check['accessible'],
                'message' => $check['message']
            ];
        }

        $allAccessible = array_reduce($urlChecks, function($carry, $check) {
            return $carry && $check['accessible'];
        }, true);

        jsonResponse(true, [
            'structureValid' => true,
            'urlChecks' => $urlChecks,
            'allAccessible' => $allAccessible
        ], 'Playlist validation complete');
        break;

    // POST /api/playlist/refresh - Notifier le player
    case 'POST:/refresh':
        requireAdminToken();

        // Créer un fichier de signal pour le player
        $signalFile = '/tmp/pisignage-playlist-refresh';
        touch($signalFile);

        jsonResponse(true, [
            'signalFile' => $signalFile,
            'timestamp' => time()
        ], 'Player refresh signal sent');
        break;

    // POST /api/playlist/upload - Upload un média
    case 'POST:/upload':
        requireAdminToken();

        if (!isset($_FILES['file'])) {
            jsonResponse(false, null, 'No file uploaded', 400);
        }

        $file = $_FILES['file'];

        // Validation
        if ($file['error'] !== UPLOAD_ERR_OK) {
            jsonResponse(false, null, 'Upload error: ' . $file['error'], 400);
        }

        // Vérifier le type MIME
        $allowedTypes = [
            'video/mp4',
            'video/webm',
            'video/ogg',
            'video/quicktime',
            'video/x-matroska'
        ];

        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);

        if (!in_array($mimeType, $allowedTypes)) {
            jsonResponse(false, null, "Unsupported file type: $mimeType", 400);
        }

        // Vérifier la taille (max 500MB)
        if ($file['size'] > 500 * 1024 * 1024) {
            jsonResponse(false, null, 'File too large (max 500MB)', 400);
        }

        // Sécuriser le nom de fichier
        $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', basename($file['name']));
        $targetPath = MEDIA_DIR . $filename;

        // Créer le répertoire si nécessaire
        if (!is_dir(MEDIA_DIR)) {
            mkdir(MEDIA_DIR, 0755, true);
        }

        // Déplacer le fichier
        if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
            jsonResponse(false, null, 'Failed to save uploaded file', 500);
        }

        jsonResponse(true, [
            'filename' => $filename,
            'path' => $targetPath,
            'url' => "file://$targetPath",
            'size' => $file['size'],
            'mimeType' => $mimeType
        ], 'File uploaded successfully');
        break;

    default:
        jsonResponse(false, null, 'Invalid endpoint or method', 404);
}
