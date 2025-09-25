<?php
/**
 * PiSignage - API Screenshot Corrigée
 * Capture correcte de l'écran avec détection X11/Framebuffer
 */

header('Content-Type: application/json');

// Configuration
define('SCREENSHOTS_PATH', '/opt/pisignage/screenshots');
define('WEB_SCREENSHOTS_PATH', '/screenshots');
define('MAX_QUALITY', 95);
define('DEFAULT_QUALITY', 85);

// Créer le dossier si nécessaire
if (!file_exists(SCREENSHOTS_PATH)) {
    @mkdir(SCREENSHOTS_PATH, 0755, true);
}

/**
 * Détecte si X11 est actif
 */
function isX11Active() {
    exec("ps aux | grep -v grep | grep Xorg 2>/dev/null", $output);
    return !empty($output);
}

/**
 * Capture d'écran avec la méthode appropriée
 */
function captureScreenshot($filename) {
    $success = false;
    $method = 'unknown';

    // Si X11 est actif, utiliser scrot en priorité
    if (isX11Active()) {
        // Copier Xauthority pour www-data
        exec("sudo cp /home/pi/.Xauthority /tmp/.Xauthority 2>/dev/null");
        exec("sudo chmod 644 /tmp/.Xauthority 2>/dev/null");

        // Essayer scrot (capture X11)
        if (file_exists('/usr/bin/scrot')) {
            $cmd = "export XAUTHORITY=/tmp/.Xauthority; DISPLAY=:0 scrot -q 90 '$filename' 2>&1";
            exec($cmd, $output, $retval);
            if ($retval === 0 && file_exists($filename)) {
                $success = true;
                $method = 'scrot';
            }
        }

        // Si scrot échoue, essayer import (ImageMagick)
        if (!$success && file_exists('/usr/bin/import')) {
            $cmd = "export XAUTHORITY=/tmp/.Xauthority; DISPLAY=:0 import -window root '$filename' 2>&1";
            exec($cmd, $output, $retval);
            if ($retval === 0 && file_exists($filename)) {
                $success = true;
                $method = 'import';
            }
        }
    }

    // Si pas X11 ou échec, utiliser raspi2png (hardware)
    if (!$success && file_exists('/usr/bin/raspi2png')) {
        $cmd = "sudo raspi2png -p '$filename' 2>&1";
        exec($cmd, $output, $retval);
        if ($retval === 0 && file_exists($filename)) {
            $success = true;
            $method = 'raspi2png';
        }
    }

    // Fallback sur fbgrab (framebuffer)
    if (!$success && file_exists('/usr/bin/fbgrab')) {
        $cmd = "sudo fbgrab -d /dev/fb0 '$filename' 2>&1";
        exec($cmd, $output, $retval);
        if ($retval === 0 && file_exists($filename)) {
            $success = true;
            $method = 'fbgrab';
        }
    }

    return ['success' => $success, 'method' => $method];
}

// Traitement de la requête
$timestamp = date('Ymd_His');
$filename = "screenshot_{$timestamp}.png";
$filepath = SCREENSHOTS_PATH . '/' . $filename;

// Nettoyer les vieux screenshots (garder seulement les 10 derniers)
$screenshots = glob(SCREENSHOTS_PATH . '/screenshot_*.png');
if (count($screenshots) > 10) {
    usort($screenshots, function($a, $b) {
        return filemtime($a) - filemtime($b);
    });
    $toDelete = array_slice($screenshots, 0, count($screenshots) - 10);
    foreach ($toDelete as $file) {
        @unlink($file);
    }
}

// Capturer
$result = captureScreenshot($filepath);

if ($result['success']) {
    $size = filesize($filepath);
    $url = WEB_SCREENSHOTS_PATH . '/' . $filename;

    echo json_encode([
        'success' => true,
        'data' => [
            'filename' => $filename,
            'size' => $size,
            'format' => 'png',
            'method' => $result['method'],
            'url' => $url,
            'x11_active' => isX11Active()
        ],
        'message' => "Capture d'écran réussie ({$result['method']})",
        'timestamp' => date('Y-m-d H:i:s')
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Échec de la capture d\'écran',
        'x11_active' => isX11Active()
    ]);
}
?>