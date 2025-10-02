<?php
/**
 * PiSignage v0.8.9 - Schedule Management API
 *
 * Manages playlist scheduling with recurrence patterns, priorities, and conflict detection.
 * Supports daily, weekly, monthly, and one-time schedules with post-playback actions.
 *
 * @package    PiSignage
 * @subpackage API
 * @version    0.8.9
 * @since      0.8.0
 */

require_once '../config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Data file paths
define('SCHEDULES_FILE', '/opt/pisignage/data/schedules.json');
// PLAYLISTS_PATH is now defined in config.php

/**
 * Check if playlist file exists.
 *
 * @param string $playlistName Playlist name without extension
 * @return bool True if playlist exists
 * @since 0.8.0
 */
function playlistExists($playlistName) {
    $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';
    return file_exists($playlistFile);
}

/**
 * Load all schedules from storage.
 *
 * @return array Array of schedule objects
 * @since 0.8.0
 */
function loadSchedules() {
    if (!file_exists(SCHEDULES_FILE)) {
        return [];
    }

    $content = file_get_contents(SCHEDULES_FILE);
    $schedules = json_decode($content, true);

    return is_array($schedules) ? $schedules : [];
}

/**
 * Save schedules to storage.
 *
 * @param array $schedules Array of schedule objects
 * @return bool True on success
 * @since 0.8.0
 */
function saveSchedules($schedules) {
    $json = json_encode($schedules, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    return file_put_contents(SCHEDULES_FILE, $json) !== false;
}

/**
 * Generate unique schedule ID.
 *
 * @return string Unique ID with 'sched_' prefix
 * @since 0.8.0
 */
function generateId() {
    return uniqid('sched_', true);
}

/**
 * Validate schedule data.
 *
 * Checks required fields, time formats, and playlist existence.
 *
 * @param array $data Schedule data to validate
 * @return array Array of error messages (empty if valid)
 * @since 0.8.0
 */
function validateSchedule($data) {
    $errors = [];

    // Required fields
    if (empty($data['name'])) {
        $errors[] = "Le nom du planning est requis";
    }

    if (empty($data['playlist'])) {
        $errors[] = "La playlist est requise";
    } elseif (!playlistExists($data['playlist'])) {
        $errors[] = "La playlist '{$data['playlist']}' n'existe pas. Veuillez créer la playlist ou en sélectionner une autre.";
    }

    if (empty($data['schedule']['start_time'])) {
        $errors[] = "L'heure de début est requise";
    }

    // Validate time format (HH:MM)
    if (!empty($data['schedule']['start_time']) && !preg_match('/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/', $data['schedule']['start_time'])) {
        $errors[] = "Format d'heure de début invalide (HH:MM attendu)";
    }

    if (!empty($data['schedule']['end_time']) && !preg_match('/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/', $data['schedule']['end_time'])) {
        $errors[] = "Format d'heure de fin invalide (HH:MM attendu)";
    }

    // Validate end time is after start time
    if (!empty($data['schedule']['start_time']) && !empty($data['schedule']['end_time'])) {
        if ($data['schedule']['end_time'] <= $data['schedule']['start_time'] && empty($data['schedule']['continuous'])) {
            $errors[] = "L'heure de fin doit être postérieure à l'heure de début";
        }
    }

    // Validate recurrence
    if ($data['schedule']['recurrence']['type'] === 'weekly') {
        if (empty($data['schedule']['recurrence']['days']) || !is_array($data['schedule']['recurrence']['days'])) {
            $errors[] = "Au moins un jour doit être sélectionné pour la récurrence hebdomadaire";
        }
    }

    return $errors;
}

/**
 * Calculate next run time for a schedule.
 *
 * Handles daily, weekly, monthly, and one-time recurrence patterns.
 *
 * @param array $schedule Schedule object with recurrence settings
 * @return string ISO 8601 datetime string
 * @since 0.8.0
 */
function calculateNextRun($schedule) {
    $now = new DateTime();
    $startTime = $schedule['schedule']['start_time'];
    $recurrence = $schedule['schedule']['recurrence'];

    // Parse start time
    list($hour, $minute) = explode(':', $startTime);

    // Create base datetime for today
    $nextRun = clone $now;
    $nextRun->setTime((int)$hour, (int)$minute, 0);

    // If time has passed today, start from tomorrow
    if ($nextRun <= $now) {
        $nextRun->modify('+1 day');
    }

    // Handle recurrence types
    switch ($recurrence['type']) {
        case 'once':
            // For one-time schedules, check if start date is set
            if (!empty($recurrence['start_date'])) {
                $startDate = new DateTime($recurrence['start_date']);
                $startDate->setTime((int)$hour, (int)$minute, 0);
                return $startDate->format('Y-m-d\TH:i:s\Z');
            }
            return $nextRun->format('Y-m-d\TH:i:s\Z');

        case 'daily':
            // Already handled above
            return $nextRun->format('Y-m-d\TH:i:s\Z');

        case 'weekly':
            // Find next matching day
            $days = $recurrence['days'];
            $maxAttempts = 7;
            $attempts = 0;

            while ($attempts < $maxAttempts) {
                $dayOfWeek = (int)$nextRun->format('w'); // 0 = Sunday

                if (in_array($dayOfWeek, $days)) {
                    return $nextRun->format('Y-m-d\TH:i:s\Z');
                }

                $nextRun->modify('+1 day');
                $attempts++;
            }
            break;

        case 'monthly':
            // Monthly on specific date
            if (!empty($recurrence['date_specific'])) {
                $nextRun->setDate((int)$nextRun->format('Y'), (int)$nextRun->format('m'), $recurrence['date_specific']);

                if ($nextRun <= $now) {
                    $nextRun->modify('+1 month');
                }
            }
            return $nextRun->format('Y-m-d\TH:i:s\Z');
    }

    return $nextRun->format('Y-m-d\TH:i:s\Z');
}

/**
 * Detect time and recurrence conflicts between schedules.
 *
 * @param array $newSchedule Schedule to check
 * @param array $existingSchedules Array of existing schedules
 * @param string|null $excludeId Schedule ID to exclude from conflict check
 * @return array Array of conflicting schedules with details
 * @since 0.8.0
 */
function detectConflicts($newSchedule, $existingSchedules, $excludeId = null) {
    $conflicts = [];

    foreach ($existingSchedules as $schedule) {
        // Skip if disabled or if it's the same schedule being edited
        if (!$schedule['enabled'] || ($excludeId && $schedule['id'] === $excludeId)) {
            continue;
        }

        // Check if schedules overlap
        $newStart = $newSchedule['schedule']['start_time'];
        $newEnd = !empty($newSchedule['schedule']['end_time']) ? $newSchedule['schedule']['end_time'] : '23:59';
        $existingStart = $schedule['schedule']['start_time'];
        $existingEnd = !empty($schedule['schedule']['end_time']) ? $schedule['schedule']['end_time'] : '23:59';

        // Convert times to minutes for comparison
        $newStartMin = timeToMinutes($newStart);
        $newEndMin = timeToMinutes($newEnd);
        $existingStartMin = timeToMinutes($existingStart);
        $existingEndMin = timeToMinutes($existingEnd);

        // Check overlap
        if ($newStartMin < $existingEndMin && $newEndMin > $existingStartMin) {
            // Check if they occur on the same days
            if (schedulesOverlapDays($newSchedule, $schedule)) {
                $conflicts[] = [
                    'schedule_id' => $schedule['id'],
                    'schedule_name' => $schedule['name'],
                    'time_overlap' => "{$existingStart} - {$existingEnd}",
                    'priority' => $schedule['priority']
                ];
            }
        }
    }

    return $conflicts;
}

/**
 * Convert time string to minutes since midnight.
 *
 * @param string $time Time in HH:MM format
 * @return int Minutes since midnight
 * @since 0.8.0
 */
function timeToMinutes($time) {
    list($hour, $minute) = explode(':', $time);
    return ((int)$hour * 60) + (int)$minute;
}

/**
 * Check if two schedules have overlapping recurrence days.
 *
 * @param array $schedule1 First schedule object
 * @param array $schedule2 Second schedule object
 * @return bool True if schedules may occur on same days
 * @since 0.8.0
 */
function schedulesOverlapDays($schedule1, $schedule2) {
    $rec1 = $schedule1['schedule']['recurrence'];
    $rec2 = $schedule2['schedule']['recurrence'];

    // If both are daily, they always overlap
    if ($rec1['type'] === 'daily' && $rec2['type'] === 'daily') {
        return true;
    }

    // If one is daily and the other isn't, they overlap
    if ($rec1['type'] === 'daily' || $rec2['type'] === 'daily') {
        return true;
    }

    // If both are weekly, check for common days
    if ($rec1['type'] === 'weekly' && $rec2['type'] === 'weekly') {
        $days1 = $rec1['days'] ?? [];
        $days2 = $rec2['days'] ?? [];

        return count(array_intersect($days1, $days2)) > 0;
    }

    // For other cases, assume they might overlap
    return true;
}

/**
 * Parse JSON request body.
 *
 * @return array Decoded request data
 * @since 0.8.0
 */
function getRequestData() {
    $input = file_get_contents('php://input');
    return json_decode($input, true) ?? [];
}

/**
 * Send JSON response and exit.
 *
 * @param array $data Response data
 * @param int $statusCode HTTP status code
 * @since 0.8.0
 */
function sendResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit();
}

// ==================== ROUTE HANDLING ====================

$method = $_SERVER['REQUEST_METHOD'];
$path = $_SERVER['PATH_INFO'] ?? '/';
$pathParts = explode('/', trim($path, '/'));
$id = $pathParts[0] ?? null;

// GET /api/schedule.php - List all schedules
if ($method === 'GET' && empty($id)) {
    $schedules = loadSchedules();

    // Optionally filter by enabled status
    if (isset($_GET['enabled'])) {
        $enabled = $_GET['enabled'] === 'true' || $_GET['enabled'] === '1';
        $schedules = array_filter($schedules, function($s) use ($enabled) {
            return $s['enabled'] === $enabled;
        });
    }

    // Sort by next_run
    usort($schedules, function($a, $b) {
        $aNext = $a['metadata']['next_run'] ?? '';
        $bNext = $b['metadata']['next_run'] ?? '';
        return strcmp($aNext, $bNext);
    });

    sendResponse([
        'success' => true,
        'data' => array_values($schedules),
        'count' => count($schedules),
        'timestamp' => date('c')
    ]);
}

// GET /api/schedule.php/{id} - Get single schedule
if ($method === 'GET' && !empty($id)) {
    $schedules = loadSchedules();

    foreach ($schedules as $schedule) {
        if ($schedule['id'] === $id) {
            sendResponse([
                'success' => true,
                'data' => $schedule,
                'timestamp' => date('c')
            ]);
        }
    }

    sendResponse([
        'success' => false,
        'message' => "Planning introuvable: {$id}",
        'timestamp' => date('c')
    ], 404);
}

// POST /api/schedule.php - Create new schedule
if ($method === 'POST') {
    $data = getRequestData();

    // Validate input
    $errors = validateSchedule($data);
    if (!empty($errors)) {
        sendResponse([
            'success' => false,
            'message' => 'Données invalides',
            'errors' => $errors,
            'timestamp' => date('c')
        ], 400);
    }

    // Check for conflicts
    $schedules = loadSchedules();
    $conflicts = detectConflicts($data, $schedules);

    if (!empty($conflicts) && $data['conflict_behavior'] !== 'ignore') {
        sendResponse([
            'success' => false,
            'message' => 'Conflits détectés',
            'conflicts' => $conflicts,
            'timestamp' => date('c')
        ], 409);
    }

    // Create new schedule
    $schedule = [
        'id' => generateId(),
        'name' => $data['name'],
        'description' => $data['description'] ?? '',
        'playlist' => $data['playlist'],
        'enabled' => $data['enabled'] ?? true,
        'priority' => $data['priority'] ?? 1,
        'schedule' => $data['schedule'],
        'conflict_behavior' => $data['conflict_behavior'] ?? 'ignore',
        'post_actions' => $data['post_actions'] ?? [
            'revert_default' => true,
            'stop_playback' => false,
            'take_screenshot' => false
        ],
        'metadata' => [
            'created_at' => date('c'),
            'updated_at' => date('c'),
            'created_by' => 'admin',
            'last_run' => null,
            'next_run' => calculateNextRun($data),
            'run_count' => 0
        ]
    ];

    $schedules[] = $schedule;

    if (saveSchedules($schedules)) {
        sendResponse([
            'success' => true,
            'message' => 'Planning créé avec succès',
            'data' => $schedule,
            'timestamp' => date('c')
        ], 201);
    } else {
        sendResponse([
            'success' => false,
            'message' => 'Erreur lors de la sauvegarde',
            'timestamp' => date('c')
        ], 500);
    }
}

// PUT /api/schedule.php/{id} - Update schedule
if ($method === 'PUT' && !empty($id)) {
    $data = getRequestData();
    $schedules = loadSchedules();
    $found = false;

    // Validate input
    $errors = validateSchedule($data);
    if (!empty($errors)) {
        sendResponse([
            'success' => false,
            'message' => 'Données invalides',
            'errors' => $errors,
            'timestamp' => date('c')
        ], 400);
    }

    // Check for conflicts (excluding the current schedule)
    $conflicts = detectConflicts($data, $schedules, $id);

    if (!empty($conflicts) && $data['conflict_behavior'] !== 'ignore') {
        sendResponse([
            'success' => false,
            'message' => 'Conflits détectés',
            'conflicts' => $conflicts,
            'timestamp' => date('c')
        ], 409);
    }

    foreach ($schedules as $index => $schedule) {
        if ($schedule['id'] === $id) {
            // Preserve metadata
            $oldMetadata = $schedule['metadata'];

            $schedules[$index] = [
                'id' => $id,
                'name' => $data['name'],
                'description' => $data['description'] ?? '',
                'playlist' => $data['playlist'],
                'enabled' => $data['enabled'] ?? $schedule['enabled'],
                'priority' => $data['priority'] ?? $schedule['priority'],
                'schedule' => $data['schedule'],
                'conflict_behavior' => $data['conflict_behavior'] ?? $schedule['conflict_behavior'],
                'post_actions' => $data['post_actions'] ?? $schedule['post_actions'],
                'metadata' => [
                    'created_at' => $oldMetadata['created_at'],
                    'updated_at' => date('c'),
                    'created_by' => $oldMetadata['created_by'],
                    'last_run' => $oldMetadata['last_run'],
                    'next_run' => calculateNextRun($data),
                    'run_count' => $oldMetadata['run_count']
                ]
            ];

            $found = true;
            break;
        }
    }

    if (!$found) {
        sendResponse([
            'success' => false,
            'message' => "Planning introuvable: {$id}",
            'timestamp' => date('c')
        ], 404);
    }

    if (saveSchedules($schedules)) {
        sendResponse([
            'success' => true,
            'message' => 'Planning modifié avec succès',
            'data' => $schedules[$index],
            'timestamp' => date('c')
        ]);
    } else {
        sendResponse([
            'success' => false,
            'message' => 'Erreur lors de la sauvegarde',
            'timestamp' => date('c')
        ], 500);
    }
}

// PATCH /api/schedule.php/{id}/toggle - Toggle enabled status
if ($method === 'PATCH' && !empty($id) && strpos($path, '/toggle') !== false) {
    $schedules = loadSchedules();
    $found = false;

    foreach ($schedules as $index => $schedule) {
        if ($schedule['id'] === $id) {
            $schedules[$index]['enabled'] = !$schedule['enabled'];
            $schedules[$index]['metadata']['updated_at'] = date('c');
            $found = true;
            break;
        }
    }

    if (!$found) {
        sendResponse([
            'success' => false,
            'message' => "Planning introuvable: {$id}",
            'timestamp' => date('c')
        ], 404);
    }

    if (saveSchedules($schedules)) {
        sendResponse([
            'success' => true,
            'message' => 'Statut modifié avec succès',
            'data' => $schedules[$index],
            'timestamp' => date('c')
        ]);
    } else {
        sendResponse([
            'success' => false,
            'message' => 'Erreur lors de la sauvegarde',
            'timestamp' => date('c')
        ], 500);
    }
}

// DELETE /api/schedule.php/{id} - Delete schedule
if ($method === 'DELETE' && !empty($id)) {
    $schedules = loadSchedules();
    $found = false;

    foreach ($schedules as $index => $schedule) {
        if ($schedule['id'] === $id) {
            array_splice($schedules, $index, 1);
            $found = true;
            break;
        }
    }

    if (!$found) {
        sendResponse([
            'success' => false,
            'message' => "Planning introuvable: {$id}",
            'timestamp' => date('c')
        ], 404);
    }

    if (saveSchedules($schedules)) {
        sendResponse([
            'success' => true,
            'message' => 'Planning supprimé avec succès',
            'timestamp' => date('c')
        ]);
    } else {
        sendResponse([
            'success' => false,
            'message' => 'Erreur lors de la sauvegarde',
            'timestamp' => date('c')
        ], 500);
    }
}

// If no route matched
sendResponse([
    'success' => false,
    'message' => 'Méthode ou route non supportée',
    'timestamp' => date('c')
], 405);
