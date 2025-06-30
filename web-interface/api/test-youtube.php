<?php
/**
 * Script de test pour diagnostiquer les problèmes YouTube
 */

// Activer l'affichage des erreurs pour le diagnostic
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/plain; charset=utf-8');

echo "=== Test de l'API YouTube ===\n\n";

// Test 1: Vérifier les includes
echo "1. Test des includes:\n";
$includes = [
    '../includes/config.php',
    '../includes/auth.php',
    '../includes/functions.php',
    '../includes/security.php'
];

foreach ($includes as $file) {
    if (file_exists($file)) {
        echo "   ✓ $file existe\n";
    } else {
        echo "   ✗ $file MANQUANT!\n";
    }
}

// Inclure les fichiers nécessaires
define('PI_SIGNAGE_WEB', true);

try {
    require_once '../includes/config.php';
    echo "\n2. Config chargée avec succès\n";
    
    // Test 2: Vérifier les constantes
    echo "\n3. Vérification des constantes:\n";
    $constants = ['VIDEO_DIR', 'YTDLP_BIN', 'PROGRESS_DIR', 'DISPLAY_MODE'];
    foreach ($constants as $const) {
        if (defined($const)) {
            echo "   ✓ $const = " . constant($const) . "\n";
        } else {
            echo "   ✗ $const NON DÉFINI!\n";
        }
    }
    
    // Test 3: Vérifier yt-dlp
    echo "\n4. Vérification de yt-dlp:\n";
    if (defined('YTDLP_BIN')) {
        $ytdlp = YTDLP_BIN;
        if (file_exists($ytdlp)) {
            echo "   ✓ yt-dlp existe à: $ytdlp\n";
            if (is_executable($ytdlp)) {
                echo "   ✓ yt-dlp est exécutable\n";
                
                // Tester l'exécution
                exec($ytdlp . ' --version 2>&1', $output, $status);
                if ($status === 0) {
                    echo "   ✓ Version: " . $output[0] . "\n";
                } else {
                    echo "   ✗ Erreur d'exécution: " . implode("\n", $output) . "\n";
                }
            } else {
                echo "   ✗ yt-dlp n'est PAS exécutable!\n";
            }
        } else {
            echo "   ✗ yt-dlp n'existe pas à: $ytdlp\n";
        }
    }
    
    // Test 4: Vérifier les répertoires
    echo "\n5. Vérification des répertoires:\n";
    if (defined('VIDEO_DIR')) {
        $dir = VIDEO_DIR;
        if (is_dir($dir)) {
            echo "   ✓ VIDEO_DIR existe: $dir\n";
            if (is_writable($dir)) {
                echo "   ✓ VIDEO_DIR est writable\n";
            } else {
                echo "   ✗ VIDEO_DIR n'est PAS writable!\n";
            }
        } else {
            echo "   ✗ VIDEO_DIR n'existe pas: $dir\n";
        }
    }
    
    if (defined('PROGRESS_DIR')) {
        $dir = PROGRESS_DIR;
        if (is_dir($dir)) {
            echo "   ✓ PROGRESS_DIR existe: $dir\n";
            if (is_writable($dir)) {
                echo "   ✓ PROGRESS_DIR est writable\n";
            } else {
                echo "   ✗ PROGRESS_DIR n'est PAS writable!\n";
            }
        } else {
            echo "   ✗ PROGRESS_DIR n'existe pas: $dir\n";
            echo "     Tentative de création...\n";
            if (@mkdir($dir, 0777, true)) {
                echo "     ✓ Créé avec succès\n";
            } else {
                echo "     ✗ Échec de la création\n";
            }
        }
    }
    
    // Test 5: Tester la fonction downloadYouTubeVideo
    echo "\n6. Test de la fonction downloadYouTubeVideo:\n";
    require_once '../includes/functions.php';
    
    if (function_exists('downloadYouTubeVideo')) {
        echo "   ✓ Fonction downloadYouTubeVideo existe\n";
    } else {
        echo "   ✗ Fonction downloadYouTubeVideo MANQUANTE!\n";
    }
    
    // Test 6: Informations PHP
    echo "\n7. Informations PHP:\n";
    echo "   PHP Version: " . phpversion() . "\n";
    echo "   Utilisateur: " . get_current_user() . "\n";
    echo "   Processus: " . posix_getpwuid(posix_geteuid())['name'] . "\n";
    
} catch (Exception $e) {
    echo "\n✗ ERREUR: " . $e->getMessage() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}

echo "\n=== Fin du test ===\n";