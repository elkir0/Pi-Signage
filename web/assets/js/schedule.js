/**
 * PiSignage Schedule Module
 * Manages playlist scheduling with recurrence, priorities, and conflict detection
 * Version: 0.8.5
 */

(function() {
    'use strict';

    // Ensure PiSignage namespace exists
    window.PiSignage = window.PiSignage || {};

    // Schedule Module
    PiSignage.Schedule = {
        schedules: [],
        playlists: [],
        currentView: 'list',
        currentMonth: new Date().getMonth(),
        currentYear: new Date().getFullYear(),
        editingScheduleId: null,
        pendingSchedule: null,

        /**
         * Initialize module
         */
        init: function() {
            console.log('[Schedule] Initializing module...');

            this.loadPlaylists();
            this.loadSchedules();
            this.attachEventListeners();
            this.startAutoRefresh();
        },

        /**
         * Attach event listeners
         */
        attachEventListeners: function() {
            // Recurrence type change
            const recurrenceRadios = document.querySelectorAll('input[name="recurrence-type"]');
            recurrenceRadios.forEach(radio => {
                radio.addEventListener('change', (e) => {
                    this.handleRecurrenceTypeChange(e.target.value);
                });
            });

            // Continuous playback toggle
            const continuousCheckbox = document.getElementById('schedule-continuous');
            if (continuousCheckbox) {
                continuousCheckbox.addEventListener('change', (e) => {
                    document.getElementById('schedule-end-time').disabled = e.target.checked;
                });
            }

            // No end date toggle
            const noEndDateCheckbox = document.getElementById('schedule-no-end-date');
            if (noEndDateCheckbox) {
                noEndDateCheckbox.addEventListener('change', (e) => {
                    document.getElementById('schedule-end-date').disabled = e.target.checked;
                });
            }

            // Time change for duration calculation
            const startTimeInput = document.getElementById('schedule-start-time');
            const endTimeInput = document.getElementById('schedule-end-time');
            if (startTimeInput && endTimeInput) {
                startTimeInput.addEventListener('change', () => this.updateDurationEstimate());
                endTimeInput.addEventListener('change', () => this.updateDurationEstimate());
            }

            // Playlist selection change
            const playlistSelect = document.getElementById('schedule-playlist');
            if (playlistSelect) {
                playlistSelect.addEventListener('change', (e) => {
                    this.updatePlaylistPreview(e.target.value);
                });
            }

            console.log('[Schedule] Event listeners attached');
        },

        /**
         * Load playlists from API
         */
        loadPlaylists: async function() {
            try {
                const response = await fetch('/api/playlist-simple.php');

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const data = await response.json();

                if (data.success && data.data) {
                    this.playlists = data.data;
                    this.populatePlaylistDropdown();
                    console.log('[Schedule] Loaded', this.playlists.length, 'playlists');
                } else {
                    console.warn('[Schedule] No playlists found');
                    this.playlists = [];
                }
            } catch (error) {
                console.error('[Schedule] Error loading playlists:', error);
                showAlert('Erreur lors du chargement des playlists', 'error');
                this.playlists = [];
            }
        },

        /**
         * Populate playlist dropdown
         */
        populatePlaylistDropdown: function() {
            const select = document.getElementById('schedule-playlist');
            if (!select) return;

            // Clear existing options except first
            select.innerHTML = '<option value="">▼ Sélectionner une playlist</option>';

            this.playlists.forEach(playlist => {
                const option = document.createElement('option');
                option.value = playlist.name;
                option.textContent = playlist.name;
                select.appendChild(option);
            });
        },

        /**
         * Update playlist preview
         */
        updatePlaylistPreview: function(playlistName) {
            const preview = document.getElementById('playlist-preview');
            if (!preview) return;

            const playlist = this.playlists.find(p => p.name === playlistName);
            if (playlist && playlist.items) {
                const itemCount = playlist.items.length;
                const duration = this.calculatePlaylistDuration(playlist.items);
                preview.textContent = `📊 ${itemCount} médias, durée ~${duration}`;
            } else {
                preview.textContent = '';
            }
        },

        /**
         * Calculate playlist duration
         */
        calculatePlaylistDuration: function(items) {
            let totalSeconds = 0;
            items.forEach(item => {
                totalSeconds += parseInt(item.duration) || 10; // Default 10s
            });

            const minutes = Math.floor(totalSeconds / 60);
            const seconds = totalSeconds % 60;

            if (minutes >= 60) {
                const hours = Math.floor(minutes / 60);
                const remainingMinutes = minutes % 60;
                return `${hours}h ${remainingMinutes}min`;
            }

            return `${minutes}min ${seconds}s`;
        },

        /**
         * Load schedules from API
         */
        loadSchedules: async function() {
            try {
                const response = await fetch('/api/schedule.php');
                const data = await response.json();

                if (data.success) {
                    this.schedules = data.data || [];
                    this.renderSchedules();
                    this.updateStatistics();
                }
            } catch (error) {
                console.error('[Schedule] Error loading schedules:', error);
                showAlert('Erreur lors du chargement des plannings', 'error');
            }
        },

        /**
         * Render schedules based on current view
         */
        renderSchedules: function() {
            if (this.schedules.length === 0) {
                document.getElementById('empty-state').style.display = 'flex';
            } else {
                document.getElementById('empty-state').style.display = 'none';
            }

            switch (this.currentView) {
                case 'list':
                    this.renderListView();
                    break;
                case 'calendar':
                    this.renderCalendarView();
                    break;
                case 'timeline':
                    this.renderTimelineView();
                    break;
            }
        },

        /**
         * Render list view
         */
        renderListView: function() {
            const container = document.getElementById('schedule-list');
            if (!container) return;

            // Clear existing items (except empty state)
            const existingItems = container.querySelectorAll('.schedule-item');
            existingItems.forEach(item => item.remove());

            // Sort by next_run
            const sortedSchedules = [...this.schedules].sort((a, b) => {
                return (a.metadata.next_run || '').localeCompare(b.metadata.next_run || '');
            });

            sortedSchedules.forEach(schedule => {
                const card = this.createScheduleCard(schedule);
                container.appendChild(card);
            });
        },

        /**
         * Create schedule card element
         */
        createScheduleCard: function(schedule) {
            const card = document.createElement('div');
            card.className = 'schedule-item';
            card.dataset.scheduleId = schedule.id;

            // Status indicator
            const statusClass = schedule.enabled ? 'active' : 'inactive';
            const statusIcon = schedule.enabled ? '✅' : '⏸️';
            const statusText = schedule.enabled ? 'Actif' : 'Inactif';

            // Recurrence display
            const recurrenceText = this.formatRecurrence(schedule.schedule.recurrence);
            const daysText = this.formatDays(schedule.schedule.recurrence);

            // Priority badge
            const priorityLabels = ['Basse', 'Normale', 'Haute', 'Urgente'];
            const priorityText = priorityLabels[schedule.priority] || 'Normale';

            // Next run
            const nextRunText = this.formatNextRun(schedule.metadata.next_run);

            card.innerHTML = `
                <div class="schedule-status-bar ${statusClass}"></div>

                <div class="schedule-content">
                    <div class="schedule-header">
                        <div class="schedule-title-section">
                            <h4 class="schedule-name">${this.escapeHtml(schedule.name)}</h4>
                            <span class="schedule-playlist">Playlist: "${this.escapeHtml(schedule.playlist)}"</span>
                            ${schedule.description ? `<p class="schedule-description">${this.escapeHtml(schedule.description)}</p>` : ''}
                        </div>

                        <div class="schedule-toggle">
                            <label class="toggle-switch">
                                <input type="checkbox" ${schedule.enabled ? 'checked' : ''}
                                    onchange="PiSignage.Schedule.toggleSchedule('${schedule.id}')">
                                <span class="toggle-slider"></span>
                            </label>
                        </div>
                    </div>

                    <div class="schedule-timing">
                        <span class="time-display">⏰ ${schedule.schedule.start_time} - ${schedule.schedule.end_time || '∞'}</span>
                        <span class="recurrence-badge">🔁 ${recurrenceText}</span>
                        ${daysText ? `<span class="days-display">${daysText}</span>` : ''}
                    </div>

                    <div class="schedule-status">
                        <span class="status-indicator ${statusClass}">${statusIcon} ${statusText}</span>
                        <span class="next-run">Prochaine: ${nextRunText}</span>
                        <span class="priority-badge">Priorité: ${priorityText}</span>
                    </div>

                    <div class="schedule-actions">
                        <button class="btn btn-sm btn-glass" onclick="PiSignage.Schedule.editSchedule('${schedule.id}')">
                            ✏️ Modifier
                        </button>
                        <button class="btn btn-sm btn-glass" onclick="PiSignage.Schedule.duplicateSchedule('${schedule.id}')">
                            📋 Dupliquer
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="PiSignage.Schedule.deleteSchedule('${schedule.id}')">
                            🗑️ Supprimer
                        </button>
                    </div>
                </div>
            `;

            return card;
        },

        /**
         * Format recurrence for display
         */
        formatRecurrence: function(recurrence) {
            const types = {
                'once': 'Une fois',
                'daily': 'Quotidien',
                'weekly': 'Hebdomadaire',
                'monthly': 'Mensuel'
            };
            return types[recurrence.type] || 'Inconnu';
        },

        /**
         * Format days for display
         */
        formatDays: function(recurrence) {
            if (recurrence.type !== 'weekly' || !recurrence.days) {
                return '';
            }

            const dayNames = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
            return recurrence.days.map(d => dayNames[d]).join(' ');
        },

        /**
         * Format next run datetime
         */
        formatNextRun: function(nextRun) {
            if (!nextRun) return 'Non planifié';

            const date = new Date(nextRun);
            const now = new Date();
            const tomorrow = new Date(now);
            tomorrow.setDate(tomorrow.getDate() + 1);

            const isToday = date.toDateString() === now.toDateString();
            const isTomorrow = date.toDateString() === tomorrow.toDateString();

            const time = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

            if (isToday) {
                return `Aujourd'hui ${time}`;
            } else if (isTomorrow) {
                return `Demain ${time}`;
            } else {
                return `${date.toLocaleDateString('fr-FR')} ${time}`;
            }
        },

        /**
         * Render calendar view
         */
        renderCalendarView: function() {
            // TODO: Implement calendar rendering
            const container = document.getElementById('calendar-grid');
            if (!container) return;

            container.innerHTML = '<p style="padding: 20px; text-align: center;">Vue calendrier - Fonctionnalité à venir</p>';
        },

        /**
         * Render timeline view
         */
        renderTimelineView: function() {
            // TODO: Implement timeline rendering
            const container = document.querySelector('.timeline-container');
            if (!container) return;

            container.innerHTML = '<p style="padding: 20px; text-align: center;">Vue chronologie - Fonctionnalité à venir</p>';
        },

        /**
         * Update statistics
         */
        updateStatistics: function() {
            const stats = {
                active: 0,
                inactive: 0,
                running: 0,
                upcoming: 0
            };

            const now = new Date();

            this.schedules.forEach(schedule => {
                if (schedule.enabled) {
                    stats.active++;

                    // Check if currently running
                    const nextRun = new Date(schedule.metadata.next_run);
                    if (this.isCurrentlyRunning(schedule, now)) {
                        stats.running++;
                    } else if (nextRun > now) {
                        stats.upcoming++;
                    }
                } else {
                    stats.inactive++;
                }
            });

            document.getElementById('stat-active').textContent = stats.active;
            document.getElementById('stat-inactive').textContent = stats.inactive;
            document.getElementById('stat-running').textContent = stats.running;
            document.getElementById('stat-upcoming').textContent = stats.upcoming;
        },

        /**
         * Check if schedule is currently running
         */
        isCurrentlyRunning: function(schedule, now) {
            const startTime = schedule.schedule.start_time;
            const endTime = schedule.schedule.end_time || '23:59';

            const nowTimeStr = now.toTimeString().substring(0, 5);

            return nowTimeStr >= startTime && nowTimeStr <= endTime;
        },

        /**
         * Switch view mode
         */
        switchView: function(view) {
            this.currentView = view;

            // Update button states
            document.querySelectorAll('.view-btn').forEach(btn => {
                btn.classList.remove('active');
                if (btn.dataset.view === view) {
                    btn.classList.add('active');
                }
            });

            // Update view containers
            document.querySelectorAll('.schedule-view').forEach(container => {
                container.classList.remove('active');
            });

            const viewIcons = {
                'list': '📋',
                'calendar': '📅',
                'timeline': '⏰'
            };

            const viewTitles = {
                'list': 'Liste des plannings',
                'calendar': 'Vue calendrier',
                'timeline': 'Vue chronologie'
            };

            document.getElementById('view-icon').textContent = viewIcons[view];
            document.getElementById('view-title').textContent = viewTitles[view];

            if (view === 'list') {
                document.getElementById('schedule-list').classList.add('active');
            } else if (view === 'calendar') {
                document.getElementById('schedule-calendar').classList.add('active');
            } else if (view === 'timeline') {
                document.getElementById('schedule-timeline').classList.add('active');
            }

            this.renderSchedules();
        },

        /**
         * Open add modal
         */
        openAddModal: function() {
            console.log('[Schedule] openAddModal() called');
            this.editingScheduleId = null;

            // Capture self reference for closures
            const self = this;

            // Wait for modal to be available (retry mechanism)
            const tryOpenModal = (attempt = 1) => {
                console.log(`[Schedule] tryOpenModal attempt ${attempt}`);
                const modal = document.getElementById('schedule-modal');
                const modalTitle = document.getElementById('modal-title');

                console.log(`[Schedule] Modal found:`, !!modal, 'Title found:', !!modalTitle);

                if (!modal || !modalTitle) {
                    if (attempt < 10) {
                        console.warn(`[Schedule] Modal not ready, retry ${attempt}/10...`);
                        setTimeout(() => tryOpenModal(attempt + 1), 100);
                        return;
                    } else {
                        console.error('[Schedule] Modal elements not found in DOM after 10 retries!');
                        console.error('  modal:', modal);
                        console.error('  modalTitle:', modalTitle);
                        console.error('  Available elements:', Array.from(document.querySelectorAll('[id]')).map(el => el.id));
                        return;
                    }
                }

                console.log('[Schedule] Modal elements found! Opening modal...');
                modalTitle.textContent = '✨ Nouveau Planning';
                modal.classList.add('show');

                // Reset form AFTER modal is shown
                setTimeout(() => self.resetForm(), 50);
            };

            tryOpenModal();
        },

        /**
         * Edit existing schedule
         */
        editSchedule: function(scheduleId) {
            const schedule = this.schedules.find(s => s.id === scheduleId);
            if (!schedule) return;

            this.editingScheduleId = scheduleId;
            this.populateForm(schedule);
            document.getElementById('modal-title').textContent = '✏️ Modifier le Planning';
            document.getElementById('schedule-modal').classList.add('show');
        },

        /**
         * Populate form with schedule data
         */
        populateForm: function(schedule) {
            document.getElementById('schedule-name').value = schedule.name;
            document.getElementById('schedule-playlist').value = schedule.playlist;
            document.getElementById('schedule-description').value = schedule.description || '';

            document.getElementById('schedule-start-time').value = schedule.schedule.start_time;
            document.getElementById('schedule-end-time').value = schedule.schedule.end_time || '';
            document.getElementById('schedule-continuous').checked = schedule.schedule.continuous || false;
            document.getElementById('schedule-once-only').checked = schedule.schedule.once_only || false;

            // Recurrence
            const recurrenceType = schedule.schedule.recurrence.type;
            document.querySelector(`input[name="recurrence-type"][value="${recurrenceType}"]`).checked = true;
            this.handleRecurrenceTypeChange(recurrenceType);

            if (recurrenceType === 'weekly' && schedule.schedule.recurrence.days) {
                schedule.schedule.recurrence.days.forEach(day => {
                    const checkbox = document.querySelector(`.days-selector input[value="${day}"]`);
                    if (checkbox) checkbox.checked = true;
                });
            }

            document.getElementById('schedule-start-date').value = schedule.schedule.recurrence.start_date || '';
            document.getElementById('schedule-end-date').value = schedule.schedule.recurrence.end_date || '';
            document.getElementById('schedule-no-end-date').checked = schedule.schedule.recurrence.no_end_date || false;

            // Advanced
            document.getElementById('schedule-priority').value = schedule.priority || 1;
            document.querySelector(`input[name="conflict-behavior"][value="${schedule.conflict_behavior}"]`).checked = true;

            document.getElementById('post-action-revert').checked = schedule.post_actions?.revert_default || false;
            document.getElementById('post-action-stop').checked = schedule.post_actions?.stop_playback || false;
            document.getElementById('post-action-screenshot').checked = schedule.post_actions?.take_screenshot || false;

            this.updatePlaylistPreview(schedule.playlist);
            this.updateDurationEstimate();
        },

        /**
         * Reset form
         */
        resetForm: function() {
            const setValueSafely = (id, value) => {
                const el = document.getElementById(id);
                if (el) el.value = value;
                else console.warn(`[Schedule] Element not found: ${id}`);
            };

            setValueSafely('schedule-name', '');
            setValueSafely('schedule-playlist', '');
            setValueSafely('schedule-description', '');
            setValueSafely('schedule-start-time', '');
            setValueSafely('schedule-end-time', '');
            setValueSafely('schedule-start-date', '');
            setValueSafely('schedule-end-date', '');
            setValueSafely('schedule-priority', '1');

            const setCheckedSafely = (id, checked) => {
                const el = document.getElementById(id);
                if (el) el.checked = checked;
                else console.warn(`[Schedule] Element not found: ${id}`);
            };

            setCheckedSafely('schedule-continuous', false);
            setCheckedSafely('schedule-once-only', false);
            setCheckedSafely('schedule-no-end-date', false);
            setCheckedSafely('post-action-revert', true);
            setCheckedSafely('post-action-stop', false);
            setCheckedSafely('post-action-screenshot', false);

            const dailyRadio = document.querySelector('input[name="recurrence-type"][value="daily"]');
            if (dailyRadio) dailyRadio.checked = true;
            this.handleRecurrenceTypeChange('daily');

            document.querySelectorAll('.days-selector input').forEach(cb => cb.checked = false);

            const ignoreRadio = document.querySelector('input[name="conflict-behavior"][value="ignore"]');
            if (ignoreRadio) ignoreRadio.checked = true;

            const preview = document.getElementById('playlist-preview');
            if (preview) preview.textContent = '';

            const duration = document.getElementById('duration-estimate');
            if (duration) duration.textContent = '-';

            this.switchTab('general');
        },

        /**
         * Handle recurrence type change
         */
        handleRecurrenceTypeChange: function(type) {
            const weeklyDaysGroup = document.getElementById('weekly-days-group');
            if (type === 'weekly') {
                weeklyDaysGroup.style.display = 'block';
            } else {
                weeklyDaysGroup.style.display = 'none';
            }
        },

        /**
         * Update duration estimate
         */
        updateDurationEstimate: function() {
            const startTime = document.getElementById('schedule-start-time').value;
            const endTime = document.getElementById('schedule-end-time').value;
            const estimateEl = document.getElementById('duration-estimate');

            if (!startTime || !endTime) {
                estimateEl.textContent = '-';
                return;
            }

            const start = this.timeToMinutes(startTime);
            const end = this.timeToMinutes(endTime);

            if (end <= start) {
                estimateEl.textContent = 'Heure de fin invalide';
                return;
            }

            const durationMinutes = end - start;
            const hours = Math.floor(durationMinutes / 60);
            const minutes = durationMinutes % 60;

            if (hours > 0) {
                estimateEl.textContent = `${hours}h ${minutes}min`;
            } else {
                estimateEl.textContent = `${minutes}min`;
            }
        },

        /**
         * Convert time string to minutes
         */
        timeToMinutes: function(timeStr) {
            const [hours, minutes] = timeStr.split(':').map(Number);
            return hours * 60 + minutes;
        },

        /**
         * Switch modal tab
         */
        switchTab: function(tabName) {
            // Update tab buttons
            document.querySelectorAll('.tab-btn').forEach(btn => {
                btn.classList.remove('active');
                if (btn.dataset.tab === tabName) {
                    btn.classList.add('active');
                }
            });

            // Update tab content
            document.querySelectorAll('.tab-content').forEach(content => {
                content.classList.remove('active');
                if (content.dataset.tab === tabName) {
                    content.classList.add('active');
                }
            });
        },

        /**
         * Close modal
         */
        closeModal: function() {
            document.getElementById('schedule-modal').classList.remove('show');
            this.editingScheduleId = null;
        },

        /**
         * Save schedule
         */
        saveSchedule: async function(andActivate = false) {
            // Validate form
            const scheduleData = this.getFormData();

            if (!this.validateFormData(scheduleData)) {
                return;
            }

            // If andActivate, enable the schedule
            if (andActivate) {
                scheduleData.enabled = true;
            }

            try {
                let url = '/api/schedule.php';
                let method = 'POST';

                if (this.editingScheduleId) {
                    url = `/api/schedule.php/${this.editingScheduleId}`;
                    method = 'PUT';
                }

                const response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(scheduleData)
                });

                const data = await response.json();

                if (data.success) {
                    showAlert(data.message || 'Planning sauvegardé avec succès', 'success');
                    this.closeModal();
                    this.loadSchedules();
                } else if (response.status === 409) {
                    // Conflict detected
                    this.pendingSchedule = scheduleData;
                    this.showConflictModal(data.conflicts);
                } else {
                    showAlert(data.message || 'Erreur lors de la sauvegarde', 'error');
                }
            } catch (error) {
                console.error('[Schedule] Save error:', error);
                showAlert('Erreur de connexion au serveur', 'error');
            }
        },

        /**
         * Get form data
         */
        getFormData: function() {
            const recurrenceType = document.querySelector('input[name="recurrence-type"]:checked').value;
            const selectedDays = [];

            if (recurrenceType === 'weekly') {
                document.querySelectorAll('.days-selector input:checked').forEach(cb => {
                    selectedDays.push(parseInt(cb.value));
                });
            }

            return {
                name: document.getElementById('schedule-name').value.trim(),
                description: document.getElementById('schedule-description').value.trim(),
                playlist: document.getElementById('schedule-playlist').value,
                enabled: this.editingScheduleId ? undefined : false, // Default disabled for new
                priority: parseInt(document.getElementById('schedule-priority').value),
                schedule: {
                    type: 'recurring',
                    start_time: document.getElementById('schedule-start-time').value,
                    end_time: document.getElementById('schedule-end-time').value || undefined,
                    continuous: document.getElementById('schedule-continuous').checked,
                    once_only: document.getElementById('schedule-once-only').checked,
                    recurrence: {
                        type: recurrenceType,
                        days: recurrenceType === 'weekly' ? selectedDays : undefined,
                        start_date: document.getElementById('schedule-start-date').value || undefined,
                        end_date: document.getElementById('schedule-end-date').value || undefined,
                        no_end_date: document.getElementById('schedule-no-end-date').checked
                    }
                },
                conflict_behavior: document.querySelector('input[name="conflict-behavior"]:checked').value,
                post_actions: {
                    revert_default: document.getElementById('post-action-revert').checked,
                    stop_playback: document.getElementById('post-action-stop').checked,
                    take_screenshot: document.getElementById('post-action-screenshot').checked
                }
            };
        },

        /**
         * Validate form data
         */
        validateFormData: function(data) {
            const errors = [];

            if (!data.name) {
                errors.push('Le nom du planning est requis');
            }

            if (!data.playlist) {
                errors.push('La playlist est requise');
            }

            if (!data.schedule.start_time) {
                errors.push("L'heure de début est requise");
            }

            if (data.schedule.recurrence.type === 'weekly' && (!data.schedule.recurrence.days || data.schedule.recurrence.days.length === 0)) {
                errors.push('Au moins un jour doit être sélectionné pour la récurrence hebdomadaire');
            }

            if (errors.length > 0) {
                showAlert(errors.join('\n'), 'error');
                return false;
            }

            return true;
        },

        /**
         * Show conflict modal
         */
        showConflictModal: function(conflicts) {
            const modal = document.getElementById('conflict-modal');
            const messageEl = document.getElementById('conflict-message');
            const listEl = document.getElementById('conflict-list');

            messageEl.textContent = `${conflicts.length} conflit(s) détecté(s). Les plannings suivants se chevauchent :`;

            listEl.innerHTML = conflicts.map(conflict => `
                <div class="conflict-item">
                    <strong>${this.escapeHtml(conflict.schedule_name)}</strong><br>
                    Horaire: ${conflict.time_overlap}<br>
                    Priorité: ${conflict.priority}
                </div>
            `).join('');

            modal.classList.add('show');
        },

        /**
         * Close conflict modal
         */
        closeConflictModal: function() {
            document.getElementById('conflict-modal').classList.remove('show');
        },

        /**
         * Save schedule ignoring conflicts
         */
        saveScheduleIgnoreConflicts: async function() {
            if (!this.pendingSchedule) return;

            this.pendingSchedule.conflict_behavior = 'ignore';
            this.closeConflictModal();

            try {
                let url = '/api/schedule.php';
                let method = 'POST';

                if (this.editingScheduleId) {
                    url = `/api/schedule.php/${this.editingScheduleId}`;
                    method = 'PUT';
                }

                const response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(this.pendingSchedule)
                });

                const data = await response.json();

                if (data.success) {
                    showAlert(data.message || 'Planning sauvegardé avec succès', 'success');
                    this.closeModal();
                    this.loadSchedules();
                } else {
                    showAlert(data.message || 'Erreur lors de la sauvegarde', 'error');
                }
            } catch (error) {
                console.error('[Schedule] Save error:', error);
                showAlert('Erreur de connexion au serveur', 'error');
            }

            this.pendingSchedule = null;
        },

        /**
         * Toggle schedule enabled status
         */
        toggleSchedule: async function(scheduleId) {
            try {
                // Use absolute URL to prevent path resolution issues
                const url = `${window.location.origin}/api/schedule.php/${scheduleId}/toggle`;

                const response = await fetch(url, {
                    method: 'PATCH',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const data = await response.json();

                if (data.success) {
                    showAlert('Planning modifié avec succès', 'success');
                    this.loadSchedules();
                } else {
                    showAlert(data.message || 'Erreur lors de la modification', 'error');
                }
            } catch (error) {
                console.error('[Schedule] Toggle error:', error);
                showAlert('Erreur de connexion au serveur', 'error');
            }
        },

        /**
         * Duplicate schedule
         */
        duplicateSchedule: function(scheduleId) {
            const schedule = this.schedules.find(s => s.id === scheduleId);
            if (!schedule) return;

            this.editingScheduleId = null;
            this.populateForm(schedule);
            document.getElementById('schedule-name').value = schedule.name + ' (Copie)';
            document.getElementById('modal-title').textContent = '📋 Dupliquer le Planning';
            document.getElementById('schedule-modal').classList.add('show');
        },

        /**
         * Delete schedule
         */
        deleteSchedule: async function(scheduleId) {
            const schedule = this.schedules.find(s => s.id === scheduleId);
            if (!schedule) return;

            if (!confirm(`Supprimer le planning "${schedule.name}" ?\n\nCette action est irréversible.`)) {
                return;
            }

            try {
                const response = await fetch(`/api/schedule.php/${scheduleId}`, {
                    method: 'DELETE'
                });

                const data = await response.json();

                if (data.success) {
                    showAlert(data.message || 'Planning supprimé avec succès', 'success');
                    this.loadSchedules();
                } else {
                    showAlert(data.message || 'Erreur lors de la suppression', 'error');
                }
            } catch (error) {
                console.error('[Schedule] Delete error:', error);
                showAlert('Erreur de connexion au serveur', 'error');
            }
        },

        /**
         * Refresh schedules
         */
        refresh: function() {
            this.loadSchedules();
            showAlert('Plannings actualisés', 'success');
        },

        /**
         * Start auto-refresh
         */
        startAutoRefresh: function() {
            // Refresh every 60 seconds
            setInterval(() => {
                this.loadSchedules();
            }, 60000);
        },

        /**
         * Calendar navigation
         */
        prevMonth: function() {
            this.currentMonth--;
            if (this.currentMonth < 0) {
                this.currentMonth = 11;
                this.currentYear--;
            }
            this.renderCalendarView();
        },

        nextMonth: function() {
            this.currentMonth++;
            if (this.currentMonth > 11) {
                this.currentMonth = 0;
                this.currentYear++;
            }
            this.renderCalendarView();
        },

        /**
         * Escape HTML
         */
        escapeHtml: function(text) {
            const map = {
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#039;'
            };
            return text.replace(/[&<>"']/g, m => map[m]);
        }
    };

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            if (window.location.pathname.includes('schedule.php')) {
                PiSignage.Schedule.init();
            }
        });
    } else {
        if (window.location.pathname.includes('schedule.php')) {
            PiSignage.Schedule.init();
        }
    }

})();
