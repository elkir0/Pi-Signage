<?php
/**
 * PiSignage v0.8.0 - API Screenshot Simplifiée
 * Ne garde qu'une seule capture à la fois pour éviter saturation disque
 */

require_once dirname(__DIR__) . '/config.php';

// Configuration
define('SCREENSHOT_FILE', SCREENSHOTS_PATH . '/current_screenshot.jpg');
define('SCREENSHOT_QUALITY', 75);

/**
 * Prend une capture d'écran avec la meilleure méthode disponible
 */
function takeScreenshot() {
    $tempFile = '/tmp/pisignage_screenshot_' . getmypid() . '.png';
    $captured = false;
    $method = 'none';

    // Essayer scrot d'abord (plus universel avec X11)
    if (shell_exec('which scrot 2>/dev/null')) {
        $cmd = "DISPLAY=:0 scrot -q 100 '$tempFile' 2>/dev/null";
        exec($cmd, $output, $returnCode);
        if ($returnCode === 0 && file_exists($tempFile)) {
            $captured = true;
            $method = 'scrot';
        }
    }

    // Essayer import si scrot échoue
    if (!$captured && shell_exec('which import 2>/dev/null')) {
        $cmd = "DISPLAY=:0 import -window root '$tempFile' 2>/dev/null";
        exec($cmd, $output, $returnCode);
        if ($returnCode === 0 && file_exists($tempFile)) {
            $captured = true;
            $method = 'import';
        }
    }

    // Essayer fbcat/fbgrab en dernier recours
    if (!$captured && shell_exec('which fbcat 2>/dev/null')) {
        $cmd = "fbcat > '$tempFile' 2>/dev/null";
        exec($cmd, $output, $returnCode);
        if ($returnCode === 0 && file_exists($tempFile)) {
            $captured = true;
            $method = 'fbcat';
        }
    }

    // Si capture réussie, convertir en JPEG optimisé
    if ($captured && file_exists($tempFile)) {
        // Créer le dossier screenshots si nécessaire
        if (!file_exists(SCREENSHOTS_PATH)) {
            mkdir(SCREENSHOTS_PATH, 0755, true);
        }

        // Convertir et optimiser en JPEG
        if (shell_exec('which convert 2>/dev/null')) {
            $cmd = sprintf(
                "convert '%s' -quality %d -resize '1280x720>' '%s' 2>/dev/null",
                $tempFile,
                SCREENSHOT_QUALITY,
                SCREENSHOT_FILE
            );
            exec($cmd);
        } else {
            // Simple copie si pas de convert
            copy($tempFile, SCREENSHOT_FILE);
        }

        // Nettoyer le fichier temporaire
        unlink($tempFile);

        if (file_exists(SCREENSHOT_FILE)) {
            return [
                'success' => true,
                'method' => $method,
                'file' => basename(SCREENSHOT_FILE),
                'size' => filesize(SCREENSHOT_FILE),
                'timestamp' => time()
            ];
        }
    }

    return [
        'success' => false,
        'error' => 'Impossible de capturer l\'écran',
        'method_tried' => $method
    ];
}

// Traitement de la requête
$action = $_GET['action'] ?? 'capture';

switch ($action) {
    case 'capture':
        $result = takeScreenshot();
        if ($result['success']) {
            jsonResponse(true, [
                'url' => '/screenshots/' . $result['file'],
                'size' => $result['size'],
                'method' => $result['method'],
                'timestamp' => $result['timestamp']
            ], 'Capture réussie');
        } else {
            jsonResponse(false, null, $result['error']);
        }
        break;

    case 'get':
        // Retourner la capture actuelle si elle existe
        if (file_exists(SCREENSHOT_FILE)) {
            jsonResponse(true, [
                'url' => '/screenshots/' . basename(SCREENSHOT_FILE),
                'size' => filesize(SCREENSHOT_FILE),
                'modified' => filemtime(SCREENSHOT_FILE),
                'age' => time() - filemtime(SCREENSHOT_FILE)
            ], 'Capture actuelle');
        } else {
            jsonResponse(false, null, 'Aucune capture disponible');
        }
        break;

    case 'image':
        // Retourner directement l'image
        if (file_exists(SCREENSHOT_FILE)) {
            header('Content-Type: image/jpeg');
            header('Cache-Control: no-cache, no-store, must-revalidate');
            header('Pragma: no-cache');
            header('Expires: 0');
            readfile(SCREENSHOT_FILE);
            exit;
        } else {
            http_response_code(404);
            jsonResponse(false, null, 'Aucune capture disponible');
        }
        break;

    default:
        jsonResponse(false, null, 'Action non reconnue. Actions disponibles: capture, get, image');
}
?>