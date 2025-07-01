<?php
/**
 * Gestion de la playlist Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

requireAuth();
setSecurityHeaders();

$message = '';
$messageType = '';

$selectedVideos = [];
if (file_exists(PLAYLIST_FILE)) {
    $data = json_decode(file_get_contents(PLAYLIST_FILE), true);
    if (!empty($data['videos'])) {
        foreach ($data['videos'] as $v) {
            if (isset($v['name'])) {
                $selectedVideos[] = $v['name'];
            }
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $videos = array_map('basename', $_POST['videos'] ?? []);
        $valid = [];
        foreach ($videos as $video) {
            if (isValidFilename($video)) {
                $valid[] = $video;
            }
        }
        if (savePlaylist($valid)) {
            $message = 'Playlist enregistrée avec succès';
            $messageType = 'success';
            $selectedVideos = $valid;
        } else {
            $message = "Erreur lors de l'enregistrement";
            $messageType = 'error';
        }
    } else {
        $message = 'Erreur de sécurité';
        $messageType = 'error';
    }
}

$videos = listVideos();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Playlist - Pi Signage</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
<?php include dirname(__DIR__) . '/templates/navigation.php'; ?>

<main class="container">
    <h1>📑 Gestion de la Playlist</h1>

    <?php if ($message): ?>
        <div class="alert alert-<?= $messageType ?>"><?= htmlspecialchars($message) ?></div>
    <?php endif; ?>

    <form method="post">
        <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
        <table class="table">
            <thead>
                <tr>
                    <th>Utiliser</th>
                    <th>Fichier</th>
                    <th>Taille</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($videos as $video): ?>
                <tr>
                    <td>
                        <input type="checkbox" name="videos[]" value="<?= htmlspecialchars($video['name']) ?>" <?= in_array($video['name'], $selectedVideos, true) ? 'checked' : '' ?>>
                    </td>
                    <td><?= htmlspecialchars($video['name']) ?></td>
                    <td><?= formatFileSize($video['size']) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <button type="submit" class="btn btn-success">Enregistrer</button>
    </form>
</main>

<script src="assets/js/main.js"></script>
</body>
</html>
