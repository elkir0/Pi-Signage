<?php
/**
 * PiSignage — DÉPRÉCIÉ (VLC retiré en v0.12). Ancienne API de lecture VLC.
 *
 * Le moteur de lecture unique est désormais Chromium HTML5 (player.php sur /player).
 *  - Transport / état du lecteur : /api/display.php
 *  - Lecture directe d'un média  : /api/display.php?action=playmedia
 *  - Diffuser une playlist        : /api/playlists.php?action=activate
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/../config.php';

jsonResponse(false, null,
    'VLC retiré : endpoint déprécié. Utilisez /api/display.php (transport/état/lecture directe) ou /api/playlists.php (diffusion).',
    410);
