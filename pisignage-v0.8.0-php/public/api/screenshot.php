<?php
/**
 * Screenshot API - PiSignage v0.8.0
 * Capture d'écran avec 4 méthodes de fallback
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

class ScreenshotService {
    private $methods = [
        'scrot' => 'captureWithScrot',
        'gnome-screenshot' => 'captureWithGnome',
        'import' => 'captureWithImageMagick',
        'xwd' => 'captureWithXwd'
    ];

    private $screenshot_dir;

    public function __construct() {
        $this->screenshot_dir = dirname(dirname(__DIR__)) . '/screenshots';
        if (!is_dir($this->screenshot_dir)) {
            mkdir($this->screenshot_dir, 0755, true);
        }
    }

    public function capture() {
        $timestamp = date('Y-m-d_H-i-s');
        $filename = "screenshot_{$timestamp}.png";
        $filepath = $this->screenshot_dir . '/' . $filename;

        // Try each method until one succeeds
        foreach ($this->methods as $tool => $method) {
            if ($this->isToolAvailable($tool)) {
                if ($this->$method($filepath)) {
                    return $this->prepareResponse($filename, $filepath);
                }
            }
        }

        return ['error' => 'No screenshot tool available', 'tried' => array_keys($this->methods)];
    }

    private function isToolAvailable($tool) {
        exec("which $tool 2>/dev/null", $output, $returnCode);
        return $returnCode === 0;
    }

    private function captureWithScrot($filepath) {
        exec("DISPLAY=:0 scrot -q 90 '$filepath' 2>&1", $output, $returnCode);
        return $returnCode === 0 && file_exists($filepath);
    }

    private function captureWithGnome($filepath) {
        exec("DISPLAY=:0 gnome-screenshot -f '$filepath' 2>&1", $output, $returnCode);
        return $returnCode === 0 && file_exists($filepath);
    }

    private function captureWithImageMagick($filepath) {
        exec("DISPLAY=:0 import -window root '$filepath' 2>&1", $output, $returnCode);
        return $returnCode === 0 && file_exists($filepath);
    }

    private function captureWithXwd($filepath) {
        $xwd_file = str_replace('.png', '.xwd', $filepath);
        exec("DISPLAY=:0 xwd -root -out '$xwd_file' 2>&1", $output, $returnCode);
        if ($returnCode === 0 && file_exists($xwd_file)) {
            exec("convert '$xwd_file' '$filepath' 2>&1", $output, $returnCode);
            unlink($xwd_file);
            return file_exists($filepath);
        }
        return false;
    }

    private function prepareResponse($filename, $filepath) {
        $size = filesize($filepath);
        $dimensions = getimagesize($filepath);

        // Create thumbnail
        $thumb_path = $this->screenshot_dir . '/thumb_' . $filename;
        exec("convert '$filepath' -resize 320x240 '$thumb_path' 2>&1");

        return [
            'success' => true,
            'filename' => $filename,
            'path' => "/screenshots/$filename",
            'thumb' => "/screenshots/thumb_$filename",
            'size' => $size,
            'width' => $dimensions[0] ?? 0,
            'height' => $dimensions[1] ?? 0,
            'timestamp' => time(),
            'method' => 'auto-detected'
        ];
    }
}

// Handle request
$service = new ScreenshotService();

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        echo json_encode($service->capture());
        break;

    case 'DELETE':
        // Delete screenshot
        $filename = $_GET['filename'] ?? '';
        if ($filename && preg_match('/^screenshot_[\d-_]+\.png$/', $filename)) {
            $path = dirname(dirname(__DIR__)) . '/screenshots/' . $filename;
            if (file_exists($path)) {
                unlink($path);
                echo json_encode(['success' => true, 'deleted' => $filename]);
            } else {
                http_response_code(404);
                echo json_encode(['error' => 'Screenshot not found']);
            }
        } else {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid filename']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
}