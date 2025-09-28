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
                    <button class="btn btn-primary" onclick="openUploadModal()">
                        📤 Upload
                    </button>
                </div>
            </div>

            <div class="upload-zone" id="upload-zone" ondrop="dropHandler(event);" ondragover="dragOverHandler(event);" ondragleave="dragLeaveHandler(event);">
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

<?php include 'includes/footer.php'; ?>