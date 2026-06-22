<?php
/**
 * PiSignage — Shared <head> + body open.
 * Requires $config (from auth.php). Provides anti-flash theme init, CSS, icons.
 */
if (!defined('ASSET_VERSION')) { define('ASSET_VERSION', $config['version'] ?? '0.12.0'); }
require_once __DIR__ . '/icons.php';
$pageTitle = $pageTitle ?? ucfirst(getCurrentPage());
?><!DOCTYPE html>
<html lang="fr" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="dark light">
    <title>PiSignage · <?= htmlspecialchars($pageTitle) ?></title>
    <!-- Anti-flash: apply saved theme before first paint -->
    <script>
      (function(){
        try{
          var t = localStorage.getItem('pisignage-theme');
          if(!t){ t = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'; }
          document.documentElement.setAttribute('data-theme', t);
        }catch(e){}
      })();
    </script>
    <link rel="stylesheet" href="assets/css/main.css?v=<?= ASSET_VERSION ?>">
</head>
<body data-page="<?= htmlspecialchars(getCurrentPage()) ?>">
