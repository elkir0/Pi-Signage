<?php
/*
===========================================
API MONITORING PERFORMANCE GPU - Pi 4
===========================================
Endpoint pour monitoring temps réel des performances GPU et FPS
Version: 1.0.0
Date: 2025-09-22
*/

require_once '../config.php';
require_once 'system.php';

// Configuration
$STATS_FILE = '/var/log/pisignage/fps-stats.json';
$LOG_FILE = '/var/log/pisignage/fps-monitoring.log';
$CSV_FILE = '/var/log/pisignage/fps-monitoring.log.csv';

/**
 * Récupérer statistiques GPU en temps réel
 */
function getGPUStats() {
    $stats = [];

    // Température GPU
    $temp = executeCommand('vcgencmd measure_temp');
    $stats['temperature'] = $temp ? (float)str_replace(['temp=', "'C"], '', $temp) : null;

    // Mémoire GPU
    $gpu_mem = executeCommand('vcgencmd get_mem gpu');
    $stats['memory_mb'] = $gpu_mem ? (int)str_replace(['gpu=', 'M'], '', $gpu_mem) : null;

    // Fréquences
    $arm_freq = executeCommand('vcgencmd measure_clock arm');
    $gpu_freq = executeCommand('vcgencmd measure_clock gpu');
    $stats['arm_frequency'] = $arm_freq ? (int)str_replace('frequency(48)=', '', $arm_freq) : null;
    $stats['gpu_frequency'] = $gpu_freq ? (int)str_replace('frequency(0)=', '', $gpu_freq) : null;

    // Voltage
    $voltage = executeCommand('vcgencmd measure_volts');
    $stats['voltage'] = $voltage ? (float)str_replace(['volt=', 'V'], '', $voltage) : null;

    return $stats;
}

/**
 * Récupérer statistiques système
 */

/**
 * Vérifier processus Chromium
 */
function getChromiumStats() {
    $stats = [];

    // PID Chromium
    $chromium_pid = executeCommand("pgrep -f chromium-browser | head -1");
    $stats['pid'] = $chromium_pid ? (int)$chromium_pid : null;
    $stats['running'] = $chromium_pid !== false;

    if ($chromium_pid) {
        // CPU et mémoire du processus Chromium
        $ps_stats = executeCommand("ps -p $chromium_pid -o %cpu,%mem,vsz,rss --no-headers");
        if ($ps_stats) {
            $ps_parts = preg_split('/\s+/', trim($ps_stats));
            $stats['cpu_percent'] = (float)$ps_parts[0];
            $stats['memory_percent'] = (float)$ps_parts[1];
            $stats['virtual_memory_kb'] = (int)$ps_parts[2];
            $stats['resident_memory_kb'] = (int)$ps_parts[3];
        }

        // Threads Chromium
        $threads = executeCommand("ls /proc/$chromium_pid/task | wc -l");
        $stats['threads'] = $threads ? (int)$threads : null;
    }

    return $stats;
}

/**
 * Lire dernières stats FPS si disponibles
 */
function getFPSStats() {
    global $STATS_FILE;

    if (file_exists($STATS_FILE)) {
        $content = file_get_contents($STATS_FILE);
        $data = json_decode($content, true);
        if (json_last_error() === JSON_ERROR_NONE) {
            return $data;
        }
    }

    return null;
}

/**
 * Lire historique CSV récent
 */
function getRecentHistory($limit = 20) {
    global $CSV_FILE;

    if (!file_exists($CSV_FILE)) {
        return [];
    }

    $lines = file($CSV_FILE, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (count($lines) <= 1) { // Seulement header ou vide
        return [];
    }

    // Récupérer les dernières lignes (sans header)
    $data_lines = array_slice($lines, 1); // Skip header
    $recent_lines = array_slice($data_lines, -$limit);

    $history = [];
    foreach ($recent_lines as $line) {
        $parts = str_getcsv($line);
        if (count($parts) >= 9) {
            $history[] = [
                'timestamp' => (int)$parts[0],
                'fps' => (int)$parts[1],
                'temperature' => (float)$parts[2],
                'gpu_memory' => (int)$parts[3],
                'arm_frequency' => (int)$parts[4],
                'gpu_frequency' => (int)$parts[5],
                'cpu_usage' => (float)$parts[6],
                'network_bandwidth' => (int)$parts[7],
                'frame_drops' => (int)$parts[8]
            ];
        }
    }

    return $history;
}

/**
 * Analyser santé générale du système
 */
function getHealthStatus($gpu_stats, $system_stats, $chromium_stats) {
    $issues = [];
    $warnings = [];

    // Vérifications critiques
    if (!$chromium_stats['running']) {
        $issues[] = 'Chromium non démarré';
    }

    if ($gpu_stats['temperature'] && $gpu_stats['temperature'] > 80) {
        $issues[] = 'Température GPU critique (>' . $gpu_stats['temperature'] . '°C)';
    } elseif ($gpu_stats['temperature'] && $gpu_stats['temperature'] > 75) {
        $warnings[] = 'Température GPU élevée (' . $gpu_stats['temperature'] . '°C)';
    }

    if ($system_stats['load_average']['1min'] > 4.0) {
        $issues[] = 'Charge système excessive (' . $system_stats['load_average']['1min'] . ')';
    } elseif ($system_stats['load_average']['1min'] > 3.0) {
        $warnings[] = 'Charge système élevée (' . $system_stats['load_average']['1min'] . ')';
    }

    if ($system_stats['memory']['used_percent'] > 90) {
        $issues[] = 'Mémoire critique (' . $system_stats['memory']['used_percent'] . '%)';
    } elseif ($system_stats['memory']['used_percent'] > 80) {
        $warnings[] = 'Mémoire élevée (' . $system_stats['memory']['used_percent'] . '%)';
    }

    // Déterminer status global
    $status = 'optimal';
    if (count($issues) > 0) {
        $status = 'critical';
    } elseif (count($warnings) > 0) {
        $status = 'warning';
    }

    return [
        'status' => $status,
        'issues' => $issues,
        'warnings' => $warnings,
        'score' => max(0, 100 - (count($issues) * 30) - (count($warnings) * 10))
    ];
}

// ===========================================
// ENDPOINTS API
// ===========================================

$method = $_SERVER['REQUEST_METHOD'];
$endpoint = $_GET['endpoint'] ?? 'current';

try {
    switch ($endpoint) {
        case 'current':
            // Stats temps réel complètes
            $response = [
                'timestamp' => time(),
                'iso_timestamp' => date('c'),
                'gpu' => getGPUStats(),
                'system' => getSystemStats(),
                'chromium' => getChromiumStats(),
                'fps_data' => getFPSStats()
            ];

            // Ajouter évaluation santé
            $response['health'] = getHealthStatus(
                $response['gpu'],
                $response['system'],
                $response['chromium']
            );

            break;

        case 'fps':
            // Seulement données FPS
            $response = getFPSStats();
            if (!$response) {
                $response = [
                    'error' => 'Aucune donnée FPS disponible',
                    'message' => 'Démarrer le monitoring avec monitor-fps.sh'
                ];
            }
            break;

        case 'history':
            // Historique récent
            $limit = (int)($_GET['limit'] ?? 20);
            $response = [
                'history' => getRecentHistory($limit),
                'count' => count(getRecentHistory($limit))
            ];
            break;

        case 'gpu':
            // Stats GPU uniquement
            $response = getGPUStats();
            break;

        case 'system':
            // Stats système uniquement
            $response = getSystemStats();
            break;

        case 'chromium':
            // Stats Chromium uniquement
            $response = getChromiumStats();
            break;

        case 'health':
            // Évaluation santé
            $gpu_stats = getGPUStats();
            $system_stats = getSystemStats();
            $chromium_stats = getChromiumStats();

            $response = getHealthStatus($gpu_stats, $system_stats, $chromium_stats);
            $response['timestamp'] = time();
            break;

        case 'start_monitoring':
            // Démarrer monitoring FPS (POST)
            if ($method !== 'POST') {
                throw new Exception('Méthode POST requise');
            }

            $duration = (int)($_POST['duration'] ?? 300);
            $threshold = (int)($_POST['threshold'] ?? 30);

            $command = "/opt/pisignage/scripts/monitor-fps.sh $duration $threshold > /dev/null 2>&1 &";
            $result = executeCommand($command);

            $response = [
                'success' => true,
                'message' => 'Monitoring FPS démarré',
                'duration' => $duration,
                'threshold' => $threshold
            ];
            break;

        default:
            throw new Exception('Endpoint non reconnu: ' . $endpoint);
    }

    // Réponse succès
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    // Réponse erreur
    http_response_code(400);
    echo json_encode([
        'error' => true,
        'message' => $e->getMessage(),
        'timestamp' => time()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}

/*
===========================================
DOCUMENTATION ENDPOINTS
===========================================

GET /api/performance.php?endpoint=current
  - Stats complètes temps réel (GPU + Système + Chromium + FPS)

GET /api/performance.php?endpoint=fps
  - Données FPS uniquement

GET /api/performance.php?endpoint=history&limit=20
  - Historique récent des performances

GET /api/performance.php?endpoint=gpu
  - Stats GPU uniquement

GET /api/performance.php?endpoint=system
  - Stats système uniquement

GET /api/performance.php?endpoint=chromium
  - Stats processus Chromium uniquement

GET /api/performance.php?endpoint=health
  - Évaluation santé système

POST /api/performance.php?endpoint=start_monitoring
  Body: duration=300&threshold=30
  - Démarrer monitoring FPS

Exemples:
curl http://192.168.1.103/api/performance.php?endpoint=current
curl http://192.168.1.103/api/performance.php?endpoint=fps
curl -X POST -d "duration=600&threshold=25" http://192.168.1.103/api/performance.php?endpoint=start_monitoring

===========================================
*/
?>