<?php
/**
 * Zaforge — état d'onboarding partagé (gate kiosk player.php + exception _guard.php + setup.php).
 *
 * php-fpm (www-data) ne peut PAS lire relay.json (pi:pi 0640) -> on s'appuie sur des marqueurs
 * écrits par ROOT (firstboot.sh décide, onboard-ap.sh pose) dans /opt/pisignage/config/ :
 *   .onboarding  : mode onboarding ACTIF (AP levé, l'écran montre /setup, endpoints publics ouverts).
 *   .onboarded   : COLLANT -> onboarding terminé, ne JAMAIS y revenir (écrit après WiFi + compte).
 *
 * FAIL-SAFE : toute incertitude -> "pas d'onboarding" (le gate montre /player, l'exception _guard
 * ne s'ouvre pas). Une box déjà configurée (ni .onboarding ni .onboarded) n'est jamais affectée.
 */

function zfConfigDir() { return '/opt/pisignage/config'; }

function zfOnboarded() { return @file_exists(zfConfigDir() . '/.onboarded'); }

/** Onboarding actif = marqueur .onboarding présent ET pas encore terminé (.onboarded absent). */
function zfOnboardingActive() {
    return @file_exists(zfConfigDir() . '/.onboarding') && !zfOnboarded();
}

/**
 * Le client est-il autorisé à voir/piloter l'onboarding ? UNIQUEMENT le kiosk (loopback) ou un
 * appareil sur le sous-réseau de l'AP d'onboarding (10.42.0.0/24). Défense en profondeur : même si
 * le marqueur .onboarding restait posé par erreur, les endpoints NE répondent JAMAIS sur le LAN du
 * lieu (REMOTE_ADDR = vrai pair TCP, nginx ne fait pas confiance aux en-têtes XFF).
 */
function zfOnboardingClientAllowed() {
    $r = $_SERVER['REMOTE_ADDR'] ?? '';
    if (in_array($r, ['127.0.0.1', '::1', '::ffff:127.0.0.1'], true)) return true;
    return strncmp($r, '10.42.0.', 8) === 0;
}
