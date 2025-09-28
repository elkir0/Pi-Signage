<?php
/**
 * PiSignage v0.8.5 - Authentication and Session Management
 * Handles session initialization and configuration management
 */

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Configuration
$config = [
    'version' => '0.8.5',
    'media_path' => '/opt/pisignage/media/',
    'config_path' => '/opt/pisignage/config/',
    'logs_path' => '/opt/pisignage/logs/',
    'upload_max_size' => 500 * 1024 * 1024, // 500MB
];

// Ensure directories exist
$dirs = [$config['media_path'], $config['config_path'], $config['logs_path']];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Functions for session and auth management
function isAuthenticated() {
    // For now, we'll consider all users authenticated
    // This can be extended later with proper authentication
    return true;
}

function requireAuth() {
    if (!isAuthenticated()) {
        header('Location: login.php');
        exit;
    }
}

function getCurrentPage() {
    $scriptName = basename($_SERVER['SCRIPT_NAME'], '.php');
    return $scriptName;
}
?>