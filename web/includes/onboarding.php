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
