<?php
/**
 * PiSignage v0.8.5 - Index Redirect
 * Multi-page architecture - redirects to dashboard.php
 */
require_once 'includes/auth.php';
requireAuth();

// Redirect to dashboard
header('Location: dashboard.php');
exit;
?>