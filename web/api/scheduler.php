<?php
/**
 * PiSignage — EXÉCUTEUR DE PROGRAMMATION (dayparting réel). Phase 3 de l'unification.
 *
 * Lancé par cron une fois par minute (en www-data, comme l'API web) :
 *     * * * * * www-data /usr/bin/php /opt/pisignage/web/api/scheduler.php
 *
 * Lit data/schedules.json (le store JSON édité par la page Programmation), détermine la
 * playlist qui DOIT être à l'écran maintenant (selon heure/jour/récurrence/priorité), et
 * la diffuse via playlistActivateByName() — exactement comme le bouton « Diffuser ».
 *
 * IDEMPOTENT : ne réécrit la playlist qu'aux TRANSITIONS de fenêtre (entrée/sortie), pas
 * chaque minute — sinon le player rechargerait en boucle. L'état réel est écrit dans
 * config/scheduler-state.json pour que l'UI cesse de « mentir » (badge En cours calculé
 * côté navigateur). À la fin d'une fenêtre, retour optionnel (post_actions.revert_default)
 * à la playlist qui jouait avant.
 *
 * AUCUN HTTP : pur CLI. (L'extinction d'écran reste un pipeline séparé : screen-schedule-tick.sh.)
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    echo 'scheduler.php est un exécuteur CLI (cron), pas un endpoint HTTP.';
    exit;
}

require_once __DIR__ . '/playlists-core.php'; // modèle + activation + config.php

if (!defined('SCHEDULES_FILE'))       define('SCHEDULES_FILE', '/opt/pisignage/data/schedules.json');
if (!defined('SCHEDULER_STATE_FILE')) define('SCHEDULER_STATE_FILE', CONFIG_PATH . '/scheduler-state.json');

schMain();

function schMain() {
    $schedules = schLoadSchedules();
    $now       = new DateTime('now');
    $winner    = schPickActive($schedules, $now);

    $state       = schLoadState();
    $prevId      = $state['active_schedule_id'] ?? null;
    $restoreSlug = $state['restore_slug'] ?? null;

    // ---- Une fenêtre est active maintenant ----
    if ($winner !== null) {
        $wid = (string)$winner['id'];

        if ($prevId === $wid) {
            // Déjà appliqué pour cette fenêtre : ne rien réécrire (laisse les overrides manuels).
            schWriteState($wid, $winner['playlist'], $restoreSlug, 'active', $winner['name']);
            return;
        }

        // Transition vers une nouvelle fenêtre. Si on n'était pas déjà sous contrôle du
        // scheduler, on mémorise ce qui jouait pour pouvoir le restaurer en fin de fenêtre.
        if ($prevId === null) {
            $restoreSlug = playlistActiveSlug();
        }

        $pl = playlistActivateByName($winner['playlist']);
        if ($pl === null) {
            schLog("Programmation « {$winner['name']} » : playlist « {$winner['playlist']} » introuvable — ignorée", 'ERROR');
            return; // on ne prend pas le contrôle si la playlist n'existe pas
        }
        if ($pl === false) {
            schLog("Programmation « {$winner['name']} » : échec d'activation de « {$winner['playlist']} »", 'ERROR');
            return;
        }
        schMarkRun($schedules, $wid);
        schLog("Programmation activée : « {$winner['name']} » → playlist « {$winner['playlist']} »");
        schWriteState($wid, $winner['playlist'], $restoreSlug, 'active', $winner['name']);
        return;
    }

    // ---- Aucune fenêtre active ----
    if ($prevId !== null) {
        // On vient de SORTIR d'une fenêtre programmée -> revert éventuel.
        $exited = schFindById($schedules, $prevId);
        $revert = $exited && !empty($exited['post_actions']['revert_default']);
        if ($revert && $restoreSlug) {
            $pl = playlistActivateByName($restoreSlug);
            if ($pl && $pl !== false) {
                schLog("Fin de programmation : retour à la playlist « {$restoreSlug} »");
            } else {
                schLog("Fin de programmation : playlist de restauration « {$restoreSlug} » indisponible", 'ERROR');
            }
        } else {
            schLog("Fin de programmation : pas de restauration (on laisse l'écran tel quel)");
        }
        schWriteState(null, null, null, 'idle', null);
        return;
    }

    // Aucun contrôle scheduler en cours : on met seulement à jour l'horodatage d'évaluation.
    schWriteState(null, null, null, 'idle', null);
}

/* ============================ Sélection ============================ */

/** Retourne la planification gagnante active maintenant (priorité max), ou null. */
function schPickActive($schedules, DateTime $now) {
    $candidates = [];
    foreach ($schedules as $s) {
        if (schIsActive($s, $now)) $candidates[] = $s;
    }
    if (empty($candidates)) return null;

    usort($candidates, function ($a, $b) {
        $pa = (int)($a['priority'] ?? 0);
        $pb = (int)($b['priority'] ?? 0);
        if ($pa !== $pb) return $pb - $pa;                 // priorité décroissante
        $sa = $a['schedule']['start_time'] ?? '00:00';
        $sb = $b['schedule']['start_time'] ?? '00:00';
        if ($sa !== $sb) return strcmp($sb, $sa);          // début le plus tardif (plus spécifique)
        return strcmp((string)($a['id'] ?? ''), (string)($b['id'] ?? ''));
    });
    return $candidates[0];
}

/** Une planification est-elle active à l'instant $now ? (enabled + date + jour + fenêtre horaire) */
function schIsActive($s, DateTime $now) {
    if (empty($s['enabled'])) return false;
    if (empty($s['playlist'])) return false;

    $sch  = $s['schedule'] ?? [];
    $rec  = $sch['recurrence'] ?? [];
    $type = $rec['type'] ?? 'daily';

    $today = $now->format('Y-m-d');
    $dow   = (int)$now->format('w'); // 0 = dimanche
    $dom   = (int)$now->format('j');
    $nowHM = $now->format('H:i');

    // Plage de dates (start_date / end_date) — sauf 'once' qui porte sa propre date.
    if ($type !== 'once') {
        if (!empty($rec['start_date']) && $today < substr((string)$rec['start_date'], 0, 10)) return false;
        $noEnd = !empty($rec['no_end_date']);
        if (!$noEnd && !empty($rec['end_date']) && $today > substr((string)$rec['end_date'], 0, 10)) return false;
    }

    // Jour applicable ?
    switch ($type) {
        case 'once':
            $d = !empty($rec['start_date']) ? substr((string)$rec['start_date'], 0, 10) : null;
            if ($d === null || $today !== $d) return false;
            break;
        case 'daily':
            break; // tous les jours
        case 'weekly':
            $days = is_array($rec['days'] ?? null) ? array_map('intval', $rec['days']) : [];
            if (!in_array($dow, $days, true)) return false;
            break;
        case 'monthly':
            $ds = isset($rec['date_specific']) ? (int)$rec['date_specific'] : 0;
            if ($ds <= 0 || $dom !== $ds) return false;
            break;
        default:
            return false;
    }

    // Fenêtre horaire (comparaison de chaînes HH:MM zéro-paddées — sûre).
    $start = $sch['start_time'] ?? null;
    if (!$start) return false;
    if (!empty($sch['continuous'])) {
        return $nowHM >= $start; // jusqu'à la fin de la journée / prochaine fenêtre
    }
    $end = !empty($sch['end_time']) ? $sch['end_time'] : '23:59';
    return ($nowHM >= $start && $nowHM < $end);
}

/* ============================ Store schedules ============================ */

function schLoadSchedules() {
    if (!is_file(SCHEDULES_FILE)) return [];
    $d = json_decode((string)file_get_contents(SCHEDULES_FILE), true);
    return is_array($d) ? $d : [];
}

function schFindById($schedules, $id) {
    foreach ($schedules as $s) {
        if ((string)($s['id'] ?? '') === (string)$id) return $s;
    }
    return null;
}

function schMarkRun(&$schedules, $id) {
    $changed = false;
    foreach ($schedules as &$s) {
        if ((string)($s['id'] ?? '') === (string)$id) {
            if (!isset($s['metadata']) || !is_array($s['metadata'])) $s['metadata'] = [];
            $s['metadata']['last_run']  = date('c');
            $s['metadata']['run_count'] = (int)($s['metadata']['run_count'] ?? 0) + 1;
            $changed = true;
            break;
        }
    }
    unset($s);
    if ($changed) {
        @file_put_contents(SCHEDULES_FILE, json_encode($schedules, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }
}

/* ============================ État scheduler ============================ */

function schLoadState() {
    if (is_file(SCHEDULER_STATE_FILE)) {
        $d = json_decode((string)file_get_contents(SCHEDULER_STATE_FILE), true);
        if (is_array($d)) return $d;
    }
    return [];
}

function schWriteState($activeId, $activePlaylist, $restoreSlug, $status, $activeName) {
    $state = [
        'active_schedule_id'   => $activeId,
        'active_schedule_name' => $activeName,
        'active_playlist'      => $activePlaylist,
        'restore_slug'         => $restoreSlug,
        'status'               => $status,        // 'active' | 'idle'
        'evaluated_at'         => date('c'),
    ];
    $json = json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $dir  = dirname(SCHEDULER_STATE_FILE);
    $tmp  = @tempnam($dir, '.schst.');
    if ($tmp === false) { @file_put_contents(SCHEDULER_STATE_FILE, $json); return; }
    if (@file_put_contents($tmp, $json) !== false && @rename($tmp, SCHEDULER_STATE_FILE)) {
        @chmod(SCHEDULER_STATE_FILE, 0664);
    } else {
        @unlink($tmp);
    }
}

function schLog($message, $level = 'INFO') {
    if (function_exists('logMessage')) {
        logMessage('[scheduler] ' . $message, $level);
    }
}
