<?php
require_once 'includes/auth.php';

// If already authenticated, redirect to dashboard
if (isAuthenticated()) {
    header('Location: /dashboard.php');
    exit;
}

// Handle login form submission
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';

    if (verifyLogin($username, $password)) {
        $redirect = $_SESSION['redirect_after_login'] ?? '/dashboard.php';
        unset($_SESSION['redirect_after_login']);
        header('Location: ' . $redirect);
        exit;
    } else {
        $error = 'Identifiants incorrects';
    }
}
require_once 'includes/icons.php';
?><!DOCTYPE html>
<html lang="fr" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="dark light">
    <title>PiSignage · Connexion</title>
    <script>
      (function(){try{var t=localStorage.getItem('pisignage-theme');if(!t){t=window.matchMedia&&window.matchMedia('(prefers-color-scheme: light)').matches?'light':'dark';}document.documentElement.setAttribute('data-theme',t);}catch(e){}})();
    </script>
    <link rel="stylesheet" href="assets/css/main.css?v=<?= ASSET_VERSION ?>">
    <style>
      body{display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px}
      .auth-wrap{width:100%;max-width:400px}
      .auth-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius-lg);box-shadow:var(--shadow-lg);padding:34px 30px}
      .auth-logo{width:58px;height:58px;border-radius:16px;margin:0 auto 18px;background:linear-gradient(135deg,var(--accent-bright),var(--accent-strong));display:flex;align-items:center;justify-content:center;box-shadow:0 10px 26px -8px var(--accent-ring)}
      .auth-logo svg{width:30px;height:30px;stroke:var(--accent-contrast);stroke-width:2.2}
      .auth-card h1{text-align:center;font-size:23px;margin:0 0 4px}
      .auth-sub{text-align:center;color:var(--text-dim);font-size:13.5px;margin-bottom:26px}
      .auth-field{margin-bottom:16px}
      .auth-field label{display:block;font-size:13px;font-weight:600;color:var(--text-dim);margin-bottom:7px}
      .auth-error{display:flex;align-items:center;gap:9px;background:var(--danger-soft);color:var(--danger-text);border:1px solid color-mix(in srgb,var(--danger) 30%,transparent);padding:11px 13px;border-radius:var(--radius-sm);font-size:13.5px;font-weight:500;margin-bottom:18px}
      .auth-error svg{width:18px;height:18px;flex-shrink:0}
      .auth-foot{text-align:center;color:var(--text-faint);font-size:12px;margin-top:20px}
      .auth-toggle{position:fixed;top:20px;right:20px}
    </style>
</head>
<body>
    <button class="icon-btn theme-toggle auth-toggle" id="theme-toggle" type="button" title="Basculer le thème" aria-label="Basculer le thème">
        <span class="theme-ico-dark"><?= icon('moon') ?></span>
        <span class="theme-ico-light"><?= icon('sun') ?></span>
    </button>

    <div class="auth-wrap">
        <div class="auth-card">
            <div class="auth-logo"><?= icon('kiosk') ?></div>
            <h1>PiSignage</h1>
            <p class="auth-sub">Gestion d'affichage dynamique</p>

            <?php if ($error): ?>
                <div class="auth-error"><?= icon('alert') ?><span><?= htmlspecialchars($error) ?></span></div>
            <?php endif; ?>

            <form method="POST" action="">
                <div class="auth-field">
                    <label for="username">Nom d'utilisateur</label>
                    <input type="text" id="username" name="username" autocomplete="username" required autofocus>
                </div>
                <div class="auth-field">
                    <label for="password">Mot de passe</label>
                    <input type="password" id="password" name="password" autocomplete="current-password" required>
                </div>
                <button type="submit" class="btn btn-primary btn-block btn-lg">Se connecter</button>
            </form>
        </div>
        <p class="auth-foot">PiSignage v<?= htmlspecialchars($config['version']) ?></p>
    </div>

    <script>
      (function(){
        var b=document.getElementById('theme-toggle');
        b&&b.addEventListener('click',function(){
          var r=document.documentElement,n=r.getAttribute('data-theme')==='dark'?'light':'dark';
          r.setAttribute('data-theme',n);try{localStorage.setItem('pisignage-theme',n);}catch(e){}
        });
      })();
    </script>
</body>
</html>
