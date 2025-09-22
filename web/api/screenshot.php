<?php
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    $output_file = '/opt/pisignage/media/screenshot-' . date('YmdHis') . '.png';

    // Try different screenshot methods
    $methods = [
        "scrot '$output_file'",
        "import -window root '$output_file'",
        "raspi2png -p '$output_file'"
    ];

    $success = false;
    $error = '';

    foreach ($methods as $method) {
        exec($method . ' 2>&1', $output, $return);
        if ($return === 0 && file_exists($output_file)) {
            $success = true;
            break;
        }
        $error = implode(' ', $output);
    }

    if ($success) {
        echo json_encode([
            'success' => true,
            'path' => $output_file,
            'url' => '/media/' . basename($output_file)
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'error' => 'No screenshot tool available',
            'tried' => $methods
        ]);
    }
} else {
    echo json_encode(['error' => 'Method not allowed']);
}
?>