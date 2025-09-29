<?php
/**
 * PiSignage v0.8.0 - Screenshot API
 * API de capture d'écran optimisée pour Raspberry Pi
 * Support: raspi2png > scrot > fbgrab avec cache et rate limiting
 */

require_once dirname(__DIR__) . '/config.php';

// Constantes de configuration
define('SCREENSHOT_CACHE_DIR', '/dev/shm/pisignage');
define('SCREENSHOT_RATE_LIMIT', 5); // secondes minimum entre captures
define('SCREENSHOT_MAX_CACHE_SIZE', 50 * 1024 * 1024); // 50MB
define('SCREENSHOT_QUALITY_MIN', 50);
define('SCREENSHOT_QUALITY_MAX', 100);
define('SCREENSHOT_QUALITY_DEFAULT', 85);

/**
 * Classe de gestion des captures d'écran
 */
class ScreenshotManager {
    private $cacheDir;
    private $lastCaptureFile;
    private $availableMethods = [];

    public function __construct() {
        error_log("DEBUG: ScreenshotManager constructor called");
        $this->cacheDir = SCREENSHOT_CACHE_DIR;
        $this->lastCaptureFile = $this->cacheDir . '/.last_capture';
        $this->initializeCache();
        $this->detectAvailableMethods();
        error_log("DEBUG: Available methods after detection: " . implode(', ', $this->availableMethods));
    }

    /**
     * Initialise le cache en RAM (/dev/shm)
     */
    private function initializeCache() {
        if (!file_exists($this->cacheDir)) {
            if (!mkdir($this->cacheDir, 0755, true)) {
                logMessage("Impossible de créer le cache screenshot: {$this->cacheDir}", 'ERROR');
                $this->cacheDir = SCREENSHOTS_PATH; // Fallback sur disque
                if (!file_exists($this->cacheDir)) {
                    mkdir($this->cacheDir, 0755, true);
                }
            }
        }

        // Nettoyage du cache si trop volumineux
        $this->cleanupCache();
    }

    /**
     * Détecte les méthodes de capture disponibles par ordre de préférence
     */
    private function detectAvailableMethods() {
        // Détection de la session Wayland ou X11
        $isWayland = getenv('WAYLAND_DISPLAY') !== false ||
                     strpos(shell_exec('echo $XDG_SESSION_TYPE 2>/dev/null') ?: '', 'wayland') !== false;

        // Vérifier si VLC est en cours d'exécution
        $vlcRunning = !empty(trim(shell_exec('pgrep -x vlc 2>/dev/null')));

        $methods = [
            'ffmpeg-vlc' => '/usr/bin/ffmpeg',            // FFmpeg pour VLC
            'grim' => '/usr/bin/grim',                    // Wayland standard
            'gnome-screenshot' => 'gdbus',                // GNOME via D-Bus
            'fbgrab' => '/usr/bin/fbgrab',               // Framebuffer
            'raspi2png' => '/usr/bin/raspi2png',         // Raspberry Pi GPU
            'scrot' => '/usr/bin/scrot',                 // X11 (fallback)
            'import' => '/usr/bin/import'                // ImageMagick X11
        ];

        // Si VLC est actif et ffmpeg disponible, prioriser ffmpeg-vlc
        logMessage("VLC detection: vlcRunning=" . ($vlcRunning ? 'true' : 'false') . ", ffmpeg=" . (shell_exec("which ffmpeg 2>/dev/null") ? 'found' : 'not found'));
        error_log("DEBUG: VLC detection: vlcRunning=" . ($vlcRunning ? 'true' : 'false') . ", ffmpeg=" . (shell_exec("which ffmpeg 2>/dev/null") ? 'found' : 'not found'));
        if ($vlcRunning && shell_exec("which ffmpeg 2>/dev/null")) {
            $this->availableMethods[] = 'ffmpeg-vlc';
            logMessage("Added ffmpeg-vlc to available methods");

            // Vérifier si VLC utilise DRM (pas de X11) - dans ce cas, ffmpeg-vlc est la seule solution viable
            $noX11 = !$vlcRunning || getenv('DISPLAY') === false;
            if ($noX11) {
                // En mode console/DRM, les méthodes framebuffer capturent le TTY, pas VLC
                // Prioriser ffmpeg-vlc et déplacer fbgrab/scrot en fallback
                logMessage("Mode console détecté avec VLC - Priorisation ffmpeg-vlc pour capturer le contenu vidéo réel");
            }
        }

        // Détection spéciale pour GNOME D-Bus
        if (shell_exec("gdbus introspect --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot 2>/dev/null | grep -q Screenshot")) {
            $this->availableMethods[] = 'gnome-screenshot';
        }

        foreach ($methods as $name => $path) {
            if ($name === 'gnome-screenshot' || $name === 'ffmpeg-vlc') continue; // Déjà traité

            if (file_exists($path) && is_executable($path)) {
                $this->availableMethods[] = $name;
            } elseif (shell_exec("which $name 2>/dev/null")) {
                $this->availableMethods[] = $name;
            }
        }

        // Prioriser grim et gnome-screenshot pour Wayland
        if ($isWayland && in_array('grim', $this->availableMethods)) {
            $this->availableMethods = array_diff($this->availableMethods, ['grim']);
            array_unshift($this->availableMethods, 'grim');
        }

        // Prioriser ffmpeg-vlc en mode console quand VLC est actif
        $noX11 = getenv('DISPLAY') === false || getenv('DISPLAY') === '';
        if ($vlcRunning && $noX11 && in_array('ffmpeg-vlc', $this->availableMethods)) {
            $this->availableMethods = array_diff($this->availableMethods, ['ffmpeg-vlc']);
            array_unshift($this->availableMethods, 'ffmpeg-vlc');
            logMessage("Mode console avec VLC actif - ffmpeg-vlc priorisé");
        }

        logMessage("Méthodes de capture détectées (Wayland=$isWayland, VLC=$vlcRunning, Console=$noX11): " . implode(', ', $this->availableMethods));
    }

    /**
     * Vérifie le rate limiting
     */
    private function checkRateLimit() {
        if (!file_exists($this->lastCaptureFile)) {
            return true;
        }

        $lastCapture = intval(file_get_contents($this->lastCaptureFile));
        $timeSinceLastCapture = time() - $lastCapture;

        return $timeSinceLastCapture >= SCREENSHOT_RATE_LIMIT;
    }

    /**
     * Met à jour le timestamp de dernière capture
     */
    private function updateLastCaptureTime() {
        file_put_contents($this->lastCaptureFile, time());
    }

    /**
     * Nettoie le cache si nécessaire
     */
    private function cleanupCache() {
        $files = glob($this->cacheDir . '/screenshot_*.{png,jpg,jpeg}', GLOB_BRACE);
        if (empty($files)) return;

        // Taille totale du cache
        $totalSize = 0;
        $fileData = [];

        foreach ($files as $file) {
            $size = filesize($file);
            $mtime = filemtime($file);
            $totalSize += $size;
            $fileData[] = ['file' => $file, 'size' => $size, 'mtime' => $mtime];
        }

        // Si cache trop volumineux, supprime les plus anciens
        if ($totalSize > SCREENSHOT_MAX_CACHE_SIZE) {
            usort($fileData, function($a, $b) {
                return $a['mtime'] - $b['mtime'];
            });

            $removedSize = 0;
            foreach ($fileData as $data) {
                if ($totalSize - $removedSize <= SCREENSHOT_MAX_CACHE_SIZE * 0.8) {
                    break;
                }
                unlink($data['file']);
                $removedSize += $data['size'];
            }

            logMessage("Cache nettoyé: {$removedSize} bytes supprimés");
        }
    }

    /**
     * Génère le nom de fichier pour la capture
     */
    private function generateFilename($format = 'png', $quality = null) {
        $timestamp = date('YmdHis');
        $qualityStr = $quality ? "_q{$quality}" : '';
        return "screenshot_{$timestamp}{$qualityStr}.{$format}";
    }

    /**
     * Capture avec raspi2png (méthode optimale pour Raspberry Pi)
     */
    private function captureWithRaspi2png($outputFile, $quality = null) {
        $cmd = "raspi2png -p '$outputFile'";

        // raspi2png ne supporte pas la qualité directement
        $result = executeCommand($cmd);

        if ($result['success'] && file_exists($outputFile)) {
            // Si qualité spécifiée et différente de 100, recompresse avec convert
            if ($quality && $quality < 100 && shell_exec('which convert 2>/dev/null')) {
                $tempFile = $outputFile . '.tmp';
                $convertCmd = "convert '$outputFile' -quality $quality '$tempFile' && mv '$tempFile' '$outputFile'";
                executeCommand($convertCmd);
            }
            return ['success' => true, 'method' => 'raspi2png', 'time' => 0.025];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Capture avec scrot
     */
    private function captureWithScrot($outputFile, $quality = null) {
        $qualityParam = $quality ? " -q $quality" : '';
        $cmd = "scrot$qualityParam '$outputFile'";

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($outputFile)) {
            return ['success' => true, 'method' => 'scrot', 'time' => $duration];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Capture avec fbgrab
     */
    private function captureWithFbgrab($outputFile, $quality = null) {
        // fbgrab produit toujours du PNG, conversion si nécessaire
        $tempFile = $outputFile;
        if (pathinfo($outputFile, PATHINFO_EXTENSION) !== 'png') {
            $tempFile = $this->cacheDir . '/temp_' . basename($outputFile, '.' . pathinfo($outputFile, PATHINFO_EXTENSION)) . '.png';
        }

        $cmd = "fbgrab '$tempFile'";

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($tempFile)) {
            // Conversion si format différent ou qualité spécifiée
            if ($tempFile !== $outputFile || ($quality && $quality < 100)) {
                if (shell_exec('which convert 2>/dev/null')) {
                    $qualityParam = $quality ? " -quality $quality" : '';
                    $convertCmd = "convert '$tempFile'$qualityParam '$outputFile'";
                    $convertResult = executeCommand($convertCmd);

                    if ($tempFile !== $outputFile) {
                        unlink($tempFile);
                    }

                    if (!$convertResult['success']) {
                        return ['success' => false, 'error' => 'Conversion failed: ' . implode(' ', $convertResult['output'])];
                    }
                } else {
                    if ($tempFile !== $outputFile) {
                        rename($tempFile, $outputFile);
                    }
                }
            }

            return ['success' => true, 'method' => 'fbgrab', 'time' => $duration];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Capture avec ImageMagick import
     */
    private function captureWithImport($outputFile, $quality = null) {
        $qualityParam = $quality ? " -quality $quality" : '';
        $cmd = "import -window root$qualityParam '$outputFile'";

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($outputFile)) {
            return ['success' => true, 'method' => 'import', 'time' => $duration];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Capture avec grim (Wayland standard)
     */
    private function captureWithGrim($outputFile, $quality = null) {
        $format = pathinfo($outputFile, PATHINFO_EXTENSION);
        $cmd = "grim";

        // Format et qualité
        if ($format === 'jpg' || $format === 'jpeg') {
            $cmd .= " -t jpeg";
            if ($quality) {
                $cmd .= " -q $quality";
            }
        } elseif ($format === 'png') {
            $cmd .= " -t png";
            // PNG utilise la compression, pas la qualité (0-9, 9 = max compression)
            if ($quality) {
                // Convertir la qualité (0-100) en compression (9-0)
                $compression = 9 - floor($quality / 11);
                $cmd .= " -l $compression";
            }
        }

        $cmd .= " '$outputFile'";

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($outputFile)) {
            return ['success' => true, 'method' => 'grim', 'time' => $duration];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Capture avec FFmpeg depuis VLC
     */
    private function captureWithFfmpegVlc($outputFile, $quality = null) {
        // Vérifier si VLC est actif via HTTP
        $vlcStatus = shell_exec("curl -s --user ':pisignage' 'http://localhost:8080/requests/status.json' 2>/dev/null");
        if (!$vlcStatus) {
            return ['success' => false, 'error' => 'VLC HTTP interface not accessible'];
        }

        $status = json_decode($vlcStatus, true);
        if (!$status || !isset($status['information']['category']['meta']['filename'])) {
            return ['success' => false, 'error' => 'No video file currently playing in VLC'];
        }

        $filename = $status['information']['category']['meta']['filename'];

        // Construire le chemin complet du fichier
        $videoFile = "/opt/pisignage/media/" . $filename;
        if (!file_exists($videoFile)) {
            return ['success' => false, 'error' => 'Video file not found: ' . $videoFile];
        }

        // Obtenir la position actuelle de lecture
        $currentTime = intval($status['time'] ?? 0);

        // Capturer à la position actuelle ou proche
        $seekTime = max(0, $currentTime);
        $qualityParam = $quality ? 100 - $quality : 2; // FFmpeg utilise une échelle inversée (2=haute qualité)

        $cmd = sprintf(
            "ffmpeg -ss %d -i %s -vframes 1 -q:v %d %s -y 2>&1",
            $seekTime,
            escapeshellarg($videoFile),
            $qualityParam,
            escapeshellarg($outputFile)
        );

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($outputFile) && filesize($outputFile) > 1000) {
            return ['success' => true, 'method' => 'ffmpeg-vlc', 'time' => $duration];
        }

        $errorOutput = $result['output'] ?? 'Unknown error';
        if (is_array($errorOutput)) {
            $errorOutput = implode(' ', $errorOutput);
        }
        return ['success' => false, 'error' => 'FFmpeg capture failed: ' . $errorOutput];
    }

    /**
     * Capture avec GNOME D-Bus (compatible Wayland)
     */
    private function captureWithGnomeScreenshot($outputFile, $quality = null) {
        // Génération d'un nom temporaire pour GNOME
        $tempFile = "/tmp/gnome_screenshot_" . uniqid() . ".png";

        $cmd = "gdbus call --session " .
               "--dest org.gnome.Shell.Screenshot " .
               "--object-path /org/gnome/Shell/Screenshot " .
               "--method org.gnome.Shell.Screenshot.Screenshot " .
               "true false '$tempFile'";

        $startTime = microtime(true);
        $result = executeCommand($cmd);
        $duration = microtime(true) - $startTime;

        if ($result['success'] && file_exists($tempFile)) {
            // Conversion si nécessaire
            if ($tempFile !== $outputFile || ($quality && $quality < 100)) {
                if (shell_exec('which convert 2>/dev/null')) {
                    $qualityParam = $quality ? " -quality $quality" : '';
                    $convertCmd = "convert '$tempFile'$qualityParam '$outputFile'";
                    $convertResult = executeCommand($convertCmd);
                    unlink($tempFile);

                    if (!$convertResult['success']) {
                        return ['success' => false, 'error' => 'Conversion failed'];
                    }
                } else {
                    rename($tempFile, $outputFile);
                }
            } else {
                rename($tempFile, $outputFile);
            }

            return ['success' => true, 'method' => 'gnome-screenshot', 'time' => $duration];
        }

        return ['success' => false, 'error' => $result['output']];
    }

    /**
     * Effectue la capture d'écran
     */
    public function capture($options = []) {
        // Validation du rate limiting
        if (!$this->checkRateLimit()) {
            $remainingTime = SCREENSHOT_RATE_LIMIT - (time() - intval(file_get_contents($this->lastCaptureFile)));
            return [
                'success' => false,
                'error' => 'Rate limit exceeded',
                'message' => "Veuillez attendre {$remainingTime} secondes avant la prochaine capture",
                'retry_after' => $remainingTime
            ];
        }

        // Paramètres par défaut
        $format = $options['format'] ?? 'png';
        $quality = $options['quality'] ?? SCREENSHOT_QUALITY_DEFAULT;
        $method = $options['method'] ?? 'auto';
        $returnBase64 = $options['base64'] ?? false;

        // Validation des paramètres
        if (!in_array($format, ['png', 'jpg', 'jpeg'])) {
            return ['success' => false, 'error' => 'Format non supporté. Utilisez: png, jpg, jpeg'];
        }

        if ($quality < SCREENSHOT_QUALITY_MIN || $quality > SCREENSHOT_QUALITY_MAX) {
            return ['success' => false, 'error' => "Qualité doit être entre " . SCREENSHOT_QUALITY_MIN . " et " . SCREENSHOT_QUALITY_MAX];
        }

        // Détermination de la méthode à utiliser
        $methodsToTry = [];
        if ($method === 'auto') {
            $methodsToTry = $this->availableMethods;
        } elseif (in_array($method, $this->availableMethods)) {
            $methodsToTry = [$method];
        } else {
            return ['success' => false, 'error' => "Méthode '$method' non disponible. Disponibles: " . implode(', ', $this->availableMethods)];
        }

        if (empty($methodsToTry)) {
            return ['success' => false, 'error' => 'Aucune méthode de capture disponible'];
        }

        // Génération du fichier de sortie
        $filename = $this->generateFilename($format, $quality);
        $outputFile = $this->cacheDir . '/' . $filename;

        // Tentative de capture avec les méthodes disponibles
        $lastError = '';
        $captureInfo = null;

        foreach ($methodsToTry as $currentMethod) {
            logMessage("Tentative de capture avec: $currentMethod");

            switch ($currentMethod) {
                case 'ffmpeg-vlc':
                    $result = $this->captureWithFfmpegVlc($outputFile, $quality);
                    break;
                case 'grim':
                    $result = $this->captureWithGrim($outputFile, $quality);
                    break;
                case 'gnome-screenshot':
                    $result = $this->captureWithGnomeScreenshot($outputFile, $quality);
                    break;
                case 'raspi2png':
                    $result = $this->captureWithRaspi2png($outputFile, $quality);
                    break;
                case 'scrot':
                    $result = $this->captureWithScrot($outputFile, $quality);
                    break;
                case 'fbgrab':
                    $result = $this->captureWithFbgrab($outputFile, $quality);
                    break;
                case 'import':
                    $result = $this->captureWithImport($outputFile, $quality);
                    break;
                default:
                    continue 2;
            }

            if ($result['success']) {
                $captureInfo = $result;
                break;
            } else {
                $lastError = $result['error'];
                logMessage("Échec capture avec $currentMethod: " . $lastError, 'WARNING');
            }
        }

        if (!$captureInfo) {
            return [
                'success' => false,
                'error' => 'Toutes les méthodes de capture ont échoué',
                'last_error' => $lastError,
                'tried_methods' => $methodsToTry
            ];
        }

        // Vérification finale du fichier
        if (!file_exists($outputFile) || filesize($outputFile) === 0) {
            return ['success' => false, 'error' => 'Fichier de capture vide ou inexistant'];
        }

        // Mise à jour du rate limiting
        $this->updateLastCaptureTime();

        // Informations sur le fichier
        $fileInfo = [
            'filename' => $filename,
            'size' => filesize($outputFile),
            'format' => $format,
            'quality' => $quality,
            'method' => $captureInfo['method'],
            'capture_time' => round($captureInfo['time'], 3),
            'url' => '/screenshots/' . $filename
        ];

        // Copie vers le dossier screenshots permanent si différent du cache
        $permanentFile = SCREENSHOTS_PATH . '/' . $filename;
        if ($this->cacheDir !== SCREENSHOTS_PATH) {
            copy($outputFile, $permanentFile);
            $fileInfo['permanent_url'] = '/screenshots/' . $filename;
        }

        // Encodage base64 si demandé
        if ($returnBase64) {
            $imageData = file_get_contents($outputFile);
            $mimeType = $format === 'png' ? 'image/png' : 'image/jpeg';
            $fileInfo['base64'] = 'data:' . $mimeType . ';base64,' . base64_encode($imageData);
        }

        logMessage("Capture réussie: {$filename} ({$fileInfo['size']} bytes) avec {$captureInfo['method']} en {$captureInfo['time']}s");

        return [
            'success' => true,
            'data' => $fileInfo,
            'message' => 'Capture d\'écran réussie'
        ];
    }

    /**
     * Liste les captures récentes
     */
    public function listRecent($limit = 10) {
        $files = glob($this->cacheDir . '/screenshot_*.{png,jpg,jpeg}', GLOB_BRACE);
        $screenshots = [];

        foreach ($files as $file) {
            $screenshots[] = [
                'filename' => basename($file),
                'size' => filesize($file),
                'created' => filemtime($file),
                'url' => '/screenshots/' . basename($file)
            ];
        }

        // Tri par date décroissante
        usort($screenshots, function($a, $b) {
            return $b['created'] - $a['created'];
        });

        return array_slice($screenshots, 0, $limit);
    }

    /**
     * Retourne les informations sur les méthodes disponibles
     */
    public function getMethodsInfo() {
        $info = [];
        $isWayland = getenv('WAYLAND_DISPLAY') !== false ||
                     strpos(shell_exec('echo $XDG_SESSION_TYPE 2>/dev/null') ?: '', 'wayland') !== false;

        foreach ($this->availableMethods as $method) {
            switch ($method) {
                case 'ffmpeg-vlc':
                    $info[$method] = [
                        'name' => 'FFmpeg-VLC',
                        'description' => 'Capture du contenu vidéo VLC via FFmpeg',
                        'speed' => 'Rapide',
                        'quality' => 'Excellente',
                        'recommended' => true
                    ];
                    break;
                case 'grim':
                    $info[$method] = [
                        'name' => 'grim',
                        'description' => 'Capture native Wayland',
                        'speed' => 'Très rapide',
                        'quality' => 'Excellente',
                        'recommended' => $isWayland
                    ];
                    break;
                case 'gnome-screenshot':
                    $info[$method] = [
                        'name' => 'GNOME Screenshot',
                        'description' => 'Capture GNOME via D-Bus (Wayland/X11)',
                        'speed' => 'Rapide',
                        'quality' => 'Excellente',
                        'recommended' => $isWayland
                    ];
                    break;
                case 'raspi2png':
                    $info[$method] = [
                        'name' => 'raspi2png',
                        'description' => 'Capture GPU optimisée Raspberry Pi',
                        'speed' => 'Très rapide (~25ms)',
                        'quality' => 'Excellente',
                        'recommended' => !$isWayland
                    ];
                    break;
                case 'scrot':
                    $info[$method] = [
                        'name' => 'scrot',
                        'description' => 'Capture X11 universelle',
                        'speed' => 'Rapide',
                        'quality' => 'Bonne',
                        'recommended' => false
                    ];
                    break;
                case 'fbgrab':
                    $info[$method] = [
                        'name' => 'fbgrab',
                        'description' => 'Capture framebuffer direct',
                        'speed' => 'Moyenne',
                        'quality' => 'Bonne',
                        'recommended' => false
                    ];
                    break;
                case 'import':
                    $info[$method] = [
                        'name' => 'ImageMagick import',
                        'description' => 'Capture via ImageMagick',
                        'speed' => 'Lente',
                        'quality' => 'Excellente',
                        'recommended' => false
                    ];
                    break;
            }
        }
        return $info;
    }
}

// === TRAITEMENT DE LA REQUÊTE ===

try {
    $screenshotManager = new ScreenshotManager();

    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            $action = $_GET['action'] ?? 'capture';

            switch ($action) {
                case 'capture':
                    // Paramètres de capture
                    $options = [
                        'format' => $_GET['format'] ?? 'png',
                        'quality' => intval($_GET['quality'] ?? SCREENSHOT_QUALITY_DEFAULT),
                        'method' => $_GET['method'] ?? 'auto',
                        'base64' => isset($_GET['base64']) && $_GET['base64'] !== 'false'
                    ];

                    $result = $screenshotManager->capture($options);
                    jsonResponse($result['success'], $result['data'] ?? null, $result['message'] ?? $result['error'] ?? null);
                    break;

                case 'list':
                    $limit = intval($_GET['limit'] ?? 10);
                    $screenshots = $screenshotManager->listRecent($limit);
                    jsonResponse(true, $screenshots, "Liste des {$limit} dernières captures");
                    break;

                case 'methods':
                    $methods = $screenshotManager->getMethodsInfo();
                    jsonResponse(true, $methods, 'Méthodes de capture disponibles');
                    break;

                case 'status':
                    $status = [
                        'available_methods' => $screenshotManager->getMethodsInfo(),
                        'rate_limit_seconds' => SCREENSHOT_RATE_LIMIT,
                        'cache_dir' => SCREENSHOT_CACHE_DIR,
                        'quality_range' => [SCREENSHOT_QUALITY_MIN, SCREENSHOT_QUALITY_MAX],
                        'supported_formats' => ['png', 'jpg', 'jpeg']
                    ];
                    jsonResponse(true, $status, 'Configuration de l\'API screenshot');
                    break;

                default:
                    jsonResponse(false, null, 'Action non reconnue. Actions disponibles: capture, list, methods, status');
            }
            break;

        case 'POST':
            // POST pour capture avec paramètres dans le body
            $input = json_decode(file_get_contents('php://input'), true);

            $options = [
                'format' => $input['format'] ?? 'png',
                'quality' => intval($input['quality'] ?? SCREENSHOT_QUALITY_DEFAULT),
                'method' => $input['method'] ?? 'auto',
                'base64' => $input['base64'] ?? false
            ];

            $result = $screenshotManager->capture($options);
            jsonResponse($result['success'], $result['data'] ?? null, $result['message'] ?? $result['error'] ?? null);
            break;

        default:
            jsonResponse(false, null, 'Méthode HTTP non supportée. Utilisez GET ou POST.');
    }

} catch (Exception $e) {
    logMessage("Erreur dans l'API screenshot: " . $e->getMessage(), 'ERROR');
    jsonResponse(false, null, 'Erreur interne du serveur');
}
?>