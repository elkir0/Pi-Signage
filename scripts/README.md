# PiSignage v0.12 Scripts

> **Note** : depuis la v0.12, le moteur de lecture unique est **Chromium en mode kiosk
> (HTML5)**. VLC, MPV et le dual-player ont été retirés. Les scripts de lancement VLC
> (`start-vlc.sh`, `autostart-vlc.sh`, `start-vlc-production.sh`, `vlc-final.sh`,
> `player-manager-*.sh`) n'existent plus. Voir `ARCHITECTURE.md` / `API_DOCUMENTATION.md`.

## Kiosk & affichage (Wayland / labwc)

### kiosk-apply
Générateur de configuration du kiosk Chromium (POSIX `sh`, compatible Trixie).
- Lit `/opt/pisignage/config/feature_flags` (`ENABLE_KIOSK=1|0`), `kiosk_url` et `kiosk_flags`.
- Génère l'autostart labwc (`~/.config/labwc/autostart`) qui lance
  `chromium --kiosk http://127.0.0.1/player` (page `web/player.php`).
- Idempotent : peut être relancé après modification de l'URL ou des flags Chromium.

### screen-power.sh
Allume / éteint l'écran du kiosk Wayland via `wlr-randr`, et renvoie l'état.
- Usage : `screen-power.sh on|off|state`.
- Appelé par `www-data` via `sudo -u pi` (autorisé par `/etc/sudoers.d/pisignage`),
  s'exécute donc dans la session Wayland de l'utilisateur `pi`.
- Cible toujours la vraie sortie kiosk (`HDMI-A-1`), jamais la sortie virtuelle `NOOP-1`
  créée par wlroots quand tout est éteint.

### screen-schedule-tick.sh
Applique le planning d'**extinction d'écran** programmée.
- Lancé chaque minute par `/etc/cron.d/pisignage-screen` (root).
- Lit `/opt/pisignage/config/screen_schedule.json` (écrit par l'API kiosk `PUT /screen`)
  et applique l'état désiré via `screen-power.sh`.
- Idempotent : ne bascule l'écran que si l'état réel diffère de l'état planifié.

## Programmation (dayparting)

### web/api/scheduler.php (exécuteur CLI)
Exécuteur **réel** de la programmation de playlists (dayparting). Bien que situé sous
`web/api/`, il s'agit d'un script CLI, pas d'un endpoint HTTP.
- Lancé une fois par minute par `/etc/cron.d/pisignage-scheduler` (en `www-data`).
- Lit `/opt/pisignage/data/schedules.json` et désigne la playlist qui doit être à l'écran
  (heure / jour / récurrence / priorité), puis la diffuse comme le bouton « Diffuser ».
- Idempotent : ne réécrit la playlist qu'aux transitions de fenêtre ; revert optionnel
  en fin de fenêtre. État réel écrit dans `/opt/pisignage/config/scheduler-state.json`.

## Captures d'écran (Wayland)

### grim-capture.sh
Capture l'écran composité du kiosk Wayland (labwc) — contenu Chromium inclus.
- Appelé par `www-data` via `sudo -u pi` (autorisé par `/etc/sudoers.d/pisignage`).
- Utilise `grim`, écrit `/tmp/pisignage-screenshot.png` et imprime son chemin sur stdout.

### screenshot-wayland.sh
Implémentation de capture spécifique Wayland.
- Utilise `grim` pour les compositeurs Wayland, avec replis si indisponible.

### install-raspi2png.sh
Installeur de l'outil `raspi2png` (capture directe du framebuffer, matériel Raspberry Pi).

## Rotation des logs

### rotate-logs.sh
Wrapper de compatibilité pour déclencher une rotation immédiate.
- La rotation est désormais gérée par `logrotate` (`/etc/logrotate.d/pisignage`) piloté par
  un timer systemd (`pisignage-logrotate.timer`).
- Conservé pour le bouton « Rotation & Nettoyage » de l'UI (`web/api/logs.php`).

### setup-log-rotation-cron.sh
Installe (idempotent) la rotation des logs : config `logrotate` + service/timer systemd
(`pisignage-logrotate.service` / `.timer`, déclenchement quotidien à 03:00).

## Déploiement & maintenance

### dev-deploy.sh
Déploie des fichiers de `web/` (chemins relatifs à `web/`) vers le Pi de test.
- Usage : `scripts/dev-deploy.sh assets/css/main.css login.php ...`
- `scripts/dev-deploy.sh --all` déploie tout l'arbre `web/` (hors `media`/`screenshots`).
- Cible définie par `PI` (défaut `pi@192.168.1.92`) ; ajuste ownership `www-data`.

### auto-deploy-to-pi.sh
Déploiement automatisé de tout `/opt/pisignage` vers un Pi (teste ping + SSH avant envoi).

### service-manager.php
Démon PHP de supervision de l'état système (boucle de surveillance, signaux, PID file).

## Tests

### tests/smoke.sh
Tests de fumée locaux (sans Pi requis) du mode kiosk et des scripts.

### tests/api.sh
Tests des endpoints API (serveur en cours d'exécution requis).

## Variables d'environnement

- `XDG_RUNTIME_DIR` : répertoire runtime de la session (`/run/user/<uid>`).
- `WAYLAND_DISPLAY` : socket Wayland actif (détecté automatiquement par les scripts kiosk).
- `PISIGNAGE_HOME` : répertoire de base (`/opt/pisignage`).
- `PI` : cible SSH pour `dev-deploy.sh` (défaut `pi@192.168.1.92`).
