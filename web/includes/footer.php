    <!-- Alert Container -->
    <div id="alert-container" style="position: fixed; top: 20px; right: 20px; z-index: 3000;"></div>

    <!-- PiSignage Modular JavaScript - Loaded in correct dependency order -->
    <script src="functions.js?v=v0.11.0" defer></script>
    <script src="assets/js/core.js?v=v0.11.0" defer></script>
    <script src="assets/js/api.js?v=v0.11.0" defer></script>
    <script src="assets/js/dashboard.js?v=v0.11.0" defer></script>
    <script src="assets/js/media.js?v=v0.11.0" defer></script>
    <script src="assets/js/playlists.js?v=v0.11.0" defer></script>
    <script src="assets/js/player.js?v=v0.11.0" defer></script>
    <script src="assets/js/schedule.js?v=v0.11.0" defer></script>
    <script src="assets/js/settings.js?v=v0.11.0" defer></script>
    <script src="assets/js/init.js?v=v0.11.0" defer></script>

    <script>
        // Minimal compatibility globals for any remaining inline onclick handlers
        let currentSection = '<?= getCurrentPage() ?>';
        let autoScreenshotInterval = null;
        let systemStatsInterval = null;
        let currentPlayer = 'vlc'; // Défaut VLC
        let selectedPlayer = 'vlc';

        // Mobile menu toggle function
        function toggleSidebar() {
            const sidebar = document.getElementById('sidebar');
            sidebar.classList.toggle('active');
        }

        // All initialization is now handled by assets/js/init.js?v=v0.11.0
        console.log('📄 Multi-page architecture: Basic globals defined, modular initialization will take over');
    </script>
</body>
</html>