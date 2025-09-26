<?php
/**
 * PiSignage v0.8.0 - Playlist Management API
 * Gestion robuste des playlists avec base de données SQLite
 * Compatible PHP 7.4 pour Raspberry Pi Bullseye
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetPlaylists();
        break;

    case 'POST':
        handleCreatePlaylist($input);
        break;

    case 'PUT':
        handleUpdatePlaylist($input);
        break;

    case 'DELETE':
        handleDeletePlaylist($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function getPlaylistByName($name) {
    global $db;

    if (!$db) {
        // Mode dégradé - lire depuis fichiers JSON
        $jsonFile = PLAYLISTS_PATH . '/' . sanitizeFilename($name) . '.json';
        if (file_exists($jsonFile)) {
            return json_decode(file_get_contents($jsonFile), true);
        }
        return null;
    }

    try {
        $stmt = $db->prepare("SELECT * FROM playlists WHERE name = ?");
        $stmt->execute([$name]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        logMessage("Failed to get playlist: " . $e->getMessage(), 'ERROR');
        return null;
    }
}

function calculatePlaylistDuration($items) {
    $totalDuration = 0;
    foreach ($items as $item) {
        $filepath = MEDIA_PATH . '/' . basename($item);
        if (file_exists($filepath)) {
            // Pour une estimation simple, on compte 10 secondes par élément
            // Dans une vraie implémentation, on utiliserait ffprobe
            $totalDuration += 10;
        }
    }
    return $totalDuration;
}

function getValidPlaylistItems($items) {
    $validItems = [];
    foreach ($items as $item) {
        $filepath = MEDIA_PATH . '/' . basename($item);
        if (file_exists($filepath)) {
            $validItems[] = $item;
        }
    }
    return $validItems;
}

function handleGetPlaylists() {
    global $db;
    $action = $_GET['action'] ?? 'list';

    switch ($action) {
        case 'list':
            // Mode dégradé si pas de DB
            if (!$db) {
                $playlists = [];
                $jsonFiles = glob(PLAYLISTS_PATH . '/*.json');
                foreach ($jsonFiles as $file) {
                    $playlist = json_decode(file_get_contents($file), true);
                    if ($playlist) {
                        $playlist['item_count'] = count($playlist['items'] ?? []);
                        $playlist['total_duration'] = calculatePlaylistDuration($playlist['items'] ?? []);
                        $playlists[] = $playlist;
                    }
                }
                jsonResponse(true, $playlists);
                return;
            }

            try {
                $stmt = $db->query("SELECT * FROM playlists ORDER BY updated_at DESC");
                $playlists = $stmt->fetchAll(PDO::FETCH_ASSOC);

                // Parse items JSON for each playlist
                foreach ($playlists as &$playlist) {
                    $playlist['items'] = json_decode($playlist['items'], true) ?: [];
                    $playlist['item_count'] = count($playlist['items']);
                    $playlist['total_duration'] = calculatePlaylistDuration($playlist['items']);
                }

                jsonResponse(true, $playlists);
            } catch (Exception $e) {
                logMessage("Failed to get playlists: " . $e->getMessage(), 'ERROR');
                jsonResponse(false, null, 'Failed to retrieve playlists');
            }
            break;

        case 'info':
            if (!isset($_GET['name'])) {
                jsonResponse(false, null, 'Playlist name required');
            }

            $name = $_GET['name'];
            $playlist = getPlaylistByName($name);

            if (!$playlist) {
                jsonResponse(false, null, 'Playlist not found');
            }

            $playlist['items'] = json_decode($playlist['items'], true) ?: [];
            $playlist['item_count'] = count($playlist['items']);
            $playlist['total_duration'] = calculatePlaylistDuration($playlist['items']);
            $playlist['valid_items'] = getValidPlaylistItems($playlist['items']);

            jsonResponse(true, $playlist);
            break;

        case 'export':
            if (!isset($_GET['name'])) {
                jsonResponse(false, null, 'Playlist name required');
            }

            $name = $_GET['name'];
            $playlist = getPlaylistByName($name);

            if (!$playlist) {
                jsonResponse(false, null, 'Playlist not found');
            }

            // Export as M3U format
            $m3u = generateM3U($playlist);
            header('Content-Type: audio/x-mpegurl');
            header('Content-Disposition: attachment; filename="' . $name . '.m3u"');
            echo $m3u;
            exit;
            break;

        default:
            jsonResponse(false, null, 'Unknown action: ' . $action);
    }
}

function handleCreatePlaylist($input) {
    global $db;

    // Validate input
    if (!isset($input['name']) || empty(trim($input['name']))) {
        jsonResponse(false, null, 'Playlist name is required');
    }

    $name = trim($input['name']);
    $items = $input['items'] ?? [];
    $description = $input['description'] ?? '';

    // Validate playlist name
    if (!preg_match('/^[a-zA-Z0-9_-]+$/', $name)) {
        jsonResponse(false, null, 'Playlist name can only contain letters, numbers, underscore and dash');
    }

    // Check if playlist already exists
    if (getPlaylistByName($name)) {
        jsonResponse(false, null, 'Playlist already exists');
    }

    // Validate items
    $validItems = [];
    foreach ($items as $item) {
        $filename = basename($item);
        $filepath = MEDIA_PATH . '/' . $filename;

        if (file_exists($filepath) && isValidMediaFile($filename)) {
            $validItems[] = $filename;
        } else {
            logMessage("Invalid playlist item skipped: $filename", 'WARNING');
        }
    }

    try {
        $stmt = $db->prepare("
            INSERT INTO playlists (name, items, description, created_at, updated_at)
            VALUES (?, ?, ?, datetime('now'), datetime('now'))
        ");

        $stmt->execute([
            $name,
            json_encode($validItems),
            $description
        ]);

        $playlistId = $db->lastInsertId();

        // Also save as JSON file for compatibility
        savePlaylistFile($name, $validItems, $description);

        logMessage("Playlist created: $name (" . count($validItems) . " items)");
        jsonResponse(true, [
            'id' => $playlistId,
            'name' => $name,
            'item_count' => count($validItems),
            'valid_items' => $validItems
        ], 'Playlist created successfully');

    } catch (Exception $e) {
        logMessage("Failed to create playlist: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to create playlist');
    }
}

function handleUpdatePlaylist($input) {
    global $db;

    if (!isset($input['name'])) {
        jsonResponse(false, null, 'Playlist name is required');
    }

    $name = trim($input['name']);
    $playlist = getPlaylistByName($name);

    if (!$playlist) {
        jsonResponse(false, null, 'Playlist not found');
    }

    // Update fields
    $updateFields = [];
    $updateValues = [];

    if (isset($input['items'])) {
        $items = $input['items'];
        $validItems = [];

        foreach ($items as $item) {
            $filename = basename($item);
            $filepath = MEDIA_PATH . '/' . $filename;

            if (file_exists($filepath) && isValidMediaFile($filename)) {
                $validItems[] = $filename;
            }
        }

        $updateFields[] = 'items = ?';
        $updateValues[] = json_encode($validItems);
    }

    if (isset($input['description'])) {
        $updateFields[] = 'description = ?';
        $updateValues[] = $input['description'];
    }

    if (empty($updateFields)) {
        jsonResponse(false, null, 'No fields to update');
    }

    $updateFields[] = 'updated_at = datetime(\'now\')';

    try {
        $updateValues[] = $name;
        $sql = "UPDATE playlists SET " . implode(', ', $updateFields) . " WHERE name = ?";
        $stmt = $db->prepare($sql);
        $stmt->execute($updateValues);

        // Update JSON file
        $updatedPlaylist = getPlaylistByName($name);
        $items = json_decode($updatedPlaylist['items'], true) ?: [];
        savePlaylistFile($name, $items, $updatedPlaylist['description']);

        logMessage("Playlist updated: $name");
        jsonResponse(true, null, 'Playlist updated successfully');

    } catch (Exception $e) {
        logMessage("Failed to update playlist: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to update playlist');
    }
}

function handleDeletePlaylist($input) {
    global $db;

    if (!isset($input['name'])) {
        jsonResponse(false, null, 'Playlist name is required');
    }

    $name = trim($input['name']);
    $playlist = getPlaylistByName($name);

    if (!$playlist) {
        jsonResponse(false, null, 'Playlist not found');
    }

    try {
        $stmt = $db->prepare("DELETE FROM playlists WHERE name = ?");
        $stmt->execute([$name]);

        // Delete JSON file
        $jsonFile = PLAYLISTS_PATH . '/' . $name . '.json';
        if (file_exists($jsonFile)) {
            unlink($jsonFile);
        }

        // Check if playlist is used in schedules
        $scheduleStmt = $db->prepare("SELECT COUNT(*) FROM schedules WHERE playlist_name = ?");
        $scheduleStmt->execute([$name]);
        $scheduleCount = $scheduleStmt->fetchColumn();

        $message = 'Playlist deleted successfully';
        if ($scheduleCount > 0) {
            $message .= " (Warning: $scheduleCount schedule(s) reference this playlist)";
        }

        logMessage("Playlist deleted: $name");
        jsonResponse(true, null, $message);

    } catch (Exception $e) {
        logMessage("Failed to delete playlist: " . $e->getMessage(), 'ERROR');
        jsonResponse(false, null, 'Failed to delete playlist');
    }
}

function getPlaylistByName($name) {
    global $db;

    try {
        $stmt = $db->prepare("SELECT * FROM playlists WHERE name = ?");
        $stmt->execute([$name]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        logMessage("Failed to get playlist by name: " . $e->getMessage(), 'ERROR');
        return false;
    }
}

function savePlaylistFile($name, $items, $description = '') {
    $playlistData = [
        'name' => $name,
        'description' => $description,
        'items' => $items,
        'created_at' => date('Y-m-d H:i:s'),
        'item_count' => count($items)
    ];

    $jsonFile = PLAYLISTS_PATH . '/' . $name . '.json';
    file_put_contents($jsonFile, json_encode($playlistData, JSON_PRETTY_PRINT));
}

function calculatePlaylistDuration($items) {
    $totalDuration = 0;

    foreach ($items as $item) {
        $filepath = MEDIA_PATH . '/' . basename($item);
        if (file_exists($filepath)) {
            // Get video duration using ffprobe
            $command = "ffprobe -v quiet -show_entries format=duration -of csv=p=0 " . escapeshellarg($filepath);
            $result = executeCommand($command);

            if ($result['success'] && !empty($result['output'])) {
                $duration = floatval($result['output'][0]);
                $totalDuration += $duration;
            }
        }
    }

    return $totalDuration;
}

function getValidPlaylistItems($items) {
    $validItems = [];

    foreach ($items as $item) {
        $filename = basename($item);
        $filepath = MEDIA_PATH . '/' . $filename;

        if (file_exists($filepath) && isValidMediaFile($filename)) {
            $validItems[] = [
                'filename' => $filename,
                'size' => filesize($filepath),
                'type' => mime_content_type($filepath),
                'modified' => filemtime($filepath)
            ];
        }
    }

    return $validItems;
}

function generateM3U($playlist) {
    // Gérer les items selon qu'ils soient déjà décodés ou non
    if (is_string($playlist['items'])) {
        $items = json_decode($playlist['items'], true) ?: [];
    } else {
        $items = $playlist['items'] ?: [];
    }

    $m3u = "#EXTM3U\n";
    $m3u .= "#PLAYLIST:" . ($playlist['name'] ?? 'Playlist') . "\n";

    foreach ($items as $item) {
        $filepath = MEDIA_PATH . '/' . basename($item);
        if (file_exists($filepath)) {
            $m3u .= "#EXTINF:-1," . pathinfo($item, PATHINFO_FILENAME) . "\n";
            $m3u .= $filepath . "\n";
        }
    }

    return $m3u;
}

// Migration function for old JSON playlists
function migrateOldPlaylists() {
    global $db;

    $oldPlaylistFile = BASE_DIR . '/config/playlists.json';

    if (file_exists($oldPlaylistFile)) {
        $oldPlaylists = json_decode(file_get_contents($oldPlaylistFile), true);

        if ($oldPlaylists && is_array($oldPlaylists)) {
            foreach ($oldPlaylists as $oldPlaylist) {
                if (isset($oldPlaylist['name']) && !getPlaylistByName($oldPlaylist['name'])) {
                    try {
                        $stmt = $db->prepare("
                            INSERT INTO playlists (name, items, description, created_at, updated_at)
                            VALUES (?, ?, ?, datetime('now'), datetime('now'))
                        ");

                        $stmt->execute([
                            $oldPlaylist['name'],
                            json_encode($oldPlaylist['items'] ?? []),
                            $oldPlaylist['description'] ?? ''
                        ]);

                        logMessage("Migrated old playlist: " . $oldPlaylist['name']);
                    } catch (Exception $e) {
                        logMessage("Failed to migrate playlist: " . $e->getMessage(), 'ERROR');
                    }
                }
            }

            // Backup and remove old file
            rename($oldPlaylistFile, $oldPlaylistFile . '.backup');
            logMessage("Old playlists migrated and backed up");
        }
    }
}

// Auto-migrate on first load
if (isset($_GET['migrate']) && $_GET['migrate'] === 'true') {
    migrateOldPlaylists();
    jsonResponse(true, null, 'Migration completed');
}
?>