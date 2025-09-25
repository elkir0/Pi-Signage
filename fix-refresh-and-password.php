<?php
// Patch file to fix auto-refresh and password warning
// This file shows the changes needed
?>

<!-- FIX 1: Password field warning - wrap in form -->
<form id="network-form" onsubmit="return false;">
    <div class="form-group">
        <label class="form-label">WiFi SSID</label>
        <input type="text" class="form-control" id="wifi-ssid" placeholder="Nom du réseau">
    </div>
    <div class="form-group">
        <label class="form-label">Mot de passe</label>
        <input type="password" class="form-control" id="wifi-password" placeholder="Mot de passe" autocomplete="new-password">
    </div>
    <button type="button" class="btn btn-primary" onclick="saveNetworkConfig()">
        💾 Appliquer
    </button>
</form>

<script>
// FIX 2: Better auto-refresh after upload
// Replace the upload success callback with this:

function handleUploadSuccess() {
    showNotification('✅ Upload terminé avec succès!', 'success');
    closeModal();

    // Force refresh of media section
    setTimeout(() => {
        console.log('Force refreshing media list...');

        // Method 1: Try the global function
        if (typeof window.loadMediaFiles === 'function') {
            window.loadMediaFiles();
            return;
        }

        // Method 2: Click on media section to trigger refresh
        const mediaBtn = document.querySelector('[data-section="media"]');
        if (mediaBtn) {
            mediaBtn.click();
            return;
        }

        // Method 3: Force reload the section
        showSection('media');
    }, 1000); // Give more time for upload to complete
}
</script>