<?php
/**
 * PiSignage — Shared footer: toast container + versioned scripts.
 */
if (!defined('ASSET_VERSION')) { define('ASSET_VERSION', $config['version'] ?? '0.12.0'); }
$v = ASSET_VERSION;
?>
    <!-- Toast / notification container -->
    <div id="toast-container" aria-live="polite" aria-atomic="true"></div>

    <!-- PiSignage modular JS — dependency order (core establishes namespace first) -->
    <script src="assets/js/core.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/api.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/theme.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/ui.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/dashboard.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/media.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/playlists.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/player.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/schedule.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/settings.js?v=<?= $v ?>" defer></script>
    <script src="assets/js/init.js?v=<?= $v ?>" defer></script>
</body>
</html>
