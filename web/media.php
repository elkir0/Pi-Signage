<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Media Section -->
        <div id="media" class="content-section active">
            <div class="header">
                <h1 class="page-title">Gestion des Médias</h1>
                <div class="header-actions">
                    <button id="upload-btn" class="btn btn-primary" onclick="openUploadModal()">
                        📤 Upload
                    </button>
                </div>
            </div>

            <div class="upload-zone" id="drop-zone" data-upload-zone>
                <div class="empty-state">
                    <div class="empty-state-icon">📁</div>
                    <div class="empty-state-title">Glisser-déposer des fichiers ici</div>
                    <div class="empty-state-text">ou cliquez pour parcourir</div>
                </div>
            </div>

            <div id="media-list" class="grid grid-3">
                <!-- Media files will be loaded here -->
            </div>
        </div>
    </div>

<script>
// Bridge functions for drag & drop compatibility
function dropHandler(event) {
    event.preventDefault();
    if (PiSignage && PiSignage.media && PiSignage.media.handleDrop) {
        PiSignage.media.handleDrop(event);
    }
}

function dragOverHandler(event) {
    event.preventDefault();
    if (PiSignage && PiSignage.media && PiSignage.media.handleDragOver) {
        PiSignage.media.handleDragOver(event);
    }
}

function dragLeaveHandler(event) {
    event.preventDefault();
    if (PiSignage && PiSignage.media && PiSignage.media.handleDragLeave) {
        PiSignage.media.handleDragLeave(event);
    }
}

// Initialize drag & drop on the drop zone after page load
document.addEventListener('DOMContentLoaded', function() {
    const dropZone = document.getElementById('drop-zone');
    if (dropZone) {
        dropZone.addEventListener('dragover', dragOverHandler);
        dropZone.addEventListener('dragleave', dragLeaveHandler);
        dropZone.addEventListener('drop', dropHandler);

        // Also make it clickable to open upload modal
        dropZone.addEventListener('click', function(e) {
            if (e.target.closest('.empty-state')) {
                openUploadModal();
            }
        });
    }
});
</script>

<?php include 'includes/footer.php'; ?>