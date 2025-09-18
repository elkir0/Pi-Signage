<?php
/**
 * PiSignage Desktop v3.0 - Interface de connexion
 */

define('PISIGNAGE_DESKTOP', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';

// Rediriger si déjà connecté
if (isAuthenticated()) {
    header('Location: index.php');
    exit;
}

$error = '';

// Traitement de la connexion
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    if (authenticate($username, $password)) {
        header('Location: index.php');
        exit;
    } else {
        $error = 'Nom d\'utilisateur ou mot de passe incorrect';
    }
}

// Message de session expirée
$expired = isset($_GET['expired']);

setSecurityHeaders();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= APP_NAME ?> - Connexion</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <meta name="theme-color" content="#3b82f6">
    <style>
        body {
            background: linear-gradient(135deg, var(--accent-primary), var(--accent-hover));
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 1rem;
        }
        
        .login-container {
            background: var(--bg-primary);
            border-radius: var(--radius-lg);
            box-shadow: var(--shadow-lg);
            padding: 2rem;
            width: 100%;
            max-width: 400px;
            backdrop-filter: blur(10px);
        }
        
        .login-header {
            text-align: center;
            margin-bottom: 2rem;
        }
        
        .login-logo {
            background: linear-gradient(135deg, var(--accent-primary), var(--accent-hover));
            width: 64px;
            height: 64px;
            border-radius: var(--radius-lg);
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1rem;
            font-size: 2rem;
            color: white;
        }
        
        .login-title {
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 0.5rem;
        }
        
        .login-subtitle {
            color: var(--text-secondary);
            font-size: 0.875rem;
        }
        
        .form-group {
            margin-bottom: 1.5rem;
        }
        
        .form-label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 500;
            color: var(--text-primary);
        }
        
        .form-input {
            width: 100%;
            padding: 1rem;
            border: 2px solid var(--border-color);
            border-radius: var(--radius);
            background: var(--bg-secondary);
            color: var(--text-primary);
            font-size: 1rem;
            transition: all 0.2s ease;
        }
        
        .form-input:focus {
            outline: none;
            border-color: var(--accent-primary);
            background: var(--bg-primary);
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }
        
        .login-button {
            width: 100%;
            padding: 1rem;
            background: var(--accent-primary);
            color: white;
            border: none;
            border-radius: var(--radius);
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .login-button:hover {
            background: var(--accent-hover);
            transform: translateY(-1px);
        }
        
        .login-button:active {
            transform: translateY(0);
        }
        
        .error-message {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid var(--error);
            color: var(--error);
            padding: 1rem;
            border-radius: var(--radius);
            margin-bottom: 1rem;
            text-align: center;
            font-size: 0.875rem;
        }
        
        .expired-message {
            background: rgba(245, 158, 11, 0.1);
            border: 1px solid var(--warning);
            color: var(--warning);
            padding: 1rem;
            border-radius: var(--radius);
            margin-bottom: 1rem;
            text-align: center;
            font-size: 0.875rem;
        }
        
        .login-footer {
            text-align: center;
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid var(--border-color);
            font-size: 0.875rem;
            color: var(--text-muted);
        }
        
        .theme-toggle-login {
            position: absolute;
            top: 1rem;
            right: 1rem;
            background: rgba(255, 255, 255, 0.2);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: var(--radius);
            padding: 0.5rem;
            color: white;
            cursor: pointer;
            backdrop-filter: blur(10px);
        }
        
        .theme-toggle-login:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        
        /* Animation d'entrée */
        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .login-container {
            animation: slideUp 0.5s ease-out;
        }
        
        /* Dark mode pour login */
        [data-theme="dark"] body {
            background: linear-gradient(135deg, #1e293b, #334155);
        }
        
        [data-theme="dark"] .theme-toggle-login {
            background: rgba(0, 0, 0, 0.3);
            border-color: rgba(255, 255, 255, 0.2);
        }
    </style>
</head>
<body>
    <button class="theme-toggle-login" onclick="toggleTheme()" title="Changer de thème">
        🌙
    </button>
    
    <div class="login-container">
        <div class="login-header">
            <div class="login-logo">π</div>
            <h1 class="login-title"><?= APP_NAME ?></h1>
            <p class="login-subtitle">Connexion à l'interface d'administration</p>
        </div>
        
        <?php if ($expired): ?>
            <div class="expired-message">
                ⏰ Votre session a expiré. Veuillez vous reconnecter.
            </div>
        <?php endif; ?>
        
        <?php if ($error): ?>
            <div class="error-message">
                ❌ <?= htmlspecialchars($error) ?>
            </div>
        <?php endif; ?>
        
        <form method="post" id="login-form">
            <div class="form-group">
                <label for="username" class="form-label">Nom d'utilisateur</label>
                <input type="text" name="username" id="username" class="form-input" 
                       value="<?= htmlspecialchars($_POST['username'] ?? '') ?>" 
                       placeholder="admin" required autofocus>
            </div>
            
            <div class="form-group">
                <label for="password" class="form-label">Mot de passe</label>
                <input type="password" name="password" id="password" class="form-input" 
                       placeholder="••••••••" required>
            </div>
            
            <button type="submit" class="login-button" id="login-btn">
                🔓 Se connecter
            </button>
        </form>
        
        <div class="login-footer">
            <p><?= APP_NAME ?> v<?= APP_VERSION ?></p>
            <p style="margin-top: 0.5rem;">
                Interface simplifiée pour Desktop
            </p>
        </div>
    </div>
    
    <script>
        // Gestion du thème
        function toggleTheme() {
            const html = document.documentElement;
            const currentTheme = html.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            
            html.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
            
            // Changer l'icône
            const toggleBtn = document.querySelector('.theme-toggle-login');
            toggleBtn.textContent = newTheme === 'dark' ? '☀️' : '🌙';
        }
        
        // Charger le thème sauvegardé
        function loadTheme() {
            const savedTheme = localStorage.getItem('theme') || 'light';
            document.documentElement.setAttribute('data-theme', savedTheme);
            
            const toggleBtn = document.querySelector('.theme-toggle-login');
            toggleBtn.textContent = savedTheme === 'dark' ? '☀️' : '🌙';
        }
        
        // Animation du bouton de connexion
        document.getElementById('login-form').addEventListener('submit', function() {
            const btn = document.getElementById('login-btn');
            btn.textContent = '⏳ Connexion...';
            btn.disabled = true;
        });
        
        // Focus automatique sur le champ mot de passe si username est pré-rempli
        document.addEventListener('DOMContentLoaded', function() {
            loadTheme();
            
            const usernameField = document.getElementById('username');
            const passwordField = document.getElementById('password');
            
            if (usernameField.value) {
                passwordField.focus();
            }
            
            // Animation subtile des champs
            const inputs = document.querySelectorAll('.form-input');
            inputs.forEach((input, index) => {
                input.style.animationDelay = (index * 100) + 'ms';
                input.style.animation = 'slideUp 0.5s ease-out forwards';
            });
        });
        
        // Gestion des erreurs avec animation
        if (document.querySelector('.error-message')) {
            setTimeout(() => {
                const errorMsg = document.querySelector('.error-message');
                if (errorMsg) {
                    errorMsg.style.animation = 'slideUp 0.3s ease-out';
                }
            }, 100);
        }
        
        // Prévenir les attaques par force brute (côté client basique)
        let loginAttempts = parseInt(localStorage.getItem('loginAttempts') || '0');
        const maxAttempts = 5;
        const lockoutTime = 5 * 60 * 1000; // 5 minutes
        
        if (loginAttempts >= maxAttempts) {
            const lastAttempt = parseInt(localStorage.getItem('lastAttempt') || '0');
            const now = Date.now();
            
            if (now - lastAttempt < lockoutTime) {
                const remaining = Math.ceil((lockoutTime - (now - lastAttempt)) / 1000 / 60);
                const form = document.getElementById('login-form');
                form.innerHTML = `
                    <div class="error-message">
                        🔒 Trop de tentatives de connexion. Réessayez dans ${remaining} minute(s).
                    </div>
                `;
            } else {
                localStorage.removeItem('loginAttempts');
                localStorage.removeItem('lastAttempt');
            }
        }
        
        // Enregistrer les tentatives échouées
        if (document.querySelector('.error-message') && !document.querySelector('.expired-message')) {
            loginAttempts++;
            localStorage.setItem('loginAttempts', loginAttempts.toString());
            localStorage.setItem('lastAttempt', Date.now().toString());
        }
        
        // Réinitialiser le compteur en cas de succès (ne s'exécute pas car redirect)
        if (window.location.href.indexOf('login.php') === -1) {
            localStorage.removeItem('loginAttempts');
            localStorage.removeItem('lastAttempt');
        }
    </script>
</body>
</html>