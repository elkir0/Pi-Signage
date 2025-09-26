<?php
// Script de diagnostic pour PiSignage
// À copier sur le Raspberry Pi dans /opt/pisignage/web/diagnose.php

error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/plain');

echo "=== DIAGNOSTIC PISIGNAGE ===\n\n";

// 1. Version PHP
echo "1. PHP Version: " . PHP_VERSION . "\n";

// 2. Extensions chargées
echo "\n2. Extensions PHP:\n";
$required_extensions = ['pdo', 'pdo_sqlite', 'json', 'mbstring', 'gd', 'fileinfo'];
foreach ($required_extensions as $ext) {
    echo "  - $ext: " . (extension_loaded($ext) ? "✓ OK" : "✗ MANQUANT") . "\n";
}

// 3. Limites d'upload
echo "\n3. Limites d'upload:\n";
echo "  - upload_max_filesize: " . ini_get('upload_max_filesize') . "\n";
echo "  - post_max_size: " . ini_get('post_max_size') . "\n";
echo "  - max_execution_time: " . ini_get('max_execution_time') . "\n";
echo "  - memory_limit: " . ini_get('memory_limit') . "\n";

// 4. Chemins et permissions
echo "\n4. Vérification des chemins:\n";
$paths = [
    '/opt/pisignage' => 'BASE_DIR',
    '/opt/pisignage/media' => 'MEDIA_DIR',
    '/opt/pisignage/data' => 'DATA_DIR',
    '/opt/pisignage/logs' => 'LOGS_DIR',
    '/opt/pisignage/playlists' => 'PLAYLISTS_DIR',
    '/tmp/nginx_upload' => 'NGINX_UPLOAD'
];

foreach ($paths as $path => $name) {
    if (is_dir($path)) {
        $perms = substr(sprintf('%o', fileperms($path)), -4);
        $owner = posix_getpwuid(fileowner($path))['name'];
        $group = posix_getgrgid(filegroup($path))['name'];
        $writable = is_writable($path) ? 'W' : 'R';
        echo "  - $name: ✓ ($perms $owner:$group $writable)\n";
    } else {
        echo "  - $name: ✗ N'existe pas\n";
    }
}

// 5. Test config.php
echo "\n5. Test config.php:\n";
$config_file = '/opt/pisignage/web/config.php';
if (file_exists($config_file)) {
    echo "  - Fichier existe: ✓\n";

    // Tester l'inclusion
    ob_start();
    $error = null;
    try {
        require_once $config_file;
        echo "  - Inclusion: ✓\n";

        // Vérifier les constantes
        $constants = ['BASE_DIR', 'MEDIA_PATH', 'MAX_UPLOAD_SIZE', 'PISIGNAGE_VERSION'];
        foreach ($constants as $const) {
            if (defined($const)) {
                echo "  - $const: ✓ (" . constant($const) . ")\n";
            } else {
                echo "  - $const: ✗ Non défini\n";
            }
        }

        // Vérifier la DB
        if (isset($db) && $db !== null) {
            echo "  - Base de données: ✓ SQLite connecté\n";
        } else {
            echo "  - Base de données: ⚠ Mode dégradé (pas de DB)\n";
        }

    } catch (Exception $e) {
        echo "  - Erreur: " . $e->getMessage() . "\n";
        $error = $e;
    } catch (ParseError $e) {
        echo "  - Erreur de syntaxe: " . $e->getMessage() . "\n";
        $error = $e;
    }
    ob_end_clean();

    if ($error) {
        echo "  - Ligne: " . $error->getLine() . "\n";
        echo "  - Fichier: " . $error->getFile() . "\n";
    }
} else {
    echo "  - config.php: ✗ N'existe pas!\n";
}

// 6. Test API simple
echo "\n6. Test API simple:\n";
try {
    // Créer une réponse JSON simple
    $test_data = [
        'success' => true,
        'message' => 'Test OK',
        'timestamp' => date('Y-m-d H:i:s')
    ];
    $json = json_encode($test_data);
    if ($json) {
        echo "  - JSON encoding: ✓\n";
    } else {
        echo "  - JSON encoding: ✗ " . json_last_error_msg() . "\n";
    }
} catch (Exception $e) {
    echo "  - Erreur API: " . $e->getMessage() . "\n";
}

// 7. Permissions utilisateur web
echo "\n7. Utilisateur PHP:\n";
echo "  - User: " . get_current_user() . "\n";
echo "  - UID: " . getmyuid() . "\n";
echo "  - GID: " . getmygid() . "\n";

// 8. Test écriture
echo "\n8. Test écriture:\n";
$test_file = '/opt/pisignage/data/test_write.txt';
$test_content = "Test " . date('Y-m-d H:i:s');
if (@file_put_contents($test_file, $test_content)) {
    echo "  - Écriture dans /data: ✓\n";
    @unlink($test_file);
} else {
    echo "  - Écriture dans /data: ✗\n";
}

// 9. Erreur log
echo "\n9. Dernières erreurs PHP:\n";
$log_file = '/opt/pisignage/logs/php_error.log';
if (file_exists($log_file)) {
    $lines = array_slice(file($log_file), -5);
    foreach ($lines as $line) {
        echo "  " . trim($line) . "\n";
    }
} else {
    echo "  - Pas de log d'erreur\n";
}

echo "\n=== FIN DU DIAGNOSTIC ===\n";
?>