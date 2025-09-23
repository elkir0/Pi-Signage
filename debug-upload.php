<?php
/**
 * Debug script to see what's being received
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

echo "DEBUG Upload - " . date('Y-m-d H:i:s') . "\n\n";

echo "REQUEST_METHOD: " . $_SERVER['REQUEST_METHOD'] . "\n";
echo "Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'Not set') . "\n\n";

echo "POST data:\n";
var_dump($_POST);

echo "\nFILES data:\n";
var_dump($_FILES);

echo "\nRaw input:\n";
echo "php://input length: " . strlen(file_get_contents('php://input')) . " bytes\n";

if (isset($_FILES['files'])) {
    echo "\nFiles array analysis:\n";
    echo "files[name]: " . print_r($_FILES['files']['name'], true) . "\n";
    echo "files[tmp_name]: " . print_r($_FILES['files']['tmp_name'], true) . "\n";
    echo "files[size]: " . print_r($_FILES['files']['size'], true) . "\n";
    echo "files[error]: " . print_r($_FILES['files']['error'], true) . "\n";
}

echo "\nCondition checks:\n";
echo "isset(\$_FILES['files']): " . (isset($_FILES['files']) ? 'YES' : 'NO') . "\n";
echo "empty(\$_FILES['files']['name'][0]): " . (empty($_FILES['files']['name'][0]) ? 'YES' : 'NO') . "\n";
?>