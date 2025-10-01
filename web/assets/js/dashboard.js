/**
 * PiSignage Dashboard Module
 * Handles dashboard-specific functionality including stats display and quick actions
 */

// Ensure PiSignage namespace exists
window.PiSignage = window.PiSignage || {};

// Dashboard functionality
PiSignage.dashboard = {
    intervals: {
        stats: null
    },

    init: function() {
        console.log('📊 Initializing dashboard...');
        this.loadInitialStats();
        this.startStatsRefresh();
        this.setupQuickActions();
    },

    loadInitialStats: function() {
        // Load stats immediately on dashboard load
        setTimeout(() => {
            this.refreshStats();
        }, 100);
    },

    refreshStats: async function() {
        try {
            const data = await PiSignage.api.system.getStats();
            if (data.success && data.data) {
                this.updateStatsDisplay(data.data);
            }
        } catch (error) {
            console.error('Error refreshing stats:', error);
        }
    },

    updateStatsDisplay: function(stats) {
        const updateElement = (id, value) => {
            const el = document.getElementById(id);
            if (el) {
                el.textContent = value;
                // Add animation class for visual feedback
                el.classList.add('stat-updated');
                setTimeout(() => el.classList.remove('stat-updated'), 500);
            }
        };

        // Update CPU, RAM, Temperature
        updateElement('cpu-usage', ((stats.cpu && stats.cpu.usage) || 0) + '%');
        updateElement('ram-usage', ((stats.memory && stats.memory.percent) || 0) + '%');
        updateElement('temperature', (stats.temperature || 0) + '°C');

        // Update system stats
        updateElement('uptime', stats.uptime || '--');
        updateElement('network', stats.network || '--');
        updateElement('media-count', (stats.media_count || 0) + ' fichiers');

        // Update storage with formatted info
        const storageEl = document.getElementById('storage');
        if (storageEl && stats.disk) {
            storageEl.textContent = `${stats.disk.used_formatted} / ${stats.disk.total_formatted} (${stats.disk.percent}%)`;
        }

        // Update additional storage indicator
        const storageUsageEl = document.getElementById('storage-usage');
        if (storageUsageEl && stats.disk) {
            storageUsageEl.textContent = stats.disk.percent + '%';
        }
    },

    startStatsRefresh: function() {
        // Clear existing interval
        if (this.intervals.stats) {
            clearInterval(this.intervals.stats);
        }

        // Start new interval
        this.intervals.stats = setInterval(() => {
            this.refreshStats();
        }, 5000);

        console.log('📊 Dashboard stats refresh started (5s interval)');
    },

    stopStatsRefresh: function() {
        if (this.intervals.stats) {
            clearInterval(this.intervals.stats);
            this.intervals.stats = null;
            console.log('📊 Dashboard stats refresh stopped');
        }
    },

    setupQuickActions: function() {
        // Quick screenshot functionality
        this.setupQuickScreenshot();
    },

    setupQuickScreenshot: function() {
        // Make takeQuickScreenshot globally available
        window.takeQuickScreenshot = this.takeQuickScreenshot.bind(this);
    },

    takeQuickScreenshot: async function(source = 'dashboard') {
        showAlert(`Capture depuis ${source}...`, 'info');

        try {
            const data = await PiSignage.api.screenshot.capture();
            if (data.success) {
                this.showScreenshotModal(data.data.url);
                showAlert('Capture réalisée!', 'success');
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Screenshot error:', error);
            showAlert('Erreur lors de la capture', 'error');
        }
    },

    showScreenshotModal: function(imageUrl) {
        // Create modal for quick screenshot display
        const modal = document.createElement('div');
        modal.className = 'modal active';
        modal.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 10000;
        `;

        modal.innerHTML = `
            <div class="modal-content" style="
                background: #2a2d3a;
                border-radius: 15px;
                padding: 30px;
                max-width: 90%;
                max-height: 90%;
                position: relative;
                box-shadow: 0 20px 60px rgba(0,0,0,0.5);
            ">
                <h3 style="margin-bottom: 20px; color: #4a9eff; text-align: center;">📸 Capture d'écran</h3>
                <img src="${imageUrl}?${Date.now()}" style="
                    width: 100%;
                    max-width: 800px;
                    border-radius: 10px;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
                ">
                <button class="btn btn-primary" style="
                    margin-top: 20px;
                    width: 100%;
                    padding: 12px;
                    font-size: 16px;
                " onclick="this.closest('.modal').remove()">
                    Fermer
                </button>
            </div>
        `;

        // Close on background click
        modal.addEventListener('click', function(e) {
            if (e.target === modal) {
                modal.remove();
            }
        });

        document.body.appendChild(modal);
    },

    // Player switcher functionality for dashboard
    getCurrentPlayer: async function() {
        try {
            const data = await PiSignage.api.system.getCurrentPlayer();
            if (data.success) {
                const player = data.player || 'vlc';
                PiSignage.player.setCurrentPlayer(player);
                this.updatePlayerInterface();

                // Update radio buttons
                const radioBtn = document.getElementById('player-' + player);
                if (radioBtn) {
                    radioBtn.checked = true;
                }
            }
        } catch (error) {
            console.error('Get player error:', error);
            // Use VLC as default fallback
            PiSignage.player.setCurrentPlayer('vlc');
            this.updatePlayerInterface();
        }
    },

    updatePlayerInterface: function() {
        const player = PiSignage.player.getCurrentPlayer();
        // Ensure player is a string with fallback to 'vlc'
        const playerStr = (typeof player === 'string' && player) ? player : 'vlc';
        const playerName = playerStr.toUpperCase();

        // Update main status display
        const currentPlayerEl = document.getElementById('current-player');
        if (currentPlayerEl) {
            currentPlayerEl.textContent = playerName;
            currentPlayerEl.style.color = playerStr === 'vlc' ? '#4a9eff' : '#51cf66';
        }

        // Update controls section if present
        const controlsNameEl = document.getElementById('player-controls-name');
        if (controlsNameEl) {
            controlsNameEl.textContent = `Contrôles ${playerName}`;
        }

        // Update restart button text
        const restartTextEl = document.getElementById('restart-player-text');
        if (restartTextEl) {
            restartTextEl.textContent = `Redémarrer ${playerName}`;
        }

        // Update radio buttons
        document.querySelectorAll('input[name="player"]').forEach(radio => {
            radio.checked = (radio.value === playerStr);
        });

        // Adapt button colors based on player
        const playerButtons = document.querySelectorAll('.player-btn');
        playerButtons.forEach(btn => {
            if (playerStr === 'vlc') {
                btn.style.background = 'linear-gradient(135deg, #4a9eff, #3d7edb)';
            } else {
                btn.style.background = 'linear-gradient(135deg, #51cf66, #3eb854)';
            }
        });
    },

    switchPlayer: async function() {
        // PiSignage v0.8.9+ uses VLC exclusively - player switching removed
        showAlert('PiSignage utilise désormais VLC exclusivement pour une expérience optimale', 'info');
        return;
    }
};

// Global functions for backward compatibility
window.switchPlayer = function() {
    // PiSignage v0.8.9+ - VLC only
    showAlert('PiSignage utilise VLC exclusivement', 'info');
};

window.getCurrentPlayer = function() {
    return 'vlc'; // PiSignage v0.8.9+
};

window.updatePlayerInterface = function() {
    // No-op in VLC-only mode
};

// CSS for stat update animation
const dashboardStyles = document.createElement('style');
dashboardStyles.textContent = `
    .stat-updated {
        animation: statPulse 0.5s ease-out;
    }

    @keyframes statPulse {
        0% { transform: scale(1); }
        50% { transform: scale(1.05); }
        100% { transform: scale(1); }
    }
`;
document.head.appendChild(dashboardStyles);

console.log('✅ PiSignage Dashboard module loaded - Stats and quick actions ready');