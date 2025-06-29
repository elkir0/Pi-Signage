<?php
/**
 * Page de connexion Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/security.php';

// Si déjà authentifié, rediriger vers le dashboard
if (isAuthenticated()) {
    header('Location: dashboard.php');
    exit;
}

// Traitement du formulaire de connexion
$error = '';
$redirect = $_GET['redirect'] ?? 'dashboard.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Vérifier le rate limiting
    $clientIP = getClientIP();
    if (!checkRateLimit('login_' . $clientIP, 5, 300)) {
        $error = 'Trop de tentatives de connexion. Réessayez dans quelques minutes.';
    } elseif (!validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $error = 'Erreur de sécurité. Veuillez réessayer.';
    } else {
        $username = sanitizeInput($_POST['username'] ?? '');
        $password = $_POST['password'] ?? '';
        
        if (validateCredentials($username, $password)) {
            loginUser($username);
            
            // Rediriger vers la page demandée ou le dashboard
            $redirect = filter_var($redirect, FILTER_SANITIZE_URL);
            header('Location: ' . $redirect);
            exit;
        } else {
            $error = 'Identifiants invalides';
            logActivity('LOGIN_FAILED', $username);
        }
    }
}

startSecureSession();
$csrf_token = generateCSRFToken();
setSecurityHeaders();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow">
    <title>Pi Signage - Connexion</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <style>
        /* Styles inline pour la page de connexion */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        
        .login-container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
            width: 100%;
            max-width: 400px;
            overflow: hidden;
        }
        
        .login-header {
            background: #333;
            color: white;
            padding: 2rem;
            text-align: center;
        }
        
        .login-header h1 {
            font-size: 1.5rem;
            font-weight: 300;
            margin-bottom: 0.5rem;
        }
        
        .login-header p {
            font-size: 0.9rem;
            opacity: 0.8;
        }
        
        .login-body {
            padding: 2rem;
        }
        
        .form-group {
            margin-bottom: 1.5rem;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 0.5rem;
            color: #555;
            font-size: 0.9rem;
            font-weight: 500;
        }
        
        .form-group input {
            width: 100%;
            padding: 0.75rem 1rem;
            border: 2px solid #e1e4e8;
            border-radius: 5px;
            font-size: 1rem;
            transition: border-color 0.3s;
        }
        
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .error-message {
            background: #fee;
            color: #c33;
            padding: 0.75rem;
            border-radius: 5px;
            margin-bottom: 1.5rem;
            font-size: 0.9rem;
            text-align: center;
        }
        
        .btn-login {
            width: 100%;
            padding: 0.75rem;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: background 0.3s;
        }
        
        .btn-login:hover {
            background: #5a67d8;
        }
        
        .btn-login:active {
            transform: translateY(1px);
        }
        
        .login-footer {
            text-align: center;
            padding: 1.5rem;
            background: #f8f9fa;
            color: #666;
            font-size: 0.85rem;
        }
        
        .version {
            margin-top: 0.5rem;
            opacity: 0.7;
        }
        
        @media (max-width: 480px) {
            .login-container {
                box-shadow: none;
            }
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-header">
            <h1>🖥️ Pi Signage</h1>
            <p>Interface de gestion Digital Signage</p>
        </div>
        
        <div class="login-body">
            <?php if ($error): ?>
                <div class="error-message">
                    <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>
            
            <form method="post" action="">
                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf_token) ?>">
                
                <div class="form-group">
                    <label for="username">Nom d'utilisateur</label>
                    <input 
                        type="text" 
                        id="username" 
                        name="username" 
                        required 
                        autofocus
                        autocomplete="username"
                        placeholder="admin"
                    >
                </div>
                
                <div class="form-group">
                    <label for="password">Mot de passe</label>
                    <input 
                        type="password" 
                        id="password" 
                        name="password" 
                        required
                        autocomplete="current-password"
                        placeholder="••••••••"
                    >
                </div>
                
                <button type="submit" class="btn-login">
                    Se connecter
                </button>
            </form>
        </div>
        
        <div class="login-footer">
            <div>Pi Signage Digital</div>
            <div class="version">Version 2.1.0</div>
        </div>
    </div>
    
    <script>
        // Focus sur le champ username au chargement
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('username').focus();
        });
    </script>
</body>
</html>