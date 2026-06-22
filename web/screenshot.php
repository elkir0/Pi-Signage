<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Capture d\'écran';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = '<button class="btn btn-primary" type="button" onclick="takeScreenshot()">' . icon('camera') . 'Capturer</button>';
?>
<div class="main">
    <?php pageHeader('Capture d\'écran', 'Aperçu en temps réel de l\'écran du lecteur', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <div class="card">
            <div class="card-head">
                <h2 class="card-title"><?= icon('camera') ?>Capture en temps réel</h2>
                <button class="btn btn-secondary btn-sm" id="auto-capture-btn" type="button" onclick="toggleAutoCapture()">Auto-capture (OFF)</button>
            </div>

            <div class="screenshot-preview" id="screenshot-preview">
                <img id="screenshot-img" src="" alt="Capture d'écran" style="display:none">
                <div class="empty-state" id="screenshot-empty">
                    <?= icon('camera') ?>
                    <h3>Aucune capture</h3>
                    <p>Cliquez sur « Capturer » pour générer un aperçu de l'écran.</p>
                </div>
            </div>
        </div>

      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>
