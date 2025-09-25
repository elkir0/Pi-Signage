<?php
header('Content-Type: application/json');

// Chemins
define('SCRIPTS_PATH', '/opt/pisignage/scripts');
define('MEDIA_PATH', '/opt/pisignage/media');
define('LOGS_PATH', '/opt/pisignage/logs');

// Fonction pour exécuter une commande en tant que pi
function executeAsUser($cmd) {
    $fullCmd = "sudo -u pi bash -c 'export XDG_RUNTIME_DIR=/run/user/1000; export DISPLAY=:0; " . $cmd . "'";
    exec($fullCmd . " 2>&1", $output, $retval);
    return ['output' => $output, 'retval' => $retval];
}

// Récupération de la méthode et des données
$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true) ?: $_REQUEST;

switch ($method) {
    case 'GET':
        // Status du player
        $status = [
            'vlc' => false,
            'mpv' => false,
            'current' => 'none'
        ];

        // Check VLC
        exec("ps aux | grep -v grep | grep vlc 2>/dev/null", $vlcOutput);
        $status['vlc'] = !empty($vlcOutput);

        // Check MPV
        exec("ps aux | grep -v grep | grep mpv 2>/dev/null", $mpvOutput);
        $status['mpv'] = !empty($mpvOutput);

        // Déterminer le player actuel
        if ($status['vlc']) {
            $status['current'] = 'vlc';
        } elseif ($status['mpv']) {
            $status['current'] = 'mpv';
        }

        echo json_encode(['success' => true, 'status' => $status]);
        break;

    case 'POST':
        $action = $input['action'] ?? '';
        $success = false;
        $message = '';

        switch ($action) {
            case 'start':
                // Démarrer le player
                $result = executeAsUser('/opt/pisignage/scripts/start-video.sh');
                $success = ($result['retval'] === 0);
                $message = !empty($result['output']) ? implode("\n", $result['output']) : 'Player started';
                break;

            case 'stop':
                // Arrêter tous les players
                exec("pkill -9 vlc 2>/dev/null");
                exec("pkill -9 mpv 2>/dev/null");
                exec("pkill -9 feh 2>/dev/null");
                $success = true;
                $message = 'All players stopped';
                break;

            case 'restart':
                // Redémarrer le player
                exec("pkill -9 vlc 2>/dev/null");
                exec("pkill -9 mpv 2>/dev/null");
                sleep(1);
                $result = executeAsUser('/opt/pisignage/scripts/start-video.sh');
                $success = ($result['retval'] === 0);
                $message = 'Player restarted';
                break;

            case 'switch':
            case 'switch_player':
                // Basculer entre VLC et MPV
                exec("ps aux | grep -v grep | grep vlc 2>/dev/null", $vlcRunning);

                if (!empty($vlcRunning)) {
                    // VLC tourne, passer à MPV
                    exec("pkill -9 vlc 2>/dev/null");
                    sleep(1);
                    $cmd = "export LIBGL_ALWAYS_SOFTWARE=1; mpv --vo=x11 --hwdec=no --fullscreen --loop-playlist=inf /opt/pisignage/media/*.mp4 > /opt/pisignage/logs/mpv.log 2>&1 &";
                    $result = executeAsUser($cmd);
                    $message = 'Switched to MPV';
                } else {
                    // MPV tourne ou rien, passer à VLC
                    exec("pkill -9 mpv 2>/dev/null");
                    sleep(1);
                    $cmd = "cvlc --intf dummy --vout x11 --fullscreen --loop /opt/pisignage/media/*.mp4 > /opt/pisignage/logs/vlc.log 2>&1 &";
                    $result = executeAsUser($cmd);
                    $message = 'Switched to VLC';
                }
                $success = true;
                break;

            case 'play-file':
            case 'play_file':
                $filename = basename($input['file'] ?? '');
                if (empty($filename)) {
                    echo json_encode(['success' => false, 'message' => 'File required']);
                    exit;
                }

                $filepath = MEDIA_PATH . '/' . $filename;
                if (!file_exists($filepath)) {
                    echo json_encode(['success' => false, 'message' => 'File not found']);
                    exit;
                }

                // Arrêter les players actuels
                exec("pkill -9 vlc 2>/dev/null");
                exec("pkill -9 mpv 2>/dev/null");
                sleep(1);

                // Lancer avec VLC (plus fiable)
                $cmd = "cvlc --intf dummy --vout x11 --fullscreen --loop --no-video-title-show '" . escapeshellcmd($filepath) . "' > /opt/pisignage/logs/vlc.log 2>&1 &";
                $result = executeAsUser($cmd);

                $success = true;
                $message = "Playing: $filename";
                break;

            case 'screenshot':
                // Prendre une capture d'écran
                $cmd = "scrot /tmp/screenshot.png 2>/dev/null && echo 'OK' || (sudo fbgrab /tmp/screenshot.png 2>/dev/null && echo 'OK')";
                $result = executeAsUser($cmd);

                if (file_exists('/tmp/screenshot.png')) {
                    $success = true;
                    $message = 'Screenshot taken';
                } else {
                    $success = false;
                    $message = 'Failed to take screenshot';
                }
                break;

            default:
                $message = 'Unknown action: ' . $action;
                break;
        }

        echo json_encode(['success' => $success, 'message' => $message]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
        break;
}
?>