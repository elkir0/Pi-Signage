<?php
session_start();

// Configuration
$config = [
    'version' => '0.8.3',
    'media_path' => '/opt/pisignage/media/',
    'config_path' => '/opt/pisignage/config/',
    'logs_path' => '/opt/pisignage/logs/',
    'upload_max_size' => 500 * 1024 * 1024, // 500MB
];

// Ensure directories exist
$dirs = [$config['media_path'], $config['config_path'], $config['logs_path']];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v<?= $config['version'] ?> - Interface de Gestion</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --primary: #4a9eff;
            --secondary: #ff6b6b;
            --success: #51cf66;
            --warning: #ffd43b;
            --danger: #ff6b6b;
            --dark: #1a1a2e;
            --dark-light: #16213e;
            --light: #f0f3f7;
            --glass: rgba(255, 255, 255, 0.05);
            --glass-border: rgba(255, 255, 255, 0.1);
        }

        body {
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: var(--light);
            min-height: 100vh;
            display: flex;
            overflow-x: hidden;
        }

        /* Glassmorphism Effects */
        .glass {
            background: var(--glass);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }

        /* Sidebar */
        .sidebar {
            width: 280px;
            height: 100vh;
            background: rgba(26, 26, 46, 0.95);
            backdrop-filter: blur(20px);
            border-right: 1px solid var(--glass-border);
            padding: 30px 20px;
            position: fixed;
            left: 0;
            top: 0;
            overflow-y: auto;
            z-index: 1000;
            transition: transform 0.3s ease;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 15px;
            margin-bottom: 50px;
            padding: 15px;
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            border-radius: 15px;
            font-size: 24px;
            font-weight: bold;
            letter-spacing: 1px;
            text-align: center;
            justify-content: center;
            box-shadow: 0 10px 25px rgba(74, 158, 255, 0.3);
        }

        .logo-version {
            font-size: 12px;
            opacity: 0.8;
            display: block;
            margin-top: 5px;
        }

        .nav-section {
            margin-bottom: 30px;
        }

        .nav-title {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 1px;
            text-transform: uppercase;
            color: rgba(240, 243, 247, 0.5);
            margin-bottom: 15px;
            padding-left: 10px;
        }

        .nav-item {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 14px 16px;
            margin-bottom: 8px;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            font-size: 15px;
            color: rgba(240, 243, 247, 0.8);
        }

        .nav-item:hover {
            background: rgba(74, 158, 255, 0.1);
            color: var(--light);
            transform: translateX(5px);
        }

        .nav-item.active {
            background: linear-gradient(135deg, rgba(74, 158, 255, 0.2), rgba(74, 158, 255, 0.1));
            color: var(--primary);
            border-left: 3px solid var(--primary);
        }

        .nav-item.active::after {
            content: '';
            position: absolute;
            right: 20px;
            width: 8px;
            height: 8px;
            background: var(--primary);
            border-radius: 50%;
            box-shadow: 0 0 10px var(--primary);
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.5; transform: scale(1.1); }
            100% { opacity: 1; transform: scale(1); }
        }

        /* Main Content */
        .main-content {
            flex: 1;
            margin-left: 280px;
            padding: 30px;
            position: relative;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
            padding: 20px 30px;
            background: var(--glass);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            border: 1px solid var(--glass-border);
        }

        .page-title {
            font-size: 32px;
            font-weight: 600;
            background: linear-gradient(135deg, var(--primary), #ff6b6b);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .header-actions {
            display: flex;
            gap: 15px;
        }

        /* Content Sections */
        .content-section {
            display: none;
            animation: fadeIn 0.5s ease;
        }

        .content-section.active {
            display: block;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Cards */
        .card {
            background: var(--glass);
            backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 20px;
            padding: 25px;
            margin-bottom: 25px;
            transition: all 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(74, 158, 255, 0.2);
            border-color: rgba(74, 158, 255, 0.3);
        }

        /* Player Selector Styles */
        .player-selector {
            background: var(--glass);
            backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
        }

        .selector-title {
            color: #4a9eff;
            font-weight: 600;
            margin-bottom: 15px;
            font-size: 16px;
        }

        .player-options {
            display: flex;
            gap: 15px;
            margin-bottom: 15px;
            flex-wrap: wrap;
        }

        .player-option {
            flex: 1;
            min-width: 200px;
            cursor: pointer;
            position: relative;
        }

        .player-option input[type="radio"] {
            position: absolute;
            opacity: 0;
            width: 0;
            height: 0;
        }

        .option-content {
            display: flex;
            align-items: center;
            padding: 15px;
            background: rgba(255, 255, 255, 0.05);
            border: 2px solid rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            transition: all 0.3s ease;
        }

        .player-option:hover .option-content {
            background: rgba(74, 158, 255, 0.1);
            border-color: rgba(74, 158, 255, 0.3);
        }

        .player-option input:checked + .option-content {
            background: linear-gradient(135deg, rgba(74, 158, 255, 0.2), rgba(61, 126, 219, 0.2));
            border-color: #4a9eff;
            box-shadow: 0 0 20px rgba(74, 158, 255, 0.3);
        }

        .option-icon {
            font-size: 24px;
            margin-right: 12px;
        }

        .option-name {
            font-weight: 600;
            color: #fff;
            font-size: 16px;
        }

        .option-desc {
            color: rgba(255, 255, 255, 0.7);
            font-size: 12px;
            margin-top: 2px;
        }

        .btn-switch {
            background: linear-gradient(135deg, #4a9eff, #3d7edb);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 14px;
        }

        .btn-switch:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(74, 158, 255, 0.4);
        }

        .player-status {
            background: var(--glass);
            backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
        }

        .status-title {
            color: #4a9eff;
            font-weight: 600;
            margin-bottom: 15px;
            font-size: 16px;
        }

        .card-title {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        /* Grid Layout */
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }

        .grid-2 {
            grid-template-columns: repeat(2, 1fr);
        }

        .grid-3 {
            grid-template-columns: repeat(3, 1fr);
        }

        /* Stats Cards */
        .stat-card {
            background: linear-gradient(135deg, var(--glass), rgba(74, 158, 255, 0.1));
            padding: 20px;
            border-radius: 15px;
            border: 1px solid var(--glass-border);
            text-align: center;
            transition: all 0.3s ease;
        }

        .stat-card:hover {
            transform: scale(1.05);
            box-shadow: 0 10px 30px rgba(74, 158, 255, 0.3);
        }

        .stat-value {
            font-size: 36px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 5px;
        }

        .stat-label {
            font-size: 14px;
            color: rgba(240, 243, 247, 0.6);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        /* Buttons */
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .btn-primary {
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            color: white;
            box-shadow: 0 5px 15px rgba(74, 158, 255, 0.3);
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 7px 20px rgba(74, 158, 255, 0.4);
        }

        .btn-success {
            background: linear-gradient(135deg, var(--success), #42c056);
            color: white;
            box-shadow: 0 5px 15px rgba(81, 207, 102, 0.3);
        }

        .btn-danger {
            background: linear-gradient(135deg, var(--danger), #ff5252);
            color: white;
            box-shadow: 0 5px 15px rgba(255, 107, 107, 0.3);
        }

        .btn-glass {
            background: var(--glass);
            color: var(--light);
            border: 1px solid var(--glass-border);
            backdrop-filter: blur(10px);
        }

        .btn-glass:hover {
            background: rgba(74, 158, 255, 0.2);
            border-color: var(--primary);
        }

        /* Forms */
        .form-group {
            margin-bottom: 20px;
        }

        .form-label {
            display: block;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 500;
            color: rgba(240, 243, 247, 0.8);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .form-control {
            width: 100%;
            padding: 12px 16px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--glass-border);
            border-radius: 10px;
            color: var(--light);
            font-size: 15px;
            transition: all 0.3s ease;
        }

        .form-control:focus {
            outline: none;
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.1);
            box-shadow: 0 0 20px rgba(74, 158, 255, 0.2);
        }

        /* Enhanced Player Controls */
        .now-playing-card {
            background: linear-gradient(135deg, var(--glass), rgba(74, 158, 255, 0.05));
            border: 1px solid var(--primary);
        }

        .now-playing-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
        }

        .now-playing-title {
            font-size: 22px;
            font-weight: 600;
            margin: 0 0 8px 0;
            color: var(--light);
        }

        .now-playing-meta {
            display: flex;
            gap: 15px;
            font-size: 14px;
            color: rgba(240, 243, 247, 0.7);
        }

        .player-state {
            padding: 4px 12px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            font-weight: 500;
        }

        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 25px;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: var(--danger);
            animation: pulse 2s infinite;
        }

        .status-indicator.playing .status-dot {
            background: var(--success);
        }

        .status-indicator.paused .status-dot {
            background: var(--warning);
            animation: none;
        }

        /* Progress Section */
        .progress-section {
            display: flex;
            align-items: center;
            gap: 15px;
            margin: 25px 0;
        }

        .time-current, .time-total {
            font-size: 13px;
            font-weight: 500;
            color: var(--light);
            min-width: 45px;
        }

        .progress-bar-container {
            flex: 1;
            position: relative;
        }

        .progress-bar-bg {
            height: 8px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            position: relative;
            overflow: hidden;
        }

        .progress-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--primary), var(--success));
            border-radius: 10px;
            transition: width 0.3s ease;
        }

        .progress-bar-input {
            position: absolute;
            top: -6px;
            left: 0;
            width: 100%;
            height: 20px;
            opacity: 0;
            cursor: pointer;
        }

        /* Transport Controls */
        .transport-controls {
            display: flex;
            gap: 12px;
            justify-content: center;
            align-items: center;
            margin: 25px 0;
        }

        .control-btn {
            width: 50px;
            height: 50px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            background: var(--glass);
            border: 2px solid var(--glass-border);
            color: var(--light);
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .control-btn.primary {
            width: 65px;
            height: 65px;
            font-size: 26px;
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            border-color: var(--primary);
        }

        .control-btn.secondary {
            width: 40px;
            height: 40px;
            font-size: 18px;
            opacity: 0.7;
        }

        .control-btn:hover {
            transform: scale(1.1);
            border-color: var(--primary);
        }

        .control-btn.active {
            background: var(--primary);
            color: white;
        }

        /* Volume Section */
        .volume-section {
            display: flex;
            align-items: center;
            gap: 15px;
            max-width: 300px;
            margin: 0 auto;
        }

        .volume-btn {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: var(--glass);
            border: 2px solid var(--glass-border);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .volume-slider-container {
            flex: 1;
            position: relative;
            height: 8px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
        }

        .volume-slider {
            position: absolute;
            width: 100%;
            height: 100%;
            opacity: 0;
            cursor: pointer;
        }

        .volume-fill {
            height: 100%;
            background: var(--primary);
            border-radius: 10px;
            transition: width 0.1s ease;
        }

        .volume-value {
            min-width: 40px;
            font-size: 13px;
            color: var(--light);
        }

        /* Playlist Controls */
        .playlist-control-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
        }

        .playlist-actions {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }

        .queue-section {
            background: rgba(255, 255, 255, 0.03);
            border-radius: 10px;
            padding: 15px;
            max-height: 300px;
            overflow-y: auto;
        }

        .queue-list {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .queue-item {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px;
            background: var(--glass);
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .queue-item:hover {
            background: rgba(74, 158, 255, 0.1);
        }

        .queue-item.current {
            border-left: 3px solid var(--primary);
            background: rgba(74, 158, 255, 0.15);
        }

        /* Quick Play Grid */
        .quick-play-grid {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }

        .quick-play-actions {
            display: flex;
            gap: 10px;
        }

        /* System Stats Grid */
        .system-stats-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 15px;
        }

        .stat-item {
            text-align: center;
            padding: 10px;
            background: rgba(255, 255, 255, 0.03);
            border-radius: 10px;
        }

        .stat-item label {
            display: block;
            font-size: 11px;
            color: rgba(240, 243, 247, 0.6);
            margin-bottom: 5px;
            text-transform: uppercase;
        }

        .stat-item span {
            font-size: 18px;
            font-weight: 600;
            color: var(--primary);
        }

        @media (max-width: 768px) {
            .transport-controls {
                flex-wrap: wrap;
            }

            .system-stats-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        /* Upload Zone */
        .upload-zone {
            border: 2px dashed var(--glass-border);
            border-radius: 15px;
            padding: 40px;
            text-align: center;
            background: var(--glass);
            transition: all 0.3s ease;
            cursor: pointer;
        }

        .upload-zone:hover {
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.1);
        }

        .upload-zone.dragging {
            border-color: var(--success);
            background: rgba(81, 207, 102, 0.1);
        }

        /* Alert Messages */
        .alert {
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            animation: slideIn 0.3s ease;
        }

        @keyframes slideIn {
            from { transform: translateX(-100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }

        .alert-success {
            background: rgba(81, 207, 102, 0.2);
            border: 1px solid rgba(81, 207, 102, 0.4);
            color: var(--success);
        }

        .alert-error {
            background: rgba(255, 107, 107, 0.2);
            border: 1px solid rgba(255, 107, 107, 0.4);
            color: var(--danger);
        }

        .alert-info {
            background: rgba(74, 158, 255, 0.2);
            border: 1px solid rgba(74, 158, 255, 0.4);
            color: var(--primary);
        }

        /* Responsive */
        .menu-toggle {
            display: none;
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 1001;
            background: var(--glass);
            padding: 10px;
            border-radius: 10px;
            cursor: pointer;
        }

        @media (max-width: 768px) {
            .menu-toggle {
                display: block;
            }

            .sidebar {
                transform: translateX(-100%);
            }

            .sidebar.active {
                transform: translateX(0);
            }

            .main-content {
                margin-left: 0;
            }

            .grid {
                grid-template-columns: 1fr;
            }
        }

        /* Scrollbar Styling */
        ::-webkit-scrollbar {
            width: 10px;
            height: 10px;
        }

        ::-webkit-scrollbar-track {
            background: var(--dark);
            border-radius: 10px;
        }

        ::-webkit-scrollbar-thumb {
            background: var(--primary);
            border-radius: 10px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #3d7edb;
        }

        /* Loading Spinner */
        .spinner {
            border: 3px solid var(--glass-border);
            border-top: 3px solid var(--primary);
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.8);
            z-index: 2000;
            justify-content: center;
            align-items: center;
            backdrop-filter: blur(5px);
        }

        .modal.active {
            display: flex;
        }

        .modal-content {
            background: var(--dark);
            padding: 30px;
            border-radius: 20px;
            border: 1px solid var(--glass-border);
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            animation: modalSlideIn 0.3s ease;
        }

        @keyframes modalSlideIn {
            from {
                transform: translateY(-50px);
                opacity: 0;
            }
            to {
                transform: translateY(0);
                opacity: 1;
            }
        }

        /* Progress Bar */
        .progress-bar {
            width: 100%;
            height: 8px;
            background: var(--glass);
            border-radius: 10px;
            overflow: hidden;
            margin: 15px 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--primary), var(--success));
            border-radius: 10px;
            transition: width 0.3s ease;
            animation: progressPulse 2s ease infinite;
        }

        @keyframes progressPulse {
            0% { opacity: 1; }
            50% { opacity: 0.8; }
            100% { opacity: 1; }
        }

        /* Screenshot Preview */
        .screenshot-preview {
            position: relative;
            border-radius: 15px;
            overflow: hidden;
            background: var(--glass);
            border: 1px solid var(--glass-border);
            margin: 20px 0;
        }

        .screenshot-preview img {
            width: 100%;
            height: auto;
            display: block;
        }

        .screenshot-overlay {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(180deg, transparent, rgba(0, 0, 0, 0.7));
            display: flex;
            align-items: flex-end;
            padding: 20px;
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .screenshot-preview:hover .screenshot-overlay {
            opacity: 1;
        }

        /* Tab Navigation */
        .tab-nav {
            display: flex;
            gap: 10px;
            margin-bottom: 25px;
            border-bottom: 1px solid var(--glass-border);
            padding-bottom: 15px;
        }

        .tab-btn {
            padding: 10px 20px;
            background: transparent;
            border: none;
            color: rgba(240, 243, 247, 0.6);
            cursor: pointer;
            font-size: 15px;
            font-weight: 500;
            transition: all 0.3s ease;
            position: relative;
        }

        .tab-btn:hover {
            color: var(--light);
        }

        .tab-btn.active {
            color: var(--primary);
        }

        .tab-btn.active::after {
            content: '';
            position: absolute;
            bottom: -16px;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, var(--primary), transparent);
            border-radius: 3px;
        }

        /* Empty State */
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: rgba(240, 243, 247, 0.4);
        }

        .empty-state-icon {
            font-size: 64px;
            margin-bottom: 20px;
            opacity: 0.5;
        }

        .empty-state-title {
            font-size: 20px;
            margin-bottom: 10px;
        }

        .empty-state-text {
            font-size: 14px;
        }

        /* Playlist Editor Styles */
        .playlist-editor-container {
            display: flex;
            gap: 20px;
            height: calc(100vh - 140px);
            margin-top: 20px;
        }

        .playlist-panel {
            background: var(--glass);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .media-library-panel {
            width: 30%;
            min-width: 280px;
        }

        .workspace-panel {
            width: 45%;
            min-width: 400px;
        }

        .properties-panel {
            width: 25%;
            min-width: 250px;
        }

        .panel-header {
            padding: 20px;
            border-bottom: 1px solid var(--glass-border);
            background: rgba(255, 255, 255, 0.02);
        }

        .panel-header h3 {
            margin: 0 0 10px 0;
            font-size: 16px;
            color: var(--primary);
        }

        .panel-controls {
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .playlist-info {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        .playlist-stats {
            font-size: 12px;
            opacity: 0.7;
        }

        .panel-content {
            flex: 1;
            padding: 20px;
            overflow-y: auto;
        }

        .media-filters {
            display: flex;
            gap: 5px;
            margin-bottom: 15px;
            flex-wrap: wrap;
        }

        .filter-btn {
            padding: 6px 12px;
            background: transparent;
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            color: var(--light);
            font-size: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .filter-btn:hover {
            background: rgba(74, 158, 255, 0.1);
            border-color: var(--primary);
        }

        .filter-btn.active {
            background: var(--primary);
            border-color: var(--primary);
            color: white;
        }

        .search-input {
            flex: 1;
            padding: 8px 12px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            color: var(--light);
            font-size: 12px;
        }

        .search-input::placeholder {
            color: rgba(240, 243, 247, 0.5);
        }

        .search-input:focus {
            outline: none;
            border-color: var(--primary);
            background: rgba(255, 255, 255, 0.08);
        }

        .btn-icon {
            padding: 8px;
            background: transparent;
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            color: var(--light);
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .btn-icon:hover {
            background: rgba(74, 158, 255, 0.1);
            border-color: var(--primary);
        }

        .media-library-list {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .media-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid transparent;
            border-radius: 10px;
            cursor: grab;
            transition: all 0.3s ease;
            position: relative;
        }

        .media-item:hover {
            background: rgba(255, 255, 255, 0.06);
            border-color: var(--glass-border);
            transform: translateY(-1px);
        }

        .media-item.dragging {
            opacity: 0.5;
            cursor: grabbing;
        }

        .media-item-icon {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            background: var(--primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            flex-shrink: 0;
        }

        .media-item-icon.video {
            background: linear-gradient(135deg, #ff6b6b, #ee5a52);
        }

        .media-item-icon.image {
            background: linear-gradient(135deg, #51cf66, #40c057);
        }

        .media-item-icon.audio {
            background: linear-gradient(135deg, #ffd43b, #fab005);
        }

        .media-item-info {
            flex: 1;
            min-width: 0;
        }

        .media-item-name {
            font-size: 13px;
            font-weight: 500;
            color: var(--light);
            margin-bottom: 4px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .media-item-meta {
            font-size: 11px;
            color: rgba(240, 243, 247, 0.6);
        }

        .media-item-actions {
            display: flex;
            gap: 5px;
        }

        .btn-add {
            padding: 4px 8px;
            background: var(--success);
            border: none;
            border-radius: 6px;
            color: white;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .btn-add:hover {
            background: #45a049;
            transform: scale(1.05);
        }

        /* Playlist Workspace */
        .playlist-workspace {
            position: relative;
            height: 100%;
        }

        .drop-zone {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            border: 2px dashed var(--glass-border);
            border-radius: 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.3s ease;
        }

        .drop-zone.drag-over {
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.05);
        }

        .drop-zone.hidden {
            display: none;
        }

        .drop-zone-content {
            text-align: center;
            color: rgba(240, 243, 247, 0.6);
        }

        .drop-zone-icon {
            font-size: 48px;
            margin-bottom: 15px;
            opacity: 0.3;
        }

        .drop-zone-hint {
            font-size: 12px;
            margin-top: 10px;
        }

        .playlist-items {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .playlist-item {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 15px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--glass-border);
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
        }

        .playlist-item:hover {
            background: rgba(255, 255, 255, 0.07);
            transform: translateY(-1px);
        }

        .playlist-item.selected {
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.1);
        }

        .playlist-item.dragging {
            opacity: 0.5;
            transform: rotate(5deg);
        }

        .drag-handle {
            cursor: grab;
            color: rgba(240, 243, 247, 0.4);
            font-size: 14px;
            padding: 5px;
        }

        .drag-handle:hover {
            color: var(--primary);
        }

        .playlist-item-icon {
            width: 50px;
            height: 50px;
            border-radius: 8px;
            background: var(--primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            flex-shrink: 0;
        }

        .playlist-item-content {
            flex: 1;
            min-width: 0;
        }

        .playlist-item-name {
            font-size: 14px;
            font-weight: 500;
            color: var(--light);
            margin-bottom: 5px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .playlist-item-details {
            display: flex;
            gap: 15px;
            font-size: 12px;
            color: rgba(240, 243, 247, 0.6);
        }

        .playlist-item-actions {
            display: flex;
            gap: 5px;
        }

        .btn-sm {
            padding: 6px 10px;
            border: none;
            border-radius: 6px;
            font-size: 11px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .btn-danger {
            background: var(--danger);
            color: white;
        }

        .btn-danger:hover {
            background: #e63946;
            transform: scale(1.05);
        }

        /* Properties Panel */
        .properties-section {
            margin-bottom: 25px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--glass-border);
        }

        .properties-section:last-child {
            border-bottom: none;
        }

        .properties-section h4 {
            margin: 0 0 15px 0;
            font-size: 14px;
            color: var(--primary);
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-size: 12px;
            color: rgba(240, 243, 247, 0.8);
        }

        .form-group input[type="text"],
        .form-group input[type="number"],
        .form-group select {
            width: 100%;
            padding: 8px 12px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            color: var(--light);
            font-size: 12px;
        }

        .form-group input[type="text"]:focus,
        .form-group input[type="number"]:focus,
        .form-group select:focus {
            outline: none;
            border-color: var(--primary);
            background: rgba(255, 255, 255, 0.08);
        }

        .form-group input[type="checkbox"] {
            margin-right: 8px;
        }

        .btn-block {
            width: 100%;
            margin-bottom: 10px;
        }

        /* Modal Styles */
        .modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.7);
            backdrop-filter: blur(5px);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .modal-content {
            background: var(--glass);
            backdrop-filter: blur(20px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow: hidden;
        }

        .modal-header {
            padding: 20px;
            border-bottom: 1px solid var(--glass-border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .modal-header h3 {
            margin: 0;
            color: var(--primary);
        }

        .btn-close {
            background: none;
            border: none;
            color: var(--light);
            font-size: 24px;
            cursor: pointer;
            padding: 0;
            width: 30px;
            height: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 6px;
            transition: all 0.3s ease;
        }

        .btn-close:hover {
            background: rgba(255, 255, 255, 0.1);
        }

        .modal-body {
            padding: 20px;
            max-height: 60vh;
            overflow-y: auto;
        }

        .existing-playlist-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px;
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--glass-border);
            border-radius: 10px;
            margin-bottom: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .existing-playlist-item:hover {
            background: rgba(255, 255, 255, 0.06);
            border-color: var(--primary);
        }

        .existing-playlist-info h4 {
            margin: 0 0 5px 0;
            color: var(--light);
        }

        .existing-playlist-meta {
            font-size: 12px;
            color: rgba(240, 243, 247, 0.6);
        }

        /* Animations */
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .playlist-item {
            animation: fadeInUp 0.3s ease;
        }

        /* Responsive Design */
        @media (max-width: 1200px) {
            .playlist-editor-container {
                flex-direction: column;
                height: auto;
            }

            .playlist-panel {
                width: 100%;
                height: 400px;
            }

            .media-library-panel,
            .workspace-panel,
            .properties-panel {
                width: 100%;
                min-width: auto;
            }
        }

        @media (max-width: 768px) {
            .playlist-editor-container {
                margin-top: 10px;
                gap: 10px;
            }

            .panel-header {
                padding: 15px;
            }

            .panel-content {
                padding: 15px;
            }

            .media-filters {
                gap: 3px;
            }

            .filter-btn {
                padding: 4px 8px;
                font-size: 11px;
            }
        }
    </style>
    <script src="functions.js" defer></script>
</head>
<body>
    <!-- Menu Toggle (Mobile) -->
    <div class="menu-toggle" onclick="toggleSidebar()">
        <svg width="24" height="24" fill="currentColor">
            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
        </svg>
    </div>

    <!-- Sidebar -->
    <div class="sidebar" id="sidebar">
        <div class="logo">
            <div>
                🖥️ PiSignage
                <span class="logo-version">v<?= $config['version'] ?></span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Principal</div>
            <div class="nav-item active" onclick="showSection('dashboard')">
                <span>📊</span>
                <span>Dashboard</span>
            </div>
            <div class="nav-item" onclick="showSection('media')">
                <span>📁</span>
                <span>Médias</span>
            </div>
            <div class="nav-item" onclick="showSection('playlists')">
                <span>🎵</span>
                <span>Playlists</span>
            </div>
            <div class="nav-item" onclick="showSection('youtube')">
                <span>📺</span>
                <span>YouTube</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Contrôle</div>
            <div class="nav-item" onclick="showSection('player')">
                <span>▶️</span>
                <span>Lecteur</span>
            </div>
            <div class="nav-item" onclick="showSection('schedule')">
                <span>📅</span>
                <span>Programmation</span>
            </div>
            <div class="nav-item" onclick="showSection('screenshot')">
                <span>📸</span>
                <span>Capture</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Système</div>
            <div class="nav-item" onclick="showSection('settings')">
                <span>⚙️</span>
                <span>Paramètres</span>
            </div>
            <div class="nav-item" onclick="showSection('logs')">
                <span>📋</span>
                <span>Logs</span>
            </div>
        </div>
    </div>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Dashboard Section -->
        <div id="dashboard" class="content-section active">
            <div class="header">
                <h1 class="page-title">Dashboard</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('dashboard')">
                        📸 Capture
                    </button>
                    <button class="btn btn-primary" onclick="refreshStats()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="grid grid-3">
                <div class="stat-card">
                    <div class="stat-value" id="cpu-usage">--</div>
                    <div class="stat-label">CPU</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="ram-usage">--</div>
                    <div class="stat-label">RAM</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="temperature">--</div>
                    <div class="stat-label">Température</div>
                </div>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🎵</span>
                        Lecteur Vidéo
                    </h3>
                    <!-- Sélecteur de lecteur vidéo -->
                    <div class="player-selector">
                        <div class="selector-title">Choisir le lecteur :</div>
                        <div class="player-options">
                            <label class="player-option">
                                <input type="radio" name="player" value="vlc" id="player-vlc" checked>
                                <div class="option-content">
                                    <div class="option-icon">🎛️</div>
                                    <div class="option-details">
                                        <div class="option-name">VLC</div>
                                        <div class="option-desc">Fonctionnalités avancées</div>
                                    </div>
                                </div>
                            </label>
                            <label class="player-option">
                                <input type="radio" name="player" value="mpv" id="player-mpv">
                                <div class="option-content">
                                    <div class="option-icon">🚀</div>
                                    <div class="option-details">
                                        <div class="option-name">MPV</div>
                                        <div class="option-desc">Performance optimale</div>
                                    </div>
                                </div>
                            </label>
                        </div>
                        <button class="btn-switch" onclick="switchPlayer()">Basculer Lecteur</button>
                    </div>

                    <!-- Statut du lecteur -->
                    <div class="player-status">
                        <div class="status-title">Statut : <span id="current-player">VLC</span></div>
                        <p><strong>État:</strong> <span id="player-state">Arrêté</span></p>
                        <p><strong>Fichier:</strong> <span id="player-file">Aucun</span></p>
                        <p><strong>Position:</strong> <span id="player-position">00:00</span></p>
                    </div>
                    <div class="player-controls">
                        <div class="player-btn" onclick="playerControl('play')">▶️</div>
                        <div class="player-btn" onclick="playerControl('pause')">⏸️</div>
                        <div class="player-btn" onclick="playerControl('stop')">⏹️</div>
                        <div class="player-btn" onclick="takeQuickScreenshot('player')">📸</div>
                    </div>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>📊</span>
                        Statistiques Système
                    </h3>
                    <div id="system-stats">
                        <p><strong>Uptime:</strong> <span id="uptime">--</span></p>
                        <p><strong>Stockage:</strong> <span id="storage">--</span></p>
                        <p><strong>Réseau:</strong> <span id="network">--</span></p>
                        <p><strong>Médias:</strong> <span id="media-count">--</span> fichiers</p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Media Section -->
        <div id="media" class="content-section">
            <div class="header">
                <h1 class="page-title">Gestion des Médias</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="showUploadModal()">
                        📤 Upload
                    </button>
                </div>
            </div>

            <div class="upload-zone" id="upload-zone" ondrop="dropHandler(event);" ondragover="dragOverHandler(event);" ondragleave="dragLeaveHandler(event);">
                <div class="empty-state">
                    <div class="empty-state-icon">📁</div>
                    <div class="empty-state-title">Glisser-déposer des fichiers ici</div>
                    <div class="empty-state-text">ou cliquez pour parcourir</div>
                </div>
            </div>

            <div id="media-list" class="grid grid-3">
                <!-- Media files will be loaded here -->
            </div>
        </div>

        <!-- Playlists Section -->
        <div id="playlists" class="content-section">
            <div class="header">
                <h1 class="page-title">Éditeur de Playlists</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="createNewPlaylist()">
                        ➕ Nouvelle Playlist
                    </button>
                    <button class="btn btn-secondary" onclick="loadExistingPlaylist()">
                        📂 Charger
                    </button>
                    <button class="btn btn-success" onclick="saveCurrentPlaylist()" id="save-playlist-btn" disabled>
                        💾 Sauvegarder
                    </button>
                </div>
            </div>

            <!-- Playlist Editor Interface -->
            <div class="playlist-editor-container">
                <!-- Media Library Panel (Left) -->
                <div class="playlist-panel media-library-panel">
                    <div class="panel-header">
                        <h3>📁 Bibliothèque Média</h3>
                        <div class="panel-controls">
                            <button class="btn-icon" onclick="refreshMediaLibrary()" title="Actualiser">
                                🔄
                            </button>
                            <input type="text" class="search-input" placeholder="Rechercher..." id="media-search" onkeyup="filterMediaLibrary()">
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="media-filters">
                            <button class="filter-btn active" data-type="all" onclick="filterMediaType('all')">Tous</button>
                            <button class="filter-btn" data-type="video" onclick="filterMediaType('video')">Vidéos</button>
                            <button class="filter-btn" data-type="image" onclick="filterMediaType('image')">Images</button>
                            <button class="filter-btn" data-type="audio" onclick="filterMediaType('audio')">Audio</button>
                        </div>
                        <div class="media-library-list" id="media-library-list">
                            <!-- Media files will be loaded here -->
                        </div>
                    </div>
                </div>

                <!-- Playlist Workspace Panel (Center) -->
                <div class="playlist-panel workspace-panel">
                    <div class="panel-header">
                        <h3>🎵 Playlist Workspace</h3>
                        <div class="playlist-info">
                            <span id="playlist-name-display">Nouvelle Playlist</span>
                            <span class="playlist-stats">
                                <span id="item-count">0 éléments</span> -
                                <span id="total-duration">00:00</span>
                            </span>
                        </div>
                    </div>
                    <div class="panel-content">
                        <div class="playlist-workspace" id="playlist-workspace">
                            <div class="drop-zone" id="playlist-drop-zone">
                                <div class="drop-zone-content">
                                    <div class="drop-zone-icon">📁</div>
                                    <p>Glissez des médias ici pour créer votre playlist</p>
                                    <p class="drop-zone-hint">Ou cliquez sur "+" dans la bibliothèque</p>
                                </div>
                            </div>
                            <div class="playlist-items" id="playlist-items">
                                <!-- Playlist items will be added here -->
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Properties Panel (Right) -->
                <div class="playlist-panel properties-panel">
                    <div class="panel-header">
                        <h3>⚙️ Propriétés</h3>
                    </div>
                    <div class="panel-content">
                        <div class="properties-section">
                            <h4>Playlist</h4>
                            <div class="form-group">
                                <label>Nom:</label>
                                <input type="text" id="playlist-name-input" placeholder="Nom de la playlist" onchange="updatePlaylistName()">
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-loop" onchange="updatePlaylistSettings()">
                                    Lecture en boucle
                                </label>
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-shuffle" onchange="updatePlaylistSettings()">
                                    Lecture aléatoire
                                </label>
                            </div>
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" id="playlist-auto-advance" checked onchange="updatePlaylistSettings()">
                                    Avancement automatique
                                </label>
                            </div>
                        </div>

                        <div class="properties-section" id="item-properties" style="display: none;">
                            <h4>Élément sélectionné</h4>
                            <div class="form-group">
                                <label>Fichier:</label>
                                <span id="selected-file-name">-</span>
                            </div>
                            <div class="form-group">
                                <label>Durée (secondes):</label>
                                <input type="number" id="item-duration" min="1" max="3600" value="10" onchange="updateItemDuration()">
                            </div>
                            <div class="form-group">
                                <label>Transition:</label>
                                <select id="item-transition" onchange="updateItemTransition()">
                                    <option value="none">Aucune</option>
                                    <option value="fade">Fondu</option>
                                    <option value="slide-left">Glissement gauche</option>
                                    <option value="slide-right">Glissement droite</option>
                                    <option value="zoom">Zoom</option>
                                    <option value="dissolve">Dissolution</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Durée transition (ms):</label>
                                <input type="number" id="transition-duration" min="0" max="5000" value="1000" onchange="updateTransitionDuration()">
                            </div>
                        </div>

                        <div class="properties-section">
                            <h4>Actions</h4>
                            <button class="btn btn-primary btn-block" onclick="previewPlaylist()" id="preview-btn" disabled>
                                ▶️ Aperçu
                            </button>
                            <button class="btn btn-secondary btn-block" onclick="clearPlaylist()">
                                🗑️ Vider
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Loading existing playlists modal -->
            <div id="load-playlist-modal" class="modal" style="display: none;">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3>Charger une Playlist</h3>
                        <button class="btn-close" onclick="closeLoadPlaylistModal()">×</button>
                    </div>
                    <div class="modal-body">
                        <div id="existing-playlists-list">
                            <!-- Existing playlists will be loaded here -->
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- YouTube Section -->
        <div id="youtube" class="content-section">
            <div class="header">
                <h1 class="page-title">Téléchargement YouTube</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📥</span>
                    Télécharger une vidéo
                </h3>
                <div class="form-group">
                    <label class="form-label">URL YouTube</label>
                    <input type="url" class="form-control" id="youtube-url" placeholder="https://www.youtube.com/watch?v=...">
                </div>
                <div class="form-group">
                    <label class="form-label">Qualité</label>
                    <select class="form-control" id="youtube-quality">
                        <option value="best">Meilleure qualité</option>
                        <option value="720p">720p</option>
                        <option value="480p">480p</option>
                        <option value="360p">360p</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Compression</label>
                    <select class="form-control" id="youtube-compression">
                        <option value="none">Aucune</option>
                        <option value="h264">H.264 Optimisé</option>
                        <option value="ultralight">Ultra léger</option>
                    </select>
                </div>
                <button class="btn btn-primary" onclick="downloadYoutube()">
                    📥 Télécharger
                </button>
                <div class="progress-bar" style="display: none;" id="youtube-progress">
                    <div class="progress-fill" id="youtube-progress-fill"></div>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Historique
                </h3>
                <div id="youtube-history">
                    <!-- History will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Enhanced Player Section -->
        <div id="player" class="content-section">
            <div class="header">
                <h1 class="page-title">Contrôle du Lecteur</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="refreshPlayerStatus()">
                        🔄 Actualiser
                    </button>
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('player')">
                        📸 Capture
                    </button>
                </div>
            </div>

            <!-- Now Playing Card -->
            <div class="card now-playing-card">
                <div class="now-playing-header">
                    <div class="now-playing-info">
                        <h3 class="now-playing-title" id="now-playing-title">Aucun média en lecture</h3>
                        <p class="now-playing-meta" id="now-playing-meta">
                            <span class="player-state" id="player-state">Arrêté</span>
                            <span class="player-type">VLC</span>
                        </p>
                    </div>
                    <div class="now-playing-status">
                        <div class="status-indicator" id="status-indicator">
                            <span class="status-dot"></span>
                            <span id="status-text">Hors ligne</span>
                        </div>
                    </div>
                </div>

                <!-- Progress Bar -->
                <div class="progress-section">
                    <span class="time-current" id="time-current">00:00</span>
                    <div class="progress-bar-container">
                        <div class="progress-bar-bg">
                            <div class="progress-bar-fill" id="progress-fill" style="width: 0%"></div>
                            <input type="range" class="progress-bar-input" id="seek-bar"
                                   min="0" max="100" value="0"
                                   onchange="seekTo(this.value)"
                                   oninput="updateSeekPreview(this.value)">
                        </div>
                    </div>
                    <span class="time-total" id="time-total">00:00</span>
                </div>

                <!-- Transport Controls -->
                <div class="transport-controls">
                    <button class="control-btn secondary" id="shuffle-btn" onclick="toggleShuffle()" title="Aléatoire">
                        🔀
                    </button>
                    <button class="control-btn" id="previous-btn" onclick="playerControl('previous')" title="Précédent">
                        ⏮️
                    </button>
                    <button class="control-btn primary" id="play-pause-btn" onclick="togglePlayPause()" title="Lecture/Pause">
                        ▶️
                    </button>
                    <button class="control-btn" id="stop-btn" onclick="playerControl('stop')" title="Arrêt">
                        ⏹️
                    </button>
                    <button class="control-btn" id="next-btn" onclick="playerControl('next')" title="Suivant">
                        ⏭️
                    </button>
                    <button class="control-btn secondary" id="loop-btn" onclick="toggleLoop()" title="Répéter">
                        🔁
                    </button>
                </div>

                <!-- Volume Control -->
                <div class="volume-section">
                    <button class="volume-btn" id="mute-btn" onclick="toggleMute()" title="Muet">
                        🔊
                    </button>
                    <div class="volume-slider-container">
                        <input type="range" class="volume-slider" id="volume-slider"
                               min="0" max="100" value="50"
                               oninput="setVolume(this.value)">
                        <div class="volume-fill" id="volume-fill" style="width: 50%"></div>
                    </div>
                    <span class="volume-value" id="volume-value">50%</span>
                </div>
            </div>

            <!-- Playlist Control Card -->
            <div class="card">
                <h3 class="card-title">
                    <span>🎵</span>
                    Gestion des Playlists
                </h3>

                <div class="playlist-control-grid">
                    <!-- Playlist Selector -->
                    <div class="playlist-selector-section">
                        <div class="form-group">
                            <label class="form-label">Playlist active</label>
                            <select class="form-control" id="playlist-select" onchange="previewPlaylist()">
                                <option value="">-- Sélectionner une playlist --</option>
                            </select>
                        </div>

                        <div class="playlist-actions">
                            <button class="btn btn-primary" onclick="loadPlaylist()">
                                ▶️ Charger
                            </button>
                            <button class="btn btn-glass" onclick="showPlaylistQueue()">
                                📋 File d'attente
                            </button>
                        </div>
                    </div>

                    <!-- Current Queue -->
                    <div class="queue-section" id="queue-section" style="display: none;">
                        <h4>File d'attente actuelle</h4>
                        <div class="queue-list" id="queue-list">
                            <!-- Queue items will be loaded here -->
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Media Control -->
            <div class="card">
                <h3 class="card-title">
                    <span>📂</span>
                    Lecture rapide
                </h3>

                <div class="quick-play-grid">
                    <div class="form-group">
                        <label class="form-label">Fichier média</label>
                        <select class="form-control" id="media-select">
                            <option value="">-- Sélectionner un fichier --</option>
                        </select>
                    </div>

                    <div class="quick-play-actions">
                        <button class="btn btn-primary" onclick="playMediaFile()">
                            ▶️ Lire maintenant
                        </button>
                        <button class="btn btn-secondary" onclick="addMediaToQueue()">
                            ➕ Ajouter à la file
                        </button>
                    </div>
                </div>
            </div>

            <!-- System Stats -->
            <div class="card">
                <h3 class="card-title">
                    <span>📊</span>
                    Statistiques système
                </h3>
                <div class="system-stats-grid">
                    <div class="stat-item">
                        <label>CPU</label>
                        <span id="player-cpu">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Mémoire</label>
                        <span id="player-memory">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Température</label>
                        <span id="player-temp">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Uptime</label>
                        <span id="player-uptime">--</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Schedule Section -->
        <div id="schedule" class="content-section">
            <div class="header">
                <h1 class="page-title">Programmation</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="addSchedule()">
                        ➕ Ajouter
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📅</span>
                    Calendrier
                </h3>
                <div id="schedule-list">
                    <!-- Schedule items will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Screenshot Section -->
        <div id="screenshot" class="content-section">
            <div class="header">
                <h1 class="page-title">Capture d'écran</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📸</span>
                    Capture en temps réel
                </h3>
                <div class="screenshot-preview" id="screenshot-preview">
                    <img id="screenshot-img" src="" alt="Capture d'écran" style="display: none;">
                    <div class="empty-state" id="screenshot-empty">
                        <div class="empty-state-icon">📸</div>
                        <div class="empty-state-title">Aucune capture</div>
                    </div>
                </div>
                <div class="player-controls">
                    <button class="btn btn-primary" onclick="takeScreenshot()">
                        📸 Prendre une capture
                    </button>
                    <button class="btn btn-glass" id="auto-capture-btn" onclick="toggleAutoCapture()">
                        🔄 Auto-capture (OFF)
                    </button>
                </div>
            </div>
        </div>

        <!-- Settings Section -->
        <div id="settings" class="content-section">
            <div class="header">
                <h1 class="page-title">Paramètres</h1>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🖥️</span>
                        Affichage
                    </h3>
                    <div class="form-group">
                        <label class="form-label">Résolution</label>
                        <select class="form-control" id="resolution">
                            <option value="1920x1080">1920x1080 (Full HD)</option>
                            <option value="1280x720">1280x720 (HD)</option>
                            <option value="1024x768">1024x768</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Rotation</label>
                        <select class="form-control" id="rotation">
                            <option value="0">0° (Normal)</option>
                            <option value="90">90° (Droite)</option>
                            <option value="180">180° (Inversé)</option>
                            <option value="270">270° (Gauche)</option>
                        </select>
                    </div>
                    <button class="btn btn-primary" onclick="saveDisplayConfig()">
                        💾 Appliquer
                    </button>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>🌐</span>
                        Réseau
                    </h3>
                    <form id="network-form" onsubmit="return false;">
                        <div class="form-group">
                            <label class="form-label">WiFi SSID</label>
                            <input type="text" class="form-control" id="wifi-ssid" placeholder="Nom du réseau">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Mot de passe</label>
                            <input type="password" class="form-control" id="wifi-password" placeholder="Mot de passe" autocomplete="new-password">
                        </div>
                        <button type="button" class="btn btn-primary" onclick="saveNetworkConfig()">
                            💾 Appliquer
                        </button>
                    </form>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>🔧</span>
                    Actions système
                </h3>
                <div style="display: flex; gap: 15px; flex-wrap: wrap;">
                    <button class="btn btn-danger" onclick="systemAction('reboot')">
                        🔄 Redémarrer
                    </button>
                    <button class="btn btn-danger" onclick="systemAction('shutdown')">
                        ⚡ Éteindre
                    </button>
                    <button class="btn btn-glass" onclick="restartCurrentPlayer()">
                        🎵 <span id="restart-player-text">Redémarrer VLC</span>
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('clear-cache')">
                        🗑️ Vider le cache
                    </button>
                </div>
            </div>
        </div>

        <!-- Logs Section -->
        <div id="logs" class="content-section">
            <div class="header">
                <h1 class="page-title">Logs Système</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="refreshLogs()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Logs récents
                </h3>
                <div id="logs-content" style="background: rgba(0,0,0,0.3); padding: 20px; border-radius: 10px; font-family: monospace; font-size: 12px; max-height: 500px; overflow-y: auto;">
                    <!-- Logs will be loaded here -->
                </div>
            </div>
        </div>
    </div>

    <!-- Alert Container -->
    <div id="alert-container" style="position: fixed; top: 20px; right: 20px; z-index: 3000;"></div>

    <script>
        // Global variables
        let currentSection = 'dashboard';
        let autoScreenshotInterval = null;
        let systemStatsInterval = null;
        let currentPlayer = 'vlc'; // Défaut VLC
        let selectedPlayer = 'vlc';

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            // Initialize immediately with direct calls to ensure execution
            setTimeout(function() {
                // Call refreshStats directly with fetch to ensure it works
                fetch('/api/system.php?action=stats')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if (data.success && data.data) {
                            // Update all stats directly
                            var el;
                            el = document.getElementById('cpu-usage');
                            if (el) el.textContent = ((data.data.cpu && data.data.cpu.usage) || 0) + '%';

                            el = document.getElementById('ram-usage');
                            if (el) el.textContent = ((data.data.memory && data.data.memory.percent) || 0) + '%';

                            el = document.getElementById('temperature');
                            if (el) el.textContent = (data.data.temperature || 0) + '°C';

                            el = document.getElementById('uptime');
                            if (el) el.textContent = data.data.uptime || '--';

                            el = document.getElementById('storage');
                            if (el && data.data.disk) {
                                el.textContent = data.data.disk.used_formatted + ' / ' + data.data.disk.total_formatted + ' (' + data.data.disk.percent + '%)';
                            }

                            el = document.getElementById('network');
                            if (el) el.textContent = data.data.network || '--';

                            el = document.getElementById('media-count');
                            if (el) el.textContent = (data.data.media_count || 0) + ' fichiers';
                        }
                    });

                // Also load media and playlists
                loadMediaFiles();
                loadPlaylists();
                getCurrentPlayer();
                updatePlayerInterface();
            }, 100);

            // Auto refresh stats every 5 seconds
            systemStatsInterval = setInterval(refreshStats, 5000);

            // Auto refresh player status every 3 seconds
            setInterval(function() {
                updatePlayerStatus();
            }, 3000);
        });

        // Navigation
        function showSection(section) {
            // Update sections
            document.querySelectorAll('.content-section').forEach(el => {
                el.classList.remove('active');
            });
            document.getElementById(section).classList.add('active');

            // Update nav items
            document.querySelectorAll('.nav-item').forEach(el => {
                el.classList.remove('active');
                // Check if this nav item corresponds to the current section
                const onclick = el.getAttribute('onclick');
                if (onclick && onclick.includes(`'${section}'`)) {
                    el.classList.add('active');
                }
            });

            // Initialize playlist editor if switching to playlists
            if (section === 'playlists') {
                setTimeout(() => {
                    if (typeof initPlaylistEditor === 'function') {
                        initPlaylistEditor();
                    } else {
                        loadPlaylists(); // Fallback to old function
                    }
                }, 100);
            }

            currentSection = section;
        }

        // Toggle sidebar (mobile)
        function toggleSidebar() {
            document.getElementById('sidebar').classList.toggle('active');
        }

        // Show alert
        function showAlert(message, type = 'info') {
            const alertDiv = document.createElement('div');
            alertDiv.className = `alert alert-${type}`;
            alertDiv.innerHTML = message;

            document.getElementById('alert-container').appendChild(alertDiv);

            setTimeout(() => {
                alertDiv.remove();
            }, 3000);
        }

        // System stats
        window.refreshStats = function refreshStats() {
            fetch('/api/system.php?action=stats')
                .then(function(response) { return response.json(); })
                .then(function(data) {
                    if (data.success && data.data) {
                        // CPU, RAM, Temperature
                        var cpuEl = document.getElementById('cpu-usage');
                        if (cpuEl) cpuEl.textContent = ((data.data.cpu && data.data.cpu.usage) || 0) + '%';

                        var ramEl = document.getElementById('ram-usage');
                        if (ramEl) ramEl.textContent = ((data.data.memory && data.data.memory.percent) || 0) + '%';

                        var tempEl = document.getElementById('temperature');
                        if (tempEl) tempEl.textContent = (data.data.temperature || 0) + '°C';

                        // Stats système
                        var uptimeEl = document.getElementById('uptime');
                        if (uptimeEl) {
                            uptimeEl.textContent = data.data.uptime || '--';
                        }

                        var storageEl = document.getElementById('storage');
                        if (storageEl && data.data.disk) {
                            storageEl.textContent = data.data.disk.used_formatted + ' / ' + data.data.disk.total_formatted + ' (' + data.data.disk.percent + '%)';
                        }

                        var networkEl = document.getElementById('network');
                        if (networkEl) {
                            networkEl.textContent = data.data.network || '--';
                        }

                        var mediaCountEl = document.getElementById('media-count');
                        if (mediaCountEl) {
                            mediaCountEl.textContent = (data.data.media_count || 0) + ' fichiers';
                        }
                    }
                })
                .catch(function(error) {
                    console.error('Error loading stats:', error);
                });
        }

        // Enhanced Player Control with Real-time Status
        let playerState = {
            isPlaying: false,
            isPaused: false,
            currentFile: null,
            position: 0,
            duration: 0,
            volume: 50,
            isMuted: false,
            isLooping: false,
            isShuffling: false
        };

        let statusUpdateInterval = null;

        function playerControl(action) {
            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: action
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    if (data.status) {
                        updatePlayerUI(data.status);
                    }
                    showAlert(`${action} exécuté`, 'success');
                } else {
                    showAlert(data.message || `Erreur: ${action}`, 'error');
                }
            })
            .catch(error => {
                console.error('Player control error:', error);
                showAlert('Erreur de communication', 'error');
            });
        }

        function togglePlayPause() {
            const action = playerState.isPlaying ? 'pause' : 'play';
            playerControl(action);
        }

        function seekTo(percentage) {
            const position = (playerState.duration * percentage) / 100;
            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'seek',
                    params: { position: position }
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.status) {
                    updatePlayerUI(data.status);
                }
            });
        }

        function setVolume(volume) {
            playerState.volume = volume;
            document.getElementById('volume-value').textContent = volume + '%';
            document.getElementById('volume-fill').style.width = volume + '%';

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'volume',
                    params: { volume: volume }
                })
            });
        }

        function toggleMute() {
            playerState.isMuted = !playerState.isMuted;
            const muteBtn = document.getElementById('mute-btn');

            if (playerState.isMuted) {
                muteBtn.textContent = '🔇';
                setVolume(0);
            } else {
                muteBtn.textContent = '🔊';
                setVolume(playerState.volume || 50);
            }
        }

        function toggleLoop() {
            playerState.isLooping = !playerState.isLooping;
            const loopBtn = document.getElementById('loop-btn');
            loopBtn.classList.toggle('active');

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'set_loop',
                    params: { enabled: playerState.isLooping }
                })
            });
        }

        function toggleShuffle() {
            playerState.isShuffling = !playerState.isShuffling;
            const shuffleBtn = document.getElementById('shuffle-btn');
            shuffleBtn.classList.toggle('active');

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'set_random',
                    params: { enabled: playerState.isShuffling }
                })
            });
        }

        // Update Player UI with status data
        function updatePlayerUI(status) {
            if (!status) return;

            // Update player state
            playerState.isPlaying = status.state === 'playing';
            playerState.isPaused = status.state === 'paused';
            playerState.currentFile = status.current_file;
            playerState.position = status.position || 0;
            playerState.duration = status.duration || 0;
            playerState.volume = status.volume || 50;

            // Update Now Playing
            const titleEl = document.getElementById('now-playing-title');
            const metaEl = document.getElementById('player-state');
            const statusEl = document.getElementById('status-indicator');
            const statusTextEl = document.getElementById('status-text');

            if (status.current_file) {
                titleEl.textContent = status.current_file;
            } else {
                titleEl.textContent = 'Aucun média en lecture';
            }

            // Update status indicator
            switch (status.state) {
                case 'playing':
                    metaEl.textContent = 'En lecture';
                    statusEl.className = 'status-indicator playing';
                    statusTextEl.textContent = 'En ligne';
                    document.getElementById('play-pause-btn').textContent = '⏸️';
                    break;
                case 'paused':
                    metaEl.textContent = 'En pause';
                    statusEl.className = 'status-indicator paused';
                    statusTextEl.textContent = 'En pause';
                    document.getElementById('play-pause-btn').textContent = '▶️';
                    break;
                default:
                    metaEl.textContent = 'Arrêté';
                    statusEl.className = 'status-indicator';
                    statusTextEl.textContent = 'Hors ligne';
                    document.getElementById('play-pause-btn').textContent = '▶️';
            }

            // Update progress bar
            if (playerState.duration > 0) {
                const progress = (playerState.position / playerState.duration) * 100;
                document.getElementById('progress-fill').style.width = progress + '%';
                document.getElementById('seek-bar').value = progress;
                document.getElementById('time-current').textContent = formatTime(playerState.position);
                document.getElementById('time-total').textContent = formatTime(playerState.duration);
            }

            // Update volume
            document.getElementById('volume-slider').value = playerState.volume;
            document.getElementById('volume-fill').style.width = playerState.volume + '%';
            document.getElementById('volume-value').textContent = Math.round(playerState.volume) + '%';

            // Update system stats if available
            if (status.system) {
                document.getElementById('player-cpu').textContent = status.system.cpu + '%';
                document.getElementById('player-memory').textContent = status.system.memory.percent + '%';
                document.getElementById('player-temp').textContent = status.system.temperature + '°C';
                document.getElementById('player-uptime').textContent = status.system.uptime || '--';
            }
        }

        // Refresh Player Status
        function refreshPlayerStatus() {
            fetch('/api/player-control.php?action=status')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.data) {
                        updatePlayerUI(data.data);
                    }
                })
                .catch(error => console.error('Error fetching player status:', error));
        }

        // Load playlist to player
        function loadPlaylist() {
            const playlistSelect = document.getElementById('playlist-select');
            const playlistName = playlistSelect.value;

            if (!playlistName) {
                showAlert('Veuillez sélectionner une playlist', 'warning');
                return;
            }

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'load_playlist',
                    params: { name: playlistName }
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Playlist "${playlistName}" chargée`, 'success');
                    refreshPlayerStatus();
                } else {
                    showAlert(data.message || 'Erreur lors du chargement', 'error');
                }
            });
        }

        // Play media file
        function playMediaFile() {
            const mediaSelect = document.getElementById('media-select');
            const file = mediaSelect.value;

            if (!file) {
                showAlert('Veuillez sélectionner un fichier', 'warning');
                return;
            }

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'play_file',
                    params: { file: file }
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Lecture de ${file}`, 'success');
                    refreshPlayerStatus();
                } else {
                    showAlert(data.message || 'Erreur de lecture', 'error');
                }
            });
        }

        // Add media to queue
        function addMediaToQueue() {
            const mediaSelect = document.getElementById('media-select');
            const file = mediaSelect.value;

            if (!file) {
                showAlert('Veuillez sélectionner un fichier', 'warning');
                return;
            }

            fetch('/api/player-control.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'add_to_playlist',
                    params: { file: file }
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`${file} ajouté à la file d'attente`, 'success');
                    refreshPlayerStatus();
                } else {
                    showAlert(data.message || 'Erreur', 'error');
                }
            });
        }

        // Show playlist queue
        function showPlaylistQueue() {
            const queueSection = document.getElementById('queue-section');
            queueSection.style.display = queueSection.style.display === 'none' ? 'block' : 'none';

            if (queueSection.style.display === 'block') {
                // Load queue items
                fetch('/api/player-control.php?action=status')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success && data.data && data.data.playlist) {
                            renderQueueItems(data.data.playlist);
                        }
                    });
            }
        }

        // Render queue items
        function renderQueueItems(playlist) {
            const queueList = document.getElementById('queue-list');
            if (!playlist || playlist.length === 0) {
                queueList.innerHTML = '<div class="empty-state">File d'attente vide</div>';
                return;
            }

            queueList.innerHTML = playlist.map((item, index) => `
                <div class="queue-item ${item.current ? 'current' : ''}" data-index="${index}">
                    <span class="queue-number">${index + 1}</span>
                    <span class="queue-name">${item.name}</span>
                    ${item.current ? '<span class="queue-current">▶️</span>' : ''}
                </div>
            `).join('');
        }

        // Format time helper
        function formatTime(seconds) {
            if (!seconds || isNaN(seconds)) return '00:00';
            const mins = Math.floor(seconds / 60);
            const secs = Math.floor(seconds % 60);
            return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        }

        // Update seek preview
        function updateSeekPreview(value) {
            // Optional: Show time preview on hover
            const position = (playerState.duration * value) / 100;
            // Could add a tooltip showing the time
        }

        // Initialize player on page load
        function initializePlayer() {
            // Load playlists
            fetch('/api/playlist-simple.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.data) {
                        const playlistSelect = document.getElementById('playlist-select');
                        playlistSelect.innerHTML = '<option value="">-- Sélectionner une playlist --</option>';
                        data.data.forEach(playlist => {
                            playlistSelect.innerHTML += `<option value="${playlist.name}">${playlist.name}</option>`;
                        });
                    }
                });

            // Load media files
            fetch('/api/media.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.data) {
                        const mediaSelect = document.getElementById('media-select');
                        mediaSelect.innerHTML = '<option value="">-- Sélectionner un fichier --</option>';
                        data.data.forEach(file => {
                            mediaSelect.innerHTML += `<option value="${file.name}">${file.name}</option>`;
                        });
                    }
                });

            // Start status polling
            refreshPlayerStatus();
            statusUpdateInterval = setInterval(refreshPlayerStatus, 2000);
        }

        // Clean up on page unload
        window.addEventListener('beforeunload', () => {
            if (statusUpdateInterval) {
                clearInterval(statusUpdateInterval);
            }
        });

        // Update Player Status (Adaptive) - Keep for compatibility
        function updatePlayerStatus() {
            refreshPlayerStatus();
        }
                if (data.success) {
                    const status = data.running ? 'En lecture' : 'Arrêté';
                    const statusColor = data.running ? '#51cf66' : '#ffd43b';

                    // Mettre à jour l'affichage avec le nom du lecteur actuel
                    const playerElement = document.getElementById('player-state');
                    if (playerElement) {
                        playerElement.textContent = status;
                        playerElement.style.color = statusColor;
                    }

                    const fileElement = document.getElementById('player-file');
                    if (fileElement) {
                        fileElement.textContent = data.status || 'Aucun';
                    }

                    const positionElement = document.getElementById('player-position');
                    if (positionElement) {
                        positionElement.textContent = data.position || '00:00';
                    }
                }
            })
            .catch(error => console.error(`Erreur status ${currentPlayer}:`, error));
        }

        // Get current player from config
        function getCurrentPlayer() {
            fetch('/api/system.php?action=get_player')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        // Mettre à jour les variables globales
                        currentPlayer = data.player || 'vlc';
                        selectedPlayer = currentPlayer;

                        // Mettre à jour l'interface
                        updatePlayerInterface();

                        // Update radio buttons
                        if (document.getElementById('player-' + currentPlayer)) {
                            document.getElementById('player-' + currentPlayer).checked = true;
                        }
                    }
                })
                .catch(error => {
                    console.error('Get player error:', error);
                    // En cas d'erreur, utiliser VLC par défaut
                    currentPlayer = 'vlc';
                    selectedPlayer = 'vlc';
                    updatePlayerInterface();
                });
        }

        // Update Player Interface (NOUVELLE FONCTION ADAPTATIVE)
        function updatePlayerInterface() {
            const playerName = currentPlayer.toUpperCase();

            // Mettre à jour le statut principal
            const currentPlayerElement = document.getElementById('current-player');
            if (currentPlayerElement) {
                currentPlayerElement.textContent = playerName;
                currentPlayerElement.style.color = currentPlayer === 'vlc' ? '#4a9eff' : '#51cf66';
            }

            // Mettre à jour le titre des contrôles dans la section Player
            const controlsNameElement = document.getElementById('player-controls-name');
            if (controlsNameElement) {
                controlsNameElement.textContent = `Contrôles ${playerName}`;
            }

            // Mettre à jour le texte du bouton de redémarrage
            const restartTextElement = document.getElementById('restart-player-text');
            if (restartTextElement) {
                restartTextElement.textContent = `Redémarrer ${playerName}`;
            }

            // Mettre à jour les boutons radio
            document.querySelectorAll('input[name="player"]').forEach(radio => {
                radio.checked = (radio.value === currentPlayer);
            });

            // Adapter les boutons de contrôle selon le lecteur
            const playerButtons = document.querySelectorAll('.player-btn');
            playerButtons.forEach(btn => {
                if (currentPlayer === 'vlc') {
                    btn.style.background = 'linear-gradient(135deg, #4a9eff, #3d7edb)';
                } else {
                    btn.style.background = 'linear-gradient(135deg, #51cf66, #3eb854)';
                }
            });
        }

        // Switch between players (CORRIGÉ ET AMÉLIORÉ)
        function switchPlayer() {
            const newSelectedPlayer = document.querySelector('input[name="player"]:checked').value;

            if (newSelectedPlayer === currentPlayer) {
                showAlert(`${newSelectedPlayer.toUpperCase()} est déjà le lecteur actif`, 'info');
                return;
            }

            if (confirm(`Basculer vers ${newSelectedPlayer.toUpperCase()} ?\nLe lecteur ${currentPlayer.toUpperCase()} sera arrêté.`)) {
                showAlert(`🔄 Basculement vers ${newSelectedPlayer.toUpperCase()} en cours...`, 'info');

                fetch('/api/system.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'switch_player',
                        player: newSelectedPlayer,
                        current_player: currentPlayer
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        // Mettre à jour immédiatement les variables globales
                        currentPlayer = newSelectedPlayer;
                        selectedPlayer = newSelectedPlayer;

                        // Mettre à jour l'interface
                        updatePlayerInterface();

                        showAlert(`✅ Basculement vers ${newSelectedPlayer.toUpperCase()} réussi!`, 'success');

                        // Refresh status après un délai
                        setTimeout(() => {
                            updatePlayerStatus();
                        }, 1500);
                    } else {
                        showAlert(data.message || 'Erreur lors du basculement', 'error');
                        // Remettre le bon bouton radio en cas d'erreur
                        document.getElementById('player-' + currentPlayer).checked = true;
                    }
                })
                .catch(error => {
                    showAlert('Erreur de communication lors du basculement', 'error');
                    console.error('Switch error:', error);
                    // Remettre le bon bouton radio en cas d'erreur
                    document.getElementById('player-' + currentPlayer).checked = true;
                });
            } else {
                // L'utilisateur a annulé, remettre le bon bouton radio
                document.getElementById('player-' + currentPlayer).checked = true;
            }
        }

        // Play single file (ADAPTATIF)
        function playSingleFile() {
            const file = document.getElementById('single-file-select').value;
            if (!file) {
                showAlert('Sélectionnez un fichier', 'error');
                return;
            }

            const playerName = currentPlayer.toUpperCase();

            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'play-file',
                    file: file,
                    player: currentPlayer
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message || `${playerName}: Lecture de ${file} démarrée!`, 'success');
                    setTimeout(() => updatePlayerStatus(), 500);
                } else {
                    showAlert(data.message || `Erreur ${playerName}: Lecture impossible`, 'error');
                }
            })
            .catch(error => showAlert(`Erreur de communication avec ${playerName}`, 'error'));
        }

        // Play playlist (ADAPTATIF)
        function playPlaylist() {
            const playlist = document.getElementById('playlist-select').value;
            if (!playlist) {
                showAlert('Sélectionnez une playlist', 'error');
                return;
            }

            const playerName = currentPlayer.toUpperCase();

            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'play-playlist',
                    playlist: playlist,
                    player: currentPlayer
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message || `${playerName}: Playlist ${playlist} lancée!`, 'success');
                    setTimeout(() => updatePlayerStatus(), 500);
                } else {
                    showAlert(`Erreur ${playerName}: ` + data.message, 'error');
                }
            })
            .catch(error => showAlert(`Erreur de communication avec ${playerName}`, 'error'));
        }

        // Screenshot functions
        function takeScreenshot() {
            showAlert('Capture en cours...', 'info');

            fetch('/api/screenshot.php?action=capture')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const img = document.getElementById('screenshot-img');
                        const empty = document.getElementById('screenshot-empty');

                        img.src = data.data.url + '?' + Date.now();
                        img.style.display = 'block';
                        empty.style.display = 'none';

                        showAlert('Capture réalisée!', 'success');
                    } else {
                        showAlert('Erreur: ' + data.message, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showAlert('Erreur lors de la capture', 'error');
                });
        }

        function takeQuickScreenshot(source) {
            showAlert(`Capture depuis ${source}...`, 'info');

            fetch('/api/screenshot.php?action=capture')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        // Create modal
                        const modal = document.createElement('div');
                        modal.className = 'modal active';
                        modal.innerHTML = `
                            <div class="modal-content">
                                <h3 style="margin-bottom: 20px;">📸 Capture d'écran</h3>
                                <img src="${data.data.url}?${Date.now()}" style="width: 100%; border-radius: 10px;">
                                <button class="btn btn-primary" style="margin-top: 20px;" onclick="this.closest('.modal').remove()">
                                    Fermer
                                </button>
                            </div>
                        `;
                        document.body.appendChild(modal);

                        showAlert('Capture réalisée!', 'success');
                    } else {
                        showAlert('Erreur: ' + data.message, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showAlert('Erreur lors de la capture', 'error');
                });
        }

        function toggleAutoCapture() {
            const btn = document.getElementById('auto-capture-btn');

            if (autoScreenshotInterval) {
                clearInterval(autoScreenshotInterval);
                autoScreenshotInterval = null;
                btn.textContent = '🔄 Auto-capture (OFF)';
                showAlert('Auto-capture désactivée', 'info');
            } else {
                autoScreenshotInterval = setInterval(takeScreenshot, 30000);
                btn.textContent = '🔄 Auto-capture (ON)';
                showAlert('Auto-capture activée (30s)', 'success');
            }
        }

        // Media management
        window.loadMediaFiles = function loadMediaFiles() {
            fetch('/api/media.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const container = document.getElementById('media-list');
                        const fileSelect = document.getElementById('single-file-select');

                        container.innerHTML = '';
                        fileSelect.innerHTML = '<option value="">-- Choisir --</option>';

                        (data.data || []).forEach(file => {
                            // Add to grid
                            const card = document.createElement('div');
                            card.className = 'card';
                            card.innerHTML = `
                                <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                    <input type="checkbox" id="media-${file.name}" value="${file.name}" style="margin-right: 10px;">
                                    <h4 style="margin: 0; flex: 1;">${file.name}</h4>
                                </div>
                                <p>Taille: ${(file.size / 1024 / 1024).toFixed(2)} MB</p>
                                <p>Type: ${file.type}</p>
                                <button class="btn btn-danger" onclick="deleteFile('${file.name}')">
                                    🗑️ Supprimer
                                </button>
                            `;
                            container.appendChild(card);

                            // Add to select
                            const option = document.createElement('option');
                            option.value = file.name;
                            option.textContent = file.name;
                            fileSelect.appendChild(option);
                        });
                    }
                })
                .catch(error => console.error('Error loading media:', error));
        }

        function deleteFile(filename) {
            if (!confirm(`Supprimer ${filename}?`)) return;

            fetch('/api/media.php', {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ filename: filename, action: 'delete' })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Fichier supprimé!', 'success');
                    loadMediaFiles();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de suppression', 'error'));
        }

        // Playlist management
        function loadPlaylists() {
            fetch('/api/playlist-simple.php')
                .then(function(response) { return response.json(); })
                .then(function(data) {
                    if (data.success) {
                        var container = document.getElementById('playlist-container');
                        var select = document.getElementById('playlist-select');

                        if (container) container.innerHTML = '';
                        if (select) select.innerHTML = '<option value="">-- Choisir --</option>';

                        if (data.data && container) {
                            data.data.forEach(function(playlist) {
                                // Add to container
                                var card = document.createElement('div');
                                card.className = 'card';
                                card.innerHTML = '<h3 class="card-title">' + playlist.name + '</h3>' +
                                    '<p>' + (playlist.items ? playlist.items.length : 0) + ' fichiers</p>' +
                                    '<button class="btn btn-primary" onclick="editPlaylist(\'' + playlist.name + '\')">' +
                                    '✏️ Modifier</button>' +
                                    '<button class="btn btn-danger" onclick="deletePlaylist(\'' + playlist.name + '\')">' +
                                    '🗑️ Supprimer</button>';
                                container.appendChild(card);

                            // Add to select
                                // Add to select
                                if (select) {
                                    var option = document.createElement('option');
                                    option.value = playlist.name;
                                    option.textContent = playlist.name;
                                    select.appendChild(option);
                                }
                            });
                        }
                    }
                })
                .catch(function(error) {
                    console.error('Error loading playlists:', error);
                });
        }

        // Create new playlist
        function createPlaylist() {
            const name = prompt('Nom de la nouvelle playlist:');
            if (!name) return;

            // Get selected files from media section
            const selectedFiles = Array.from(document.querySelectorAll('#media input[type="checkbox"]:checked'))
                .map(cb => cb.value);

            fetch('/api/playlist.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'create',
                    name: name,
                    items: selectedFiles
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist créée!', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de création', 'error'));
        }

        // Edit playlist
        function editPlaylist(name) {
            // Load playlist details
            fetch(`/api/playlist.php?action=info&name=${encodeURIComponent(name)}`)
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.data) {
                        const playlist = data.data;

                        // Create edit modal
                        const modalHTML = `
                            <div id="editPlaylistModal" style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 9999;">
                                <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #2a2d3a; padding: 30px; border-radius: 10px; width: 600px; max-width: 90%; max-height: 80vh; overflow-y: auto;">
                                    <h2 style="margin: 0 0 20px; color: #4a9eff;">✏️ Modifier Playlist: ${name}</h2>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Nom de la playlist:</label>
                                        <input type="text" id="edit-playlist-name" value="${name}" style="width: 100%; padding: 8px; background: #1a1a2e; border: 1px solid #4a9eff; border-radius: 5px; color: white;">
                                    </div>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Fichiers dans la playlist:</label>
                                        <div id="edit-playlist-items" style="max-height: 200px; overflow-y: auto; border: 1px solid #4a9eff; padding: 10px; border-radius: 5px;">
                                            ${playlist.items.map(item => `
                                                <div style="margin-bottom: 5px;">
                                                    <input type="checkbox" id="item-${item}" value="${item}" checked>
                                                    <label for="item-${item}" style="margin-left: 5px;">${item}</label>
                                                </div>
                                            `).join('')}
                                        </div>
                                    </div>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Ajouter des fichiers:</label>
                                        <select id="add-files-select" multiple style="width: 100%; height: 100px; background: #1a1a2e; border: 1px solid #4a9eff; color: white;">
                                            <!-- Will be populated with available files -->
                                        </select>
                                    </div>

                                    <div style="text-align: right;">
                                        <button class="btn btn-primary" onclick="savePlaylistChanges('${name}')">💾 Sauvegarder</button>
                                        <button class="btn btn-secondary" onclick="closeEditPlaylistModal()">Annuler</button>
                                    </div>
                                </div>
                            </div>
                        `;

                        // Remove existing modal if any
                        const existingModal = document.getElementById('editPlaylistModal');
                        if (existingModal) existingModal.remove();

                        // Add modal to page
                        document.body.insertAdjacentHTML('beforeend', modalHTML);

                        // Populate available files
                        fetch('/api/media.php?action=list')
                            .then(response => response.json())
                            .then(mediaData => {
                                if (mediaData.success && mediaData.data) {
                                    const select = document.getElementById('add-files-select');
                                    mediaData.data.forEach(file => {
                                        if (!playlist.items.includes(file.name)) {
                                            const option = document.createElement('option');
                                            option.value = file.name;
                                            option.textContent = file.name;
                                            select.appendChild(option);
                                        }
                                    });
                                }
                            });
                    } else {
                        showAlert('Erreur lors du chargement de la playlist', 'error');
                    }
                })
                .catch(error => showAlert('Erreur de chargement', 'error'));
        }

        function closeEditPlaylistModal() {
            const modal = document.getElementById('editPlaylistModal');
            if (modal) modal.remove();
        }

        function savePlaylistChanges(originalName) {
            const newName = document.getElementById('edit-playlist-name').value;

            // Get selected existing items
            const selectedItems = Array.from(document.querySelectorAll('#edit-playlist-items input:checked'))
                .map(cb => cb.value);

            // Get newly selected files
            const newFiles = Array.from(document.getElementById('add-files-select').selectedOptions)
                .map(option => option.value);

            const allItems = [...selectedItems, ...newFiles];

            fetch('/api/playlist.php', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'update',
                    oldName: originalName,
                    name: newName,
                    items: allItems
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist modifiée!', 'success');
                    closeEditPlaylistModal();
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        // Delete playlist
        function deletePlaylist(name) {
            if (!confirm(`Supprimer la playlist "${name}"?`)) return;

            fetch('/api/playlist.php', {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'delete',
                    name: name
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist supprimée!', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de suppression', 'error'));
        }

        // YouTube download avec monitoring
        let youtubeMonitorInterval = null;
        let downloadStartTime = null;
        let currentDownloadUrl = '';
        let currentDownloadQuality = '';

        function downloadYoutube() {
            const url = document.getElementById('youtube-url').value;
            const quality = document.getElementById('youtube-quality').value;

            // Sauvegarder pour l'historique
            currentDownloadUrl = url;
            currentDownloadQuality = quality;

            if (!url) {
                showAlert('Entrez une URL YouTube', 'error');
                return;
            }

            // Afficher le feedback détaillé
            showAlert('🚀 Lancement du téléchargement...', 'info');
            document.getElementById('youtube-progress').style.display = 'block';

            // Créer zone de feedback si elle n'existe pas
            let feedbackDiv = document.getElementById('youtube-feedback');
            if (!feedbackDiv) {
                feedbackDiv = document.createElement('div');
                feedbackDiv.id = 'youtube-feedback';
                feedbackDiv.style.cssText = 'margin-top: 20px; padding: 15px; background: rgba(0,0,0,0.3); border-radius: 8px; font-family: monospace; font-size: 12px; max-height: 200px; overflow-y: auto;';
                document.getElementById('youtube').appendChild(feedbackDiv);
            }
            feedbackDiv.innerHTML = '<div style="color: #4a9eff;">📥 Connexion à YouTube...</div>';

            downloadStartTime = Date.now();

            // Utiliser l'API simplifiée
            fetch('/api/youtube-simple.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    url: url,
                    quality: quality
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement lancé</div>';
                    feedbackDiv.innerHTML += '<div style="color: #999;">⏳ Récupération des informations vidéo...</div>';

                    // Démarrer le monitoring
                    startYoutubeMonitoring();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                    document.getElementById('youtube-progress').style.display = 'none';
                }
            })
            .catch(error => {
                showAlert('Erreur de connexion', 'error');
                document.getElementById('youtube-progress').style.display = 'none';
            });
        }

        function startYoutubeMonitoring() {
            let checkCount = 0;
            const maxChecks = 120; // 10 minutes max

            youtubeMonitorInterval = setInterval(() => {
                checkCount++;

                fetch('/api/youtube-simple.php?action=status')
                    .then(response => response.json())
                    .then(data => {
                        const feedbackDiv = document.getElementById('youtube-feedback');
                        const progressBar = document.getElementById('youtube-progress-fill');

                        if (data.downloading) {
                            // Afficher les logs
                            if (data.log) {
                                const lines = data.log.split('\n').filter(l => l.trim());
                                const lastLine = lines[lines.length - 1] || '';

                                // Extraire le pourcentage si présent
                                const percentMatch = lastLine.match(/(\d+\.?\d*)%/);
                                if (percentMatch) {
                                    const percent = parseFloat(percentMatch[1]);
                                    if (progressBar) {
                                        progressBar.style.width = percent + '%';
                                    }
                                    feedbackDiv.innerHTML = '<div style="color: #4a9eff;">⏬ Téléchargement: ' + percent.toFixed(1) + '%</div>';
                                }

                                // Afficher info sur la vidéo
                                if (lastLine.includes('Destination:')) {
                                    const filename = lastLine.split('/').pop();
                                    feedbackDiv.innerHTML += '<div style="color: #fff;">📁 ' + filename + '</div>';
                                }
                            }
                        } else {
                            // Téléchargement terminé
                            clearInterval(youtubeMonitorInterval);
                            const elapsed = Math.round((Date.now() - downloadStartTime) / 1000);

                            feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement terminé (' + elapsed + 's)</div>';
                            showAlert('✅ Vidéo téléchargée avec succès!', 'success');

                            document.getElementById('youtube-progress').style.display = 'none';

                            // Ajouter à l'historique
                            const historyDiv = document.getElementById('youtube-history');
                            if (historyDiv) {
                                const now = new Date().toLocaleString('fr-FR');
                                const historyItem = `
                                    <div style="padding: 10px; margin-bottom: 10px; background: rgba(74,158,255,0.1); border-radius: 5px; border-left: 3px solid #4a9eff;">
                                        <div style="color: #4a9eff; font-size: 12px;">${now}</div>
                                        <div style="color: #fff; margin: 5px 0;">✅ ${currentDownloadUrl}</div>
                                        <div style="color: #999; font-size: 11px;">Qualité: ${currentDownloadQuality} - Durée: ${elapsed}s</div>
                                    </div>
                                `;
                                historyDiv.innerHTML = historyItem + historyDiv.innerHTML;

                                // Limiter l'historique à 10 entrées
                                const items = historyDiv.children;
                                while (items.length > 10) {
                                    historyDiv.removeChild(items[items.length - 1]);
                                }
                            }

                            // Auto-refresh MEDIA
                            setTimeout(() => {
                                loadMediaFiles();
                                feedbackDiv.innerHTML += '<div style="color: #999;">📂 Section MEDIA mise à jour</div>';
                            }, 2000);

                            // Effacer le formulaire
                            document.getElementById('youtube-url').value = '';
                        }

                        // Timeout après 10 minutes
                        if (checkCount >= maxChecks) {
                            clearInterval(youtubeMonitorInterval);
                            feedbackDiv.innerHTML += '<div style="color: #f44;">⚠️ Timeout - Vérifiez les logs</div>';
                            document.getElementById('youtube-progress').style.display = 'none';
                        }
                    })
                    .catch(error => {
                        console.error('Monitoring error:', error);
                    });
            }, 5000); // Check toutes les 5 secondes
        }

        // System actions
        function systemAction(action) {
            if (action === 'reboot' || action === 'shutdown') {
                if (!confirm(`Êtes-vous sûr de vouloir ${action}?`)) return;
            }

            fetch('/api/system.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Action ${action} exécutée!`, 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur système', 'error'));
        }

        // Settings
        function saveDisplayConfig() {
            const resolution = document.getElementById('resolution').value;
            const rotation = document.getElementById('rotation').value;

            fetch('/api/config.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    type: 'display',
                    resolution: resolution,
                    rotation: rotation
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration sauvegardée!', 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        function saveNetworkConfig() {
            const ssid = document.getElementById('wifi-ssid').value;
            const password = document.getElementById('wifi-password').value;

            if (!ssid) {
                showAlert('Entrez un SSID', 'error');
                return;
            }

            fetch('/api/config.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    type: 'network',
                    ssid: ssid,
                    password: password
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration WiFi sauvegardée!', 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        // Logs
        function refreshLogs() {
            fetch('/api/logs.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('logs-content').innerHTML = data.data.logs.replace(/\n/g, '<br>');
                    }
                })
                .catch(error => console.error('Error loading logs:', error));
        }

        // Drag & Drop
        function dragOverHandler(ev) {
            ev.preventDefault();
            document.getElementById('upload-zone').classList.add('dragging');
        }

        function dragLeaveHandler(ev) {
            document.getElementById('upload-zone').classList.remove('dragging');
        }

        function dropHandler(ev) {
            ev.preventDefault();
            document.getElementById('upload-zone').classList.remove('dragging');

            const files = ev.dataTransfer.files;
            if (files.length > 0) {
                uploadFiles(files);
            }
        }

        function uploadFiles(files) {
            const formData = new FormData();
            let totalSize = 0;

            for (let i = 0; i < files.length; i++) {
                formData.append('files[]', files[i]);
                totalSize += files[i].size;
            }

            showAlert(`📤 Upload de ${files.length} fichier(s) - ${(totalSize/1024/1024).toFixed(1)}MB`, 'info');

            // Afficher une barre de progression
            const progressDiv = document.createElement('div');
            progressDiv.style.cssText = 'position: fixed; bottom: 20px; right: 20px; background: #2a2d3a; padding: 15px; border-radius: 8px; z-index: 1000; box-shadow: 0 4px 6px rgba(0,0,0,0.3);';
            progressDiv.innerHTML = `
                <div style="color: #4a9eff; margin-bottom: 10px;">Upload en cours...</div>
                <div style="width: 200px; height: 10px; background: rgba(255,255,255,0.1); border-radius: 5px;">
                    <div id="upload-progress-bar" style="width: 0%; height: 100%; background: #4a9eff; border-radius: 5px; transition: width 0.3s;"></div>
                </div>
            `;
            document.body.appendChild(progressDiv);

            const xhr = new XMLHttpRequest();

            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percent = (e.loaded / e.total) * 100;
                    const bar = document.getElementById('upload-progress-bar');
                    if (bar) bar.style.width = percent + '%';
                }
            });

            xhr.onload = function() {
                if (xhr.status === 200) {
                        // AUTO-REFRESH après upload réussi
                        console.log("Auto-refresh: tentative de refresh...");
                        setTimeout(function() {
                            if (typeof loadMediaFiles === "function") {
                                console.log("Auto-refresh: appel de loadMediaFiles");
                                loadMediaFiles();
                            }
                            // Forcer affichage section media
                            var mediaSection = document.getElementById("media");
                            if (mediaSection) {
                                mediaSection.classList.add("active");
                                mediaSection.style.display = "block";
                            }
                        }, 800);
                    try {
                        const data = JSON.parse(xhr.responseText);
                        if (data.success) {
                            showAlert('✅ Upload terminé avec succès!', 'success');

                            // Auto-refresh MEDIA après un délai
                            setTimeout(() => {
                                loadMediaFiles();
                                showAlert('📂 Section MEDIA mise à jour', 'info');
                            }, 1000);
                        } else {
                            showAlert('Erreur: ' + data.message, 'error');
                        }
                    } catch (e) {
                        showAlert('Erreur de réponse serveur', 'error');
                    }
                }
                // Retirer la barre de progression
                setTimeout(() => {
                    if (progressDiv.parentNode) {
                        progressDiv.remove();
                    }
                }, 2000);
            };

            xhr.onerror = function() {
                showAlert('Erreur d\'upload', 'error');
                if (progressDiv.parentNode) {
                    progressDiv.remove();
                }
            };

            xhr.open('POST', '/api/upload.php');
            xhr.send(formData);
        }

        // Volume control (ADAPTATIF)
        function setVolume(value) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'volume',
                    value: value,
                    player: currentPlayer
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    console.log(`${currentPlayer.toUpperCase()}: Volume réglé à ${value}%`);
                } else {
                    console.warn(`Erreur volume ${currentPlayer.toUpperCase()}:`, data.message);
                }
            })
            .catch(error => console.error(`Erreur volume ${currentPlayer.toUpperCase()}:`, error));
        }

        // Upload Modal Functions
        function showUploadModal() {
            const modalHTML = `
                <div id="uploadModal" style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 9999;">
                    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #2a2d3a; padding: 30px; border-radius: 10px; width: 500px; max-width: 90%;">
                        <h2 style="margin: 0 0 20px; color: #4a9eff;">📤 Upload de Fichiers</h2>
                        <div style="border: 2px dashed #4a9eff; padding: 40px; text-align: center; margin-bottom: 20px;">
                            <input type="file" id="uploadFiles" multiple accept="video/*,image/*" style="display: none;" onchange="uploadFiles(this.files)">
                            <button class="btn btn-primary" onclick="document.getElementById('uploadFiles').click()">
                                Sélectionner des fichiers
                            </button>
                            <p style="margin: 10px 0; color: #999;">ou glissez-déposez ici</p>
                        </div>
                        <div style="text-align: right;">
                            <button class="btn btn-secondary" onclick="closeUploadModal()">Annuler</button>
                        </div>
                    </div>
                </div>
            `;

            // Remove existing modal if any
            const existingModal = document.getElementById('uploadModal');
            if (existingModal) {
                existingModal.remove();
            }

            // Add new modal
            document.body.insertAdjacentHTML('beforeend', modalHTML);

            // Add drag and drop
            const modal = document.getElementById('uploadModal');
            const dropZone = modal.querySelector('div[style*="border: 2px dashed"]');

            dropZone.addEventListener('dragover', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#fff';
            });

            dropZone.addEventListener('dragleave', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#4a9eff';
            });

            dropZone.addEventListener('drop', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#4a9eff';
                handleFileSelect(e.dataTransfer.files);
            });
        }

        function closeUploadModal() {
            const modal = document.getElementById('uploadModal');
            if (modal) {
                modal.remove();
            }
        }

        function handleFileSelect(files) {
            if (files && files.length > 0) {
                closeUploadModal();
                uploadFiles(files);
            }
        }

        // Fonction pour redémarrer le lecteur actuel
        function restartCurrentPlayer() {
            const player = currentPlayer || 'vlc';
            const playerName = player.toUpperCase();

            showAlert(`Redémarrage de ${playerName}...`, 'info');

            fetch('/api/player.php?action=restart')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert(`${playerName} redémarré avec succès`, 'success');
                        setTimeout(() => {
                            updatePlayerStatus();
                            updatePlayerInterface();
                        }, 2000);
                    } else {
                        showAlert(data.message || 'Erreur lors du redémarrage', 'error');
                    }
                })
                .catch(error => {
                    console.error('Restart player error:', error);
                    showAlert('Erreur de communication', 'error');
                });
        }

        // Fonction pour redémarrer le système
        function restartSystem() {
            if (confirm('Êtes-vous sûr de vouloir redémarrer le système ?')) {
                showAlert('Redémarrage du système...', 'info');

                fetch('/api/system.php?action=restart')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Le système va redémarrer dans 5 secondes...', 'success');
                            document.body.style.opacity = '0.5';
                            document.body.style.pointerEvents = 'none';
                        } else {
                            showAlert(data.message || 'Erreur lors du redémarrage', 'error');
                        }
                    })
                    .catch(error => {
                        console.error('Restart system error:', error);
                        showAlert('Erreur de communication', 'error');
                    });
            }
        }

        // Fonction pour arrêter le système
        function shutdownSystem() {
            if (confirm('Êtes-vous sûr de vouloir arrêter le système ?')) {
                showAlert('Arrêt du système...', 'info');

                fetch('/api/system.php?action=shutdown')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Le système va s\'arrêter dans 5 secondes...', 'success');
                            document.body.style.opacity = '0.5';
                            document.body.style.pointerEvents = 'none';
                        } else {
                            showAlert(data.message || 'Erreur lors de l\'arrêt', 'error');
                        }
                    })
                    .catch(error => {
                        console.error('Shutdown system error:', error);
                        showAlert('Erreur de communication', 'error');
                    });
            }
        }

        // Fonctions pour gérer les playlists
        /* Commented duplicate function
        function loadPlaylistsDuplicate() {
            fetch('/api/playlist.php?action=list')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('playlist-container');
                    if (!container) return;

                    if (data.success && data.playlists) {
                        if (data.playlists.length === 0) {
                            container.innerHTML = '<p style="text-align: center; opacity: 0.6; margin: 20px;">Aucune playlist créée</p>';
                        } else {
                            container.innerHTML = data.playlists.map(playlist => `
                                <div class="card" style="margin-bottom: 15px;">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <div>
                                            <h4 style="margin: 0 0 5px 0;">${playlist.name || 'Playlist sans nom'}</h4>
                                            <p style="margin: 0; opacity: 0.7;">
                                                ${playlist.items ? playlist.items.length : 0} médias
                                            </p>
                                        </div>
                                        <div style="display: flex; gap: 10px;">
                                            <button class="btn btn-primary btn-sm" onclick="playPlaylist('${playlist.id || playlist.name}')">
                                                ▶️ Lire
                                            </button>
                                            <button class="btn btn-glass btn-sm" onclick="editPlaylist('${playlist.id || playlist.name}')">
                                                ✏️ Modifier
                                            </button>
                                            <button class="btn btn-danger btn-sm" onclick="deletePlaylist('${playlist.id || playlist.name}')">
                                                🗑️ Supprimer
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            `).join('');
                        }
                    } else {
                        container.innerHTML = '<p style="text-align: center; color: #ff6b6b; margin: 20px;">Erreur de chargement des playlists</p>';
                    }
                })
                .catch(error => {
                    console.error('Load playlists error:', error);
                    const container = document.getElementById('playlist-container');
                    if (container) {
                        container.innerHTML = '<p style="text-align: center; color: #ff6b6b; margin: 20px;">Erreur de connexion</p>';
                    }
                });
        } */

        function createPlaylist() {
            const name = prompt('Nom de la nouvelle playlist:');
            if (name) {
                fetch('/api/playlist.php?action=create', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({name: name})
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Playlist créée', 'success');
                        loadPlaylists();
                    } else {
                        showAlert(data.message || 'Erreur', 'error');
                    }
                })
                .catch(error => {
                    console.error('Create playlist error:', error);
                    showAlert('Erreur de création', 'error');
                });
            }
        }

        function playPlaylist(id) {
            fetch(`/api/playlist.php?action=play&id=${id}`)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Playlist lancée', 'success');
                    } else {
                        showAlert(data.message || 'Erreur', 'error');
                    }
                });
        }

        function editPlaylist(id) {
            showAlert('Fonction d\'édition en cours de développement', 'info');
        }

        function deletePlaylist(id) {
            if (confirm('Supprimer cette playlist ?')) {
                fetch(`/api/playlist.php?action=delete&id=${id}`)
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert('Playlist supprimée', 'success');
                            loadPlaylists();
                        } else {
                            showAlert(data.message || 'Erreur', 'error');
                        }
                    });
            }
        }

        // Charger les playlists au changement de section
        function showSectionOriginal(section) {
            // Update sections
            document.querySelectorAll('.content-section').forEach(el => {
                el.classList.remove('active');
            });
            const targetSection = document.getElementById(section);
            if (targetSection) {
                targetSection.classList.add('active');
            }

            // Update nav
            document.querySelectorAll('.nav-item').forEach(el => {
                el.classList.remove('active');
            });
            event.target.closest('.nav-item').classList.add('active');

            // Charger les playlists si on va dans cette section
            if (section === 'playlists') {
                loadPlaylists();
            }
        }

        // Charger les playlists au démarrage si on est dans cette section
        document.addEventListener('DOMContentLoaded', function() {
            const activeSection = document.querySelector('.content-section.active');
            if (activeSection && activeSection.id === 'playlists') {
                loadPlaylists();
            }

            // Initialize player controls
            initializePlayer();
        });

        // Advanced Playlist Editor JavaScript
        let currentPlaylist = {
            name: '',
            items: [],
            settings: {
                loop: true,
                shuffle: false,
                auto_advance: true,
                fade_duration: 1000
            }
        };

        let mediaLibrary = [];
        let selectedItem = null;
        let draggedElement = null;
        let playlistModified = false;

        // Initialize playlist editor when section is loaded
        function initPlaylistEditor() {
            loadMediaLibrary();
            resetPlaylistEditor();
            setupEventListeners();
        }

        // Setup event listeners for drag & drop and interactions
        function setupEventListeners() {
            // Drop zone listeners
            const dropZone = document.getElementById('playlist-drop-zone');
            if (dropZone) {
                dropZone.addEventListener('dragover', handleDragOver);
                dropZone.addEventListener('drop', handleDrop);
                dropZone.addEventListener('dragleave', handleDragLeave);
            }

            // Playlist workspace listeners
            const workspace = document.getElementById('playlist-workspace');
            if (workspace) {
                workspace.addEventListener('dragover', handleDragOver);
                workspace.addEventListener('drop', handleDrop);
            }
        }

        // Load media library
        function refreshMediaLibrary() {
            loadMediaLibrary();
        }

        function loadMediaLibrary() {
            fetch('/api/media.php?action=list')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        mediaLibrary = data.data || [];
                        renderMediaLibrary();
                    } else {
                        showAlert('Erreur de chargement des médias', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error loading media library:', error);
                    showAlert('Erreur de connexion aux médias', 'error');
                });
        }

        // Render media library
        function renderMediaLibrary() {
            const container = document.getElementById('media-library-list');
            if (!container) return;

            const searchTerm = document.getElementById('media-search')?.value.toLowerCase() || '';
            const activeFilter = document.querySelector('.filter-btn.active')?.dataset.type || 'all';

            const filteredMedia = mediaLibrary.filter(file => {
                const matchesSearch = !searchTerm || file.name.toLowerCase().includes(searchTerm);
                const matchesFilter = activeFilter === 'all' || getMediaType(file.type) === activeFilter;
                return matchesSearch && matchesFilter;
            });

            container.innerHTML = filteredMedia.map(file => {
                const mediaType = getMediaType(file.type);
                const icon = getMediaIcon(mediaType);
                const duration = file.duration ? formatTime(file.duration) : '';
                const size = file.size_formatted || '';

                return `
                    <div class="media-item" draggable="true" data-file="${file.name}" data-type="${mediaType}">
                        <div class="media-item-icon ${mediaType}">
                            ${icon}
                        </div>
                        <div class="media-item-info">
                            <div class="media-item-name" title="${file.name}">${file.name}</div>
                            <div class="media-item-meta">${duration} ${size}</div>
                        </div>
                        <div class="media-item-actions">
                            <button class="btn-add" onclick="addMediaToPlaylist('${file.name}')" title="Ajouter à la playlist">
                                +
                            </button>
                        </div>
                    </div>
                `;
            }).join('');

            // Add drag listeners to media items
            container.querySelectorAll('.media-item').forEach(item => {
                item.addEventListener('dragstart', handleMediaDragStart);
                item.addEventListener('dragend', handleMediaDragEnd);
            });
        }

        // Get media type from MIME type
        function getMediaType(mimeType) {
            if (mimeType.startsWith('video/')) return 'video';
            if (mimeType.startsWith('audio/')) return 'audio';
            if (mimeType.startsWith('image/')) return 'image';
            return 'file';
        }

        // Get media icon
        function getMediaIcon(type) {
            const icons = {
                video: '🎬',
                audio: '🎵',
                image: '🖼️',
                file: '📄'
            };
            return icons[type] || icons.file;
        }

        // Filter media library
        function filterMediaLibrary() {
            renderMediaLibrary();
        }

        function filterMediaType(type) {
            // Update filter buttons
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.type === type);
            });
            renderMediaLibrary();
        }

        // Drag and drop handlers
        function handleMediaDragStart(e) {
            draggedElement = e.target;
            e.target.classList.add('dragging');
            e.dataTransfer.setData('text/plain', e.target.dataset.file);
            e.dataTransfer.effectAllowed = 'copy';
        }

        function handleMediaDragEnd(e) {
            e.target.classList.remove('dragging');
            draggedElement = null;
        }

        function handleDragOver(e) {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'copy';

            const dropZone = document.getElementById('playlist-drop-zone');
            if (dropZone && !dropZone.classList.contains('hidden')) {
                dropZone.classList.add('drag-over');
            }
        }

        function handleDragLeave(e) {
            const dropZone = document.getElementById('playlist-drop-zone');
            if (dropZone) {
                dropZone.classList.remove('drag-over');
            }
        }

        function handleDrop(e) {
            e.preventDefault();
            const fileName = e.dataTransfer.getData('text/plain');

            const dropZone = document.getElementById('playlist-drop-zone');
            if (dropZone) {
                dropZone.classList.remove('drag-over');
            }

            if (fileName) {
                addMediaToPlaylist(fileName);
            }
        }

        // Add media to playlist
        function addMediaToPlaylist(fileName) {
            const mediaFile = mediaLibrary.find(file => file.name === fileName);
            if (!mediaFile) return;

            const playlistItem = {
                file: fileName,
                duration: getDefaultDuration(mediaFile.type),
                transition: 'none',
                order: currentPlaylist.items.length
            };

            currentPlaylist.items.push(playlistItem);
            renderPlaylistItems();
            updatePlaylistStats();
            setPlaylistModified(true);
            showDropZone(false);
        }

        // Get default duration based on media type
        function getDefaultDuration(mimeType) {
            if (mimeType.startsWith('image/')) return 10;
            if (mimeType.startsWith('video/')) return 30;
            if (mimeType.startsWith('audio/')) return 60;
            return 10;
        }

        // Render playlist items
        function renderPlaylistItems() {
            const container = document.getElementById('playlist-items');
            if (!container) return;

            container.innerHTML = currentPlaylist.items.map((item, index) => {
                const mediaFile = mediaLibrary.find(file => file.name === item.file);
                const mediaType = mediaFile ? getMediaType(mediaFile.type) : 'file';
                const icon = getMediaIcon(mediaType);

                return `
                    <div class="playlist-item" data-index="${index}" onclick="selectPlaylistItem(${index})">
                        <div class="drag-handle" onmousedown="startItemDrag(event, ${index})">⋮⋮</div>
                        <div class="playlist-item-icon ${mediaType}">
                            ${icon}
                        </div>
                        <div class="playlist-item-content">
                            <div class="playlist-item-name" title="${item.file}">${item.file}</div>
                            <div class="playlist-item-details">
                                <span>Durée: ${item.duration}s</span>
                                <span>Transition: ${item.transition}</span>
                                <span>Position: ${index + 1}</span>
                            </div>
                        </div>
                        <div class="playlist-item-actions">
                            <button class="btn btn-sm btn-danger" onclick="removePlaylistItem(${index})" title="Supprimer">
                                🗑️
                            </button>
                        </div>
                    </div>
                `;
            }).join('');

            // Update drop zone visibility
            showDropZone(currentPlaylist.items.length === 0);
        }

        // Show/hide drop zone
        function showDropZone(show) {
            const dropZone = document.getElementById('playlist-drop-zone');
            if (dropZone) {
                dropZone.classList.toggle('hidden', !show);
            }
        }

        // Select playlist item
        function selectPlaylistItem(index) {
            selectedItem = index;

            // Update visual selection
            document.querySelectorAll('.playlist-item').forEach((item, i) => {
                item.classList.toggle('selected', i === index);
            });

            // Update properties panel
            updatePropertiesPanel();
        }

        // Update properties panel
        function updatePropertiesPanel() {
            const propertiesSection = document.getElementById('item-properties');
            if (!propertiesSection) return;

            if (selectedItem !== null && currentPlaylist.items[selectedItem]) {
                const item = currentPlaylist.items[selectedItem];

                document.getElementById('selected-file-name').textContent = item.file;
                document.getElementById('item-duration').value = item.duration;
                document.getElementById('item-transition').value = item.transition;
                document.getElementById('transition-duration').value = currentPlaylist.settings.fade_duration;

                propertiesSection.style.display = 'block';
            } else {
                propertiesSection.style.display = 'none';
            }
        }

        // Remove playlist item
        function removePlaylistItem(index) {
            currentPlaylist.items.splice(index, 1);

            // Update order values
            currentPlaylist.items.forEach((item, i) => {
                item.order = i;
            });

            renderPlaylistItems();
            updatePlaylistStats();
            setPlaylistModified(true);

            // Clear selection if removed item was selected
            if (selectedItem === index) {
                selectedItem = null;
                updatePropertiesPanel();
            } else if (selectedItem > index) {
                selectedItem--;
            }
        }

        // Update item properties
        function updateItemDuration() {
            if (selectedItem !== null && currentPlaylist.items[selectedItem]) {
                const duration = parseInt(document.getElementById('item-duration').value) || 10;
                currentPlaylist.items[selectedItem].duration = Math.max(1, Math.min(3600, duration));
                renderPlaylistItems();
                updatePlaylistStats();
                setPlaylistModified(true);
            }
        }

        function updateItemTransition() {
            if (selectedItem !== null && currentPlaylist.items[selectedItem]) {
                const transition = document.getElementById('item-transition').value;
                currentPlaylist.items[selectedItem].transition = transition;
                renderPlaylistItems();
                setPlaylistModified(true);
            }
        }

        function updateTransitionDuration() {
            const duration = parseInt(document.getElementById('transition-duration').value) || 1000;
            currentPlaylist.settings.fade_duration = Math.max(0, Math.min(5000, duration));
            setPlaylistModified(true);
        }

        // Update playlist settings
        function updatePlaylistSettings() {
            currentPlaylist.settings.loop = document.getElementById('playlist-loop').checked;
            currentPlaylist.settings.shuffle = document.getElementById('playlist-shuffle').checked;
            currentPlaylist.settings.auto_advance = document.getElementById('playlist-auto-advance').checked;
            setPlaylistModified(true);
        }

        function updatePlaylistName() {
            const name = document.getElementById('playlist-name-input').value.trim();
            if (name) {
                currentPlaylist.name = name;
                document.getElementById('playlist-name-display').textContent = name;
                setPlaylistModified(true);
            }
        }

        // Update playlist statistics
        function updatePlaylistStats() {
            const itemCount = currentPlaylist.items.length;
            const totalDuration = currentPlaylist.items.reduce((sum, item) => sum + item.duration, 0);

            document.getElementById('item-count').textContent = `${itemCount} élément${itemCount !== 1 ? 's' : ''}`;
            document.getElementById('total-duration').textContent = formatTime(totalDuration);

            // Enable/disable buttons
            const hasItems = itemCount > 0;
            document.getElementById('preview-btn').disabled = !hasItems;
            document.getElementById('save-playlist-btn').disabled = !hasItems || !currentPlaylist.name;
        }

        // Format time in seconds to MM:SS
        function formatTime(seconds) {
            const mins = Math.floor(seconds / 60);
            const secs = seconds % 60;
            return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        }

        // Playlist management functions
        function createNewPlaylist() {
            if (playlistModified) {
                if (!confirm('Voulez-vous abandonner les modifications actuelles?')) {
                    return;
                }
            }
            resetPlaylistEditor();
        }

        function resetPlaylistEditor() {
            currentPlaylist = {
                name: '',
                items: [],
                settings: {
                    loop: true,
                    shuffle: false,
                    auto_advance: true,
                    fade_duration: 1000
                }
            };

            selectedItem = null;
            setPlaylistModified(false);

            // Update UI
            document.getElementById('playlist-name-input').value = '';
            document.getElementById('playlist-name-display').textContent = 'Nouvelle Playlist';
            document.getElementById('playlist-loop').checked = currentPlaylist.settings.loop;
            document.getElementById('playlist-shuffle').checked = currentPlaylist.settings.shuffle;
            document.getElementById('playlist-auto-advance').checked = currentPlaylist.settings.auto_advance;

            renderPlaylistItems();
            updatePlaylistStats();
            updatePropertiesPanel();
        }

        function setPlaylistModified(modified) {
            playlistModified = modified;
            const saveBtn = document.getElementById('save-playlist-btn');
            if (saveBtn) {
                saveBtn.disabled = !modified || !currentPlaylist.name || currentPlaylist.items.length === 0;
            }
        }

        // Save current playlist
        function saveCurrentPlaylist() {
            if (!currentPlaylist.name) {
                const name = prompt('Nom de la playlist:');
                if (!name) return;
                currentPlaylist.name = name;
                document.getElementById('playlist-name-input').value = name;
                document.getElementById('playlist-name-display').textContent = name;
            }

            if (currentPlaylist.items.length === 0) {
                showAlert('La playlist doit contenir au moins un élément', 'warning');
                return;
            }

            const playlistData = {
                name: currentPlaylist.name,
                items: currentPlaylist.items,
                settings: currentPlaylist.settings
            };

            fetch('/api/playlist-simple.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(playlistData)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Playlist "${currentPlaylist.name}" sauvegardée!`, 'success');
                    setPlaylistModified(false);
                } else {
                    showAlert('Erreur: ' + (data.message || 'Échec de la sauvegarde'), 'error');
                }
            })
            .catch(error => {
                console.error('Save error:', error);
                showAlert('Erreur de connexion lors de la sauvegarde', 'error');
            });
        }

        // Load existing playlist
        function loadExistingPlaylist() {
            fetch('/api/playlist-simple.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const playlists = data.data || [];
                        showLoadPlaylistModal(playlists);
                    } else {
                        showAlert('Erreur de chargement des playlists', 'error');
                    }
                })
                .catch(error => {
                    console.error('Load error:', error);
                    showAlert('Erreur de connexion', 'error');
                });
        }

        function showLoadPlaylistModal(playlists) {
            const modal = document.getElementById('load-playlist-modal');
            const container = document.getElementById('existing-playlists-list');

            if (!modal || !container) return;

            container.innerHTML = playlists.map(playlist => `
                <div class="existing-playlist-item" onclick="loadPlaylistData('${playlist.name}')">
                    <div class="existing-playlist-info">
                        <h4>${playlist.name}</h4>
                        <div class="existing-playlist-meta">
                            ${playlist.items ? playlist.items.length : 0} éléments -
                            Modifié: ${playlist.modified || 'Inconnu'}
                        </div>
                    </div>
                </div>
            `).join('');

            modal.style.display = 'flex';
        }

        function closeLoadPlaylistModal() {
            const modal = document.getElementById('load-playlist-modal');
            if (modal) {
                modal.style.display = 'none';
            }
        }

        function loadPlaylistData(playlistName) {
            if (playlistModified) {
                if (!confirm('Voulez-vous abandonner les modifications actuelles?')) {
                    return;
                }
            }

            fetch('/api/playlist-simple.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const playlist = data.data.find(p => p.name === playlistName);
                        if (playlist) {
                            currentPlaylist = {
                                name: playlist.name,
                                items: playlist.items || [],
                                settings: playlist.settings || {
                                    loop: true,
                                    shuffle: false,
                                    auto_advance: true,
                                    fade_duration: 1000
                                }
                            };

                            // Update UI
                            document.getElementById('playlist-name-input').value = currentPlaylist.name;
                            document.getElementById('playlist-name-display').textContent = currentPlaylist.name;
                            document.getElementById('playlist-loop').checked = currentPlaylist.settings.loop;
                            document.getElementById('playlist-shuffle').checked = currentPlaylist.settings.shuffle;
                            document.getElementById('playlist-auto-advance').checked = currentPlaylist.settings.auto_advance;

                            renderPlaylistItems();
                            updatePlaylistStats();
                            setPlaylistModified(false);
                            closeLoadPlaylistModal();

                            showAlert(`Playlist "${playlistName}" chargée!`, 'success');
                        }
                    }
                })
                .catch(error => {
                    console.error('Load playlist error:', error);
                    showAlert('Erreur de chargement', 'error');
                });
        }

        // Clear playlist
        function clearPlaylist() {
            if (currentPlaylist.items.length === 0) return;

            if (confirm('Voulez-vous vider la playlist?')) {
                currentPlaylist.items = [];
                selectedItem = null;
                renderPlaylistItems();
                updatePlaylistStats();
                updatePropertiesPanel();
                setPlaylistModified(true);
            }
        }

        // Preview playlist
        function previewPlaylist() {
            if (currentPlaylist.items.length === 0) {
                showAlert('Aucun élément à prévisualiser', 'warning');
                return;
            }

            // Create preview data
            const previewData = {
                name: currentPlaylist.name || 'Aperçu',
                items: currentPlaylist.items.map(item => item.file),
                duration: 5 // Short preview duration
            };

            // Show preview info
            const itemNames = currentPlaylist.items.slice(0, 3).map(item => item.file).join(', ');
            const moreText = currentPlaylist.items.length > 3 ? ` et ${currentPlaylist.items.length - 3} autres...` : '';

            showAlert(`Aperçu de la playlist: ${itemNames}${moreText}`, 'info');
        }

        // Item reordering (drag & drop for playlist items)
        let draggedItemIndex = null;

        function startItemDrag(event, index) {
            draggedItemIndex = index;
            const item = event.target.closest('.playlist-item');
            if (item) {
                item.classList.add('dragging');
                item.draggable = true;

                item.addEventListener('dragstart', (e) => {
                    e.dataTransfer.setData('text/plain', index.toString());
                    e.dataTransfer.effectAllowed = 'move';
                });

                item.addEventListener('dragend', () => {
                    item.classList.remove('dragging');
                    item.draggable = false;
                    draggedItemIndex = null;
                });
            }
        }

    </script>
</body>
</html>