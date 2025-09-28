<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Schedule Section -->
        <div id="schedule" class="content-section active">
            <div class="header">
                <h1 class="page-title">Programmation</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="addSchedule()">
                        ➕ Ajouter
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📅</span>
                    Calendrier
                </h3>
                <div id="schedule-list">
                    <!-- Schedule items will be loaded here -->
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>