<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Screenshot Section -->
        <div id="screenshot" class="content-section active">
            <div class="header">
                <h1 class="page-title">Capture d'écran</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📸</span>
                    Capture en temps réel
                </h3>
                <div class="screenshot-preview" id="screenshot-preview">
                    <img id="screenshot-img" src="" alt="Capture d'écran" style="display: none;">
                    <div class="empty-state" id="screenshot-empty">
                        <div class="empty-state-icon">📸</div>
                        <div class="empty-state-title">Aucune capture</div>
                    </div>
                </div>
                <div class="player-controls">
                    <button class="btn btn-primary" onclick="takeScreenshot()">
                        📸 Prendre une capture
                    </button>
                    <button class="btn btn-glass" id="auto-capture-btn" onclick="toggleAutoCapture()">
                        🔄 Auto-capture (OFF)
                    </button>
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>