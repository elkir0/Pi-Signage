<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v<?= $config['version'] ?> - <?= ucfirst(getCurrentPage()) ?></title>
    <link rel="stylesheet" href="assets/css/main.css?v=870">
</head>
<body>
    <!-- Menu Toggle (Mobile) -->
    <div class="menu-toggle" onclick="toggleSidebar()">
        <svg width="24" height="24" fill="currentColor">
            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
        </svg>
    </div>