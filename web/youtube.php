<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- YouTube Section -->
        <div id="youtube" class="content-section active">
            <div class="header">
                <h1 class="page-title">Téléchargement YouTube</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📥</span>
                    Télécharger une vidéo
                </h3>
                <div class="form-group">
                    <label class="form-label">URL YouTube</label>
                    <input type="url" class="form-control" id="youtube-url" placeholder="https://www.youtube.com/watch?v=...">
                </div>
                <div class="form-group">
                    <label class="form-label">Qualité</label>
                    <select class="form-control" id="youtube-quality">
                        <option value="best">Meilleure qualité</option>
                        <option value="720p">720p</option>
                        <option value="480p">480p</option>
                        <option value="360p">360p</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Compression</label>
                    <select class="form-control" id="youtube-compression">
                        <option value="none">Aucune</option>
                        <option value="h264">H.264 Optimisé</option>
                        <option value="ultralight">Ultra léger</option>
                    </select>
                </div>
                <button class="btn btn-primary" onclick="downloadYoutube()">
                    📥 Télécharger
                </button>
                <div class="progress-bar" style="display: none;" id="youtube-progress">
                    <div class="progress-fill" id="youtube-progress-fill"></div>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Historique
                </h3>
                <div id="youtube-history">
                    <!-- History will be loaded here -->
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>