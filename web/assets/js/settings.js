/**
 * PiSignage Settings Module
 * Handles audio output, password change, and logout
 */

(function() {
    'use strict';

    // Initialize settings module
    const Settings = {
        init: function() {
            console.log('⚙️ Settings module initialized');
            this.loadCurrentSettings();
        },

        loadCurrentSettings: async function() {
            try {
                const response = await fetch('/api/settings.php');
                const data = await response.json();

                if (data.success && data.data) {
                    // Set audio output
                    const audioSelect = document.getElementById('audio-output');
                    if (audioSelect && data.data.audio_output) {
                        audioSelect.value = data.data.audio_output;
                    }
                }
            } catch (error) {
                console.error('Error loading settings:', error);
            }
        }
    };

    // Global functions for onclick handlers
    window.saveAudioConfig = async function() {
        const audioOutput = document.getElementById('audio-output').value;

        try {
            const response = await fetch('/api/settings.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'update_audio',
                    audio_output: audioOutput
                })
            });

            const data = await response.json();

            if (data.success) {
                showAlert(data.message || 'Sortie audio mise à jour', 'success');
            } else {
                showAlert(data.message || 'Erreur lors de la mise à jour', 'error');
            }
        } catch (error) {
            console.error('Error updating audio:', error);
            showAlert('Erreur de communication avec le serveur', 'error');
        }
    };

    window.changePassword = async function() {
        const oldPassword = document.getElementById('old-password').value;
        const newPassword = document.getElementById('new-password').value;
        const confirmPassword = document.getElementById('confirm-password').value;

        // Validation
        if (!oldPassword || !newPassword || !confirmPassword) {
            showAlert('Tous les champs sont requis', 'error');
            return;
        }

        if (newPassword.length < 6) {
            showAlert('Le nouveau mot de passe doit contenir au moins 6 caractères', 'error');
            return;
        }

        if (newPassword !== confirmPassword) {
            showAlert('Les mots de passe ne correspondent pas', 'error');
            return;
        }

        try {
            const response = await fetch('/api/settings.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'update_password',
                    old_password: oldPassword,
                    new_password: newPassword
                })
            });

            const data = await response.json();

            if (data.success) {
                showAlert(data.message || 'Mot de passe mis à jour', 'success');
                // Clear form
                document.getElementById('old-password').value = '';
                document.getElementById('new-password').value = '';
                document.getElementById('confirm-password').value = '';
            } else {
                showAlert(data.message || 'Erreur lors de la mise à jour', 'error');
            }
        } catch (error) {
            console.error('Error changing password:', error);
            showAlert('Erreur de communication avec le serveur', 'error');
        }
    };

    window.logout = async function() {
        if (confirm('Voulez-vous vraiment vous déconnecter ?')) {
            try {
                const response = await fetch('/api/settings.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'logout'
                    })
                });

                // Redirect to login regardless of response
                window.location.href = '/login.php';
            } catch (error) {
                console.error('Logout error:', error);
                // Still redirect to login on error
                window.location.href = '/login.php';
            }
        }
    };

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => Settings.init());
    } else {
        Settings.init();
    }

    // Expose Settings module
    if (typeof window.PiSignage === 'undefined') {
        window.PiSignage = {};
    }
    window.PiSignage.Settings = Settings;
})();
