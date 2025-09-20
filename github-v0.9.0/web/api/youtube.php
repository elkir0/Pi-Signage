<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$action = $_POST['action'] ?? 'download';
$response = ['success' => false];

if ($action === 'download') {
    $url = $_POST['url'] ?? '';
    
    if (filter_var($url, FILTER_VALIDATE_URL)) {
        // Vérifier que c'est bien YouTube
        if (strpos($url, 'youtube.com') !== false || strpos($url, 'youtu.be') !== false) {
            $outputDir = '/opt/pisignage/media/';
            $outputFile = $outputDir . 'youtube_' . uniqid() . '.mp4';
            
            // Télécharger avec yt-dlp
            $cmd = "yt-dlp -f 'best[height<=720]' -o '$outputFile' '$url' 2>&1";
            exec($cmd, $output, $returnCode);
            
            if ($returnCode === 0 && file_exists($outputFile)) {
                $response['success'] = true;
                $response['file'] = basename($outputFile);
                $response['message'] = 'Téléchargement réussi!';
            } else {
                $response['error'] = 'Échec du téléchargement';
                $response['details'] = implode("\n", $output);
            }
        } else {
            $response['error'] = 'URL non YouTube';
        }
    } else {
        $response['error'] = 'URL invalide';
    }
}

echo json_encode($response);
