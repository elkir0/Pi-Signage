<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.8.0 - Interface Moderne</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --primary-color: #6366f1;
            --primary-dark: #4f46e5;
            --secondary-color: #8b5cf6;
            --accent-color: #06b6d4;
            --success-color: #10b981;
            --warning-color: #f59e0b;
            --error-color: #ef4444;
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-card: rgba(30, 41, 59, 0.9);
            --bg-glass: rgba(255, 255, 255, 0.1);
            --text-primary: #f8fafc;
            --text-secondary: #cbd5e1;
            --text-muted: #64748b;
            --border-color: rgba(148, 163, 184, 0.2);
            --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
            --border-radius: 12px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }

        [data-theme="light"] {
            --bg-primary: #f8fafc;
            --bg-secondary: #ffffff;
            --bg-card: rgba(255, 255, 255, 0.95);
            --bg-glass: rgba(0, 0, 0, 0.1);
            --text-primary: #1e293b;
            --text-secondary: #475569;
            --text-muted: #94a3b8;
            --border-color: rgba(148, 163, 184, 0.3);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
            color: var(--text-primary);
            min-height: 100vh;
            transition: var(--transition);
            overflow-x: hidden;
        }

        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background:
                radial-gradient(circle at 20% 80%, rgba(120, 119, 198, 0.3) 0%, transparent 50%),
                radial-gradient(circle at 80% 20%, rgba(255, 119, 198, 0.3) 0%, transparent 50%),
                radial-gradient(circle at 40% 40%, rgba(120, 219, 255, 0.3) 0%, transparent 50%);
            z-index: -1;
            pointer-events: none;
        }

        /* Custom Scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
        }

        ::-webkit-scrollbar-track {
            background: var(--bg-secondary);
        }

        ::-webkit-scrollbar-thumb {
            background: var(--primary-color);
            border-radius: 4px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: var(--primary-dark);
        }

        /* Header */
        .header {
            background: var(--bg-glass);
            backdrop-filter: blur(20px);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            margin: 20px;
            padding: 20px 30px;
            box-shadow: var(--shadow-xl);
            position: relative;
            overflow: hidden;
        }

        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 2px;
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color), var(--accent-color));
        }

        .header-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .logo-icon {
            width: 50px;
            height: 50px;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            color: white;
            box-shadow: var(--shadow-lg);
        }

        .logo-text {
            display: flex;
            flex-direction: column;
        }

        .logo-title {
            font-size: 28px;
            font-weight: 800;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .logo-version {
            font-size: 14px;
            color: var(--text-muted);
            font-weight: 500;
        }

        .header-controls {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .theme-toggle, .fullscreen-btn {
            width: 40px;
            height: 40px;
            border: none;
            border-radius: 8px;
            background: var(--bg-glass);
            color: var(--text-primary);
            cursor: pointer;
            transition: var(--transition);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }

        .theme-toggle:hover, .fullscreen-btn:hover {
            background: var(--primary-color);
            color: white;
            transform: scale(1.05);
        }

        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: var(--bg-glass);
            border-radius: 20px;
            border: 1px solid var(--border-color);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--success-color);
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        /* Navigation */
        .nav-container {
            margin: 0 20px 20px;
        }

        .nav-tabs {
            display: flex;
            gap: 8px;
            padding: 8px;
            background: var(--bg-glass);
            backdrop-filter: blur(20px);
            border-radius: var(--border-radius);
            border: 1px solid var(--border-color);
            overflow-x: auto;
            scrollbar-width: none;
        }

        .nav-tabs::-webkit-scrollbar {
            display: none;
        }

        .nav-tab {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            background: transparent;
            color: var(--text-secondary);
            cursor: pointer;
            transition: var(--transition);
            white-space: nowrap;
            font-weight: 500;
            font-size: 14px;
            position: relative;
            overflow: hidden;
        }

        .nav-tab::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
            transition: left 0.5s;
        }

        .nav-tab:hover::before {
            left: 100%;
        }

        .nav-tab:hover {
            background: var(--bg-glass);
            color: var(--text-primary);
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .nav-tab.active {
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            color: white;
            box-shadow: var(--shadow-lg);
        }

        .nav-tab i {
            font-size: 16px;
        }

        /* Main Content */
        .main-content {
            margin: 0 20px 20px;
        }

        .tab-content {
            display: none;
            animation: fadeInUp 0.5s ease-out;
        }

        .tab-content.active {
            display: block;
        }

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

        /* Cards */
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }

        .card {
            background: var(--bg-card);
            backdrop-filter: blur(20px);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 24px;
            box-shadow: var(--shadow-lg);
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 1px;
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            opacity: 0;
            transition: var(--transition);
        }

        .card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-xl);
        }

        .card:hover::before {
            opacity: 1;
        }

        .card-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 20px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .card-icon {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 16px;
        }

        .card-title {
            font-size: 18px;
            font-weight: 600;
            color: var(--text-primary);
            margin: 0;
        }

        /* Stats */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 16px;
        }

        .stat-item {
            background: var(--bg-glass);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            text-align: center;
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .stat-item::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 2px;
            background: var(--primary-color);
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }

        .stat-item:hover::before {
            transform: scaleX(1);
        }

        .stat-value {
            font-size: 24px;
            font-weight: 700;
            color: var(--primary-color);
            margin-bottom: 4px;
            font-variant-numeric: tabular-nums;
        }

        .stat-label {
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-weight: 500;
        }

        .stat-trend {
            font-size: 10px;
            margin-top: 4px;
        }

        .trend-up {
            color: var(--success-color);
        }

        .trend-down {
            color: var(--error-color);
        }

        /* Buttons */
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            font-weight: 500;
            font-size: 14px;
            cursor: pointer;
            transition: var(--transition);
            text-decoration: none;
            position: relative;
            overflow: hidden;
            white-space: nowrap;
        }

        .btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
            transition: left 0.5s;
        }

        .btn:hover::before {
            left: 100%;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .btn:active {
            transform: translateY(0);
        }

        .btn-primary {
            background: linear-gradient(135deg, var(--primary-color), var(--primary-dark));
            color: white;
        }

        .btn-secondary {
            background: var(--bg-glass);
            color: var(--text-primary);
            border: 1px solid var(--border-color);
        }

        .btn-success {
            background: linear-gradient(135deg, var(--success-color), #059669);
            color: white;
        }

        .btn-warning {
            background: linear-gradient(135deg, var(--warning-color), #d97706);
            color: white;
        }

        .btn-danger {
            background: linear-gradient(135deg, var(--error-color), #dc2626);
            color: white;
        }

        .btn-sm {
            padding: 8px 16px;
            font-size: 12px;
        }

        .btn-lg {
            padding: 16px 32px;
            font-size: 16px;
        }

        /* Form Elements */
        .form-group {
            margin-bottom: 20px;
        }

        .form-label {
            display: block;
            font-weight: 500;
            color: var(--text-primary);
            margin-bottom: 8px;
            font-size: 14px;
        }

        .form-input {
            width: 100%;
            padding: 12px 16px;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            background: var(--bg-glass);
            color: var(--text-primary);
            font-size: 14px;
            transition: var(--transition);
        }

        .form-input:focus {
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
            background: var(--bg-card);
        }

        .form-input::placeholder {
            color: var(--text-muted);
        }

        /* Media Grid */
        .media-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 16px;
        }

        .media-item {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 16px;
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .media-item:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
        }

        .media-thumbnail {
            width: 100%;
            height: 120px;
            background: var(--bg-glass);
            border-radius: 8px;
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
            color: var(--primary-color);
            position: relative;
            overflow: hidden;
        }

        .media-thumbnail img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            border-radius: 8px;
        }

        .media-info {
            text-align: center;
        }

        .media-name {
            font-weight: 500;
            color: var(--text-primary);
            margin-bottom: 4px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .media-meta {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 12px;
        }

        /* Progress Bar */
        .progress-bar {
            width: 100%;
            height: 8px;
            background: var(--bg-glass);
            border-radius: 4px;
            overflow: hidden;
            margin: 12px 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            border-radius: 4px;
            transition: width 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .progress-fill::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            bottom: 0;
            right: 0;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
            animation: shimmer 2s infinite;
        }

        @keyframes shimmer {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(100%); }
        }

        /* Player Controls */
        .player-controls {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            flex-wrap: wrap;
            margin: 20px 0;
        }

        .player-btn {
            width: 48px;
            height: 48px;
            border: none;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            color: white;
            font-size: 16px;
            cursor: pointer;
            transition: var(--transition);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .player-btn:hover {
            transform: scale(1.1);
            box-shadow: var(--shadow-lg);
        }

        .player-btn.play {
            width: 56px;
            height: 56px;
            font-size: 20px;
        }

        /* Volume Control */
        .volume-control {
            display: flex;
            align-items: center;
            gap: 12px;
            margin: 16px 0;
        }

        .volume-slider {
            flex: 1;
            height: 6px;
            background: var(--bg-glass);
            border-radius: 3px;
            outline: none;
            -webkit-appearance: none;
        }

        .volume-slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            width: 18px;
            height: 18px;
            border-radius: 50%;
            background: var(--primary-color);
            cursor: pointer;
            box-shadow: var(--shadow-md);
        }

        .volume-slider::-moz-range-thumb {
            width: 18px;
            height: 18px;
            border-radius: 50%;
            background: var(--primary-color);
            cursor: pointer;
            border: none;
            box-shadow: var(--shadow-md);
        }

        /* Drag and Drop */
        .drop-zone {
            border: 2px dashed var(--border-color);
            border-radius: var(--border-radius);
            padding: 40px;
            text-align: center;
            background: var(--bg-glass);
            transition: var(--transition);
            cursor: pointer;
        }

        .drop-zone:hover, .drop-zone.dragover {
            border-color: var(--primary-color);
            background: rgba(99, 102, 241, 0.1);
        }

        .drop-zone-icon {
            font-size: 48px;
            color: var(--primary-color);
            margin-bottom: 16px;
        }

        .drop-zone-text {
            color: var(--text-secondary);
            font-weight: 500;
        }

        /* Playlist Builder */
        .playlist-builder {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            min-height: 400px;
        }

        .playlist-section {
            background: var(--bg-glass);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 20px;
        }

        .playlist-section h4 {
            margin-bottom: 16px;
            color: var(--text-primary);
            font-weight: 600;
        }

        .draggable-item {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px;
            margin-bottom: 8px;
            cursor: move;
            transition: var(--transition);
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .draggable-item:hover {
            transform: scale(1.02);
            box-shadow: var(--shadow-md);
        }

        .draggable-item.dragging {
            opacity: 0.5;
            transform: rotate(5deg);
        }

        /* Toast Notifications */
        .toast-container {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .toast {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 16px 20px;
            box-shadow: var(--shadow-xl);
            backdrop-filter: blur(20px);
            min-width: 300px;
            animation: slideInRight 0.3s ease-out;
            position: relative;
            overflow: hidden;
        }

        .toast::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--primary-color);
        }

        .toast.success::before { background: var(--success-color); }
        .toast.warning::before { background: var(--warning-color); }
        .toast.error::before { background: var(--error-color); }

        .toast-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }

        .toast-icon {
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            color: white;
        }

        .toast-close {
            background: none;
            border: none;
            color: var(--text-muted);
            cursor: pointer;
            font-size: 16px;
            margin-left: auto;
        }

        @keyframes slideInRight {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }

        /* Loading States */
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 2px solid rgba(99, 102, 241, 0.2);
            border-radius: 50%;
            border-top-color: var(--primary-color);
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .skeleton {
            background: linear-gradient(90deg,
                rgba(255,255,255,0.1) 25%,
                rgba(255,255,255,0.2) 50%,
                rgba(255,255,255,0.1) 75%);
            background-size: 200% 100%;
            animation: skeleton-loading 2s infinite;
            border-radius: 4px;
        }

        @keyframes skeleton-loading {
            0% { background-position: 200% 0; }
            100% { background-position: -200% 0; }
        }

        /* Modal */
        .modal {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(10px);
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: center;
            opacity: 0;
            visibility: hidden;
            transition: var(--transition);
        }

        .modal.show {
            opacity: 1;
            visibility: visible;
        }

        .modal-content {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 24px;
            max-width: 500px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            transform: scale(0.9);
            transition: var(--transition);
        }

        .modal.show .modal-content {
            transform: scale(1);
        }

        /* Responsive Design */
        @media (max-width: 768px) {
            .header-content {
                flex-direction: column;
                text-align: center;
            }

            .nav-tabs {
                flex-direction: column;
                gap: 4px;
            }

            .grid {
                grid-template-columns: 1fr;
            }

            .playlist-builder {
                grid-template-columns: 1fr;
            }

            .player-controls {
                gap: 8px;
            }

            .player-btn {
                width: 40px;
                height: 40px;
                font-size: 14px;
            }

            .player-btn.play {
                width: 48px;
                height: 48px;
                font-size: 18px;
            }

            .toast {
                min-width: 280px;
                margin: 0 10px;
            }
        }

        /* Utility Classes */
        .hidden { display: none !important; }
        .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
        .text-center { text-align: center; }
        .text-left { text-align: left; }
        .text-right { text-align: right; }
        .flex { display: flex; }
        .flex-col { flex-direction: column; }
        .items-center { align-items: center; }
        .justify-center { justify-content: center; }
        .justify-between { justify-content: space-between; }
        .gap-2 { gap: 8px; }
        .gap-4 { gap: 16px; }
        .mb-4 { margin-bottom: 16px; }
        .mt-4 { margin-top: 16px; }
        .p-4 { padding: 16px; }

        /* Dark mode specific animations */
        [data-theme="dark"] .card {
            background: rgba(30, 41, 59, 0.7);
        }

        [data-theme="dark"] .nav-tab.active {
            box-shadow: 0 0 20px rgba(99, 102, 241, 0.3);
        }

        /* Light mode adjustments */
        [data-theme="light"] .card {
            background: rgba(255, 255, 255, 0.9);
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }

        [data-theme="light"] .nav-tab.active {
            box-shadow: 0 4px 12px rgba(99, 102, 241, 0.2);
        }
    </style>
</head>
<body data-theme="dark">
    <!-- Toast Container -->
    <div class="toast-container" id="toast-container"></div>

    <!-- Header -->
    <header class="header">
        <div class="header-content">
            <div class="logo">
                <div class="logo-icon">
                    <i class="fas fa-tv"></i>
                </div>
                <div class="logo-text">
                    <h1 class="logo-title">PiSignage</h1>
                    <span class="logo-version">v0.8.0 - Interface Moderne</span>
                </div>
            </div>

            <div class="header-controls">
                <div class="status-indicator">
                    <div class="status-dot"></div>
                    <span>En ligne</span>
                </div>
                <button class="theme-toggle" onclick="toggleTheme()" title="Changer de thème">
                    <i class="fas fa-moon" id="theme-icon"></i>
                </button>
                <button class="fullscreen-btn" onclick="toggleFullscreen()" title="Plein écran">
                    <i class="fas fa-expand"></i>
                </button>
            </div>
        </div>
    </header>

    <!-- Navigation -->
    <nav class="nav-container">
        <div class="nav-tabs" id="nav-tabs">
            <button class="nav-tab active" onclick="showTab('dashboard')" data-tab="dashboard">
                <i class="fas fa-chart-line"></i>
                <span>Dashboard</span>
            </button>
            <button class="nav-tab" onclick="showTab('media')" data-tab="media">
                <i class="fas fa-photo-video"></i>
                <span>Médias</span>
            </button>
            <button class="nav-tab" onclick="showTab('playlist')" data-tab="playlist">
                <i class="fas fa-list-ul"></i>
                <span>Playlists</span>
            </button>
            <button class="nav-tab" onclick="showTab('player')" data-tab="player">
                <i class="fas fa-play-circle"></i>
                <span>Lecteur</span>
            </button>
            <button class="nav-tab" onclick="showTab('youtube')" data-tab="youtube">
                <i class="fab fa-youtube"></i>
                <span>YouTube</span>
            </button>
            <button class="nav-tab" onclick="showTab('screenshot')" data-tab="screenshot">
                <i class="fas fa-camera"></i>
                <span>Capture</span>
            </button>
            <button class="nav-tab" onclick="showTab('scheduler')" data-tab="scheduler">
                <i class="fas fa-clock"></i>
                <span>Programmation</span>
            </button>
            <button class="nav-tab" onclick="showTab('settings')" data-tab="settings">
                <i class="fas fa-cog"></i>
                <span>Paramètres</span>
            </button>
        </div>
    </nav>

    <!-- Main Content -->
    <main class="main-content">
        <!-- Dashboard Tab -->
        <div id="dashboard-tab" class="tab-content active">
            <div class="grid">
                <!-- System Stats -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-server"></i>
                        </div>
                        <h3 class="card-title">Performances Système</h3>
                    </div>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-value" id="cpu-usage">--</div>
                            <div class="stat-label">CPU</div>
                            <div class="stat-trend trend-up" id="cpu-trend">
                                <i class="fas fa-arrow-up"></i> +2%
                            </div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="memory-usage">--</div>
                            <div class="stat-label">RAM</div>
                            <div class="stat-trend trend-down" id="memory-trend">
                                <i class="fas fa-arrow-down"></i> -1%
                            </div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="temperature">--</div>
                            <div class="stat-label">Température</div>
                            <div class="stat-trend" id="temp-trend">
                                <i class="fas fa-thermometer-half"></i>
                            </div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="uptime">--</div>
                            <div class="stat-label">Uptime</div>
                        </div>
                    </div>
                </div>

                <!-- VLC Player Status -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-play"></i>
                        </div>
                        <h3 class="card-title">Lecteur VLC</h3>
                    </div>
                    <div class="mb-4">
                        <div class="flex items-center gap-2 mb-2">
                            <span class="text-muted">État:</span>
                            <span id="vlc-state" class="font-weight-500">Arrêté</span>
                        </div>
                        <div class="flex items-center gap-2 mb-2">
                            <span class="text-muted">Fichier:</span>
                            <span id="vlc-file" class="font-weight-500">Aucun</span>
                        </div>
                        <div class="flex items-center gap-2">
                            <span class="text-muted">Position:</span>
                            <span id="vlc-position" class="font-weight-500">00:00</span>
                        </div>
                    </div>
                    <div class="player-controls">
                        <button class="player-btn play" onclick="vlcControl('play')" title="Lecture">
                            <i class="fas fa-play"></i>
                        </button>
                        <button class="player-btn" onclick="vlcControl('pause')" title="Pause">
                            <i class="fas fa-pause"></i>
                        </button>
                        <button class="player-btn" onclick="vlcControl('stop')" title="Arrêt">
                            <i class="fas fa-stop"></i>
                        </button>
                    </div>
                </div>

                <!-- Quick Stats -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-chart-pie"></i>
                        </div>
                        <h3 class="card-title">Statistiques Rapides</h3>
                    </div>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-value" id="media-count">--</div>
                            <div class="stat-label">Fichiers</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="playlist-count">--</div>
                            <div class="stat-label">Playlists</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="storage-usage">--</div>
                            <div class="stat-label">Stockage</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="last-screenshot">--</div>
                            <div class="stat-label">Dernière capture</div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-bolt"></i>
                    </div>
                    <h3 class="card-title">Actions Rapides</h3>
                </div>
                <div class="flex gap-4 flex-wrap">
                    <button class="btn btn-primary" onclick="takeScreenshot()">
                        <i class="fas fa-camera"></i>
                        Capture d'écran
                    </button>
                    <button class="btn btn-secondary" onclick="refreshMediaList()">
                        <i class="fas fa-sync"></i>
                        Actualiser médias
                    </button>
                    <button class="btn btn-secondary" onclick="showTab('media')">
                        <i class="fas fa-upload"></i>
                        Uploader fichier
                    </button>
                    <button class="btn btn-secondary" onclick="showTab('youtube')">
                        <i class="fab fa-youtube"></i>
                        Télécharger YouTube
                    </button>
                </div>
            </div>
        </div>

        <!-- Media Management Tab -->
        <div id="media-tab" class="tab-content">
            <div class="grid">
                <!-- File Upload -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-cloud-upload-alt"></i>
                        </div>
                        <h3 class="card-title">Upload de Fichiers</h3>
                    </div>

                    <div class="drop-zone" id="dropZone" onclick="document.getElementById('fileInput').click()">
                        <div class="drop-zone-icon">
                            <i class="fas fa-cloud-upload-alt"></i>
                        </div>
                        <div class="drop-zone-text">
                            <strong>Cliquez pour sélectionner</strong> ou glissez-déposez vos fichiers ici
                        </div>
                        <div class="text-muted mt-2">
                            Formats supportés: MP4, AVI, MOV, JPG, PNG, MP3, WAV
                        </div>
                    </div>

                    <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" class="hidden">

                    <div id="upload-progress" class="hidden">
                        <div class="progress-bar">
                            <div class="progress-fill" id="upload-progress-bar"></div>
                        </div>
                        <div class="text-center mt-2">
                            <span id="upload-status">Upload en cours...</span>
                            <span id="upload-percent">0%</span>
                        </div>
                    </div>

                    <div class="flex gap-2 mt-4">
                        <button class="btn btn-primary" onclick="uploadFiles()">
                            <i class="fas fa-upload"></i>
                            Uploader
                        </button>
                        <button class="btn btn-secondary" onclick="clearFileSelection()">
                            <i class="fas fa-times"></i>
                            Annuler
                        </button>
                    </div>
                </div>

                <!-- Media Filters -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-filter"></i>
                        </div>
                        <h3 class="card-title">Filtres</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Type de fichier</label>
                        <select class="form-input" id="media-filter" onchange="filterMedia()">
                            <option value="">Tous les fichiers</option>
                            <option value="video">Vidéos</option>
                            <option value="image">Images</option>
                            <option value="audio">Audio</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Recherche</label>
                        <input type="text" class="form-input" id="media-search" placeholder="Rechercher un fichier..." oninput="searchMedia()">
                    </div>

                    <button class="btn btn-secondary" onclick="refreshMediaList()">
                        <i class="fas fa-sync"></i>
                        Actualiser la liste
                    </button>
                </div>
            </div>

            <!-- Media List -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-folder-open"></i>
                    </div>
                    <h3 class="card-title">Bibliothèque Médias</h3>
                </div>
                <div id="media-list" class="media-grid">
                    <!-- Media items will be loaded here -->
                    <div class="media-item skeleton" style="height: 200px;"></div>
                    <div class="media-item skeleton" style="height: 200px;"></div>
                    <div class="media-item skeleton" style="height: 200px;"></div>
                </div>
            </div>
        </div>

        <!-- Playlist Tab -->
        <div id="playlist-tab" class="tab-content">
            <div class="grid">
                <!-- Playlist Creator -->
                <div class="card" style="grid-column: 1 / -1;">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-plus-circle"></i>
                        </div>
                        <h3 class="card-title">Créateur de Playlist</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Nom de la playlist</label>
                        <input type="text" class="form-input" id="playlist-name" placeholder="Ma nouvelle playlist">
                    </div>

                    <div class="playlist-builder">
                        <div class="playlist-section">
                            <h4><i class="fas fa-folder-open"></i> Médias Disponibles</h4>
                            <div id="available-media-list">
                                <!-- Available media items -->
                            </div>
                        </div>

                        <div class="playlist-section">
                            <h4><i class="fas fa-list-ol"></i> Playlist (Glissez-déposez)</h4>
                            <div id="playlist-items-list" class="min-height-200">
                                <div class="text-center text-muted p-4">
                                    Glissez des médias ici pour créer votre playlist
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="flex gap-2 mt-4">
                        <button class="btn btn-primary" onclick="savePlaylist()">
                            <i class="fas fa-save"></i>
                            Sauvegarder
                        </button>
                        <button class="btn btn-secondary" onclick="clearPlaylist()">
                            <i class="fas fa-trash"></i>
                            Vider
                        </button>
                        <button class="btn btn-secondary" onclick="previewPlaylist()">
                            <i class="fas fa-eye"></i>
                            Aperçu
                        </button>
                    </div>
                </div>
            </div>

            <!-- Existing Playlists -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-list"></i>
                    </div>
                    <h3 class="card-title">Playlists Existantes</h3>
                </div>
                <div id="playlists-list">
                    <!-- Existing playlists will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Player Tab -->
        <div id="player-tab" class="tab-content">
            <div class="grid">
                <!-- Main Player Controls -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-play-circle"></i>
                        </div>
                        <h3 class="card-title">Contrôles Lecteur</h3>
                    </div>

                    <div class="player-controls">
                        <button class="player-btn" onclick="vlcControl('previous')" title="Précédent">
                            <i class="fas fa-backward"></i>
                        </button>
                        <button class="player-btn play" onclick="vlcControl('play')" title="Lecture">
                            <i class="fas fa-play"></i>
                        </button>
                        <button class="player-btn" onclick="vlcControl('pause')" title="Pause">
                            <i class="fas fa-pause"></i>
                        </button>
                        <button class="player-btn" onclick="vlcControl('stop')" title="Arrêt">
                            <i class="fas fa-stop"></i>
                        </button>
                        <button class="player-btn" onclick="vlcControl('next')" title="Suivant">
                            <i class="fas fa-forward"></i>
                        </button>
                    </div>

                    <div class="volume-control">
                        <i class="fas fa-volume-down"></i>
                        <input type="range" class="volume-slider" id="volume-control" min="0" max="100" value="50" onchange="setVolume(this.value)">
                        <i class="fas fa-volume-up"></i>
                        <span id="volume-display">50%</span>
                    </div>

                    <div class="progress-bar">
                        <div class="progress-fill" id="player-progress"></div>
                    </div>

                    <div class="text-center mt-4">
                        <div id="now-playing" class="text-muted">Aucun média en lecture</div>
                        <div id="time-display" class="text-sm text-muted">00:00 / 00:00</div>
                    </div>
                </div>

                <!-- Playlist Player -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-list-ul"></i>
                        </div>
                        <h3 class="card-title">Lecture de Playlist</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Sélectionner une playlist</label>
                        <select class="form-input" id="playlist-select">
                            <option value="">-- Choisir une playlist --</option>
                        </select>
                    </div>

                    <div class="flex gap-2">
                        <button class="btn btn-primary" onclick="playPlaylist()">
                            <i class="fas fa-play"></i>
                            Lancer la playlist
                        </button>
                        <button class="btn btn-secondary" onclick="shufflePlaylist()">
                            <i class="fas fa-random"></i>
                            Lecture aléatoire
                        </button>
                    </div>
                </div>

                <!-- Single File Player -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-file-video"></i>
                        </div>
                        <h3 class="card-title">Lecture de Fichier</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Sélectionner un fichier</label>
                        <select class="form-input" id="single-file-select">
                            <option value="">-- Choisir un fichier --</option>
                        </select>
                    </div>

                    <div class="flex gap-2">
                        <button class="btn btn-primary" onclick="playSingleFile()">
                            <i class="fas fa-play"></i>
                            Lancer le fichier
                        </button>
                        <button class="btn btn-secondary" onclick="previewFile()">
                            <i class="fas fa-eye"></i>
                            Aperçu
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- YouTube Tab -->
        <div id="youtube-tab" class="tab-content">
            <div class="grid">
                <!-- YouTube Downloader -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fab fa-youtube"></i>
                        </div>
                        <h3 class="card-title">Téléchargeur YouTube</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">URL YouTube</label>
                        <input type="url" class="form-input" id="youtube-url" placeholder="https://www.youtube.com/watch?v=...">
                    </div>

                    <div class="grid" style="grid-template-columns: 1fr 1fr;">
                        <div class="form-group">
                            <label class="form-label">Qualité vidéo</label>
                            <select class="form-input" id="download-quality">
                                <option value="best">Meilleure qualité</option>
                                <option value="1080p">1080p (Full HD)</option>
                                <option value="720p">720p (HD)</option>
                                <option value="480p">480p</option>
                                <option value="360p">360p</option>
                                <option value="worst">Plus petite taille</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Format</label>
                            <select class="form-input" id="download-format">
                                <option value="mp4">MP4 (Vidéo)</option>
                                <option value="mp3">MP3 (Audio seulement)</option>
                                <option value="webm">WebM</option>
                            </select>
                        </div>
                    </div>

                    <div class="flex gap-2">
                        <button class="btn btn-primary" onclick="downloadYoutube()">
                            <i class="fas fa-download"></i>
                            Télécharger
                        </button>
                        <button class="btn btn-secondary" onclick="previewYoutube()">
                            <i class="fas fa-eye"></i>
                            Aperçu
                        </button>
                    </div>

                    <div id="download-progress" class="hidden">
                        <div class="progress-bar">
                            <div class="progress-fill" id="youtube-progress-bar"></div>
                        </div>
                        <div class="text-center mt-2">
                            <span id="download-status">Téléchargement en cours...</span>
                            <span id="download-percent">0%</span>
                        </div>
                    </div>
                </div>

                <!-- YouTube History -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-history"></i>
                        </div>
                        <h3 class="card-title">Historique des Téléchargements</h3>
                    </div>
                    <div id="youtube-history">
                        <!-- Download history will be loaded here -->
                    </div>
                </div>
            </div>
        </div>

        <!-- Screenshot Tab -->
        <div id="screenshot-tab" class="tab-content">
            <div class="grid">
                <!-- Screenshot Capture -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-camera"></i>
                        </div>
                        <h3 class="card-title">Capture d'Écran</h3>
                    </div>

                    <div class="text-center mb-4">
                        <div id="screenshot-display-container" class="mb-4">
                            <img id="screenshot-display" class="hidden" style="max-width: 100%; border-radius: 8px; box-shadow: var(--shadow-lg);">
                            <div id="screenshot-placeholder" class="bg-glass" style="height: 200px; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: var(--text-muted);">
                                <div>
                                    <i class="fas fa-camera" style="font-size: 48px; margin-bottom: 16px;"></i>
                                    <div>Aucune capture disponible</div>
                                </div>
                            </div>
                        </div>

                        <div class="flex gap-2 justify-center flex-wrap">
                            <button class="btn btn-primary" onclick="takeScreenshot()">
                                <i class="fas fa-camera"></i>
                                Capturer maintenant
                            </button>
                            <button class="btn btn-secondary" onclick="toggleAutoScreenshot()" id="auto-screenshot-btn">
                                <i class="fas fa-clock"></i>
                                Auto-capture (OFF)
                            </button>
                            <button class="btn btn-secondary" onclick="downloadScreenshot()">
                                <i class="fas fa-download"></i>
                                Télécharger
                            </button>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Intervalle auto-capture (secondes)</label>
                        <input type="range" class="volume-slider" id="auto-interval" min="5" max="300" value="30" onchange="updateIntervalDisplay()">
                        <div class="text-center mt-2">
                            <span id="interval-display">30 secondes</span>
                        </div>
                    </div>
                </div>

                <!-- Screenshot Settings -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-cog"></i>
                        </div>
                        <h3 class="card-title">Paramètres de Capture</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Qualité de capture</label>
                        <select class="form-input" id="screenshot-quality">
                            <option value="high">Haute qualité</option>
                            <option value="medium" selected>Qualité moyenne</option>
                            <option value="low">Qualité réduite</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Format d'image</label>
                        <select class="form-input" id="screenshot-format">
                            <option value="png">PNG (Sans perte)</option>
                            <option value="jpg" selected>JPG (Compressé)</option>
                            <option value="webp">WebP (Moderne)</option>
                        </select>
                    </div>

                    <button class="btn btn-secondary" onclick="saveScreenshotSettings()">
                        <i class="fas fa-save"></i>
                        Sauvegarder paramètres
                    </button>
                </div>
            </div>

            <!-- Screenshot History -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-images"></i>
                    </div>
                    <h3 class="card-title">Galerie des Captures</h3>
                </div>
                <div id="screenshot-history" class="media-grid">
                    <!-- Screenshot history will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Scheduler Tab -->
        <div id="scheduler-tab" class="tab-content">
            <div class="grid">
                <!-- Schedule Creator -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-calendar-plus"></i>
                        </div>
                        <h3 class="card-title">Nouveau Programme</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Nom du programme</label>
                        <input type="text" class="form-input" id="schedule-name" placeholder="Programme du matin">
                    </div>

                    <div class="grid" style="grid-template-columns: 1fr 1fr;">
                        <div class="form-group">
                            <label class="form-label">Playlist</label>
                            <select class="form-input" id="schedule-playlist">
                                <option value="">-- Choisir une playlist --</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Type de programmation</label>
                            <select class="form-input" id="schedule-type">
                                <option value="daily">Quotidien</option>
                                <option value="weekly">Hebdomadaire</option>
                                <option value="monthly">Mensuel</option>
                                <option value="once">Une fois</option>
                            </select>
                        </div>
                    </div>

                    <div class="grid" style="grid-template-columns: 1fr 1fr;">
                        <div class="form-group">
                            <label class="form-label">Heure de début</label>
                            <input type="time" class="form-input" id="schedule-start">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Heure de fin</label>
                            <input type="time" class="form-input" id="schedule-end">
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Jours de la semaine</label>
                        <div class="flex gap-2 flex-wrap">
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="1"> Lundi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="2"> Mardi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="3"> Mercredi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="4"> Jeudi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="5"> Vendredi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="6"> Samedi
                            </label>
                            <label class="flex items-center gap-1">
                                <input type="checkbox" value="0"> Dimanche
                            </label>
                        </div>
                    </div>

                    <div class="flex gap-2">
                        <button class="btn btn-primary" onclick="saveSchedule()">
                            <i class="fas fa-save"></i>
                            Sauvegarder
                        </button>
                        <button class="btn btn-secondary" onclick="clearScheduleForm()">
                            <i class="fas fa-times"></i>
                            Annuler
                        </button>
                    </div>
                </div>

                <!-- Calendar View -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-calendar"></i>
                        </div>
                        <h3 class="card-title">Vue Calendrier</h3>
                    </div>
                    <div id="calendar-view">
                        <!-- Simple calendar view will be here -->
                        <div class="text-center text-muted p-4">
                            Calendrier interactif (à implémenter)
                        </div>
                    </div>
                </div>
            </div>

            <!-- Active Schedules -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-list-alt"></i>
                    </div>
                    <h3 class="card-title">Programmes Actifs</h3>
                </div>
                <div id="schedules-list">
                    <!-- Active schedules will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Settings Tab -->
        <div id="settings-tab" class="tab-content">
            <div class="grid">
                <!-- Display Settings -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-desktop"></i>
                        </div>
                        <h3 class="card-title">Paramètres d'Affichage</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Résolution</label>
                        <select class="form-input" id="resolution">
                            <option value="1920x1080">1920x1080 (Full HD)</option>
                            <option value="1280x720">1280x720 (HD)</option>
                            <option value="1024x768">1024x768</option>
                            <option value="800x600">800x600</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Rotation de l'écran</label>
                        <select class="form-input" id="rotation">
                            <option value="0">0° (Normal)</option>
                            <option value="90">90° (Droite)</option>
                            <option value="180">180° (Inversé)</option>
                            <option value="270">270° (Gauche)</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Mode d'affichage</label>
                        <select class="form-input" id="display-mode">
                            <option value="fullscreen">Plein écran</option>
                            <option value="windowed">Fenêtré</option>
                            <option value="borderless">Sans bordures</option>
                        </select>
                    </div>

                    <button class="btn btn-primary" onclick="saveDisplayConfig()">
                        <i class="fas fa-save"></i>
                        Appliquer les paramètres
                    </button>
                </div>

                <!-- Audio Settings -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-volume-up"></i>
                        </div>
                        <h3 class="card-title">Paramètres Audio</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Sortie audio</label>
                        <select class="form-input" id="audio-output">
                            <option value="auto">Automatique</option>
                            <option value="hdmi">HDMI</option>
                            <option value="jack">Jack 3.5mm</option>
                            <option value="usb">USB</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Volume par défaut</label>
                        <input type="range" class="volume-slider" id="default-volume" min="0" max="100" value="50" onchange="updateVolumeDisplay()">
                        <div class="text-center mt-2">
                            <span id="volume-display">50%</span>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label">
                            <input type="checkbox" id="auto-mute">
                            Couper le son automatiquement la nuit
                        </label>
                    </div>

                    <button class="btn btn-primary" onclick="saveAudioConfig()">
                        <i class="fas fa-save"></i>
                        Sauvegarder paramètres
                    </button>
                </div>

                <!-- Network Settings -->
                <div class="card">
                    <div class="card-header">
                        <div class="card-icon">
                            <i class="fas fa-wifi"></i>
                        </div>
                        <h3 class="card-title">Paramètres Réseau</h3>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Nom d'hôte</label>
                        <input type="text" class="form-input" id="hostname" placeholder="pisignage">
                    </div>

                    <div class="form-group">
                        <label class="form-label">Fuseau horaire</label>
                        <select class="form-input" id="timezone">
                            <option value="Europe/Paris">Europe/Paris</option>
                            <option value="Europe/London">Europe/London</option>
                            <option value="America/New_York">America/New_York</option>
                            <option value="America/Los_Angeles">America/Los_Angeles</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">
                            <input type="checkbox" id="auto-update">
                            Mise à jour automatique
                        </label>
                    </div>

                    <button class="btn btn-primary" onclick="saveNetworkConfig()">
                        <i class="fas fa-save"></i>
                        Sauvegarder
                    </button>
                </div>
            </div>

            <!-- System Actions -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-tools"></i>
                    </div>
                    <h3 class="card-title">Actions Système</h3>
                </div>

                <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                    <button class="btn btn-secondary" onclick="systemAction('restart-vlc')">
                        <i class="fas fa-play-circle"></i>
                        Redémarrer VLC
                    </button>
                    <button class="btn btn-secondary" onclick="systemAction('clear-cache')">
                        <i class="fas fa-trash"></i>
                        Vider le cache
                    </button>
                    <button class="btn btn-secondary" onclick="systemAction('update-system')">
                        <i class="fas fa-sync"></i>
                        Mettre à jour
                    </button>
                    <button class="btn btn-warning" onclick="systemAction('reboot')">
                        <i class="fas fa-redo"></i>
                        Redémarrer
                    </button>
                    <button class="btn btn-danger" onclick="systemAction('shutdown')">
                        <i class="fas fa-power-off"></i>
                        Éteindre
                    </button>
                </div>
            </div>

            <!-- System Information -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">
                        <i class="fas fa-info-circle"></i>
                    </div>
                    <h3 class="card-title">Informations Système</h3>
                </div>
                <div id="system-info">
                    <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                        <div class="stat-item">
                            <div class="stat-value">v0.8.0</div>
                            <div class="stat-label">Version PiSignage</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="os-version">--</div>
                            <div class="stat-label">Système d'exploitation</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="kernel-version">--</div>
                            <div class="stat-label">Noyau</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="ip-address">--</div>
                            <div class="stat-label">Adresse IP</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <!-- File Preview Modal -->
    <div class="modal" id="preview-modal">
        <div class="modal-content">
            <div class="flex justify-between items-center mb-4">
                <h3>Aperçu du fichier</h3>
                <button class="btn btn-secondary" onclick="closeModal('preview-modal')">
                    <i class="fas fa-times"></i>
                </button>
            </div>
            <div id="preview-content">
                <!-- Preview content will be loaded here -->
            </div>
        </div>
    </div>

    <script>
        // Global Variables
        let currentTheme = 'dark';
        let autoScreenshotInterval = null;
        let systemStatsInterval = null;
        let isFullscreen = false;
        let draggedElement = null;

        // Initialize Application
        document.addEventListener('DOMContentLoaded', function() {
            initializeApp();
            setupEventListeners();
            startSystemMonitoring();
        });

        function initializeApp() {
            // Load initial data
            loadSystemStats();
            refreshMediaList();
            refreshPlaylists();
            loadPlaylistsForSelects();
            updateThemeIcon();

            // Setup drag and drop
            setupDragAndDrop();

            // Load saved settings
            loadSavedSettings();
        }

        function setupEventListeners() {
            // File input change
            document.getElementById('fileInput').addEventListener('change', handleFileSelection);

            // Drag and drop for file upload
            const dropZone = document.getElementById('dropZone');
            dropZone.addEventListener('dragover', handleDragOver);
            dropZone.addEventListener('drop', handleFileDrop);
            dropZone.addEventListener('dragenter', handleDragEnter);
            dropZone.addEventListener('dragleave', handleDragLeave);

            // Keyboard shortcuts
            document.addEventListener('keydown', handleKeyboardShortcuts);

            // Window resize
            window.addEventListener('resize', handleWindowResize);
        }

        // Theme Management
        function toggleTheme() {
            currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
            document.body.setAttribute('data-theme', currentTheme);
            updateThemeIcon();
            localStorage.setItem('pisignage-theme', currentTheme);
        }

        function updateThemeIcon() {
            const icon = document.getElementById('theme-icon');
            icon.className = currentTheme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
        }

        // Fullscreen Management
        function toggleFullscreen() {
            if (!isFullscreen) {
                if (document.documentElement.requestFullscreen) {
                    document.documentElement.requestFullscreen();
                }
            } else {
                if (document.exitFullscreen) {
                    document.exitFullscreen();
                }
            }
        }

        document.addEventListener('fullscreenchange', function() {
            isFullscreen = !!document.fullscreenElement;
            const icon = document.querySelector('.fullscreen-btn i');
            icon.className = isFullscreen ? 'fas fa-compress' : 'fas fa-expand';
        });

        // Tab Management
        function showTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });

            // Remove active from nav tabs
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });

            // Show selected tab
            document.getElementById(tabName + '-tab').classList.add('active');
            document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

            // Load tab-specific data
            loadTabData(tabName);
        }

        function loadTabData(tabName) {
            switch(tabName) {
                case 'media':
                    refreshMediaList();
                    break;
                case 'playlist':
                    refreshPlaylists();
                    updateAvailableMediaList();
                    break;
                case 'player':
                    loadPlaylistsForSelects();
                    loadMediaForSelects();
                    break;
                case 'screenshot':
                    loadScreenshotHistory();
                    break;
                case 'scheduler':
                    refreshSchedules();
                    break;
                case 'settings':
                    loadSystemInfo();
                    break;
            }
        }

        // Toast Notifications
        function showToast(message, type = 'info', duration = 5000) {
            const toastContainer = document.getElementById('toast-container');
            const toast = document.createElement('div');
            toast.className = `toast ${type}`;

            const icons = {
                success: 'fas fa-check',
                warning: 'fas fa-exclamation-triangle',
                error: 'fas fa-times',
                info: 'fas fa-info'
            };

            toast.innerHTML = `
                <div class="toast-header">
                    <div class="toast-icon" style="background: var(--${type}-color);">
                        <i class="${icons[type]}"></i>
                    </div>
                    <strong>${type.charAt(0).toUpperCase() + type.slice(1)}</strong>
                    <button class="toast-close" onclick="this.parentElement.parentElement.remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div>${message}</div>
            `;

            toastContainer.appendChild(toast);

            // Auto remove after duration
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.remove();
                }
            }, duration);
        }

        // System Monitoring
        function startSystemMonitoring() {
            systemStatsInterval = setInterval(loadSystemStats, 5000);
        }

        async function loadSystemStats() {
            try {
                const response = await fetch('/api/system.php');
                const data = await response.json();

                if (data.success) {
                    updateSystemStats(data.data);
                }
            } catch (error) {
                console.error('Error loading system stats:', error);
            }
        }

        function updateSystemStats(stats) {
            // Update CPU
            const cpuElement = document.getElementById('cpu-usage');
            if (cpuElement) {
                cpuElement.textContent = stats.cpu + '%';
                updateTrend('cpu-trend', stats.cpu, parseInt(cpuElement.dataset.previous || '0'));
                cpuElement.dataset.previous = stats.cpu;
            }

            // Update Memory
            const memoryElement = document.getElementById('memory-usage');
            if (memoryElement) {
                memoryElement.textContent = stats.memory + '%';
                updateTrend('memory-trend', stats.memory, parseInt(memoryElement.dataset.previous || '0'));
                memoryElement.dataset.previous = stats.memory;
            }

            // Update Temperature
            const tempElement = document.getElementById('temperature');
            if (tempElement) {
                tempElement.textContent = stats.temperature + '°C';
            }

            // Update Uptime
            const uptimeElement = document.getElementById('uptime');
            if (uptimeElement) {
                uptimeElement.textContent = stats.uptime;
            }

            // Update other stats
            updateElementIfExists('media-count', stats.media_count);
            updateElementIfExists('storage-usage', stats.storage);
        }

        function updateTrend(elementId, current, previous) {
            const element = document.getElementById(elementId);
            if (!element) return;

            const diff = current - previous;
            if (diff > 0) {
                element.className = 'stat-trend trend-up';
                element.innerHTML = `<i class="fas fa-arrow-up"></i> +${diff}%`;
            } else if (diff < 0) {
                element.className = 'stat-trend trend-down';
                element.innerHTML = `<i class="fas fa-arrow-down"></i> ${diff}%`;
            } else {
                element.className = 'stat-trend';
                element.innerHTML = `<i class="fas fa-minus"></i> 0%`;
            }
        }

        function updateElementIfExists(id, value) {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value;
            }
        }

        // File Management
        function handleFileSelection(event) {
            const files = event.target.files;
            displaySelectedFiles(files);
        }

        function displaySelectedFiles(files) {
            const dropZone = document.getElementById('dropZone');
            const fileList = document.createElement('div');
            fileList.className = 'selected-files mt-4';

            fileList.innerHTML = '<h5>Fichiers sélectionnés:</h5>';

            Array.from(files).forEach(file => {
                const fileItem = document.createElement('div');
                fileItem.className = 'flex items-center gap-2 p-2 bg-glass rounded mt-2';
                fileItem.innerHTML = `
                    <i class="${getFileIcon(file.type)}"></i>
                    <span>${file.name}</span>
                    <span class="text-muted">(${formatFileSize(file.size)})</span>
                `;
                fileList.appendChild(fileItem);
            });

            // Remove previous file list
            const existing = dropZone.querySelector('.selected-files');
            if (existing) existing.remove();

            dropZone.appendChild(fileList);
        }

        function clearFileSelection() {
            document.getElementById('fileInput').value = '';
            const dropZone = document.getElementById('dropZone');
            const fileList = dropZone.querySelector('.selected-files');
            if (fileList) fileList.remove();
        }

        // Drag and Drop
        function handleDragOver(e) {
            e.preventDefault();
        }

        function handleDragEnter(e) {
            e.preventDefault();
            e.target.classList.add('dragover');
        }

        function handleDragLeave(e) {
            e.preventDefault();
            e.target.classList.remove('dragover');
        }

        function handleFileDrop(e) {
            e.preventDefault();
            e.target.classList.remove('dragover');

            const files = e.dataTransfer.files;
            document.getElementById('fileInput').files = files;
            displaySelectedFiles(files);
        }

        function setupDragAndDrop() {
            // Setup playlist drag and drop
            const playlistItemsList = document.getElementById('playlist-items-list');

            playlistItemsList.addEventListener('dragover', function(e) {
                e.preventDefault();
            });

            playlistItemsList.addEventListener('drop', function(e) {
                e.preventDefault();
                const filename = e.dataTransfer.getData('text/plain');
                addToPlaylist(filename);
            });
        }

        // Media Management
        async function refreshMediaList() {
            try {
                const response = await fetch('/api/media.php?action=list');
                const data = await response.json();

                if (data.success) {
                    displayMediaList(data.data);
                    updateAvailableMediaList(data.data);
                } else {
                    showToast('Erreur lors du chargement des médias', 'error');
                }
            } catch (error) {
                console.error('Error loading media:', error);
                showToast('Erreur de connexion', 'error');
            }
        }

        function displayMediaList(mediaFiles) {
            const mediaList = document.getElementById('media-list');
            mediaList.innerHTML = '';

            if (mediaFiles.length === 0) {
                mediaList.innerHTML = `
                    <div class="text-center text-muted p-4" style="grid-column: 1 / -1;">
                        <i class="fas fa-folder-open" style="font-size: 48px; margin-bottom: 16px;"></i>
                        <div>Aucun fichier média trouvé</div>
                        <div class="mt-2">Uploadez vos premiers fichiers pour commencer</div>
                    </div>
                `;
                return;
            }

            mediaFiles.forEach(file => {
                const mediaItem = document.createElement('div');
                mediaItem.className = 'media-item';

                const iconClass = getFileIconClass(file.type);
                const fileSize = formatFileSize(file.size);

                mediaItem.innerHTML = `
                    <div class="media-thumbnail">
                        ${file.thumbnail ?
                            `<img src="${file.thumbnail}" alt="${file.name}">` :
                            `<i class="${iconClass}"></i>`
                        }
                    </div>
                    <div class="media-info">
                        <div class="media-name" title="${file.name}">${file.name}</div>
                        <div class="media-meta">${file.type} • ${fileSize}</div>
                        <div class="flex gap-1 justify-center">
                            <button class="btn btn-sm btn-secondary" onclick="previewMedia('${file.name}')">
                                <i class="fas fa-eye"></i>
                            </button>
                            <button class="btn btn-sm btn-danger" onclick="deleteMedia('${file.name}')">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </div>
                `;

                mediaList.appendChild(mediaItem);
            });
        }

        async function uploadFiles() {
            const fileInput = document.getElementById('fileInput');
            const files = fileInput.files;

            if (files.length === 0) {
                showToast('Veuillez sélectionner au moins un fichier', 'warning');
                return;
            }

            const formData = new FormData();
            for (let i = 0; i < files.length; i++) {
                formData.append('files[]', files[i]);
            }

            showUploadProgress(true);

            try {
                const response = await fetch('/api/upload.php', {
                    method: 'POST',
                    body: formData
                });

                const data = await response.json();
                showUploadProgress(false);

                if (data.success) {
                    showToast('Fichiers uploadés avec succès!', 'success');
                    clearFileSelection();
                    refreshMediaList();
                } else {
                    showToast('Erreur lors de l\'upload: ' + data.message, 'error');
                }
            } catch (error) {
                showUploadProgress(false);
                showToast('Erreur lors de l\'upload', 'error');
            }
        }

        function showUploadProgress(show, percent = 0) {
            const progressContainer = document.getElementById('upload-progress');
            const progressBar = document.getElementById('upload-progress-bar');
            const progressPercent = document.getElementById('upload-percent');

            if (show) {
                progressContainer.classList.remove('hidden');
                progressBar.style.width = percent + '%';
                if (progressPercent) progressPercent.textContent = percent + '%';
            } else {
                progressContainer.classList.add('hidden');
            }
        }

        // Utility Functions
        function getFileIcon(mimeType) {
            if (mimeType.startsWith('video/')) return '🎬';
            if (mimeType.startsWith('image/')) return '🖼️';
            if (mimeType.startsWith('audio/')) return '🎵';
            return '📄';
        }

        function getFileIconClass(mimeType) {
            if (mimeType.startsWith('video/')) return 'fas fa-film';
            if (mimeType.startsWith('image/')) return 'fas fa-image';
            if (mimeType.startsWith('audio/')) return 'fas fa-music';
            return 'fas fa-file';
        }

        function formatFileSize(bytes) {
            const sizes = ['B', 'KB', 'MB', 'GB'];
            if (bytes === 0) return '0 B';
            const i = Math.floor(Math.log(bytes) / Math.log(1024));
            return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
        }

        // Player Controls
        async function vlcControl(action) {
            try {
                const response = await fetch('/api/player.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ action: action })
                });

                const data = await response.json();

                if (data.success) {
                    showToast(`Action ${action} exécutée`, 'success');
                    updateVLCStatus();
                } else {
                    showToast(`Erreur: ${data.message}`, 'error');
                }
            } catch (error) {
                showToast('Erreur de communication avec VLC', 'error');
            }
        }

        function setVolume(volume) {
            vlcControl('volume').then(() => {
                document.getElementById('volume-display').textContent = volume + '%';
            });
        }

        // Screenshot Functions
        async function takeScreenshot() {
            showToast('Capture en cours...', 'info');

            try {
                const response = await fetch('/api/screenshot.php?action=capture');
                const data = await response.json();

                if (data.success) {
                    displayScreenshot(data.data.url);
                    showToast('Capture réalisée avec succès!', 'success');
                    updateLastScreenshotTime();
                } else {
                    showToast('Erreur lors de la capture: ' + data.message, 'error');
                }
            } catch (error) {
                showToast('Erreur lors de la capture', 'error');
            }
        }

        function displayScreenshot(url) {
            const img = document.getElementById('screenshot-display');
            const placeholder = document.getElementById('screenshot-placeholder');

            img.src = url + '?t=' + Date.now();
            img.classList.remove('hidden');
            placeholder.style.display = 'none';
        }

        function toggleAutoScreenshot() {
            const button = document.getElementById('auto-screenshot-btn');

            if (autoScreenshotInterval) {
                clearInterval(autoScreenshotInterval);
                autoScreenshotInterval = null;
                button.innerHTML = '<i class="fas fa-clock"></i> Auto-capture (OFF)';
                showToast('Auto-capture désactivée', 'info');
            } else {
                const interval = parseInt(document.getElementById('auto-interval').value) * 1000;
                autoScreenshotInterval = setInterval(takeScreenshot, interval);
                button.innerHTML = '<i class="fas fa-clock"></i> Auto-capture (ON)';
                showToast('Auto-capture activée', 'success');
            }
        }

        function updateIntervalDisplay() {
            const interval = document.getElementById('auto-interval').value;
            document.getElementById('interval-display').textContent = interval + ' secondes';
        }

        function updateLastScreenshotTime() {
            const element = document.getElementById('last-screenshot');
            if (element) {
                element.textContent = new Date().toLocaleTimeString();
            }
        }

        function updateVolumeDisplay() {
            const volume = document.getElementById('default-volume').value;
            document.getElementById('volume-display').textContent = volume + '%';
        }

        // Keyboard Shortcuts
        function handleKeyboardShortcuts(e) {
            // Ctrl+Space for play/pause
            if (e.ctrlKey && e.code === 'Space') {
                e.preventDefault();
                vlcControl('pause');
            }

            // F11 for fullscreen
            if (e.key === 'F11') {
                e.preventDefault();
                toggleFullscreen();
            }

            // Ctrl+T for new screenshot
            if (e.ctrlKey && e.key === 't') {
                e.preventDefault();
                takeScreenshot();
            }
        }

        // Placeholder functions for incomplete features
        function refreshPlaylists() {
            console.log('Loading playlists...');
        }

        function loadPlaylistsForSelects() {
            console.log('Loading playlists for selects...');
        }

        function updateAvailableMediaList() {
            console.log('Updating available media list...');
        }

        function loadMediaForSelects() {
            console.log('Loading media for selects...');
        }

        function loadScreenshotHistory() {
            console.log('Loading screenshot history...');
        }

        function refreshSchedules() {
            console.log('Loading schedules...');
        }

        function loadSystemInfo() {
            console.log('Loading system info...');
        }

        function loadSavedSettings() {
            // Load theme from localStorage
            const savedTheme = localStorage.getItem('pisignage-theme');
            if (savedTheme) {
                currentTheme = savedTheme;
                document.body.setAttribute('data-theme', currentTheme);
                updateThemeIcon();
            }
        }

        function handleWindowResize() {
            // Handle responsive layout changes
        }

        // System Actions
        async function systemAction(action) {
            if (['reboot', 'shutdown'].includes(action)) {
                const actionText = action === 'reboot' ? 'redémarrer' : 'éteindre';
                if (!confirm(`Êtes-vous sûr de vouloir ${actionText} le système?`)) {
                    return;
                }
            }

            try {
                const response = await fetch('/api/system.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ action: action })
                });

                const data = await response.json();

                if (data.success) {
                    showToast(`Action ${action} exécutée avec succès!`, 'success');
                } else {
                    showToast('Erreur lors de l\'exécution', 'error');
                }
            } catch (error) {
                showToast('Erreur lors de l\'exécution', 'error');
            }
        }

        // Modal Management
        function closeModal(modalId) {
            const modal = document.getElementById(modalId);
            modal.classList.remove('show');
        }

        // Additional placeholder functions for completeness
        function deleteMedia(filename) {
            if (confirm('Êtes-vous sûr de vouloir supprimer ce fichier?')) {
                console.log('Deleting media:', filename);
                // Implementation here
            }
        }

        function previewMedia(filename) {
            console.log('Previewing media:', filename);
            // Implementation here
        }

        function downloadYoutube() {
            console.log('Downloading YouTube video...');
            // Implementation here
        }

        function savePlaylist() {
            console.log('Saving playlist...');
            // Implementation here
        }

        function playPlaylist() {
            console.log('Playing playlist...');
            // Implementation here
        }

        function saveSchedule() {
            console.log('Saving schedule...');
            // Implementation here
        }

        function saveDisplayConfig() {
            console.log('Saving display config...');
            // Implementation here
        }

        function saveAudioConfig() {
            console.log('Saving audio config...');
            // Implementation here
        }

        function saveNetworkConfig() {
            console.log('Saving network config...');
            // Implementation here
        }
    </script>
</body>
</html>