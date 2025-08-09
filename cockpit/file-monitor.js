// ANQA File Monitor - Integrated with Cockpit
// Based on the ai-development-monitor system from /Volumes/DANIEL/ai-development-monitor

const fs = require('fs');
const path = require('path');
const chokidar = require('chokidar'); // Will install this

class ANQAFileMonitor {
    constructor(io) {
        this.io = io; // Socket.io instance from cockpit
        this.watchedPaths = [
            '/Users/danielrogers/anqa-website/system-optimization',
            '/Users/danielrogers/anqa-website/database',
            '/Users/danielrogers/anqa-website/scripts',
            '/Users/danielrogers/anqa-website/frontend',
            '/Users/danielrogers/anqa-website/backend'
        ];
        this.fileHistory = [];
        this.lastActivity = null;
        this.init();
    }

    init() {
        console.log('🔍 ANQA File Monitor - Starting file oversight system...');
        
        // Initialize file watchers for each path
        this.watchedPaths.forEach(watchPath => {
            if (fs.existsSync(watchPath)) {
                this.setupWatcher(watchPath);
            }
        });
        
        this.log('INFO', 'File oversight system active - monitoring AI development activity');
    }

    setupWatcher(watchPath) {
        const watcher = chokidar.watch(watchPath, {
            ignored: [
                '**/node_modules/**',
                '**/.git/**',
                '**/coverage/**',
                '**/*.log',
                '**/cockpit.pid'
            ],
            persistent: true,
            ignoreInitial: true
        });

        watcher
            .on('add', (filePath) => this.handleFileEvent('CREATED', filePath))
            .on('change', (filePath) => this.handleFileEvent('MODIFIED', filePath))
            .on('unlink', (filePath) => this.handleFileEvent('DELETED', filePath))
            .on('addDir', (dirPath) => this.handleFileEvent('DIR_CREATED', dirPath))
            .on('unlinkDir', (dirPath) => this.handleFileEvent('DIR_DELETED', dirPath));

        console.log(`📁 Watching: ${watchPath}`);
    }

    handleFileEvent(eventType, filePath) {
        const timestamp = new Date().toISOString();
        const relativePath = filePath.replace('/Users/danielrogers/anqa-website/', '');
        
        const fileEvent = {
            id: Date.now(),
            timestamp,
            type: eventType,
            path: relativePath,
            fullPath: filePath,
            size: this.getFileSize(filePath),
            extension: path.extname(filePath)
        };

        // Add to history
        this.fileHistory.unshift(fileEvent);
        
        // Keep only last 100 events
        if (this.fileHistory.length > 100) {
            this.fileHistory = this.fileHistory.slice(0, 100);
        }

        // Update last activity
        this.lastActivity = timestamp;

        // Log the event
        this.log('FILE_EVENT', `${eventType}: ${relativePath}`);

        // Broadcast to cockpit clients
        this.io.emit('file_event', fileEvent);
        this.io.emit('file_history_update', {
            recentFiles: this.fileHistory.slice(0, 10),
            totalEvents: this.fileHistory.length,
            lastActivity: this.lastActivity
        });

        // Special handling for important files
        if (this.isImportantFile(filePath)) {
            this.handleImportantFileChange(fileEvent);
        }
    }

    getFileSize(filePath) {
        try {
            if (fs.existsSync(filePath)) {
                const stats = fs.statSync(filePath);
                return stats.size;
            }
        } catch (error) {
            // File might have been deleted
        }
        return 0;
    }

    isImportantFile(filePath) {
        const importantPatterns = [
            /\.md$/,
            /\.sql$/,
            /\.json$/,
            /\.sh$/,
            /package\.json$/,
            /README/,
            /CHANGELOG/,
            /system-optimization/
        ];
        
        return importantPatterns.some(pattern => pattern.test(filePath));
    }

    handleImportantFileChange(fileEvent) {
        this.log('IMPORTANT', `Important file ${fileEvent.type.toLowerCase()}: ${fileEvent.path}`);
        
        // Send special notification for important files
        this.io.emit('important_file_change', {
            ...fileEvent,
            priority: 'high',
            notification: `AI modified important file: ${fileEvent.path}`
        });
    }

    log(level, message) {
        const timestamp = new Date().toISOString();
        const logEntry = { timestamp, level, message };
        
        console.log(`[${level}] ${message}`);
        
        // Send to cockpit log system
        this.io.emit('monitor_log', logEntry);
    }

    // API methods for cockpit
    getRecentActivity(limit = 10) {
        return {
            recentFiles: this.fileHistory.slice(0, limit),
            totalEvents: this.fileHistory.length,
            lastActivity: this.lastActivity,
            watchedPaths: this.watchedPaths
        };
    }

    getFileStats() {
        const stats = {
            totalFiles: 0,
            byExtension: {},
            byType: {
                CREATED: 0,
                MODIFIED: 0,
                DELETED: 0
            },
            lastHour: 0
        };

        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

        this.fileHistory.forEach(event => {
            stats.byType[event.type] = (stats.byType[event.type] || 0) + 1;
            
            if (event.extension) {
                stats.byExtension[event.extension] = (stats.byExtension[event.extension] || 0) + 1;
            }
            
            if (new Date(event.timestamp) > oneHourAgo) {
                stats.lastHour++;
            }
        });

        stats.totalFiles = this.fileHistory.length;
        return stats;
    }
}

module.exports = ANQAFileMonitor;
