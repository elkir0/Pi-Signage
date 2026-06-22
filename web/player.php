<?php
/**
 * PiSignage Chromium HTML5 Player
 * Page minimaliste pour lecture vidéo fullscreen avec playlist
 *
 * Features:
 * - HTML5 <video> fullscreen autoplay
 * - Gestion playlist JSON (autoLoop, autoplay)
 * - Support MP4 (H.264/AAC) et WebM (VP9/Opus)
 * - Wake Lock API (empêche veille écran)
 * - Masquage curseur
 * - Auto-retry sur erreur
 * - Enchaînement automatique
 */

// Kiosk : ne jamais mettre cette page en cache côté Chromium — sinon une mise à jour de
// player.php (overlay, correctifs) n'apparaît qu'après vidage du cache. On force le frais.
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Expires: 0');
?>
<!DOCTYPE html>
<html lang="fr" translate="no">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Désactive la barre de traduction Chrome sur le kiosk -->
    <meta name="google" content="notranslate">
    <title>PiSignage Player</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: #000;
            overflow: hidden;
            cursor: none; /* Masquer curseur */
            -webkit-user-select: none;
            user-select: none;
        }

        #player-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: #000;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        /* Double <video> (C1) : un joue pendant que l'autre précharge l'item suivant.
           Crossfade par opacité -> aucun flash noir entre les items. */
        #video, #video2 {
            position: absolute;
            inset: 0;
            width: 100%;
            height: 100%;
            object-fit: contain; /* mis à jour dynamiquement par item.fit */
            opacity: 0;
            transition: opacity .45s ease;
        }
        #video.is-active, #video2.is-active { opacity: 1; }

        #image {
            position: absolute;
            inset: 0;
            width: 100%;
            height: 100%;
            object-fit: contain; /* Default, sera mis à jour dynamiquement */
            opacity: 0;
            transition: opacity .45s ease;
            display: none; /* Masqué par défaut, affiché pour les items image */
        }
        #image.is-active { opacity: 1; }

        /* Splash de marque (R4) : affiché au boot et tant qu'aucun contenu ne joue,
           au lieu d'une page blanche / d'un simple texte. */
        #loading {
            position: absolute;
            inset: 0;
            z-index: 10;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 18px;
            background: radial-gradient(1200px 600px at 50% 35%, #0d1421 0%, #000 70%);
            color: #e6ebf2;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #loading .splash-logo {
            width: 84px;
            height: 84px;
            border-radius: 22px;
            background: linear-gradient(135deg, #34d399, #059669);
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 14px 40px -10px rgba(16, 185, 129, 0.55);
            animation: ps-pulse 1.8s ease-in-out infinite;
        }
        #loading .splash-logo svg { width: 46px; height: 46px; stroke: #04130c; stroke-width: 2.2; fill: none; }
        #loading .splash-title {
            font-size: 1.9rem;
            font-weight: 800;
            letter-spacing: -.5px;
        }
        #loading .splash-msg {
            font-size: 1rem;
            font-weight: 500;
            color: #8b98ad;
            letter-spacing: .2px;
        }
        @keyframes ps-pulse {
            0%, 100% { transform: scale(1);    box-shadow: 0 14px 40px -10px rgba(16,185,129,0.45); }
            50%      { transform: scale(1.06); box-shadow: 0 18px 52px -8px rgba(16,185,129,0.7); }
        }

        #error {
            position: absolute;
            color: #f87171;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 0.95rem;
            font-weight: 500;
            text-align: center;
            z-index: 10;
            display: none;
            padding: 18px 22px;
            background: rgba(10,15,26,0.9);
            border: 1px solid rgba(248,113,113,0.35);
            border-radius: 12px;
        }

        /* Debug overlay - masqué par défaut, visible sur Ctrl+D */
        #debug {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(0,0,0,0.8);
            color: #0f0;
            font-family: monospace;
            font-size: 0.8rem;
            padding: 10px;
            border-radius: 4px;
            z-index: 100;
            display: none;
            max-width: 400px;
            word-wrap: break-word;
        }

        /* ============================================================== */
        /* COUCHE OVERLAY (independante du lecteur)                        */
        /* Tokens emerald : accent #10b981 / bright #34d399 /             */
        /* contrast #04130c ; carte opaque #0a0f1aEE ; texte #e6ebf2.     */
        /* Animations limitees a opacity/transform (Pi4).                 */
        /* ============================================================== */
        #overlay-root {
            position: fixed;
            inset: 0;
            pointer-events: none;
            z-index: 5;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            color: #e6ebf2;
        }

        #overlay-root .ov-zone {
            position: absolute;
            /* will-change limite aux proprietes animees (anti burn-in) */
            will-change: transform;
        }

        /* ----- Horloge + date (haut-droite) ----- */
        #ov-clock {
            top: 3.2vh;
            right: 3vw;
            text-align: right;
            padding: 10px 16px;
            background: rgba(4, 19, 12, 0.55);
            border: 1px solid rgba(52, 211, 153, 0.28);
            border-radius: 12px;
            opacity: 0;
            transition: opacity .6s ease;
        }
        #ov-clock.ov-on { opacity: 1; }
        #ov-clock-time {
            font-size: 3.4vh;
            font-weight: 700;
            line-height: 1.05;
            letter-spacing: .5px;
            font-variant-numeric: tabular-nums;
            font-feature-settings: "tnum" 1;
            color: #ffffff;
            text-shadow: 0 1px 6px rgba(0,0,0,0.7);
        }
        #ov-clock-date {
            margin-top: 2px;
            font-size: 1.7vh;
            font-weight: 500;
            color: #34d399;
            text-transform: capitalize;
            text-shadow: 0 1px 4px rgba(0,0,0,0.7);
        }

        /* ----- Carte rotative (centre-bas) ----- */
        #ov-cards {
            left: 50%;
            bottom: 16vh;
            transform: translateX(-50%);
            width: min(62vw, 880px);
            height: 11vh;
            min-height: 78px;
        }
        #overlay-root .ov-card {
            position: absolute;
            inset: 0;
            display: flex;
            align-items: center;
            gap: 16px;
            padding: 14px 26px;
            background: rgba(10, 15, 26, 0.94); /* #0a0f1a ~94% */
            border: 1px solid rgba(16, 185, 129, 0.45);
            border-left: 4px solid #10b981;
            border-radius: 14px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.45);
            opacity: 0;
            transition: opacity 1.1s ease; /* crossfade lent */
        }
        #overlay-root .ov-card.ov-on { opacity: 1; }
        #overlay-root .ov-card-icon {
            flex: 0 0 auto;
            width: 6.2vh;
            height: 6.2vh;
            min-width: 40px;
            min-height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 50%;
            background: rgba(16, 185, 129, 0.16);
            border: 1px solid rgba(52, 211, 153, 0.5);
            color: #34d399;
        }
        #overlay-root .ov-card-icon svg {
            width: 58%;
            height: 58%;
            display: block;
        }
        #overlay-root .ov-card-text {
            flex: 1 1 auto;
            font-size: 2.7vh;
            font-weight: 600;
            line-height: 1.2;
            color: #e6ebf2;
            text-shadow: 0 1px 4px rgba(0,0,0,0.6);
            overflow: hidden;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
        }

        /* ----- QR (bas-droite) ----- */
        #ov-qr {
            right: 3vw;
            bottom: 16vh;
            display: none; /* active uniquement si qr.enabled */
            flex-direction: column;
            align-items: center;
            gap: 8px;
            padding: 12px;
            background: rgba(10, 15, 26, 0.94);
            border: 1px solid rgba(16, 185, 129, 0.45);
            border-radius: 14px;
            opacity: 0;
            transition: opacity .8s ease;
        }
        #ov-qr.ov-show { display: flex; }
        #ov-qr.ov-on { opacity: 1; }
        #ov-qr-canvas {
            width: 13vh;
            height: 13vh;
            min-width: 96px;
            min-height: 96px;
            background: #ffffff;
            border-radius: 6px;
            padding: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        #ov-qr-canvas img,
        #ov-qr-canvas canvas {
            width: 100%;
            height: 100%;
            display: block;
            image-rendering: pixelated;
        }
        #ov-qr-label {
            max-width: 14vh;
            text-align: center;
            font-size: 1.6vh;
            font-weight: 600;
            color: #34d399;
            line-height: 1.15;
        }

        /* ----- Bandeau bas ----- */
        #ov-banner {
            left: 0;
            right: 0;
            bottom: 0;
            opacity: 0;
            transition: opacity .6s ease;
        }
        #ov-banner.ov-on { opacity: 1; }
        #ov-banner .ov-banner-rule {
            height: 3px;
            width: 100%;
            background: linear-gradient(90deg, #04130c 0%, #10b981 35%, #34d399 50%, #10b981 65%, #04130c 100%);
        }
        #ov-banner .ov-banner-body {
            display: flex;
            align-items: center;
            gap: 18px;
            padding: 1.6vh 3vw;
            background: linear-gradient(0deg, rgba(4,19,12,0.92) 0%, rgba(4,19,12,0.70) 70%, rgba(4,19,12,0) 100%);
        }
        #ov-banner-logo {
            flex: 0 0 auto;
            height: 6vh;
            max-height: 64px;
            width: auto;
            display: none; /* affiche si logo present */
            border-radius: 8px;
        }
        #ov-banner-logo.ov-show { display: block; }
        #ov-banner .ov-banner-text {
            display: flex;
            flex-direction: column;
            gap: 2px;
            min-width: 0;
        }
        #ov-banner-name {
            font-size: 3vh;
            font-weight: 700;
            line-height: 1.1;
            color: #ffffff;
            text-shadow: 0 2px 8px rgba(0,0,0,0.8);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        #ov-banner-subtitle {
            font-size: 1.9vh;
            font-weight: 500;
            line-height: 1.15;
            color: #34d399;
            text-shadow: 0 1px 6px rgba(0,0,0,0.8);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
    </style>
</head>
<body>

<div id="player-container">
    <video id="video" playsinline></video>
    <video id="video2" playsinline></video>
    <img id="image" alt="">

    <!-- ============================================================== -->
    <!-- Couche overlay (independante du lecteur). z-index 5 :          -->
    <!-- au-dessus de #video / #image, sous #loading/#error/#debug.     -->
    <!-- pointer-events:none => ne capte jamais d'evenement.            -->
    <!-- ============================================================== -->
    <div id="overlay-root" aria-hidden="true">
        <div id="ov-clock" class="ov-zone">
            <div id="ov-clock-time">--:--</div>
            <div id="ov-clock-date">&nbsp;</div>
        </div>

        <div id="ov-cards" class="ov-zone">
            <div id="ov-card-a" class="ov-card"></div>
            <div id="ov-card-b" class="ov-card"></div>
        </div>

        <div id="ov-qr" class="ov-zone">
            <div id="ov-qr-canvas"></div>
            <div id="ov-qr-label"></div>
        </div>

        <div id="ov-banner" class="ov-zone">
            <div class="ov-banner-rule"></div>
            <div class="ov-banner-body">
                <img id="ov-banner-logo" alt="" />
                <div class="ov-banner-text">
                    <div id="ov-banner-name"></div>
                    <div id="ov-banner-subtitle"></div>
                </div>
            </div>
        </div>
    </div>

    <div id="loading">
        <div class="splash-logo"><svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg></div>
        <div class="splash-title">PiSignage</div>
        <div class="splash-msg" id="loading-msg">Démarrage…</div>
    </div>
    <div id="error"></div>
    <div id="debug">
        <div>Status: <span id="debug-status">initializing</span></div>
        <div>FPS: <span id="debug-fps">0</span></div>
        <div>Video: <span id="debug-video-info">-</span></div>
        <div>Playlist items: <span id="debug-playlist-items">0</span></div>
        <div>Current index: <span id="debug-current-index">-</span></div>
        <div>Current URL: <span id="debug-current-url">-</span></div>
        <div>Errors: <span id="debug-errors">0</span></div>
        <div>Wake Lock: <span id="debug-wakelock">-</span></div>
    </div>
</div>

<script>
/**
 * PiSignage Chromium HTML5 Player
 * Gestion complète de la playlist avec auto-retry et Wake Lock
 */

class PiSignagePlayer {
    constructor() {
        // Double <video> pour préchargement + crossfade (C1, anti flash noir).
        this.videoEls = [document.getElementById('video'), document.getElementById('video2')];
        this.activeIdx = 0;
        this.video = this.videoEls[this.activeIdx]; // référence TOUJOURS la vidéo active (visible)
        this.preloadIdx = -1;                       // index playlist préchargé dans la vidéo inactive
        this.image = document.getElementById('image');
        this.loading = document.getElementById('loading');
        this.errorDiv = document.getElementById('error');
        this.debug = document.getElementById('debug');
        
        this.playlist = null;
        this.currentIndex = 0;
        this.errorCount = 0;
        this.maxRetries = 3;
        this.wakeLock = null;
        this.pollInterval = null;
        this.commandInterval = null;
        this.stateInterval = null;
        this.lastCmdSeq = -1;   // -1 = baseline non initialisée (cf. startCommandPolling)
        this.paused = false;

        // Debug mode (Ctrl+D pour afficher)
        this.debugMode = false;

        // FPS counter
        this.fps = 0;
        this.frameCount = 0;
        this.lastFpsUpdate = Date.now();
        this.animationFrameId = null;

        this.init();
    }

    async init() {
        console.log('[PiSignage Player] Initializing...');
        this.setupEventListeners();
        this.setupKeyboardShortcuts();
        await this.loadPlaylist();
        await this.requestWakeLock();
        this.startPolling();
        this.startCommandPolling();
        this.startStateReporting();
        this.startFpsCounter();
    }

    setupEventListeners() {
        // Les écouteurs sont posés sur LES DEUX <video> ; chaque handler n'agit que pour
        // la vidéo ACTIVE (l'autre est en préchargement et ne doit pas piloter la lecture).
        this.videoEls.forEach((vid) => {
            vid.addEventListener('loadedmetadata', () => {
                if (vid !== this.video) return;
                console.log('[Video] Metadata loaded:', vid.duration, 'seconds');
                this.updateDebug('status', 'playing');
            });
            vid.addEventListener('canplay', () => {
                if (vid !== this.video) return;
                this.hideLoading();
            });
            vid.addEventListener('playing', () => {
                if (vid !== this.video) return;
                this.hideError();
            });
            vid.addEventListener('ended', () => {
                if (vid !== this.video) return;
                console.log('[Video] Ended');
                this.handleVideoEnded();
            });
            vid.addEventListener('error', () => {
                if (vid !== this.video) return;
                console.error('[Video] Error');
                this.handleVideoError();
            });
        });

        // Visibilité page (réacquérir Wake Lock si nécessaire)
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                this.requestWakeLock();
            }
        });
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl+D: Toggle debug overlay
            if (e.ctrlKey && e.key === 'd') {
                e.preventDefault();
                this.debugMode = !this.debugMode;
                this.debug.style.display = this.debugMode ? 'block' : 'none';
                if (this.debugMode) {
                    // Force immediate update when enabling debug
                    this.updateDebug('fps', this.fps);
                    this.updateVideoInfo();
                }
            }
            // Ctrl+R: Reload playlist
            if (e.ctrlKey && e.key === 'r') {
                e.preventDefault();
                this.reloadPlaylist();
            }
            // Ctrl+N: Next video
            if (e.ctrlKey && e.key === 'n') {
                e.preventDefault();
                this.playNext();
            }
        });
    }

    async loadPlaylist() {
        try {
            console.log('[Playlist] Loading from /api/playlist...');
            this.showLoading('Chargement de la playlist…');

            const response = await fetch('/api/playlist', { cache: 'no-store' });
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const result = await response.json();
            if (!result.success) {
                throw new Error(result.message || 'Failed to load playlist');
            }

            const pl = result.data;
            // Vérifier AVANT d'écraser la playlist courante (une réponse vide transitoire
            // ne doit pas effacer un contenu valide en cours de lecture).
            if (!pl.items || pl.items.length === 0) {
                throw new Error('Playlist is empty');
            }

            this.playlist = pl;
            console.log('[Playlist] Loaded:', this.playlist);
            this.updateDebug('playlist-items', this.playlist.items.length);

            // Cache hors-ligne (R5) : mémorise la dernière playlist valide.
            try { localStorage.setItem('pisignage:last-playlist', JSON.stringify(this.playlist)); } catch (e) {}

            // Démarrer lecture si autoplay
            if (this.playlist.autoplay) {
                this.playItem(0);
            } else {
                this.hideLoading();
            }

        } catch (error) {
            console.error('[Playlist] Load error:', error);

            // Déjà en lecture : ne rien casser, on garde le contenu courant à l'écran.
            if (this.playlist && this.playlist.items && this.playlist.items.length) {
                console.warn('[Playlist] Réseau/API indisponible — maintien du contenu courant.');
                return;
            }

            // Repli hors-ligne (R5) : rejouer la dernière playlist connue en cache.
            try {
                const cached = JSON.parse(localStorage.getItem('pisignage:last-playlist') || 'null');
                if (cached && cached.items && cached.items.length) {
                    console.warn('[Playlist] Repli hors-ligne : lecture du dernier contenu connu.');
                    this.playlist = cached;
                    this.updateDebug('playlist-items', cached.items.length);
                    if (cached.autoplay !== false) { this.playItem(0); } else { this.hideLoading(); }
                    return;
                }
            } catch (e) {}

            this.showError(`Failed to load playlist: ${error.message}`);
        }
    }

    async reloadPlaylist() {
        console.log('[Playlist] Reloading...');
        await this.loadPlaylist();
    }

    playItem(index) {
        if (!this.playlist || !this.playlist.items) {
            console.error('[Player] No playlist loaded');
            return;
        }

        if (index < 0 || index >= this.playlist.items.length) {
            console.error('[Player] Invalid index:', index);
            return;
        }

        this.currentIndex = index;
        const item = this.playlist.items[index];

        // Overlay par-video : si un overlay specifique existe pour cet item, il REMPLACE
        // l'overlay global ; sinon le global est applique. (Controleur dans un <script>
        // posterieur mais defini avant le 1er playItem qui s'execute apres DOMContentLoaded.)
        if (window.PiSignageOverlay && window.PiSignageOverlay.applyForItem) window.PiSignageOverlay.applyForItem(item);

        console.log(`[Player] Playing item ${index}:`, item);

        this.updateDebug('current-index', index);
        this.updateDebug('current-url', item.url);

        this.paused = false;

        if (this.isImageItem(item)) {
            this.showImage(item, index);
        } else {
            this.playVideoItem(item, index);
        }

        this.reportState();  // remontée immédiate à l'admin (page Lecteur / dashboard)
    }

    // ----- Chemin IMAGE -----
    showImage(item, index) {
        // Masquer/mettre en pause les deux vidéos (crossfade géré par opacity).
        this.videoEls.forEach(v => { v.classList.remove('is-active'); try { v.pause(); } catch (e) {} });

        this.image.style.objectFit = item.fit || 'contain';
        this.image.src = item.url;
        this.image.style.display = 'block';
        void this.image.offsetWidth; // reflow -> la transition d'opacité s'applique
        this.image.classList.add('is-active');
        this.hideLoading();
        this.hideError();
        this.updateDebug('status', 'playing (image)');

        const imageDuration = (item.duration && item.duration > 0) ? item.duration : 10;
        setTimeout(() => {
            if (this.currentIndex === index) {
                console.log(`[Player] Image duration ${imageDuration}s elapsed`);
                this.playNext();
            }
        }, imageDuration * 1000);

        this.errorCount = 0;
        this.preloadNext(); // précharger l'éventuelle vidéo suivante
    }

    // ----- Chemin VIDEO (préchargement + crossfade, C1) -----
    playVideoItem(item, index) {
        // La vidéo "incoming" est la vidéo INACTIVE (elle contient peut-être déjà l'item préchargé).
        const newIdx = 1 - this.activeIdx;
        const incoming = this.videoEls[newIdx];

        incoming.muted = item.mute !== undefined ? item.mute : false;
        incoming.loop = item.loop !== undefined ? item.loop : false;
        incoming.style.objectFit = item.fit || 'contain';

        // Charger la source seulement si elle n'est pas déjà préchargée pour cet item.
        if (this.preloadIdx !== index || incoming.dataset.url !== item.url) {
            incoming.src = item.url;
            incoming.dataset.url = item.url;
            try { incoming.load(); } catch (e) {}
        }

        const onReady = () => {
            this.swapTo(newIdx);   // crossfade : incoming devient active
            this.hideLoading();
            this.hideError();
            this.errorCount = 0;   // succès -> reset
            this.preloadNext();    // précharger le suivant dans la (nouvelle) vidéo inactive
        };

        incoming.play().then(onReady).catch((err) => {
            console.error('[Player] Play error:', err);
            if (!incoming.muted) {
                // Politique autoplay : retry en muet.
                console.warn('[Player] Autoplay refusé, retry en muet');
                incoming.muted = true;
                incoming.play().then(onReady).catch(() => this.skipFailedItem(item, index));
            } else {
                this.skipFailedItem(item, index);
            }
        });

        // Durée custom (override) : enchaîner après N secondes.
        if (item.duration && item.duration > 0) {
            setTimeout(() => {
                if (this.currentIndex === index) {
                    console.log(`[Player] Custom duration ${item.duration}s elapsed`);
                    this.handleVideoEnded();
                }
            }, item.duration * 1000);
        }
    }

    // Bascule visuelle (crossfade) vers la vidéo d'index newIdx.
    swapTo(newIdx) {
        const incoming = this.videoEls[newIdx];
        const outgoing = this.videoEls[this.activeIdx];
        incoming.classList.add('is-active');
        if (incoming !== outgoing) {
            outgoing.classList.remove('is-active');
            // Mettre l'ancienne en pause après le crossfade (libère le décodeur GPU).
            setTimeout(() => { if (outgoing !== this.video) { try { outgoing.pause(); } catch (e) {} } }, 550);
        }
        this.activeIdx = newIdx;
        this.video = incoming;
        // Masquer l'image (si elle était affichée) après le fondu.
        this.image.classList.remove('is-active');
        setTimeout(() => {
            if (!this.image.classList.contains('is-active')) this.image.style.display = 'none';
        }, 550);
    }

    // Précharge l'item suivant (s'il est vidéo) dans la vidéo inactive -> démarrage instantané.
    preloadNext() {
        this.preloadIdx = -1;
        if (!this.playlist || !this.playlist.items || this.playlist.items.length < 2) return;

        let nextIndex = this.currentIndex + 1;
        if (nextIndex >= this.playlist.items.length) {
            if (this.playlist.autoLoop) nextIndex = 0; else return;
        }
        const nextItem = this.playlist.items[nextIndex];
        if (!nextItem || this.isImageItem(nextItem)) return; // images : pas de préchargement

        const inactive = this.videoEls[1 - this.activeIdx];
        if (inactive.dataset.url !== nextItem.url) {
            inactive.muted = true;       // préchargement muet ; reconfiguré au play
            inactive.preload = 'auto';
            inactive.src = nextItem.url;
            inactive.dataset.url = nextItem.url;
            try { inactive.load(); } catch (e) {}
        }
        this.preloadIdx = nextIndex;
    }

    // Item illisible : retry quelques fois puis passer au suivant.
    skipFailedItem(item, index) {
        console.error('[Player] Lecture impossible:', item.url);
        this.errorCount++;
        this.updateDebug('errors', this.errorCount);
        if (this.errorCount < this.maxRetries) {
            setTimeout(() => { if (this.currentIndex === index) this.playItem(index); }, 1500);
        } else {
            this.errorCount = 0;
            this.showError(`Impossible de lire : ${item.url}`, 3000);
            this.playNext();
        }
    }

    isImageItem(item) {
        // Détecter une image via type explicite ou extension de l'URL
        if (item.type && /^image/i.test(item.type)) {
            return true;
        }
        const url = (item.url || '').split('?')[0].split('#')[0];
        return /\.(jpe?g|png|gif|webp|svg|bmp)$/i.test(url);
    }

    handleVideoEnded() {
        console.log('[Player] Video ended, checking next...');

        // Si loop individuel activé, on ne passe pas au suivant
        if (this.video.loop) {
            console.log('[Player] Loop enabled, video will replay automatically');
            return;
        }

        // Passer au suivant
        this.playNext();
    }

    playNext() {
        if (!this.playlist) return;

        const nextIndex = this.currentIndex + 1;

        if (nextIndex < this.playlist.items.length) {
            // Élément suivant dans la liste
            this.playItem(nextIndex);
        } else if (this.playlist.autoLoop) {
            // Recommencer au début si autoLoop
            console.log('[Player] End of playlist, looping back to start');
            this.playItem(0);
        } else {
            // Fin de playlist sans loop
            console.log('[Player] End of playlist, stopping');
            this.showLoading('Playlist finished');
        }
    }

    handleVideoError() {
        this.errorCount++;
        this.updateDebug('errors', this.errorCount);

        console.error(`[Player] Video error (${this.errorCount}/${this.maxRetries})`);

        if (this.errorCount < this.maxRetries) {
            // Retry même élément
            console.log('[Player] Retrying current item...');
            setTimeout(() => {
                this.video.load();
                this.video.play().catch(e => console.error('[Player] Retry play failed:', e));
            }, 2000);
        } else {
            // Max retries atteint, passer au suivant
            console.error('[Player] Max retries reached, skipping to next item');
            this.showError(`Failed to play: ${this.playlist.items[this.currentIndex].url}`, 3000);
            this.errorCount = 0;
            this.playNext();
        }
    }

    async requestWakeLock() {
        if (!('wakeLock' in navigator)) {
            console.warn('[Wake Lock] Not supported');
            this.updateDebug('wakelock', 'not supported');
            return;
        }

        try {
            this.wakeLock = await navigator.wakeLock.request('screen');
            console.log('[Wake Lock] Acquired');
            this.updateDebug('wakelock', 'active');

            this.wakeLock.addEventListener('release', () => {
                console.log('[Wake Lock] Released');
                this.updateDebug('wakelock', 'released');
            });
        } catch (err) {
            console.error('[Wake Lock] Error:', err);
            this.updateDebug('wakelock', 'error');
        }
    }

    startPolling() {
        // Poll /tmp/pisignage-playlist-refresh pour détecter rechargements
        this.pollInterval = setInterval(async () => {
            try {
                const response = await fetch('/api/playlist');
                if (response.ok) {
                    const result = await response.json();
                    if (result.success && result.data.version !== this.playlist.version) {
                        console.log('[Playlist] Version changed, reloading...');
                        await this.reloadPlaylist();
                    }
                }
            } catch (err) {
                // Silent fail pour polling
            }
        }, 10000); // Poll toutes les 10 secondes
    }

    // ----- Canal de commande (page Lecteur / dashboard -> moteur réel) -----
    // Poll /api/display.php?action=command toutes les 2s. La 1re lecture sert de
    // BASELINE (on n'exécute pas une commande déjà ancienne au (re)chargement du player) ;
    // ensuite on n'exécute que lorsque `seq` progresse.
    startCommandPolling() {
        this.commandInterval = setInterval(async () => {
            try {
                const r = await fetch('/api/display.php?action=command', { cache: 'no-store' });
                if (!r.ok) return;
                const res = await r.json();
                if (!res.success || !res.data) return;
                const seq = res.data.seq | 0;
                if (this.lastCmdSeq < 0) { this.lastCmdSeq = seq; return; } // baseline
                if (seq <= this.lastCmdSeq) return;
                this.lastCmdSeq = seq;
                this.execCommand(res.data.cmd);
            } catch (e) { /* silencieux */ }
        }, 2000);
    }

    execCommand(cmd) {
        console.log('[Player] Commande reçue:', cmd);
        switch (cmd) {
            case 'next':   this.playNext(); break;
            case 'prev':   this.playPrev(); break;
            case 'pause':  this.pause(); break;
            case 'play':   this.resume(); break;
            case 'reload': this.reloadPlaylist(); break;
            default: console.warn('[Player] Commande inconnue:', cmd);
        }
    }

    pause() {
        this.paused = true;
        try { this.video.pause(); } catch (e) {}
        this.updateDebug('status', 'paused');
        this.reportState();
    }

    resume() {
        this.paused = false;
        try { this.video.play().catch(() => {}); } catch (e) {}
        this.updateDebug('status', 'playing');
        this.reportState();
    }

    playPrev() {
        if (!this.playlist || !this.playlist.items) return;
        const prevIndex = this.currentIndex - 1;
        if (prevIndex >= 0) {
            this.playItem(prevIndex);
        } else if (this.playlist.autoLoop) {
            this.playItem(this.playlist.items.length - 1);
        } else {
            this.playItem(0);
        }
    }

    // ----- Remontée d'état vers l'admin -----
    startStateReporting() {
        this.reportState();
        this.stateInterval = setInterval(() => this.reportState(), 5000); // heartbeat 5s
    }

    reportState() {
        let item = null, count = 0;
        if (this.playlist && this.playlist.items) {
            count = this.playlist.items.length;
            item = this.playlist.items[this.currentIndex] || null;
        }
        const payload = {
            status:  this.paused ? 'paused' : (item ? 'playing' : 'idle'),
            name:    (this.playlist && this.playlist.name) ? this.playlist.name : '',
            version: (this.playlist && this.playlist.version) ? this.playlist.version : 0,
            index:   this.currentIndex,
            count:   count,
            current: item ? { url: item.url || '', name: item.name || '', type: item.type || '' } : null,
        };
        try {
            fetch('/api/display.php?action=state', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                cache: 'no-store',
                body: JSON.stringify(payload),
                keepalive: true,
            }).catch(() => {});
        } catch (e) { /* silencieux */ }
    }

    startFpsCounter() {
        const updateFps = () => {
            this.frameCount++;
            const now = Date.now();
            const delta = now - this.lastFpsUpdate;

            // Update FPS every second
            if (delta >= 1000) {
                this.fps = Math.round((this.frameCount * 1000) / delta);
                this.frameCount = 0;
                this.lastFpsUpdate = now;

                if (this.debugMode) {
                    this.updateDebug('fps', this.fps);
                    this.updateVideoInfo();
                }
            }

            this.animationFrameId = requestAnimationFrame(updateFps);
        };

        updateFps();
    }

    updateVideoInfo() {
        if (!this.video.videoWidth) {
            this.updateDebug('video-info', '-');
            return;
        }

        const width = this.video.videoWidth;
        const height = this.video.videoHeight;
        const duration = Math.round(this.video.duration);
        const currentTime = Math.round(this.video.currentTime);

        const info = `${width}x${height} | ${currentTime}s/${duration}s`;
        this.updateDebug('video-info', info);
    }

    showLoading(message = 'Démarrage…') {
        const msg = document.getElementById('loading-msg');
        if (msg) msg.textContent = message;
        this.loading.style.display = 'flex';
    }

    hideLoading() {
        this.loading.style.display = 'none';
    }

    showError(message, timeout = null) {
        this.errorDiv.textContent = message;
        this.errorDiv.style.display = 'block';
        if (timeout) {
            setTimeout(() => this.hideError(), timeout);
        }
    }

    hideError() {
        this.errorDiv.style.display = 'none';
    }

    updateDebug(key, value) {
        const element = document.getElementById(`debug-${key}`);
        if (element) {
            element.textContent = value;
        }
    }
}

// Initialiser le player au chargement de la page
window.addEventListener('DOMContentLoaded', () => {
    console.log('[PiSignage] Initializing player...');
    window.__pisignagePlayer = new PiSignagePlayer();
});
</script>

<!-- ================================================================== -->
<!-- Generateur QR autonome (qrcode-generator, Kazuhiko Arase, MIT).     -->
<!-- Version reduite : modeles 8-bit byte, masques, correction d'erreur. -->
<!-- 100% local, aucune requete reseau. Expose window.qrcode(...).        -->
<!-- ================================================================== -->
<script>
/* qrcode-generator (c) Kazuhiko Arase - MIT License - https://github.com/kazuhikoarase/qrcode-generator */
var qrcode = (function () {
    function QR8bitByte(data) {
        this.mode = 4; // MODE_8BIT_BYTE
        this.data = data;
        this.parsedData = [];
        for (var i = 0, l = this.data.length; i < l; i++) {
            var byteArray = [];
            var code = this.data.charCodeAt(i);
            if (code > 0x10000) {
                byteArray[0] = 0xF0 | ((code & 0x1C0000) >>> 18);
                byteArray[1] = 0x80 | ((code & 0x3F000) >>> 12);
                byteArray[2] = 0x80 | ((code & 0xFC0) >>> 6);
                byteArray[3] = 0x80 | (code & 0x3F);
            } else if (code > 0x800) {
                byteArray[0] = 0xE0 | ((code & 0xF000) >>> 12);
                byteArray[1] = 0x80 | ((code & 0xFC0) >>> 6);
                byteArray[2] = 0x80 | (code & 0x3F);
            } else if (code > 0x80) {
                byteArray[0] = 0xC0 | ((code & 0x7C0) >>> 6);
                byteArray[1] = 0x80 | (code & 0x3F);
            } else {
                byteArray[0] = code;
            }
            this.parsedData.push(byteArray);
        }
        this.parsedData = Array.prototype.concat.apply([], this.parsedData);
        if (this.parsedData.length != this.data.length) {
            this.parsedData.unshift(191);
            this.parsedData.unshift(187);
            this.parsedData.unshift(239);
        }
    }
    QR8bitByte.prototype = {
        getLength: function () { return this.parsedData.length; },
        write: function (buffer) {
            for (var i = 0, l = this.parsedData.length; i < l; i++) {
                buffer.put(this.parsedData[i], 8);
            }
        }
    };

    function QRCodeModel(typeNumber, errorCorrectLevel) {
        this.typeNumber = typeNumber;
        this.errorCorrectLevel = errorCorrectLevel;
        this.modules = null;
        this.moduleCount = 0;
        this.dataCache = null;
        this.dataList = [];
    }
    QRCodeModel.prototype = {
        addData: function (data) { this.dataList.push(new QR8bitByte(data)); this.dataCache = null; },
        isDark: function (row, col) { return this.modules[row][col]; },
        getModuleCount: function () { return this.moduleCount; },
        make: function () { this.makeImpl(false, this.getBestMaskPattern()); },
        makeImpl: function (test, maskPattern) {
            this.moduleCount = this.typeNumber * 4 + 17;
            this.modules = new Array(this.moduleCount);
            for (var row = 0; row < this.moduleCount; row++) {
                this.modules[row] = new Array(this.moduleCount);
                for (var col = 0; col < this.moduleCount; col++) this.modules[row][col] = null;
            }
            this.setupPositionProbePattern(0, 0);
            this.setupPositionProbePattern(this.moduleCount - 7, 0);
            this.setupPositionProbePattern(0, this.moduleCount - 7);
            this.setupPositionAdjustPattern();
            this.setupTimingPattern();
            this.setupTypeInfo(test, maskPattern);
            if (this.typeNumber >= 7) this.setupTypeNumber(test);
            if (this.dataCache == null) this.dataCache = QRCodeModel.createData(this.typeNumber, this.errorCorrectLevel, this.dataList);
            this.mapData(this.dataCache, maskPattern);
        },
        setupPositionProbePattern: function (row, col) {
            for (var r = -1; r <= 7; r++) {
                if (row + r <= -1 || this.moduleCount <= row + r) continue;
                for (var c = -1; c <= 7; c++) {
                    if (col + c <= -1 || this.moduleCount <= col + c) continue;
                    this.modules[row + r][col + c] = (0 <= r && r <= 6 && (c == 0 || c == 6)) || (0 <= c && c <= 6 && (r == 0 || r == 6)) || (2 <= r && r <= 4 && 2 <= c && c <= 4);
                }
            }
        },
        getBestMaskPattern: function () {
            var minLostPoint = 0, pattern = 0;
            for (var i = 0; i < 8; i++) {
                this.makeImpl(true, i);
                var lostPoint = QRUtil.getLostPoint(this);
                if (i == 0 || minLostPoint > lostPoint) { minLostPoint = lostPoint; pattern = i; }
            }
            return pattern;
        },
        setupTimingPattern: function () {
            for (var r = 8; r < this.moduleCount - 8; r++) { if (this.modules[r][6] != null) continue; this.modules[r][6] = (r % 2 == 0); }
            for (var c = 8; c < this.moduleCount - 8; c++) { if (this.modules[6][c] != null) continue; this.modules[6][c] = (c % 2 == 0); }
        },
        setupPositionAdjustPattern: function () {
            var pos = QRUtil.getPatternPosition(this.typeNumber);
            for (var i = 0; i < pos.length; i++) {
                for (var j = 0; j < pos.length; j++) {
                    var row = pos[i], col = pos[j];
                    if (this.modules[row][col] != null) continue;
                    for (var r = -2; r <= 2; r++) {
                        for (var c = -2; c <= 2; c++) {
                            this.modules[row + r][col + c] = (r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0));
                        }
                    }
                }
            }
        },
        setupTypeNumber: function (test) {
            var bits = QRUtil.getBCHTypeNumber(this.typeNumber);
            for (var i = 0; i < 18; i++) { var mod = (!test && ((bits >> i) & 1) == 1); this.modules[Math.floor(i / 3)][i % 3 + this.moduleCount - 8 - 3] = mod; }
            for (var i = 0; i < 18; i++) { var mod = (!test && ((bits >> i) & 1) == 1); this.modules[i % 3 + this.moduleCount - 8 - 3][Math.floor(i / 3)] = mod; }
        },
        setupTypeInfo: function (test, maskPattern) {
            var data = (this.errorCorrectLevel << 3) | maskPattern;
            var bits = QRUtil.getBCHTypeInfo(data);
            for (var i = 0; i < 15; i++) {
                var mod = (!test && ((bits >> i) & 1) == 1);
                if (i < 6) this.modules[i][8] = mod; else if (i < 8) this.modules[i + 1][8] = mod; else this.modules[this.moduleCount - 15 + i][8] = mod;
            }
            for (var i = 0; i < 15; i++) {
                var mod = (!test && ((bits >> i) & 1) == 1);
                if (i < 8) this.modules[8][this.moduleCount - i - 1] = mod; else if (i < 9) this.modules[8][15 - i - 1 + 1] = mod; else this.modules[8][15 - i - 1] = mod;
            }
            this.modules[this.moduleCount - 8][8] = (!test);
        },
        mapData: function (data, maskPattern) {
            var inc = -1, row = this.moduleCount - 1, bitIndex = 7, byteIndex = 0;
            for (var col = this.moduleCount - 1; col > 0; col -= 2) {
                if (col == 6) col--;
                while (true) {
                    for (var c = 0; c < 2; c++) {
                        if (this.modules[row][col - c] == null) {
                            var dark = false;
                            if (byteIndex < data.length) dark = (((data[byteIndex] >>> bitIndex) & 1) == 1);
                            var mask = QRUtil.getMask(maskPattern, row, col - c);
                            if (mask) dark = !dark;
                            this.modules[row][col - c] = dark;
                            bitIndex--;
                            if (bitIndex == -1) { byteIndex++; bitIndex = 7; }
                        }
                    }
                    row += inc;
                    if (row < 0 || this.moduleCount <= row) { row -= inc; inc = -inc; break; }
                }
            }
        }
    };
    QRCodeModel.PAD0 = 0xEC;
    QRCodeModel.PAD1 = 0x11;
    QRCodeModel.createData = function (typeNumber, errorCorrectLevel, dataList) {
        var rsBlocks = QRRSBlock.getRSBlocks(typeNumber, errorCorrectLevel);
        var buffer = new QRBitBuffer();
        for (var i = 0; i < dataList.length; i++) { var data = dataList[i]; buffer.put(data.mode, 4); buffer.put(data.getLength(), QRUtil.getLengthInBits(data.mode, typeNumber)); data.write(buffer); }
        var totalDataCount = 0;
        for (var i = 0; i < rsBlocks.length; i++) totalDataCount += rsBlocks[i].dataCount;
        if (buffer.getLengthInBits() > totalDataCount * 8) throw new Error('code length overflow. (' + buffer.getLengthInBits() + '>' + totalDataCount * 8 + ')');
        if (buffer.getLengthInBits() + 4 <= totalDataCount * 8) buffer.put(0, 4);
        while (buffer.getLengthInBits() % 8 != 0) buffer.putBit(false);
        while (true) { if (buffer.getLengthInBits() >= totalDataCount * 8) break; buffer.put(QRCodeModel.PAD0, 8); if (buffer.getLengthInBits() >= totalDataCount * 8) break; buffer.put(QRCodeModel.PAD1, 8); }
        return QRCodeModel.createBytes(buffer, rsBlocks);
    };
    QRCodeModel.createBytes = function (buffer, rsBlocks) {
        var offset = 0, maxDcCount = 0, maxEcCount = 0;
        var dcdata = new Array(rsBlocks.length), ecdata = new Array(rsBlocks.length);
        for (var r = 0; r < rsBlocks.length; r++) {
            var dcCount = rsBlocks[r].dataCount, ecCount = rsBlocks[r].totalCount - dcCount;
            maxDcCount = Math.max(maxDcCount, dcCount); maxEcCount = Math.max(maxEcCount, ecCount);
            dcdata[r] = new Array(dcCount);
            for (var i = 0; i < dcdata[r].length; i++) dcdata[r][i] = 0xff & buffer.buffer[i + offset];
            offset += dcCount;
            var rsPoly = QRUtil.getErrorCorrectPolynomial(ecCount);
            var rawPoly = new QRPolynomial(dcdata[r], rsPoly.getLength() - 1);
            var modPoly = rawPoly.mod(rsPoly);
            ecdata[r] = new Array(rsPoly.getLength() - 1);
            for (var i = 0; i < ecdata[r].length; i++) { var modIndex = i + modPoly.getLength() - ecdata[r].length; ecdata[r][i] = (modIndex >= 0) ? modPoly.get(modIndex) : 0; }
        }
        var totalCodeCount = 0;
        for (var i = 0; i < rsBlocks.length; i++) totalCodeCount += rsBlocks[i].totalCount;
        var data = new Array(totalCodeCount), index = 0;
        for (var i = 0; i < maxDcCount; i++) for (var r = 0; r < rsBlocks.length; r++) if (i < dcdata[r].length) data[index++] = dcdata[r][i];
        for (var i = 0; i < maxEcCount; i++) for (var r = 0; r < rsBlocks.length; r++) if (i < ecdata[r].length) data[index++] = ecdata[r][i];
        return data;
    };

    var QRMode = { MODE_8BIT_BYTE: 4 };
    var QRErrorCorrectLevel = { L: 1, M: 0, Q: 3, H: 2 };
    var QRMaskPattern = { PATTERN000: 0, PATTERN001: 1, PATTERN010: 2, PATTERN011: 3, PATTERN100: 4, PATTERN101: 5, PATTERN110: 6, PATTERN111: 7 };

    var QRUtil = {
        PATTERN_POSITION_TABLE: [[], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54], [6, 32, 58], [6, 34, 62], [6, 26, 46, 66], [6, 26, 48, 70], [6, 26, 50, 74], [6, 30, 54, 78], [6, 30, 56, 82], [6, 30, 58, 86], [6, 34, 62, 90], [6, 28, 50, 72, 94], [6, 26, 50, 74, 98], [6, 30, 54, 78, 102], [6, 28, 54, 80, 106], [6, 32, 58, 84, 110], [6, 30, 58, 86, 114], [6, 34, 62, 90, 118], [6, 26, 50, 74, 98, 122], [6, 30, 54, 78, 102, 126], [6, 26, 52, 78, 104, 130], [6, 30, 56, 82, 108, 134], [6, 34, 60, 86, 112, 138], [6, 30, 58, 86, 114, 142], [6, 34, 62, 90, 118, 146], [6, 30, 54, 78, 102, 126, 150], [6, 24, 50, 76, 102, 128, 154], [6, 28, 54, 80, 106, 132, 158], [6, 32, 58, 84, 110, 136, 162], [6, 26, 54, 82, 110, 138, 166], [6, 30, 58, 86, 114, 142, 170]],
        G15: 0x537, G18: 0x1f25, G15_MASK: 0x5412,
        getBCHTypeInfo: function (data) { var d = data << 10; while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15) >= 0) d ^= (QRUtil.G15 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15))); return ((data << 10) | d) ^ QRUtil.G15_MASK; },
        getBCHTypeNumber: function (data) { var d = data << 12; while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G18) >= 0) d ^= (QRUtil.G18 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G18))); return (data << 12) | d; },
        getBCHDigit: function (data) { var digit = 0; while (data != 0) { digit++; data >>>= 1; } return digit; },
        getPatternPosition: function (typeNumber) { return QRUtil.PATTERN_POSITION_TABLE[typeNumber - 1]; },
        getMask: function (maskPattern, i, j) {
            switch (maskPattern) {
                case 0: return (i + j) % 2 == 0;
                case 1: return i % 2 == 0;
                case 2: return j % 3 == 0;
                case 3: return (i + j) % 3 == 0;
                case 4: return (Math.floor(i / 2) + Math.floor(j / 3)) % 2 == 0;
                case 5: return (i * j) % 2 + (i * j) % 3 == 0;
                case 6: return ((i * j) % 2 + (i * j) % 3) % 2 == 0;
                case 7: return ((i * j) % 3 + (i + j) % 2) % 2 == 0;
                default: throw new Error('bad maskPattern:' + maskPattern);
            }
        },
        getErrorCorrectPolynomial: function (errorCorrectLength) { var a = new QRPolynomial([1], 0); for (var i = 0; i < errorCorrectLength; i++) a = a.multiply(new QRPolynomial([1, QRMath.gexp(i)], 0)); return a; },
        getLengthInBits: function (mode, type) {
            if (1 <= type && type < 10) { switch (mode) { case 1: return 10; case 2: return 9; case 4: return 8; case 8: return 8; default: throw new Error('mode:' + mode); } }
            else if (type < 27) { switch (mode) { case 1: return 12; case 2: return 11; case 4: return 16; case 8: return 10; default: throw new Error('mode:' + mode); } }
            else if (type < 41) { switch (mode) { case 1: return 14; case 2: return 13; case 4: return 16; case 8: return 12; default: throw new Error('mode:' + mode); } }
            else throw new Error('type:' + type);
        },
        getLostPoint: function (qrcode) {
            var moduleCount = qrcode.getModuleCount(), lostPoint = 0;
            for (var row = 0; row < moduleCount; row++) {
                for (var col = 0; col < moduleCount; col++) {
                    var sameCount = 0, dark = qrcode.isDark(row, col);
                    for (var r = -1; r <= 1; r++) { if (row + r < 0 || moduleCount <= row + r) continue; for (var c = -1; c <= 1; c++) { if (col + c < 0 || moduleCount <= col + c) continue; if (r == 0 && c == 0) continue; if (dark == qrcode.isDark(row + r, col + c)) sameCount++; } }
                    if (sameCount > 5) lostPoint += (3 + sameCount - 5);
                }
            }
            for (var row = 0; row < moduleCount - 1; row++) for (var col = 0; col < moduleCount - 1; col++) { var count = 0; if (qrcode.isDark(row, col)) count++; if (qrcode.isDark(row + 1, col)) count++; if (qrcode.isDark(row, col + 1)) count++; if (qrcode.isDark(row + 1, col + 1)) count++; if (count == 0 || count == 4) lostPoint += 3; }
            for (var row = 0; row < moduleCount; row++) for (var col = 0; col < moduleCount - 6; col++) { if (qrcode.isDark(row, col) && !qrcode.isDark(row, col + 1) && qrcode.isDark(row, col + 2) && qrcode.isDark(row, col + 3) && qrcode.isDark(row, col + 4) && !qrcode.isDark(row, col + 5) && qrcode.isDark(row, col + 6)) lostPoint += 40; }
            for (var col = 0; col < moduleCount; col++) for (var row = 0; row < moduleCount - 6; row++) { if (qrcode.isDark(row, col) && !qrcode.isDark(row + 1, col) && qrcode.isDark(row + 2, col) && qrcode.isDark(row + 3, col) && qrcode.isDark(row + 4, col) && !qrcode.isDark(row + 5, col) && qrcode.isDark(row + 6, col)) lostPoint += 40; }
            var darkCount = 0;
            for (var col = 0; col < moduleCount; col++) for (var row = 0; row < moduleCount; row++) if (qrcode.isDark(row, col)) darkCount++;
            var ratio = Math.abs(100 * darkCount / moduleCount / moduleCount - 50) / 5;
            lostPoint += ratio * 10;
            return lostPoint;
        }
    };

    var QRMath = {
        glog: function (n) { if (n < 1) throw new Error('glog(' + n + ')'); return QRMath.LOG_TABLE[n]; },
        gexp: function (n) { while (n < 0) n += 255; while (n >= 256) n -= 255; return QRMath.EXP_TABLE[n]; },
        EXP_TABLE: new Array(256), LOG_TABLE: new Array(256)
    };
    for (var i = 0; i < 8; i++) QRMath.EXP_TABLE[i] = 1 << i;
    for (var i = 8; i < 256; i++) QRMath.EXP_TABLE[i] = QRMath.EXP_TABLE[i - 4] ^ QRMath.EXP_TABLE[i - 5] ^ QRMath.EXP_TABLE[i - 6] ^ QRMath.EXP_TABLE[i - 8];
    for (var i = 0; i < 255; i++) QRMath.LOG_TABLE[QRMath.EXP_TABLE[i]] = i;

    function QRPolynomial(num, shift) {
        if (num.length == undefined) throw new Error(num.length + '/' + shift);
        var offset = 0;
        while (offset < num.length && num[offset] == 0) offset++;
        this.num = new Array(num.length - offset + shift);
        for (var i = 0; i < num.length - offset; i++) this.num[i] = num[i + offset];
    }
    QRPolynomial.prototype = {
        get: function (index) { return this.num[index]; },
        getLength: function () { return this.num.length; },
        multiply: function (e) {
            var num = new Array(this.getLength() + e.getLength() - 1);
            for (var i = 0; i < this.getLength(); i++) for (var j = 0; j < e.getLength(); j++) num[i + j] ^= QRMath.gexp(QRMath.glog(this.get(i)) + QRMath.glog(e.get(j)));
            return new QRPolynomial(num, 0);
        },
        mod: function (e) {
            if (this.getLength() - e.getLength() < 0) return this;
            var ratio = QRMath.glog(this.get(0)) - QRMath.glog(e.get(0));
            var num = new Array(this.getLength());
            for (var i = 0; i < this.getLength(); i++) num[i] = this.get(i);
            for (var i = 0; i < e.getLength(); i++) num[i] ^= QRMath.gexp(QRMath.glog(e.get(i)) + ratio);
            return new QRPolynomial(num, 0).mod(e);
        }
    };

    function QRRSBlock(totalCount, dataCount) { this.totalCount = totalCount; this.dataCount = dataCount; }
    QRRSBlock.RS_BLOCK_TABLE = [[1, 26, 19], [1, 26, 16], [1, 26, 13], [1, 26, 9], [1, 44, 34], [1, 44, 28], [1, 44, 22], [1, 44, 16], [1, 70, 55], [1, 70, 44], [2, 35, 17], [2, 35, 13], [1, 100, 80], [2, 50, 32], [2, 50, 24], [4, 25, 9], [1, 134, 108], [2, 67, 43], [2, 33, 15, 2, 34, 16], [2, 33, 11, 2, 34, 12], [2, 86, 68], [4, 43, 27], [4, 43, 19], [4, 43, 15], [2, 98, 78], [4, 49, 31], [2, 32, 14, 4, 33, 15], [4, 39, 13, 1, 40, 14], [2, 121, 97], [2, 60, 38, 2, 61, 39], [4, 40, 18, 2, 41, 19], [4, 40, 14, 2, 41, 15], [2, 146, 116], [3, 58, 36, 2, 59, 37], [4, 36, 16, 4, 37, 17], [4, 36, 12, 4, 37, 13], [2, 86, 68, 2, 87, 69], [4, 69, 43, 1, 70, 44], [6, 43, 19, 2, 44, 20], [6, 43, 15, 2, 44, 16]],
    QRRSBlock.getRSBlocks = function (typeNumber, errorCorrectLevel) {
        var rsBlock = QRRSBlock.getRsBlockTable(typeNumber, errorCorrectLevel);
        if (rsBlock == undefined) throw new Error('bad rs block @ typeNumber:' + typeNumber + '/errorCorrectLevel:' + errorCorrectLevel);
        var length = rsBlock.length / 3, list = [];
        for (var i = 0; i < length; i++) { var count = rsBlock[i * 3 + 0], totalCount = rsBlock[i * 3 + 1], dataCount = rsBlock[i * 3 + 2]; for (var j = 0; j < count; j++) list.push(new QRRSBlock(totalCount, dataCount)); }
        return list;
    };
    QRRSBlock.getRsBlockTable = function (typeNumber, errorCorrectLevel) {
        switch (errorCorrectLevel) {
            case QRErrorCorrectLevel.L: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 0];
            case QRErrorCorrectLevel.M: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 1];
            case QRErrorCorrectLevel.Q: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 2];
            case QRErrorCorrectLevel.H: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 3];
            default: return undefined;
        }
    };

    function QRBitBuffer() { this.buffer = []; this.length = 0; }
    QRBitBuffer.prototype = {
        get: function (index) { var bufIndex = Math.floor(index / 8); return ((this.buffer[bufIndex] >>> (7 - index % 8)) & 1) == 1; },
        put: function (num, length) { for (var i = 0; i < length; i++) this.putBit(((num >>> (length - i - 1)) & 1) == 1); },
        getLengthInBits: function () { return this.length; },
        putBit: function (bit) { var bufIndex = Math.floor(this.length / 8); if (this.buffer.length <= bufIndex) this.buffer.push(0); if (bit) this.buffer[bufIndex] |= (0x80 >>> (this.length % 8)); this.length++; }
    };

    // Fabrique : choisit automatiquement le plus petit typeNumber qui contient les donnees.
    var _qrcode = function (typeNumber, errorCorrectLevel) {
        var ecl = QRErrorCorrectLevel[errorCorrectLevel] !== undefined ? QRErrorCorrectLevel[errorCorrectLevel] : QRErrorCorrectLevel.M;
        var model = null;
        var api = {
            addData: function (data) {
                // typeNumber 0 = auto-detect
                if (typeNumber === 0) {
                    var last = null;
                    for (var t = 1; t <= 40; t++) {
                        try {
                            var m = new QRCodeModel(t, ecl);
                            m.addData(data);
                            m.make();
                            model = m;
                            return;
                        } catch (e) { last = e; }
                    }
                    throw (last || new Error('qr: data too long'));
                } else {
                    model = new QRCodeModel(typeNumber, ecl);
                    model.addData(data);
                }
            },
            make: function () { if (model) model.make(); },
            getModuleCount: function () { return model.getModuleCount(); },
            isDark: function (r, c) { return model.isDark(r, c); }
        };
        return api;
    };
    return _qrcode;
})();
</script>

<!-- ================================================================== -->
<!-- Controleur OVERLAY (IIFE separee, totalement independante de         -->
<!-- PiSignagePlayer). Lit /data/overlay-content.json, rend les zones,    -->
<!-- gere le carrousel crossfade, l'horloge locale, le QR local et un     -->
<!-- leger anti burn-in (pixel-shift transform-only).                     -->
<!-- Mode degrade strict : try/catch partout, ne casse JAMAIS le lecteur. -->
<!-- ================================================================== -->
<script>
(function () {
    'use strict';

    var JSON_URL = '/data/overlay-content.json';
    var MEDIA_URL = '/data/media-overlays.json'; // overlays par-video {basename: overlay}
    var REFRESH_MS = 5 * 60 * 1000;   // re-fetch toutes les 5 min
    var CLOCK_MS = 30 * 1000;         // maj horloge toutes les 30s
    var SHIFT_PERIOD_MS = 60 * 1000;  // cycle anti burn-in ~60s

    // Facteurs d'echelle par taille (contrat partage : sm/md/lg/xl).
    var SIZE_SCALE = { sm: 0.8, md: 1.0, lg: 1.25, xl: 1.5 };
    function scaleFor(size) {
        var s = SIZE_SCALE[size];
        return (typeof s === 'number') ? s : 1.0; // defaut "md" = 1.0
    }

    // Valeurs par defaut neutres (mode degrade)
    var DEFAULTS = {
        version: 1,
        enabled: true,
        lang: 'fr',
        banner: { enabled: true, name: 'PiSignage', subtitle: '', logo: null, size: 'md' },
        clock: { enabled: true, size: 'md' },
        cards_size: 'md',
        cards: [],
        qr: { enabled: false, label: '', data: '', size: 'md' }
    };

    // Icones SVG inline (stroke currentColor). Jeu volontairement restreint.
    var ICONS = {
        info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>',
        clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
        bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
        check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21l8.84-8.61a5.5 5.5 0 0 0 0-7.78z"/></svg>',
        phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.81.36 1.6.7 2.34a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.74-1.27a2 2 0 0 1 2.11-.45c.74.34 1.53.57 2.34.7A2 2 0 0 1 22 16.92z"/></svg>'
    };

    function iconSvg(name) {
        return ICONS[name] || ICONS.info;
    }

    // ----- Helpers DOM surs -----
    function $(id) { return document.getElementById(id); }
    function setText(id, txt) { var el = $(id); if (el) el.textContent = (txt == null ? '' : String(txt)); }

    // ----- Etat du controleur -----
    var state = {
        cfg: null,           // config actuellement affichee (globale OU par-video)
        globalCfg: null,     // derniere config GLOBALE validee (repli quand pas d'overlay par-video)
        mediaMap: {},        // {basename: overlay} overlays par-video
        currentBasename: '',  // basename de l'item courant (pour eviter un re-render inutile)
        cards: [],
        cardTimer: null,
        cardIndex: -1,
        activeCardEl: 'a',   // quel slot affiche actuellement la carte
        clockTimer: null,
        refreshTimer: null,
        shiftTimer: null,
        lastSig: null,
        // Echelles courantes par zone (mises a jour a chaque render, lues par le pixel-shift).
        scale: { clock: 1.0, qr: 1.0, cards: 1.0 }
    };

    // ============ HORLOGE (100% local) ============
    function startClock() {
        try {
            tickClock();
            if (state.clockTimer) clearInterval(state.clockTimer);
            state.clockTimer = setInterval(tickClock, CLOCK_MS);
        } catch (e) { /* ne casse rien */ }
    }
    function tickClock() {
        try {
            var lang = (state.cfg && state.cfg.lang === 'nl') ? 'nl-BE' : 'fr-BE';
            var now = new Date();
            var hh = ('0' + now.getHours()).slice(-2);
            var mm = ('0' + now.getMinutes()).slice(-2);
            setText('ov-clock-time', hh + ':' + mm);
            var dateStr;
            try {
                dateStr = now.toLocaleDateString(lang, { weekday: 'long', day: 'numeric', month: 'long' });
            } catch (e) {
                dateStr = now.toLocaleDateString();
            }
            setText('ov-clock-date', dateStr);
        } catch (e) { /* silencieux */ }
    }

    // ============ BANDEAU ============
    function renderBanner(cfg) {
        try {
            var b = (cfg && cfg.banner) ? cfg.banner : DEFAULTS.banner;
            var bannerEl = $('ov-banner');
            if (!bannerEl) return;
            if (!b || b.enabled === false) {
                bannerEl.classList.remove('ov-on');
                return;
            }
            // Taille : le bandeau est pleine largeur (les textes/logo sont en vh). On
            // echelonne le CONTENU (textes + logo) via un scale du corps du bandeau,
            // origine bas-gauche -> le bloc reste ancre au bord et ne deborde pas a droite.
            var bScale = scaleFor(b.size);
            var bodyEl = bannerEl.querySelector('.ov-banner-body');
            if (bodyEl) {
                bodyEl.style.transformOrigin = 'left bottom';
                bodyEl.style.transform = (bScale === 1.0) ? '' : ('scale(' + bScale + ')');
            }
            setText('ov-banner-name', b.name || DEFAULTS.banner.name);
            setText('ov-banner-subtitle', b.subtitle || '');
            var logoEl = $('ov-banner-logo');
            if (logoEl) {
                if (b.logo && typeof b.logo === 'string') {
                    logoEl.onerror = function () { logoEl.classList.remove('ov-show'); };
                    logoEl.src = b.logo;
                    logoEl.classList.add('ov-show');
                } else {
                    logoEl.classList.remove('ov-show');
                    logoEl.removeAttribute('src');
                }
            }
            bannerEl.classList.add('ov-on');
        } catch (e) { /* bandeau reste muet, pas d'erreur fatale */ }
    }

    // ============ HORLOGE on/off ============
    function renderClockZone(cfg) {
        try {
            var c = (cfg && cfg.clock) ? cfg.clock : DEFAULTS.clock;
            var el = $('ov-clock');
            if (!el) return;
            // Taille : memorise l'echelle (origine haut-droite) ; le scale est compose
            // avec le pixel-shift par applyShift (un seul style.transform par element).
            state.scale.clock = scaleFor(c && c.size);
            el.style.transformOrigin = 'right top';
            if (c && c.enabled === false) { el.classList.remove('ov-on'); }
            else { el.classList.add('ov-on'); }
        } catch (e) { /* silencieux */ }
    }

    // ============ CARROUSEL CARTES (crossfade, state-machine) ============
    function normalizeCards(cfg) {
        var out = [];
        try {
            var lang = (cfg && cfg.lang === 'nl') ? 'nl' : 'fr';
            var raw = (cfg && Array.isArray(cfg.cards)) ? cfg.cards : [];
            for (var i = 0; i < raw.length; i++) {
                var c = raw[i] || {};
                var txt = '';
                if (lang === 'nl') txt = c.text_nl || c.text_fr || '';
                else txt = c.text_fr || c.text_nl || '';
                txt = String(txt).trim();
                if (!txt) continue;
                var dur = parseInt(c.duration, 10);
                if (!isFinite(dur) || dur < 3) dur = 8;
                if (dur > 120) dur = 120;
                out.push({ icon: c.icon || 'info', text: txt, duration: dur });
            }
        } catch (e) { /* renvoie ce qu'on a */ }
        return out;
    }

    function stopCarousel() {
        if (state.cardTimer) { clearTimeout(state.cardTimer); state.cardTimer = null; }
    }

    function hideCards() {
        var a = $('ov-card-a'), b = $('ov-card-b');
        if (a) a.classList.remove('ov-on');
        if (b) b.classList.remove('ov-on');
    }

    function fillCard(slotEl, card) {
        if (!slotEl) return;
        // Construire le contenu sans innerHTML d'un texte non fiable :
        // le texte passe par textContent, seul le SVG (statique) est en innerHTML.
        slotEl.textContent = '';
        var iconWrap = document.createElement('div');
        iconWrap.className = 'ov-card-icon';
        iconWrap.innerHTML = iconSvg(card.icon); // SVG statique de notre jeu ICONS
        var textWrap = document.createElement('div');
        textWrap.className = 'ov-card-text';
        textWrap.textContent = card.text;       // texte utilisateur => textContent (sur)
        slotEl.appendChild(iconWrap);
        slotEl.appendChild(textWrap);
    }

    function showNextCard() {
        try {
            if (!state.cards.length) { hideCards(); return; }

            state.cardIndex = (state.cardIndex + 1) % state.cards.length;
            var card = state.cards[state.cardIndex];

            // Slot a montrer = l'inverse du slot actif (crossfade)
            var nextSlotName = (state.activeCardEl === 'a') ? 'b' : 'a';
            var nextEl = $('ov-card-' + nextSlotName);
            var curEl = $('ov-card-' + state.activeCardEl);

            fillCard(nextEl, card);
            // Forcer un reflow pour garantir la transition d'opacity
            if (nextEl) { void nextEl.offsetWidth; nextEl.classList.add('ov-on'); }
            if (curEl) curEl.classList.remove('ov-on');
            state.activeCardEl = nextSlotName;

            stopCarousel();
            // S'il n'y a qu'une carte, on la laisse affichee en continu.
            if (state.cards.length > 1) {
                state.cardTimer = setTimeout(showNextCard, card.duration * 1000);
            }
        } catch (e) {
            // En cas de pepin, on masque les cartes mais on garde le reste vivant.
            try { hideCards(); } catch (e2) {}
        }
    }

    function startCarousel(cfg) {
        try {
            stopCarousel();
            // Taille des cartes (champ TOP-LEVEL cards_size) : memorise l'echelle.
            // Origine bas-centre ; le scale + le centrage translateX(-50%) + le
            // pixel-shift sont composes par applyCardsTransform (un seul transform).
            state.scale.cards = scaleFor(cfg && cfg.cards_size);
            var cardsEl = $('ov-cards');
            if (cardsEl) cardsEl.style.transformOrigin = 'center bottom';
            state.cards = normalizeCards(cfg);
            state.cardIndex = -1;
            // reset visuel
            hideCards();
            state.activeCardEl = 'a';
            var a = $('ov-card-a'); if (a) a.textContent = '';
            var b = $('ov-card-b'); if (b) b.textContent = '';
            if (state.cards.length > 0) {
                showNextCard();
            }
        } catch (e) {
            // Mode degrade : carrousel masque, le reste tient.
            try { hideCards(); } catch (e2) {}
        }
    }

    // ============ QR (genere localement) ============
    function renderQR(cfg) {
        var zone = $('ov-qr');
        var canvasWrap = $('ov-qr-canvas');
        if (!zone || !canvasWrap) return;
        try {
            var q = (cfg && cfg.qr) ? cfg.qr : DEFAULTS.qr;
            // Taille : memorise l'echelle (origine bas-droite) ; composee avec le
            // pixel-shift par applyShift (un seul style.transform par element).
            state.scale.qr = scaleFor(q && q.size);
            zone.style.transformOrigin = 'right bottom';
            if (!q || q.enabled !== true || !q.data || typeof q.data !== 'string') {
                zone.classList.remove('ov-show', 'ov-on');
                canvasWrap.textContent = '';
                return;
            }
            // Generation locale via window.qrcode (jamais en ligne)
            if (typeof qrcode !== 'function') {
                zone.classList.remove('ov-show', 'ov-on');
                return;
            }
            var img = buildQrImage(q.data);
            canvasWrap.textContent = '';
            if (img) {
                canvasWrap.appendChild(img);
                setText('ov-qr-label', q.label || '');
                zone.classList.add('ov-show');
                // declenche l'apparition apres affichage flex
                void zone.offsetWidth;
                zone.classList.add('ov-on');
            } else {
                zone.classList.remove('ov-show', 'ov-on');
            }
        } catch (e) {
            // QR optionnel : en cas d'echec on masque seulement le QR.
            try { zone.classList.remove('ov-show', 'ov-on'); } catch (e2) {}
        }
    }

    function buildQrImage(data) {
        try {
            var qr = qrcode(0, 'M'); // type auto, correction M
            qr.addData(data);
            qr.make();
            var count = qr.getModuleCount();
            var quiet = 4;                  // marge silencieuse
            var total = count + quiet * 2;
            var scale = 4;                  // px par module (rendu net + upscale CSS pixelated)
            var size = total * scale;

            var canvas = document.createElement('canvas');
            canvas.width = size;
            canvas.height = size;
            var ctx = canvas.getContext('2d');
            if (!ctx) return null;
            // fond blanc (zone silencieuse comprise)
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, size, size);
            ctx.fillStyle = '#04130c'; // modules sombres = contrast emerald
            for (var r = 0; r < count; r++) {
                for (var c = 0; c < count; c++) {
                    if (qr.isDark(r, c)) {
                        ctx.fillRect((c + quiet) * scale, (r + quiet) * scale, scale, scale);
                    }
                }
            }
            return canvas;
        } catch (e) {
            return null;
        }
    }

    // ============ ANTI BURN-IN (pixel-shift, transform only) ============
    function startPixelShift() {
        try {
            if (state.shiftTimer) clearInterval(state.shiftTimer);
            // Decalage tres lent de quelques px, cycle ~60s, transform uniquement.
            var amp = 3; // amplitude max en px
            var t0 = Date.now();
            var tick = function () {
                try {
                    var phase = ((Date.now() - t0) % SHIFT_PERIOD_MS) / SHIFT_PERIOD_MS; // 0..1
                    var ang = phase * 2 * Math.PI;
                    var dx = Math.round(Math.cos(ang) * amp);
                    var dy = Math.round(Math.sin(ang) * amp);
                    // Chaque zone : pixel-shift COMPOSE avec son scale courant (un seul
                    // style.transform). #ov-banner reste sans scale (le scale est porte
                    // par .ov-banner-body), il ne recoit donc que le shift.
                    applyShift($('ov-clock'), dx, dy, state.scale.clock);
                    applyShift($('ov-qr'), -dx, dy, state.scale.qr);
                    applyShift($('ov-banner'), 0, -Math.abs(dy), 1.0);
                    // #ov-cards : translateX(-50%) (centrage) + shift + scale, origine bas-centre.
                    applyCardsTransform(dx, dy, state.scale.cards);
                } catch (e) { /* silencieux */ }
            };
            tick();
            // Intervalle de 2s : mouvement imperceptible mais efficace, charge CPU negligeable.
            state.shiftTimer = setInterval(tick, 2000);
        } catch (e) { /* pas critique */ }
    }
    function applyShift(el, dx, dy, scale) {
        if (!el) return;
        // Zones non centrees (clock/qr/banner) : translate (shift) puis scale.
        // L'ordre translate->scale est correct car le scale s'applique autour de
        // l'origine deja positionnee par transform-origin (haut-droite / bas-droite).
        var s = (typeof scale === 'number') ? scale : 1.0;
        var t = 'translate3d(' + dx + 'px,' + dy + 'px,0)';
        if (s !== 1.0) t += ' scale(' + s + ')';
        el.style.transform = t;
    }
    function applyCardsTransform(dx, dy, scale) {
        // #ov-cards a un centrage de base translateX(-50%) qui DOIT etre conserve.
        // Composition : translateX(-50%) (centrage) + translate3d(shift) + scale.
        // Le translateX(-50%) reste en tete pour ne pas casser le centrage ; le scale
        // est en queue avec transform-origin bas-centre -> grossit autour du centre-bas.
        var el = $('ov-cards');
        if (!el) return;
        var s = (typeof scale === 'number') ? scale : 1.0;
        var t = 'translateX(-50%) translate3d(' + dx + 'px,' + dy + 'px,0)';
        if (s !== 1.0) t += ' scale(' + s + ')';
        el.style.transform = t;
    }

    // ============ VALIDATION / RENDU GLOBAL ============
    // Normalise une taille en sm|md|lg|xl (defaut md). Meme regle pour global et par-video.
    function validSize(v) {
        return (v === 'sm' || v === 'md' || v === 'lg' || v === 'xl') ? v : 'md';
    }

    function validateConfig(raw) {
        // Retourne une config sure : merge avec DEFAULTS, tolere les manques.
        // MEME validation pour l'overlay GLOBAL et chaque overlay PAR-VIDEO.
        var cfg = {
            version: 1,
            enabled: true,
            lang: 'fr',
            banner: { enabled: true, name: DEFAULTS.banner.name, subtitle: '', logo: null, size: 'md' },
            clock: { enabled: true, size: 'md' },
            cards_size: 'md',
            cards: [],
            qr: { enabled: false, label: '', data: '', size: 'md' }
        };
        try {
            if (raw && typeof raw === 'object') {
                if (raw.enabled === false) cfg.enabled = false;
                if (raw.lang === 'nl' || raw.lang === 'fr') cfg.lang = raw.lang;
                cfg.cards_size = validSize(raw.cards_size);
                if (raw.banner && typeof raw.banner === 'object') {
                    cfg.banner.enabled = raw.banner.enabled !== false;
                    if (typeof raw.banner.name === 'string') cfg.banner.name = raw.banner.name;
                    if (typeof raw.banner.subtitle === 'string') cfg.banner.subtitle = raw.banner.subtitle;
                    cfg.banner.logo = (typeof raw.banner.logo === 'string' && raw.banner.logo) ? raw.banner.logo : null;
                    cfg.banner.size = validSize(raw.banner.size);
                }
                if (raw.clock && typeof raw.clock === 'object') {
                    cfg.clock.enabled = raw.clock.enabled !== false;
                    cfg.clock.size = validSize(raw.clock.size);
                }
                if (Array.isArray(raw.cards)) cfg.cards = raw.cards;
                if (raw.qr && typeof raw.qr === 'object') {
                    cfg.qr.enabled = raw.qr.enabled === true;
                    if (typeof raw.qr.label === 'string') cfg.qr.label = raw.qr.label;
                    if (typeof raw.qr.data === 'string') cfg.qr.data = raw.qr.data;
                    cfg.qr.size = validSize(raw.qr.size);
                }
            }
        } catch (e) {
            // En cas de souci, on garde les defauts neutres.
        }
        return cfg;
    }

    // Rendu PARAMETRE par une config (globale OU par-video). Centralise tout le rendu
    // de zones pour que applyGlobal() et applyForItem() partagent exactement le meme code.
    function applyConfig(cfg) {
        state.cfg = cfg;

        var root = $('overlay-root');
        if (root) root.style.display = (cfg.enabled === false) ? 'none' : '';
        if (cfg.enabled === false) {
            stopCarousel();
            return;
        }

        renderBanner(cfg);
        renderClockZone(cfg);
        startClock();          // l'horloge tourne en continu (startClock est idempotent)
        startCarousel(cfg);    // le carrousel redemarre proprement sur la nouvelle config
        renderQR(cfg);
    }

    // Render du GLOBAL : memorise la config globale, puis l'affiche SI aucun overlay
    // par-video n'est actuellement actif (sinon on garde l'overlay par-video a l'ecran).
    function renderAll(cfg) {
        state.globalCfg = cfg;
        // currentBasename non vide ET present dans la map => un overlay par-video est
        // affiche : on ne l'ecrase pas avec le global (le par-video REMPLACE le global).
        if (state.currentBasename && state.mediaMap && state.mediaMap[state.currentBasename]) {
            return;
        }
        applyConfig(cfg);
    }

    // Mode degrade : bandeau + horloge avec valeurs par defaut, rien d'autre.
    function renderDegraded() {
        try {
            var cfg = validateConfig(null); // = DEFAULTS surs
            cfg.cards = [];
            cfg.qr.enabled = false;
            state.cfg = cfg;
            if (!state.globalCfg) state.globalCfg = cfg; // repli global tant que rien n'est charge
            var root = $('overlay-root');
            if (root) root.style.display = '';
            renderBanner(cfg);
            renderClockZone(cfg);
            startClock();
            stopCarousel();
            hideCards();
            var zone = $('ov-qr');
            if (zone) zone.classList.remove('ov-show', 'ov-on');
        } catch (e) { /* ultime garde-fou */ }
    }

    // ============ FETCH JSON ============
    function fetchConfig() {
        try {
            // cache-bust leger pour suivre les mises a jour cote serveur
            var url = JSON_URL + '?_=' + Date.now();
            fetch(url, { cache: 'no-store' })
                .then(function (resp) {
                    if (!resp.ok) throw new Error('HTTP ' + resp.status);
                    return resp.json();
                })
                .then(function (raw) {
                    var cfg = validateConfig(raw);
                    // Eviter de tout re-render si rien n'a change (limite le flicker).
                    var sig = null;
                    try { sig = JSON.stringify(cfg); } catch (e) { sig = null; }
                    if (sig && sig === state.lastSig) return;
                    state.lastSig = sig;
                    renderAll(cfg);
                })
                .catch(function () {
                    // JSON absent/corrompu/HTTP KO => mode degrade strict.
                    // On ne degrade que si rien n'a encore ete rendu, pour ne pas
                    // ecraser un overlay valide deja affiche par un fetch precedent.
                    if (!state.cfg) renderDegraded();
                });
        } catch (e) {
            if (!state.cfg) renderDegraded();
        }
    }

    // ============ FETCH MAP OVERLAYS PAR-VIDEO ============
    // Recupere /data/media-overlays.json = {basename: overlay}. Absent/invalide => {}.
    // Chaque overlay est valide a l'application (applyForItem) via la MEME validateConfig.
    function fetchMedia() {
        try {
            var url = MEDIA_URL + '?_=' + Date.now();
            fetch(url, { cache: 'no-store' })
                .then(function (resp) {
                    if (!resp.ok) throw new Error('HTTP ' + resp.status);
                    return resp.json();
                })
                .then(function (raw) {
                    state.mediaMap = (raw && typeof raw === 'object' && !Array.isArray(raw)) ? raw : {};
                    // Si l'item courant possede desormais (ou n'a plus) un overlay par-video,
                    // re-appliquer le bon overlay sans attendre le prochain changement d'item.
                    if (window.PiSignageOverlay && window.PiSignageOverlay.reapply) {
                        window.PiSignageOverlay.reapply();
                    }
                })
                .catch(function () {
                    // Map absente/corrompue : on garde la precedente si on en a une,
                    // sinon map vide (=> overlay global partout).
                    if (!state.mediaMap) state.mediaMap = {};
                });
        } catch (e) {
            if (!state.mediaMap) state.mediaMap = {};
        }
    }

    function startRefresh() {
        if (state.refreshTimer) clearInterval(state.refreshTimer);
        // Meme cadence (5 min) pour le global ET la map par-video.
        state.refreshTimer = setInterval(function () {
            fetchConfig();
            fetchMedia();
        }, REFRESH_MS);
    }

    // ============ BASENAME ============
    // basename = dernier segment de l'url, sans query (?) ni ancre (#).
    function basenameOf(item) {
        try {
            if (!item || !item.url) return '';
            return String(item.url).split('?')[0].split('#')[0].split('/').pop() || '';
        } catch (e) { return ''; }
    }

    // ============ API PUBLIQUE (window.PiSignageOverlay) ============
    // Applique l'overlay GLOBAL (repli quand l'item n'a pas d'overlay dedie).
    function applyGlobal() {
        try {
            // NE PAS effacer state.currentBasename ici : il doit toujours refleter l'item
            // courant (positionne par applyForItem). Sinon, si applyForItem tombe sur le
            // global parce que la map par-video n'est pas encore chargee, on perdrait la
            // trace de l'item et reapply() (apres chargement de la map) ne pourrait plus
            // re-cibler l'overlay par-video. renderAll() decide via mediaMap[currentBasename].
            var cfg = state.globalCfg || validateConfig(null);
            applyConfig(cfg);
        } catch (e) {
            try { renderDegraded(); } catch (e2) {}
        }
    }

    // Applique l'overlay du fichier courant : par-video s'il existe (REMPLACE le global),
    // sinon global. item null/absent => global. Aucune fusion.
    function applyForItem(item) {
        try {
            var bn = basenameOf(item);
            state.currentBasename = bn;
            var raw = (bn && state.mediaMap && Object.prototype.hasOwnProperty.call(state.mediaMap, bn))
                ? state.mediaMap[bn] : null;
            if (raw) {
                // Overlay par-video : valide via la MEME validateConfig, puis remplace tout.
                applyConfig(validateConfig(raw));
            } else {
                applyGlobal();
            }
        } catch (e) {
            // Mode degrade strict : ne casse jamais la video.
            try { applyGlobal(); } catch (e2) { try { renderDegraded(); } catch (e3) {} }
        }
    }

    // Re-applique l'overlay du fichier courant (ex: apres un refresh de la map par-video).
    function reapply() {
        try {
            if (state.currentBasename) {
                applyForItem({ url: state.currentBasename });
            } else {
                applyGlobal();
            }
        } catch (e) { /* silencieux */ }
    }

    window.PiSignageOverlay = {
        applyForItem: applyForItem,
        applyGlobal: applyGlobal,
        reapply: reapply
    };

    // ============ BOOT ============
    function boot() {
        try {
            // Affiche immediatement un overlay neutre (horloge + bandeau) pour
            // ne jamais laisser un ecran vide pendant le 1er fetch.
            renderDegraded();
            startPixelShift();
            fetchConfig();
            fetchMedia();
            startRefresh();
        } catch (e) {
            // L'overlay ne doit JAMAIS empecher le lecteur de tourner.
            try { renderDegraded(); } catch (e2) {}
        }
    }

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
</script>

</body>
</html>
