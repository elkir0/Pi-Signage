<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$mediaDir = '/opt/pisignage/media/';
$scriptsDir = '/opt/pisignage/scripts/';

$action = $_GET['action'] ?? $_POST['action'] ?? '';

switch($action) {
    
    case 'download-test-videos':
        // Télécharger les vidéos de test
        $testVideosScript = $scriptsDir . 'download-test-videos.sh';
        
        if (!file_exists($testVideosScript)) {
            // Créer le script s'il n'existe pas
            $scriptContent = '#!/bin/bash
# Télécharger les vidéos de test
MEDIA_DIR="/opt/pisignage/media"
mkdir -p "$MEDIA_DIR"

echo "Téléchargement des vidéos de test..."

# Big Buck Bunny (30 secondes, ~10MB)
if [ ! -f "$MEDIA_DIR/Big_Buck_Bunny.mp4" ]; then
    wget -q -O "$MEDIA_DIR/Big_Buck_Bunny.mp4" \
        "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_30mb.mp4" || \
    wget -q -O "$MEDIA_DIR/Big_Buck_Bunny.mp4" \
        "https://www.w3schools.com/html/mov_bbb.mp4"
    echo "✓ Big Buck Bunny téléchargé"
fi

# Sintel Trailer
if [ ! -f "$MEDIA_DIR/Sintel.mp4" ]; then
    wget -q -O "$MEDIA_DIR/Sintel.mp4" \
        "https://media.w3.org/2010/05/sintel/trailer.mp4"
    echo "✓ Sintel téléchargé"
fi

# Tears of Steel
if [ ! -f "$MEDIA_DIR/Tears_of_Steel.mp4" ]; then
    wget -q -O "$MEDIA_DIR/Tears_of_Steel.mp4" \
        "https://media.w3.org/2010/05/bunny/trailer.mp4"
    echo "✓ Tears of Steel téléchargé"
fi

echo "Téléchargement terminé!"
ls -lh "$MEDIA_DIR"/*.mp4
';
            file_put_contents($testVideosScript, $scriptContent);
            chmod($testVideosScript, 0755);
        }
        
        // Exécuter le script
        $output = shell_exec($testVideosScript . ' 2>&1');
        
        // Lister les fichiers téléchargés
        $files = [];
        $videos = glob($mediaDir . '*.mp4');
        foreach ($videos as $video) {
            $files[] = [
                'name' => basename($video),
                'size' => filesize($video),
                'path' => $video
            ];
        }
        
        echo json_encode([
            'success' => true,
            'message' => 'Vidéos de test téléchargées',
            'files' => $files,
            'output' => $output
        ]);
        break;
        
    case 'optimize':
        // Optimiser une vidéo pour la lecture
        $filename = basename($_POST['file'] ?? '');
        
        if (!$filename || !preg_match('/\.(mp4|avi|mkv|mov|webm)$/i', $filename)) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier invalide'
            ]);
            break;
        }
        
        $inputFile = $mediaDir . $filename;
        $outputFile = $mediaDir . 'optimized_' . $filename;
        
        if (!file_exists($inputFile)) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier introuvable'
            ]);
            break;
        }
        
        // Commande FFmpeg pour optimiser la vidéo
        // - Codec H.264 pour compatibilité maximale
        // - Bitrate adaptatif
        // - Format conteneur MP4
        $cmd = sprintf(
            'ffmpeg -i %s -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart %s 2>&1',
            escapeshellarg($inputFile),
            escapeshellarg($outputFile)
        );
        
        // Exécuter en arrière-plan avec un fichier de progression
        $progressFile = "/tmp/optimize_" . md5($filename) . ".progress";
        $pidFile = "/tmp/optimize_" . md5($filename) . ".pid";
        
        // Commande avec progression
        $fullCmd = sprintf(
            '(ffmpeg -i %s -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart -progress %s %s 2>&1 & echo $! > %s) &',
            escapeshellarg($inputFile),
            escapeshellarg($progressFile),
            escapeshellarg($outputFile),
            escapeshellarg($pidFile)
        );
        
        shell_exec($fullCmd);
        
        // Attendre que le PID soit écrit
        usleep(100000); // 100ms
        
        $pid = file_exists($pidFile) ? trim(file_get_contents($pidFile)) : null;
        
        echo json_encode([
            'success' => true,
            'message' => 'Optimisation démarrée',
            'pid' => $pid,
            'input' => $filename,
            'output' => 'optimized_' . $filename,
            'progressFile' => $progressFile
        ]);
        break;
        
    case 'optimize-progress':
        // Vérifier la progression de l'optimisation
        $progressFile = "/tmp/optimize_" . md5($_GET['file'] ?? '') . ".progress";
        
        if (!file_exists($progressFile)) {
            echo json_encode([
                'success' => false,
                'error' => 'Aucune optimisation en cours pour ce fichier'
            ]);
            break;
        }
        
        // Lire les dernières lignes du fichier de progression
        $lines = file($progressFile);
        $progress = [];
        
        foreach ($lines as $line) {
            if (preg_match('/(\w+)=(.+)/', $line, $matches)) {
                $progress[$matches[1]] = $matches[2];
            }
        }
        
        echo json_encode([
            'success' => true,
            'progress' => $progress,
            'completed' => isset($progress['progress']) && $progress['progress'] === 'end'
        ]);
        break;
        
    case 'cleanup':
        // Nettoyer les médias inutilisés
        $dryRun = ($_GET['dry_run'] ?? 'true') === 'true';
        
        // Charger les playlists pour voir quels médias sont utilisés
        $playlistFile = '/opt/pisignage/config/playlists.json';
        $usedMedia = [];
        
        if (file_exists($playlistFile)) {
            $playlists = json_decode(file_get_contents($playlistFile), true) ?? [];
            foreach ($playlists as $playlist) {
                if (isset($playlist['videos']) && is_array($playlist['videos'])) {
                    $usedMedia = array_merge($usedMedia, $playlist['videos']);
                }
            }
        }
        
        $usedMedia = array_unique($usedMedia);
        
        // Trouver tous les fichiers média
        $allMedia = [];
        $extensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif'];
        foreach ($extensions as $ext) {
            $files = glob($mediaDir . "*.$ext");
            foreach ($files as $file) {
                $allMedia[] = basename($file);
            }
        }
        
        // Identifier les fichiers non utilisés
        $unusedMedia = array_diff($allMedia, $usedMedia);
        $freedSpace = 0;
        $deletedFiles = [];
        
        foreach ($unusedMedia as $file) {
            $filepath = $mediaDir . $file;
            if (file_exists($filepath)) {
                $filesize = filesize($filepath);
                $freedSpace += $filesize;
                
                if (!$dryRun) {
                    // Vraiment supprimer le fichier
                    if (unlink($filepath)) {
                        $deletedFiles[] = [
                            'name' => $file,
                            'size' => $filesize
                        ];
                    }
                } else {
                    // Mode dry-run, juste lister
                    $deletedFiles[] = [
                        'name' => $file,
                        'size' => $filesize
                    ];
                }
            }
        }
        
        echo json_encode([
            'success' => true,
            'dryRun' => $dryRun,
            'message' => $dryRun ? 'Simulation du nettoyage' : 'Nettoyage effectué',
            'deletedFiles' => $deletedFiles,
            'freedSpace' => $freedSpace,
            'freedSpaceFormatted' => formatBytes($freedSpace),
            'totalUnused' => count($unusedMedia),
            'totalMedia' => count($allMedia),
            'totalUsed' => count($usedMedia)
        ]);
        break;
        
    case 'add-to-playlist':
        // Ajouter un média à une playlist
        $media = basename($_POST['media'] ?? '');
        $playlistId = $_POST['playlist_id'] ?? null;
        
        if (!$media || !$playlistId) {
            echo json_encode([
                'success' => false,
                'error' => 'Paramètres manquants'
            ]);
            break;
        }
        
        // Charger les playlists
        $playlistFile = '/opt/pisignage/config/playlists.json';
        $playlists = [];
        
        if (file_exists($playlistFile)) {
            $playlists = json_decode(file_get_contents($playlistFile), true) ?? [];
        }
        
        // Trouver et mettre à jour la playlist
        $updated = false;
        foreach ($playlists as &$playlist) {
            if ($playlist['id'] === $playlistId) {
                if (!isset($playlist['videos'])) {
                    $playlist['videos'] = [];
                }
                
                // Vérifier si le média n'est pas déjà dans la playlist
                if (!in_array($media, $playlist['videos'])) {
                    $playlist['videos'][] = $media;
                    $updated = true;
                }
                break;
            }
        }
        
        if ($updated) {
            // Sauvegarder les playlists
            file_put_contents($playlistFile, json_encode($playlists, JSON_PRETTY_PRINT));
            
            echo json_encode([
                'success' => true,
                'message' => 'Média ajouté à la playlist'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Playlist introuvable ou média déjà présent'
            ]);
        }
        break;
        
    case 'get-info':
        // Obtenir des informations détaillées sur un média
        $filename = basename($_GET['file'] ?? '');
        
        if (!$filename) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier non spécifié'
            ]);
            break;
        }
        
        $filepath = $mediaDir . $filename;
        
        if (!file_exists($filepath)) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier introuvable'
            ]);
            break;
        }
        
        $info = [
            'name' => $filename,
            'size' => filesize($filepath),
            'sizeFormatted' => formatBytes(filesize($filepath)),
            'modified' => date('Y-m-d H:i:s', filemtime($filepath)),
            'type' => mime_content_type($filepath)
        ];
        
        // Pour les vidéos, obtenir des infos supplémentaires
        if (preg_match('/\.(mp4|avi|mkv|mov|webm)$/i', $filename)) {
            $cmd = sprintf(
                'ffprobe -v quiet -print_format json -show_format -show_streams %s 2>/dev/null',
                escapeshellarg($filepath)
            );
            
            $ffprobeOutput = shell_exec($cmd);
            if ($ffprobeOutput) {
                $ffprobeData = json_decode($ffprobeOutput, true);
                
                // Extraire les infos pertinentes
                if (isset($ffprobeData['format'])) {
                    $info['duration'] = round($ffprobeData['format']['duration'] ?? 0);
                    $info['bitrate'] = $ffprobeData['format']['bit_rate'] ?? 0;
                }
                
                // Infos sur les streams
                if (isset($ffprobeData['streams'])) {
                    foreach ($ffprobeData['streams'] as $stream) {
                        if ($stream['codec_type'] === 'video') {
                            $info['video'] = [
                                'codec' => $stream['codec_name'] ?? '',
                                'width' => $stream['width'] ?? 0,
                                'height' => $stream['height'] ?? 0,
                                'fps' => eval('return ' . ($stream['r_frame_rate'] ?? '0/1') . ';')
                            ];
                        } elseif ($stream['codec_type'] === 'audio') {
                            $info['audio'] = [
                                'codec' => $stream['codec_name'] ?? '',
                                'channels' => $stream['channels'] ?? 0,
                                'sample_rate' => $stream['sample_rate'] ?? 0
                            ];
                        }
                    }
                }
            }
        }
        
        echo json_encode([
            'success' => true,
            'info' => $info
        ]);
        break;
        
    default:
        echo json_encode([
            'success' => false,
            'error' => 'Action non reconnue'
        ]);
}

// Fonction helper pour formater les tailles
function formatBytes($size) {
    if ($size >= 1073741824) return number_format($size / 1073741824, 2) . ' GB';
    if ($size >= 1048576) return number_format($size / 1048576, 2) . ' MB';
    if ($size >= 1024) return number_format($size / 1024, 2) . ' KB';
    return $size . ' B';
}