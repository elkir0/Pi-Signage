<?php
/**
 * PiSignage v0.8.1 - Optimized Screenshot API with raspi2png
 * Hardware-accelerated capture for Raspberry Pi
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Fonction de réponse JSON
function jsonResponse($success, $data = null, $message = null) {
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message
    ]);
    exit;
}

// Configuration
$CACHE_DIR = '/dev/shm/pisignage-screenshots';
$SCREENSHOT_FILE = $CACHE_DIR . '/latest.jpg';
$RATE_LIMIT = 5; // secondes entre captures
$LAST_CAPTURE_FILE = $CACHE_DIR . '/.last_capture';

// Créer le dossier cache si nécessaire
if (!file_exists($CACHE_DIR)) {
    mkdir($CACHE_DIR, 0755, true);
}

// Fonction principale de capture
function captureScreen() {
    global $SCREENSHOT_FILE, $CACHE_DIR;

    $timestamp = date('Y-m-d_H-i-s');
    $tempFile = $CACHE_DIR . '/capture_' . $timestamp . '.png';

    // Méthodes de capture par ordre de priorité
    $methods = [
        'raspi2png' => "raspi2png -p '$tempFile' 2>&1",
        'fbgrab' => "fbgrab -d /dev/fb0 '$tempFile' 2>&1",
        'scrot' => "DISPLAY=:0 scrot '$tempFile' 2>&1",
        'import' => "DISPLAY=:0 import -window root '$tempFile' 2>&1"
    ];

    $captureSuccess = false;
    $usedMethod = '';
    $errorMessages = [];

    // Essayer chaque méthode
    foreach ($methods as $method => $command) {
        // Vérifier si l'outil existe
        exec("which $method 2>/dev/null", $output, $returnCode);
        if ($returnCode !== 0) {
            $errorMessages[] = "$method: not installed";
            continue;
        }

        // Essayer la capture
        exec($command, $output, $returnCode);
        if ($returnCode === 0 && file_exists($tempFile)) {
            $captureSuccess = true;
            $usedMethod = $method;
            break;
        } else {
            $errorMessages[] = "$method: " . implode(' ', $output);
        }
    }

    if (!$captureSuccess) {
        return [
            'success' => false,
            'error' => 'All capture methods failed',
            'details' => $errorMessages
        ];
    }

    // Convertir en JPEG avec qualité optimale
    $jpegFile = str_replace('.png', '.jpg', $tempFile);
    exec("convert '$tempFile' -quality 85 '$jpegFile' 2>&1", $output, $returnCode);

    if ($returnCode !== 0 || !file_exists($jpegFile)) {
        // Si convert échoue, garder le PNG
        $jpegFile = $tempFile;
    } else {
        // Supprimer le PNG temporaire
        @unlink($tempFile);
    }

    // Copier comme latest
    copy($jpegFile, $SCREENSHOT_FILE);

    // Nettoyer les anciennes captures (garder 10 dernières)
    cleanOldCaptures($CACHE_DIR);

    return [
        'success' => true,
        'method' => $usedMethod,
        'file' => $jpegFile,
        'size' => filesize($jpegFile),
        'timestamp' => time()
    ];
}

// Nettoyer les anciennes captures
function cleanOldCaptures($dir) {
    $files = glob($dir . '/capture_*.{jpg,png}', GLOB_BRACE);
    if (count($files) > 10) {
        usort($files, function($a, $b) {
            return filemtime($a) - filemtime($b);
        });
        for ($i = 0; $i < count($files) - 10; $i++) {
            @unlink($files[$i]);
        }
    }
}

// Vérifier le rate limiting
function checkRateLimit() {
    global $LAST_CAPTURE_FILE, $RATE_LIMIT;

    if (file_exists($LAST_CAPTURE_FILE)) {
        $lastCapture = intval(file_get_contents($LAST_CAPTURE_FILE));
        $timeSince = time() - $lastCapture;

        if ($timeSince < $RATE_LIMIT) {
            return $RATE_LIMIT - $timeSince;
        }
    }
    return 0;
}

// Traiter la requête
$action = $_GET['action'] ?? 'capture';

switch ($action) {
    case 'capture':
        // Vérifier le rate limiting
        $waitTime = checkRateLimit();
        if ($waitTime > 0) {
            jsonResponse(false, null, "Rate limited. Wait $waitTime seconds");
            break;
        }

        // Capturer l'écran
        $result = captureScreen();

        if ($result['success']) {
            // Mettre à jour le timestamp
            file_put_contents($LAST_CAPTURE_FILE, time());

            // Retourner l'image en base64 si demandé
            if (isset($_GET['base64']) && $_GET['base64'] === 'true') {
                $imageData = base64_encode(file_get_contents($SCREENSHOT_FILE));
                jsonResponse(true, [
                    'image' => 'data:image/jpeg;base64,' . $imageData,
                    'method' => $result['method'],
                    'size' => $result['size'],
                    'timestamp' => $result['timestamp']
                ]);
            } else {
                jsonResponse(true, [
                    'url' => '/api/screenshot-raspi2png.php?action=view&t=' . time(),
                    'method' => $result['method'],
                    'size' => $result['size'],
                    'timestamp' => $result['timestamp']
                ]);
            }
        } else {
            jsonResponse(false, $result);
        }
        break;

    case 'view':
        // Afficher la dernière capture
        if (file_exists($SCREENSHOT_FILE)) {
            $ext = pathinfo($SCREENSHOT_FILE, PATHINFO_EXTENSION);
            $contentType = ($ext === 'png') ? 'image/png' : 'image/jpeg';

            header("Content-Type: $contentType");
            header('Cache-Control: no-cache');
            readfile($SCREENSHOT_FILE);
            exit;
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'No screenshot available']);
        }
        break;

    case 'status':
        // Vérifier l'état du système
        $methods = [];
        foreach (['raspi2png', 'fbgrab', 'scrot', 'import', 'convert'] as $tool) {
            exec("which $tool 2>/dev/null", $output, $returnCode);
            $methods[$tool] = ($returnCode === 0);
        }

        $lastCapture = file_exists($SCREENSHOT_FILE) ? filemtime($SCREENSHOT_FILE) : null;

        jsonResponse(true, [
            'available_methods' => $methods,
            'cache_directory' => $CACHE_DIR,
            'last_capture' => $lastCapture ? date('Y-m-d H:i:s', $lastCapture) : null,
            'rate_limit' => $RATE_LIMIT . ' seconds',
            'cache_files' => count(glob($CACHE_DIR . '/capture_*.{jpg,png}', GLOB_BRACE))
        ]);
        break;

    case 'clear':
        // Nettoyer le cache
        $files = glob($CACHE_DIR . '/*');
        foreach ($files as $file) {
            if (is_file($file)) {
                unlink($file);
            }
        }
        jsonResponse(true, null, 'Cache cleared');
        break;

    default:
        jsonResponse(false, null, 'Unknown action: ' . $action);
}
?>