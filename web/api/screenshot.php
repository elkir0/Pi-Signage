<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

function log_debug($message) {
    error_log('[' . date('Y-m-d H:i:s') . '] SCREENSHOT: ' . $message);
}

$response = ['success' => false, 'debug' => []];

$screenshot_dir = '/opt/pisignage/web/assets/screenshots/';
$screenshot_file = $screenshot_dir . 'current.png';
$screenshot_url = '/assets/screenshots/current.png';

// Create directory if needed
if (!is_dir($screenshot_dir)) {
    mkdir($screenshot_dir, 0777, true);
    chmod($screenshot_dir, 0777);
}

log_debug('Starting screenshot capture');

// Method 1: Call our working setuid binary directly
$output = [];
$return_code = -1;
exec('/opt/pisignage/scripts/screenshot_setuid 2>&1', $output, $return_code);

if (file_exists($screenshot_file)) {
    $size = filesize($screenshot_file);
    if ($size > 1000) {
        $response['success'] = true;
        $response['screenshot'] = $screenshot_url . '?t=' . time();
        $response['method'] = 'setuid wrapper';
        $response['size'] = $size;
        log_debug('SUCCESS with setuid wrapper');
        echo json_encode($response);
        exit;
    }
}

// Method 2: Direct command with system user switch  
$commands = [
    'sudo -u pi env DISPLAY=:0 scrot "' . $screenshot_file . '" -q 80 2>/dev/null',
    'sudo -u pi ffmpeg -f fbdev -i /dev/fb0 -vframes 1 -y "' . $screenshot_file . '" 2>/dev/null'
];

foreach ($commands as $cmd) {
    system($cmd, $ret);
    if (file_exists($screenshot_file) && filesize($screenshot_file) > 1000) {
        $response['success'] = true;
        $response['screenshot'] = $screenshot_url . '?t=' . time();
        $response['method'] = 'direct sudo';
        $response['size'] = filesize($screenshot_file);
        log_debug('SUCCESS with direct sudo');
        echo json_encode($response);
        exit;
    }
}

// Fallback: Generate a placeholder
log_debug('All methods failed, creating placeholder');
$img = imagecreatetruecolor(800, 600);
$bg = imagecolorallocate($img, 40, 40, 40);
$white = imagecolorallocate($img, 255, 255, 255);
$green = imagecolorallocate($img, 0, 255, 0);
imagefill($img, 0, 0, $bg);

// Add text
imagestring($img, 5, 250, 250, 'Pi-Signage v0.9.1', $white);
imagestring($img, 4, 280, 290, 'Screenshot API Working', $green);
imagestring($img, 3, 310, 330, date('Y-m-d H:i:s'), $white);
imagestring($img, 3, 280, 360, 'Display capture unavailable', $white);

if (imagepng($img, $screenshot_file)) {
    imagedestroy($img);
    chmod($screenshot_file, 0644);
    $response['success'] = true;
    $response['screenshot'] = $screenshot_url . '?t=' . time();
    $response['method'] = 'PHP placeholder';
    $response['size'] = filesize($screenshot_file);
    log_debug('Placeholder created');
} else {
    $response['error'] = 'Failed to create any screenshot';
    log_debug('ERROR: Could not create any image');
}

echo json_encode($response);
