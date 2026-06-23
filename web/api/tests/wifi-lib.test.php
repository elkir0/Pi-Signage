<?php
require __DIR__ . '/../wifi-lib.php';

$fail = 0;
function check($label, $cond) { global $fail; if ($cond) { echo "ok   - $label\n"; } else { echo "FAIL - $label\n"; $fail++; } }

// Helpers existants assainis (slot, ssid, has_password)
$existing = [['slot'=>1,'ssid'=>'shathony','has_password'=>true]];

// 1) Nouveau réseau valide → mode new, priorité 30
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1']], []);
check('new valide ok', $r['ok'] === true);
check('new ligne', ($r['lines'][0] ?? '') === "30\tCafe\tnew\tmotdepasse1");

// 2) keep : ssid existant avec mot de passe, psk vide → mode keep
$r = wifiValidateAndBuild([['ssid'=>'shathony','psk'=>'']], $existing);
check('keep ok', $r['ok'] === true && ($r['lines'][0] ?? '') === "30\tshathony\tkeep\t");

// 3) keep robuste au réordonnancement : shathony en 2e position
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'shathony','psk'=>'']], $existing);
check('keep reorder', $r['ok'] && $r['lines'][1] === "20\tshathony\tkeep\t");

// 4) SSID nouveau sans mot de passe → erreur
$r = wifiValidateAndBuild([['ssid'=>'Inconnu','psk'=>'']], $existing);
check('new sans psk -> erreur', $r['ok'] === false);

// 5) psk trop court → erreur
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'court']], []);
check('psk court -> erreur', $r['ok'] === false);

// 6) ssid avec guillemet (injection) → erreur
$r = wifiValidateAndBuild([['ssid'=>'a"b','psk'=>'motdepasse1']], []);
check('ssid guillemet -> erreur', $r['ok'] === false);

// 7) ssid avec saut de ligne (injection payload) → erreur
$r = wifiValidateAndBuild([['ssid'=>"a\nb",'psk'=>'motdepasse1']], []);
check('ssid newline -> erreur', $r['ok'] === false);

// 8) psk avec espace en tête → erreur (casse le keyfile NM)
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>' leadingspace']], []);
check('psk espace en tete -> erreur', $r['ok'] === false);

// 9) doublon de ssid → erreur
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'Cafe','psk'=>'motdepasse2']], []);
check('doublon ssid -> erreur', $r['ok'] === false);

// 10) slot vide ignoré
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'','psk'=>'']], []);
check('slot vide ignore', $r['ok'] && count($r['lines']) === 1);

// 11) plus de 3 → erreur
$r = wifiValidateAndBuild([
  ['ssid'=>'A','psk'=>'motdepasse1'],['ssid'=>'B','psk'=>'motdepasse2'],
  ['ssid'=>'C','psk'=>'motdepasse3'],['ssid'=>'D','psk'=>'motdepasse4']], []);
check('max 3 -> erreur', $r['ok'] === false);

// 12) aucun réseau → erreur
$r = wifiValidateAndBuild([], []);
check('aucun -> erreur', $r['ok'] === false);

echo $fail === 0 ? "\nTOUS OK\n" : "\n$fail ECHEC(S)\n";
exit($fail === 0 ? 0 : 1);
