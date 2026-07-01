<?php
/**
 * Zaforge — écran d'onboarding 1er démarrage. PUBLIC (pas de session).
 * Deux vues selon le client :
 *   - KIOSK (loopback 127.0.0.1) : QR de join AP + mot de passe admin + progression live.
 *   - TÉLÉPHONE (sous-réseau AP) : l'assistant (WiFi du lieu ; compte en Phase B2).
 * Le QR est généré côté serveur via qrencode (offline, aucun JS QR). Aucune mise en cache.
 */
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
require_once __DIR__ . '/includes/onboarding.php';

// La page de setup ne s'affiche QUE pour le kiosk (loopback) ou un appareil sur l'AP d'onboarding.
// Un accès depuis le LAN du lieu (ou ailleurs) repart au player — pas d'exposition de l'assistant.
if (!zfOnboardingClientAllowed()) { header('Location: /player'); exit; }

$remote = $_SERVER['REMOTE_ADDR'] ?? '';
$isKiosk = in_array($remote, ['127.0.0.1', '::1', '::ffff:127.0.0.1'], true);

// SSID de l'AP (dérivé de machine-id, identique à onboard-ap.sh).
$mid = @file_get_contents('/etc/machine-id');
$apId = $mid ? substr(trim($mid), 0, 4) : '0000';
$apSsid = 'Zaforge-Setup-' . $apId;

// Mot de passe admin par-device (posé par firstboot.sh, affiché une fois). Absent en dev/B1.
$adminPw = '';
$pwFile = '/opt/pisignage/config/.setup-admin-password';
if (is_readable($pwFile)) { $adminPw = trim((string)@file_get_contents($pwFile)); }

// QR du join WiFi de l'AP ouvert (norme WIFI:). Généré par qrencode -> SVG inline.
$qrSvg = '';
if ($isKiosk) {
    $wifiStr = 'WIFI:S:' . $apSsid . ';T:nopass;;';
    $d = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $p = @proc_open(['qrencode', '-t', 'SVG', '-m', '1', '-o', '-', $wifiStr], $d, $pipes);
    if (is_resource($p)) {
        $qrSvg = stream_get_contents($pipes[1]); fclose($pipes[1]); fclose($pipes[2]); proc_close($p);
    }
}
$e = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES);
?><!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Zaforge · Configuration</title>
<style>
  :root{--bg:#0b0f17;--card:#111827;--bd:#1f2a3a;--tx:#e2e8f0;--dim:#94a3b8;--ac:#10b981;--acd:#059669}
  *{box-sizing:border-box}
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--tx);
       min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
  .wrap{width:100%;max-width:440px}
  .logo{width:54px;height:54px;border-radius:15px;margin:0 auto 16px;background:linear-gradient(135deg,#34d399,#059669);
        display:flex;align-items:center;justify-content:center;box-shadow:0 12px 30px -10px #10b98166}
  .logo svg{width:28px;height:28px;stroke:#04140d;stroke-width:2.4;fill:none}
  h1{text-align:center;font-size:22px;margin:0 0 4px}
  .sub{text-align:center;color:var(--dim);font-size:14px;margin:0 0 22px}
  .card{background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:22px}
  .qr{background:#fff;border-radius:12px;padding:14px;width:230px;height:230px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center}
  .qr svg{width:100%;height:100%}
  .ssid{text-align:center;font-weight:600;font-size:16px;margin:0 0 4px}
  .hint{text-align:center;color:var(--dim);font-size:13px;line-height:1.5}
  .pw{margin-top:16px;background:#0b1119;border:1px solid var(--bd);border-radius:10px;padding:12px;text-align:center}
  .pw .l{font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:var(--dim)}
  .pw .v{font-family:ui-monospace,monospace;font-size:18px;color:var(--ac);margin-top:3px}
  label{display:block;font-size:13px;font-weight:600;color:var(--dim);margin:14px 0 6px}
  input{width:100%;background:#0b1119;border:1px solid #25324a;border-radius:9px;padding:11px 12px;color:var(--tx);font-size:15px}
  button{width:100%;margin-top:18px;background:var(--ac);color:#04140d;border:none;border-radius:10px;padding:13px;font-size:15px;font-weight:700;cursor:pointer}
  button:disabled{opacity:.6}
  .steps{display:flex;gap:6px;justify-content:center;margin-top:18px}
  .dot{width:9px;height:9px;border-radius:50%;background:#334155}
  .dot.on{background:var(--ac)}
  .msg{margin-top:14px;font-size:13.5px;text-align:center;min-height:20px}
  .msg.err{color:#f87171}.msg.ok{color:var(--ac)}
  .foot{text-align:center;color:#475569;font-size:12px;margin-top:18px}
</style>
</head>
<body>
<div class="wrap">
  <div class="logo"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/><path d="M8.5 7.5h7l-7 6h7" stroke-linejoin="round"/></svg></div>
  <h1>Zaforge</h1>

<?php if ($isKiosk): ?>
  <p class="sub">Configurez cet écran avec votre téléphone</p>
  <div class="card">
    <div class="qr"><?= $qrSvg ?: '<span style="color:#999">QR indisponible</span>' ?></div>
    <p class="ssid"><?= $e($apSsid) ?></p>
    <p class="hint">Scannez ce QR code avec l'appareil photo de votre téléphone pour rejoindre le réseau de configuration. L'assistant s'ouvrira automatiquement.</p>
    <?php if ($adminPw !== ''): ?>
      <div class="pw"><div class="l">Mot de passe administrateur</div><div class="v"><?= $e($adminPw) ?></div></div>
    <?php endif; ?>
    <div class="steps" id="kiosk-steps"><span class="dot on"></span><span class="dot"></span><span class="dot"></span></div>
    <p class="msg" id="kiosk-msg">En attente de connexion…</p>
  </div>
  <p class="foot">L'écran reviendra automatiquement une fois la configuration terminée.</p>
  <script>
    // Progression live (le kiosk ne perd jamais le loopback).
    async function poll(){
      try{
        const r = await fetch('/api/setup.php?action=status',{cache:'no-store'});
        if(!r.ok){ location.href='/player'; return; } // onboarding terminé -> retour au player
        const d = await r.json();
        if(!d.success) return;
        const s=d.data, dots=document.querySelectorAll('#kiosk-steps .dot'), msg=document.getElementById('kiosk-msg');
        let step=0, t='En attente de connexion…';
        if(s.clients>0){step=1;t='Téléphone connecté — suivez l\'assistant.';}
        if(s.connected_ssid){step=2;t='Connecté à « '+s.connected_ssid+' ».';}
        dots.forEach((x,i)=>x.classList.toggle('on',i<=step));
        msg.textContent=t;
      }catch(e){}
    }
    poll(); setInterval(poll,2000);
  </script>

<?php else: ?>
  <p class="sub">Assistant de configuration</p>
  <div class="card">
    <!-- Étape 1 : WiFi du lieu -->
    <div id="step1">
      <p class="hint" style="text-align:left;margin:0 0 4px">Étape 1 — Connectez l'écran au WiFi du lieu.</p>
      <label for="ssid">Nom du réseau (SSID)</label>
      <input type="text" id="ssid" autocapitalize="none" autocomplete="off" placeholder="Mon-WiFi">
      <label for="psk">Mot de passe</label>
      <input type="password" id="psk" autocomplete="off" placeholder="Clé du réseau">
      <button onclick="toStep2()">Suivant</button>
      <div class="steps"><span class="dot on"></span><span class="dot"></span></div>
    </div>
    <!-- Étape 2 : compte Zaforge -->
    <div id="step2" style="display:none">
      <p class="hint" style="text-align:left;margin:0 0 8px">Étape 2 — Mot de passe administrateur (facultatif), puis compte Zaforge.</p>
      <label for="apw">Mot de passe administrateur <span style="font-weight:400;color:#64748b">(facultatif)</span></label>
      <input type="password" id="apw" autocomplete="new-password" placeholder="Vide = garder celui affiché à l'écran">
      <label for="apw2">Confirmer le mot de passe</label>
      <input type="password" id="apw2" autocomplete="new-password" placeholder="Répétez le mot de passe">
      <div style="height:1px;background:var(--bd);margin:16px 0"></div>
      <div id="login-pane">
        <label for="email">E-mail Zaforge</label>
        <input type="email" id="email" autocapitalize="none" autocomplete="off" placeholder="vous@exemple.com">
        <label for="zpw">Mot de passe Zaforge</label>
        <input type="password" id="zpw" autocomplete="off" placeholder="Mot de passe du compte">
        <p class="hint" style="margin:8px 0 0"><a href="#" style="color:var(--ac)" onclick="toggleCode(true);return false">Utiliser un code d'enrôlement à la place</a></p>
      </div>
      <div id="code-pane" style="display:none">
        <label for="ecode">Code d'enrôlement</label>
        <input type="text" id="ecode" autocapitalize="characters" autocomplete="off" placeholder="ZF-XXXX-XXXX-XXXX">
        <p class="hint" style="margin:8px 0 0"><a href="#" style="color:var(--ac)" onclick="toggleCode(false);return false">Utiliser mon compte Zaforge</a></p>
      </div>
      <button id="go" onclick="finish()">Terminer</button>
      <div class="steps"><span class="dot on"></span><span class="dot on"></span></div>
    </div>
    <p class="msg" id="msg"></p>
  </div>
  <p class="foot">Zaforge · configuration sécurisée</p>
  <script>
    let useCode=false;
    function toStep2(){
      if(!document.getElementById('ssid').value.trim()){ msgErr('Entrez le nom du réseau.'); return; }
      document.getElementById('step1').style.display='none';
      document.getElementById('step2').style.display='';
    }
    function toggleCode(on){ useCode=on;
      document.getElementById('login-pane').style.display=on?'none':'';
      document.getElementById('code-pane').style.display=on?'':'none'; }
    function msgErr(t){ const m=document.getElementById('msg'); m.className='msg err'; m.textContent=t; }
    async function finish(){
      const ssid=document.getElementById('ssid').value.trim(), psk=document.getElementById('psk').value;
      const msg=document.getElementById('msg'), btn=document.getElementById('go');
      const apw=document.getElementById('apw').value, apw2=document.getElementById('apw2').value;
      if(apw!==apw2){ msgErr('Les mots de passe administrateur ne correspondent pas.'); return; }
      if(apw && apw.length<8){ msgErr('Mot de passe admin : 8 caractères minimum.'); return; }
      let account;
      if(useCode){
        const code=document.getElementById('ecode').value.trim().toUpperCase();
        if(!/^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/.test(code)){ msgErr('Code invalide (ZF-XXXX-XXXX-XXXX).'); return; }
        account={mode:'code',code};
      }else{
        const email=document.getElementById('email').value.trim(), zpw=document.getElementById('zpw').value;
        if(!email||!zpw){ msgErr('Entrez vos identifiants Zaforge.'); return; }
        account={mode:'login',email,password:zpw};
      }
      btn.disabled=true; msg.className='msg'; msg.textContent='Configuration… connexion au WiFi puis liaison du compte (l\'écran peut clignoter, ~30s).';
      try{
        const r=await fetch('/api/setup.php?action=apply',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ssid,psk,account,admin_password:apw})});
        const d=await r.json();
        if(d.success){ msg.className='msg ok'; msg.textContent='Terminé ✓ — l\'écran va démarrer.'; }
        else{ msgErr(d.message||'Échec — réessayez.'); btn.disabled=false; }
      }catch(e){ msgErr('Réseau interrompu — rejoignez à nouveau l\'AP « Zaforge-Setup » et réessayez.'); btn.disabled=false; }
    }
  </script>
<?php endif; ?>
</div>
</body>
</html>
