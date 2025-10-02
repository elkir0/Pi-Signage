<?php
/**
 * PiSignage - Settings API
 * Manages system settings: audio output, password, etc.
 */

require_once '../includes/auth.php';
require_once '../config.php';

header('Content-Type: application/json');

// Require authentication for settings API
if (!isAuthenticated()) {
    echo json_encode(['success' => false, 'message' => 'Authentication required']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetSettings();
        break;
    case 'POST':
        handleUpdateSettings($input);
        break;
    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetSettings() {
    $settings = loadSettings();
    jsonResponse(true, $settings);
}

function handleUpdateSettings($input) {
    if (!$input || !isset($input['action'])) {
        jsonResponse(false, null, 'Action required');
        return;
    }

    switch ($input['action']) {
        case 'update_audio':
            updateAudioOutput($input);
            break;

        case 'update_password':
            changePassword($input);
            break;

        case 'logout':
            logout();
            break;

        default:
            jsonResponse(false, null, 'Unknown action');
    }
}

function loadSettings() {
    $settingsFile = '/opt/pisignage/config/settings.json';

    if (!file_exists($settingsFile)) {
        // Default settings
        $defaultSettings = [
            'audio_output' => 'hdmi',
            'version' => '0.8.9'
        ];
        file_put_contents($settingsFile, json_encode($defaultSettings, JSON_PRETTY_PRINT));
        chmod($settingsFile, 0644);
    }

    $data = file_get_contents($settingsFile);
    return json_decode($data, true);
}

function saveSettings($settings) {
    $settingsFile = '/opt/pisignage/config/settings.json';
    if (file_put_contents($settingsFile, json_encode($settings, JSON_PRETTY_PRINT))) {
        chmod($settingsFile, 0644);
        return true;
    }
    return false;
}

function updateAudioOutput($input) {
    $audioOutput = $input['audio_output'] ?? null;

    if (!in_array($audioOutput, ['hdmi', 'jack'])) {
        jsonResponse(false, null, 'Invalid audio output. Use "hdmi" or "jack"');
        return;
    }

    // Load current settings
    $settings = loadSettings();
    $settings['audio_output'] = $audioOutput;

    // Save settings
    if (!saveSettings($settings)) {
        jsonResponse(false, null, 'Failed to save settings');
        return;
    }

    // Apply audio output change via amixer
    $device = ($audioOutput === 'hdmi') ? 2 : 1;
    $command = "sudo amixer cset numid=3 $device 2>&1";
    exec($command, $output, $returnCode);

    if ($returnCode === 0) {
        jsonResponse(true, ['audio_output' => $audioOutput], 'Sortie audio changée: ' . strtoupper($audioOutput));
    } else {
        jsonResponse(false, null, 'Erreur lors du changement de sortie audio: ' . implode("\n", $output));
    }
}

function changePassword($input) {
    $oldPassword = $input['old_password'] ?? '';
    $newPassword = $input['new_password'] ?? '';

    if (strlen($newPassword) < 6) {
        jsonResponse(false, null, 'Le nouveau mot de passe doit contenir au moins 6 caractères');
        return;
    }

    $result = updatePassword($oldPassword, $newPassword);
    jsonResponse($result['success'], null, $result['message']);
}
?>
