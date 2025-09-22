<?php
/**
 * YouTube Download API - PiSignage v0.8.0
 * Téléchargement YouTube avec yt-dlp
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

class YouTubeService {
    private $downloads_dir;
    private $queue_file;
    private $max_concurrent = 2;

    public function __construct() {
        $this->downloads_dir = dirname(dirname(__DIR__)) . '/media';
        $this->queue_file = dirname(dirname(__DIR__)) . '/logs/youtube_queue.json';

        if (!is_dir($this->downloads_dir)) {
            mkdir($this->downloads_dir, 0755, true);
        }
        if (!is_dir(dirname($this->queue_file))) {
            mkdir(dirname($this->queue_file), 0755, true);
        }
    }

    public function downloadVideo($url) {
        // Validate URL
        if (!$this->isValidYouTubeUrl($url)) {
            return ['error' => 'Invalid YouTube URL'];
        }

        // Get video info first
        $info = $this->getVideoInfo($url);
        if (isset($info['error'])) {
            return $info;
        }

        // Check if already downloading
        $queue = $this->getQueue();
        foreach ($queue as $item) {
            if ($item['url'] === $url && in_array($item['status'], ['downloading', 'pending'])) {
                return ['error' => 'Video already in download queue', 'id' => $item['id']];
            }
        }

        // Add to queue
        $download_id = uniqid('yt_');
        $queue_item = [
            'id' => $download_id,
            'url' => $url,
            'title' => $info['title'],
            'duration' => $info['duration'],
            'thumbnail' => $info['thumbnail'],
            'status' => 'pending',
            'progress' => 0,
            'started' => time(),
            'filename' => null,
            'error' => null
        ];

        $queue[] = $queue_item;
        $this->saveQueue($queue);

        // Start download in background
        $this->startBackgroundDownload($download_id, $url);

        return [
            'success' => true,
            'id' => $download_id,
            'info' => $info,
            'message' => 'Download started'
        ];
    }

    private function isValidYouTubeUrl($url) {
        $pattern = '/^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+$/';
        return preg_match($pattern, $url);
    }

    private function getVideoInfo($url) {
        $cmd = "yt-dlp --dump-json --no-warnings --no-playlist '$url' 2>&1";
        exec($cmd, $output, $return_code);

        if ($return_code !== 0) {
            // Fallback to youtube-dl if yt-dlp not available
            $cmd = "youtube-dl --dump-json --no-warnings --no-playlist '$url' 2>&1";
            exec($cmd, $output, $return_code);

            if ($return_code !== 0) {
                return ['error' => 'Failed to fetch video information. Make sure yt-dlp is installed.'];
            }
        }

        $json = implode('', $output);
        $data = json_decode($json, true);

        if (!$data) {
            return ['error' => 'Failed to parse video information'];
        }

        return [
            'title' => $data['title'] ?? 'Unknown',
            'duration' => $this->formatDuration($data['duration'] ?? 0),
            'thumbnail' => $data['thumbnail'] ?? '',
            'uploader' => $data['uploader'] ?? '',
            'view_count' => $data['view_count'] ?? 0,
            'like_count' => $data['like_count'] ?? 0,
            'upload_date' => $data['upload_date'] ?? '',
            'description' => substr($data['description'] ?? '', 0, 200),
            'formats' => $this->getAvailableFormats($data['formats'] ?? [])
        ];
    }

    private function formatDuration($seconds) {
        if ($seconds < 60) {
            return $seconds . 's';
        } elseif ($seconds < 3600) {
            return floor($seconds / 60) . 'm ' . ($seconds % 60) . 's';
        } else {
            $hours = floor($seconds / 3600);
            $minutes = floor(($seconds % 3600) / 60);
            return $hours . 'h ' . $minutes . 'm';
        }
    }

    private function getAvailableFormats($formats) {
        $result = [];
        $qualities = ['2160p', '1440p', '1080p', '720p', '480p', '360p'];

        foreach ($qualities as $quality) {
            foreach ($formats as $format) {
                if (isset($format['height']) && $format['height'] . 'p' === $quality && isset($format['ext'])) {
                    $result[] = $quality;
                    break;
                }
            }
        }

        return $result ?: ['best'];
    }

    private function startBackgroundDownload($id, $url) {
        $safe_filename = preg_replace('/[^a-zA-Z0-9_-]/', '_', $id);
        $output_path = $this->downloads_dir . '/' . $safe_filename . '.%(ext)s';
        $log_file = dirname($this->queue_file) . '/yt_' . $id . '.log';

        // yt-dlp command with progress output
        $cmd = "yt-dlp " .
               "-f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best' " .
               "--merge-output-format mp4 " .
               "--no-playlist " .
               "--newline " .
               "--progress " .
               "-o '$output_path' " .
               "'$url' > '$log_file' 2>&1 &";

        exec($cmd);

        // Update queue status
        $queue = $this->getQueue();
        foreach ($queue as &$item) {
            if ($item['id'] === $id) {
                $item['status'] = 'downloading';
                break;
            }
        }
        $this->saveQueue($queue);
    }

    public function getQueueStatus() {
        $queue = $this->getQueue();

        // Update progress for downloading items
        foreach ($queue as &$item) {
            if ($item['status'] === 'downloading') {
                $progress = $this->getDownloadProgress($item['id']);
                $item['progress'] = $progress;

                // Check if completed
                if ($progress >= 100) {
                    $item['status'] = 'completed';
                    $item['progress'] = 100;

                    // Find the downloaded file
                    $pattern = $this->downloads_dir . '/' . $item['id'] . '.*';
                    $files = glob($pattern);
                    if (!empty($files)) {
                        $item['filename'] = basename($files[0]);
                        $item['path'] = '/media/' . basename($files[0]);
                    }
                } elseif ($progress === -1) {
                    $item['status'] = 'error';
                    $item['error'] = 'Download failed';
                }
            }
        }

        $this->saveQueue($queue);

        // Process pending items if slots available
        $downloading_count = count(array_filter($queue, function($item) {
            return $item['status'] === 'downloading';
        }));

        if ($downloading_count < $this->max_concurrent) {
            foreach ($queue as &$item) {
                if ($item['status'] === 'pending') {
                    $this->startBackgroundDownload($item['id'], $item['url']);
                    break;
                }
            }
        }

        return $queue;
    }

    private function getDownloadProgress($id) {
        $log_file = dirname($this->queue_file) . '/yt_' . $id . '.log';

        if (!file_exists($log_file)) {
            return 0;
        }

        $content = file_get_contents($log_file);

        // Check for completion
        if (strpos($content, '[download] 100%') !== false ||
            strpos($content, '[Merger] Merging') !== false) {
            return 100;
        }

        // Check for errors
        if (strpos($content, 'ERROR:') !== false) {
            return -1;
        }

        // Extract progress percentage
        preg_match_all('/\[download\]\s+(\d+(?:\.\d+)?)\%/', $content, $matches);
        if (!empty($matches[1])) {
            return floatval(end($matches[1]));
        }

        return 0;
    }

    private function getQueue() {
        if (file_exists($this->queue_file)) {
            $content = file_get_contents($this->queue_file);
            return json_decode($content, true) ?: [];
        }
        return [];
    }

    private function saveQueue($queue) {
        file_put_contents($this->queue_file, json_encode($queue, JSON_PRETTY_PRINT));
    }

    public function clearQueue() {
        // Stop all downloads
        exec("pkill -f 'yt-dlp'");
        exec("pkill -f 'youtube-dl'");

        // Clear queue file
        $this->saveQueue([]);

        // Remove log files
        $logs = glob(dirname($this->queue_file) . '/yt_*.log');
        foreach ($logs as $log) {
            unlink($log);
        }

        return ['success' => true, 'message' => 'Queue cleared'];
    }

    public function removeFromQueue($id) {
        $queue = $this->getQueue();
        $queue = array_filter($queue, function($item) use ($id) {
            return $item['id'] !== $id;
        });
        $this->saveQueue(array_values($queue));

        // Kill download if running
        exec("pkill -f 'yt-dlp.*$id'");

        // Remove log file
        $log_file = dirname($this->queue_file) . '/yt_' . $id . '.log';
        if (file_exists($log_file)) {
            unlink($log_file);
        }

        return ['success' => true, 'removed' => $id];
    }
}

// Handle requests
$service = new YouTubeService();
$data = json_decode(file_get_contents('php://input'), true);

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        if (isset($_GET['action'])) {
            switch ($_GET['action']) {
                case 'queue':
                    echo json_encode($service->getQueueStatus());
                    break;
                case 'info':
                    $url = $_GET['url'] ?? '';
                    echo json_encode($service->getVideoInfo($url));
                    break;
                default:
                    echo json_encode(['error' => 'Invalid action']);
            }
        } else {
            echo json_encode($service->getQueueStatus());
        }
        break;

    case 'POST':
        if (isset($data['url'])) {
            echo json_encode($service->downloadVideo($data['url']));
        } else {
            echo json_encode(['error' => 'No URL provided']);
        }
        break;

    case 'DELETE':
        if (isset($_GET['id'])) {
            echo json_encode($service->removeFromQueue($_GET['id']));
        } elseif (isset($_GET['action']) && $_GET['action'] === 'clear') {
            echo json_encode($service->clearQueue());
        } else {
            echo json_encode(['error' => 'No ID provided']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
}