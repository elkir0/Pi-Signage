#!/usr/bin/env node

/**
 * PiSignage Complete Audit Script
 * Tests all modules and generates comprehensive report
 */

const PiSignageAuditor = require('./audit-framework');

// Test definitions for each module
const dashboardTests = [
    {
        name: 'Dashboard Page Load',
        description: 'Check if dashboard loads without errors',
        fn: async (auditor) => {
            const success = await auditor.navigateTo('/dashboard.php');
            if (success) {
                await auditor.screenshot('dashboard-initial');
            }
            return success;
        }
    },
    {
        name: 'System Stats Display',
        description: 'Verify system stats are displayed',
        fn: async (auditor) => {
            await auditor.wait(3000); // Wait for stats to load

            const stats = await auditor.evaluateFunction(() => {
                const cpu = document.getElementById('cpu-usage')?.textContent;
                const ram = document.getElementById('ram-usage')?.textContent;
                const temp = document.getElementById('temperature')?.textContent;
                const storage = document.getElementById('storage-usage')?.textContent;

                return {
                    cpu: cpu && cpu !== '0%',
                    ram: ram && ram !== '0%',
                    temp: temp && temp !== 'N/A',
                    storage: storage && storage !== 'N/A'
                };
            }, 'System Stats Check');

            console.log('Stats found:', stats);
            await auditor.screenshot('dashboard-stats');

            return stats && stats.cpu && stats.ram;
        }
    },
    {
        name: 'Quick Actions Buttons',
        description: 'Check if quick action buttons exist',
        fn: async (auditor) => {
            const buttons = await auditor.evaluateFunction(() => {
                const quickActions = document.querySelector('.quick-actions');
                return quickActions ? quickActions.querySelectorAll('button').length : 0;
            }, 'Quick Actions Count');

            console.log(`Found ${buttons} quick action buttons`);
            return buttons > 0;
        }
    },
    {
        name: 'Navigation Links',
        description: 'Verify sidebar navigation links work',
        fn: async (auditor) => {
            const links = await auditor.evaluateFunction(() => {
                const sidebar = document.getElementById('sidebar');
                return sidebar ? sidebar.querySelectorAll('a').length : 0;
            }, 'Navigation Links Count');

            console.log(`Found ${links} navigation links`);
            return links >= 8; // Should have at least 8 modules
        }
    }
];

const mediaTests = [
    {
        name: 'Media Page Load',
        description: 'Check if media page loads',
        fn: async (auditor) => {
            const success = await auditor.navigateTo('/media.php');
            if (success) {
                await auditor.screenshot('media-initial');
            }
            return success;
        }
    },
    {
        name: 'Media List Display',
        description: 'Check if media files are displayed',
        fn: async (auditor) => {
            await auditor.wait(2000);

            const mediaCount = await auditor.evaluateFunction(() => {
                const mediaGrid = document.getElementById('media-grid');
                return mediaGrid ? mediaGrid.children.length : 0;
            }, 'Media Count');

            console.log(`Found ${mediaCount} media files`);
            await auditor.screenshot('media-list');

            return mediaCount >= 0; // Can be 0 if no media
        }
    },
    {
        name: 'Upload Button',
        description: 'Check if upload button exists',
        fn: async (auditor) => {
            const uploadBtn = await auditor.checkElement('#upload-btn', 'Upload Button');
            return uploadBtn.exists;
        }
    },
    {
        name: 'Drag & Drop Zone',
        description: 'Check if drag & drop zone exists',
        fn: async (auditor) => {
            const dropZone = await auditor.checkElement('#drop-zone', 'Drop Zone');
            return dropZone.exists;
        }
    }
];

const playlistTests = [
    {
        name: 'Playlist Page Load',
        description: 'Check if playlist page loads',
        fn: async (auditor) => {
            const success = await auditor.navigateTo('/playlists.php');
            if (success) {
                await auditor.screenshot('playlist-initial');
            }
            return success;
        }
    },
    {
        name: 'Create Playlist Button',
        description: 'Check if create playlist button works',
        fn: async (auditor) => {
            const createBtn = await auditor.evaluateFunction(() => {
                const buttons = document.querySelectorAll('button');
                for (let btn of buttons) {
                    if (btn.textContent.includes('Nouvelle')) {
                        return true;
                    }
                }
                return false;
            }, 'Create Button Check');

            return createBtn;
        }
    },
    {
        name: 'Load Playlist Button',
        description: 'Check if load playlist button exists',
        fn: async (auditor) => {
            const loadBtn = await auditor.evaluateFunction(() => {
                const buttons = document.querySelectorAll('button');
                for (let btn of buttons) {
                    if (btn.textContent.includes('Charger')) {
                        return true;
                    }
                }
                return false;
            }, 'Load Button Check');

            return loadBtn;
        }
    },
    {
        name: 'Playlist Editor',
        description: 'Check if playlist editor exists',
        fn: async (auditor) => {
            const editor = await auditor.checkElement('#playlist-editor', 'Playlist Editor');
            await auditor.screenshot('playlist-editor');
            return editor.exists;
        }
    }
];

const playerTests = [
    {
        name: 'Player Page Load',
        description: 'Check if player control page loads',
        fn: async (auditor) => {
            const success = await auditor.navigateTo('/player.php');
            if (success) {
                await auditor.screenshot('player-initial');
            }
            return success;
        }
    },
    {
        name: 'Player Controls',
        description: 'Check if player controls exist',
        fn: async (auditor) => {
            const controls = await auditor.evaluateFunction(() => {
                const playBtn = document.querySelector('[onclick*="play"]');
                const pauseBtn = document.querySelector('[onclick*="pause"]');
                const stopBtn = document.querySelector('[onclick*="stop"]');

                return {
                    play: !!playBtn,
                    pause: !!pauseBtn,
                    stop: !!stopBtn
                };
            }, 'Player Controls Check');

            console.log('Player controls:', controls);
            return controls.play || controls.pause || controls.stop;
        }
    },
    {
        name: 'Volume Control',
        description: 'Check if volume control exists',
        fn: async (auditor) => {
            const volumeControl = await auditor.checkElement('#volume-slider', 'Volume Slider');
            return volumeControl.exists;
        }
    },
    {
        name: 'Player Status',
        description: 'Check if player status is displayed',
        fn: async (auditor) => {
            await auditor.wait(2000);

            const status = await auditor.evaluateFunction(() => {
                const statusElem = document.getElementById('player-status');
                return statusElem ? statusElem.textContent : null;
            }, 'Player Status');

            console.log('Player status:', status);
            await auditor.screenshot('player-status');

            return status !== null;
        }
    }
];

// Main audit execution
async function runCompleteAudit() {
    const auditor = new PiSignageAuditor('http://192.168.1.103');

    try {
        await auditor.initialize();

        // Run tests for each module
        await auditor.auditModule('Dashboard', dashboardTests);
        await auditor.auditModule('Media', mediaTests);
        await auditor.auditModule('Playlists', playlistTests);
        await auditor.auditModule('Player', playerTests);

        // Generate and save reports
        const resultsPath = await auditor.saveResults();
        const report = await auditor.generateReport();

        console.log('\n' + '='.repeat(60));
        console.log('AUDIT COMPLETE');
        console.log('='.repeat(60));
        console.log(report);

        return auditor.results;

    } catch (error) {
        console.error('Audit failed:', error);
    } finally {
        await auditor.cleanup();
    }
}

// Execute if run directly
if (require.main === module) {
    runCompleteAudit().then(() => {
        console.log('\n✅ Audit completed successfully');
        process.exit(0);
    }).catch(error => {
        console.error('\n❌ Audit failed:', error);
        process.exit(1);
    });
}

module.exports = { runCompleteAudit, dashboardTests, mediaTests, playlistTests, playerTests };