<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Logs Section -->
        <div id="logs" class="content-section active">
            <div class="header">
                <h1 class="page-title">Logs Système</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="refreshLogs()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Logs récents
                </h3>
                <div id="logs-content" style="background: rgba(0,0,0,0.3); padding: 20px; border-radius: 10px; font-family: monospace; font-size: 12px; max-height: 500px; overflow-y: auto;">
                    <!-- Logs will be loaded here -->
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>