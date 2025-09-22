<?php
/**
 * PiSignage v0.8.0 - Scheduler API
 * Manages scheduled playlist playback
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetSchedules();
        break;

    case 'POST':
        handleCreateSchedule($input);
        break;

    case 'PUT':
        handleUpdateSchedule($input);
        break;

    case 'DELETE':
        handleDeleteSchedule($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetSchedules() {
    global $db;

    try {
        $stmt = $db->query("SELECT * FROM schedules ORDER BY created_at DESC");
        $schedules = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Process schedules data
        foreach ($schedules as &$schedule) {
            $schedule['days_array'] = json_decode($schedule['days'], true);
            $schedule['enabled'] = (bool)$schedule['enabled'];
        }

        jsonResponse(true, $schedules);
    } catch (Exception $e) {
        logMessage("Failed to get schedules: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to retrieve schedules');
    }
}

function handleCreateSchedule($input) {
    global $db;

    // Validate required fields
    $requiredFields = ['name', 'playlist_name', 'start_time', 'end_time', 'days'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            jsonResponse(false, null, "Field '$field' is required");
        }
    }

    $name = trim($input['name']);
    $playlistName = trim($input['playlist_name']);
    $startTime = trim($input['start_time']);
    $endTime = trim($input['end_time']);
    $days = is_array($input['days']) ? $input['days'] : json_decode($input['days'], true);

    // Validate playlist exists
    $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';
    if (!file_exists($playlistFile)) {
        jsonResponse(false, null, 'Playlist does not exist');
    }

    // Validate time format
    if (!validateTimeFormat($startTime) || !validateTimeFormat($endTime)) {
        jsonResponse(false, null, 'Invalid time format. Use HH:MM');
    }

    // Validate days array
    if (!is_array($days) || empty($days)) {
        jsonResponse(false, null, 'Days array is required');
    }

    foreach ($days as $day) {
        if (!is_numeric($day) || $day < 0 || $day > 6) {
            jsonResponse(false, null, 'Invalid day value. Use 0-6 (Sunday-Saturday)');
        }
    }

    try {
        $stmt = $db->prepare("
            INSERT INTO schedules (name, playlist_name, start_time, end_time, days, enabled)
            VALUES (?, ?, ?, ?, ?, 1)
        ");

        $stmt->execute([
            $name,
            $playlistName,
            $startTime,
            $endTime,
            json_encode($days)
        ]);

        $scheduleId = $db->lastInsertId();

        logMessage("Schedule created: $name (ID: $scheduleId)");
        jsonResponse(true, ['id' => $scheduleId], 'Schedule created successfully');

    } catch (Exception $e) {
        logMessage("Failed to create schedule: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to create schedule');
    }
}

function handleUpdateSchedule($input) {
    global $db;

    if (!isset($input['id'])) {
        jsonResponse(false, null, 'Schedule ID is required');
    }

    $id = intval($input['id']);

    // Check if schedule exists
    $stmt = $db->prepare("SELECT * FROM schedules WHERE id = ?");
    $stmt->execute([$id]);
    $schedule = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$schedule) {
        jsonResponse(false, null, 'Schedule not found');
    }

    // Update fields if provided
    $updateFields = [];
    $updateValues = [];

    if (isset($input['name'])) {
        $updateFields[] = 'name = ?';
        $updateValues[] = trim($input['name']);
    }

    if (isset($input['playlist_name'])) {
        $playlistName = trim($input['playlist_name']);
        $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';
        if (!file_exists($playlistFile)) {
            jsonResponse(false, null, 'Playlist does not exist');
        }
        $updateFields[] = 'playlist_name = ?';
        $updateValues[] = $playlistName;
    }

    if (isset($input['start_time'])) {
        if (!validateTimeFormat($input['start_time'])) {
            jsonResponse(false, null, 'Invalid start time format');
        }
        $updateFields[] = 'start_time = ?';
        $updateValues[] = trim($input['start_time']);
    }

    if (isset($input['end_time'])) {
        if (!validateTimeFormat($input['end_time'])) {
            jsonResponse(false, null, 'Invalid end time format');
        }
        $updateFields[] = 'end_time = ?';
        $updateValues[] = trim($input['end_time']);
    }

    if (isset($input['days'])) {
        $days = is_array($input['days']) ? $input['days'] : json_decode($input['days'], true);
        if (!is_array($days) || empty($days)) {
            jsonResponse(false, null, 'Invalid days array');
        }
        $updateFields[] = 'days = ?';
        $updateValues[] = json_encode($days);
    }

    if (isset($input['enabled'])) {
        $updateFields[] = 'enabled = ?';
        $updateValues[] = $input['enabled'] ? 1 : 0;
    }

    if (empty($updateFields)) {
        jsonResponse(false, null, 'No fields to update');
    }

    try {
        $updateValues[] = $id;
        $sql = "UPDATE schedules SET " . implode(', ', $updateFields) . " WHERE id = ?";
        $stmt = $db->prepare($sql);
        $stmt->execute($updateValues);

        logMessage("Schedule updated: ID $id");
        jsonResponse(true, null, 'Schedule updated successfully');

    } catch (Exception $e) {
        logMessage("Failed to update schedule: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to update schedule');
    }
}

function handleDeleteSchedule($input) {
    global $db;

    if (!isset($input['id'])) {
        jsonResponse(false, null, 'Schedule ID is required');
    }

    $id = intval($input['id']);

    try {
        $stmt = $db->prepare("DELETE FROM schedules WHERE id = ?");
        $stmt->execute([$id]);

        if ($stmt->rowCount() > 0) {
            logMessage("Schedule deleted: ID $id");
            jsonResponse(true, null, 'Schedule deleted successfully');
        } else {
            jsonResponse(false, null, 'Schedule not found');
        }

    } catch (Exception $e) {
        logMessage("Failed to delete schedule: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to delete schedule');
    }
}

function validateTimeFormat($time) {
    return preg_match('/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/', $time);
}

// Check for active schedules (called by cron or system)
function checkActiveSchedules() {
    global $db;

    $currentTime = date('H:i');
    $currentDay = date('w'); // 0 = Sunday, 6 = Saturday

    try {
        $stmt = $db->prepare("
            SELECT * FROM schedules
            WHERE enabled = 1
            AND start_time <= ?
            AND end_time > ?
        ");
        $stmt->execute([$currentTime, $currentTime]);
        $schedules = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($schedules as $schedule) {
            $days = json_decode($schedule['days'], true);

            if (in_array($currentDay, $days)) {
                // This schedule should be active
                playScheduledPlaylist($schedule['playlist_name']);
                logMessage("Activated schedule: " . $schedule['name']);
                break; // Only activate one schedule at a time
            }
        }

    } catch (Exception $e) {
        logMessage("Failed to check active schedules: " . $e->getMessage(), 'ERROR');
    }
}

function playScheduledPlaylist($playlistName) {
    $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';

    if (!file_exists($playlistFile)) {
        logMessage("Scheduled playlist not found: $playlistName", 'ERROR');
        return false;
    }

    $playlist = json_decode(file_get_contents($playlistFile), true);

    if (!$playlist || !isset($playlist['items'])) {
        logMessage("Invalid scheduled playlist format: $playlistName", 'ERROR');
        return false;
    }

    // Stop current playback
    vlcCommand('pl_stop');
    vlcCommand('pl_empty');

    // Add playlist items
    foreach ($playlist['items'] as $item) {
        $filepath = MEDIA_PATH . '/' . basename($item);
        if (file_exists($filepath)) {
            vlcCommand('in_enqueue', ['input' => $filepath]);
        }
    }

    // Start playing
    vlcCommand('pl_play');
    vlcCommand('pl_loop'); // Enable loop for scheduled playlists

    logMessage("Started scheduled playlist: $playlistName");
    return true;
}

// Handle CLI calls for cron jobs
if (php_sapi_name() === 'cli' && isset($argv[1]) && $argv[1] === 'check') {
    checkActiveSchedules();
}
?>