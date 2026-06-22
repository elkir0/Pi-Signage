<?php
/**
 * PiSignage — DÉPRÉCIÉ (VLC retiré en v0.12). Ancienne API de contrôle VLC (port 8080).
 *
 * Le contrôle du lecteur réel (Chromium) passe par /api/display.php :
 *  - POST ?action=command {cmd:next|prev|play|pause|reload}
 *  - GET  ?action=state
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/../config.php';

jsonResponse(false, null,
    'VLC retiré : endpoint déprécié. Utilisez /api/display.php (transport/état du lecteur Chromium).',
    410);
