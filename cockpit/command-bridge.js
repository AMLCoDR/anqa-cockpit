// ANQA Command Bridge - Cursor Integration
// Based on ai-development-monitor command processing system

const fs = require('fs');
const path = require('path');

class ANQACommandBridge {
    constructor(milestoneDB, io) {
        this.milestoneDB = milestoneDB;
        this.io = io;
        this.commandFilePath = path.join(__dirname, 'command.log');
        this.lastProcessedSize = 0;
        this.init();
    }

    init() {
        try {
            // Create command file if it doesn't exist
            if (!fs.existsSync(this.commandFilePath)) {
                fs.writeFileSync(this.commandFilePath, '', 'utf8');
                console.log(`🔗 [COMMAND BRIDGE] Created command file: ${this.commandFilePath}`);
            }

            // Get initial file size
            const stats = fs.statSync(this.commandFilePath);
            this.lastProcessedSize = stats.size;

            console.log(`🔗 [COMMAND BRIDGE] Watching for Cursor commands in: ${this.commandFilePath}`);
            
            // Watch for file changes
            fs.watch(this.commandFilePath, (eventType, filename) => {
                if (eventType === 'change') {
                    this.processNewCommands();
                }
            });
            
            console.log(`🔗 [COMMAND BRIDGE] Command bridge initialized successfully`);
        } catch (error) {
            console.error(`🔗 [COMMAND BRIDGE] Error during initialization:`, error);
            throw error;
        }
    }

    processNewCommands() {
        try {
            const content = fs.readFileSync(this.commandFilePath, 'utf8');
            const currentSize = Buffer.byteLength(content, 'utf8');
            
            // Only process if file has grown (new content added)
            if (currentSize > this.lastProcessedSize) {
                const newContent = content.slice(this.lastProcessedSize);
                const newLines = newContent.split('\n').filter(line => line.trim());
                
                for (const line of newLines) {
                    if (line.trim()) {
                        this.processCommand(line.trim());
                    }
                }
                
                this.lastProcessedSize = currentSize;
            }
        } catch (error) {
            console.error('🔗 [COMMAND BRIDGE] Error processing commands:', error);
        }
    }

    async processCommand(commandString) {
        console.log(`🔗 [COMMAND BRIDGE] Received from Cursor: "${commandString}"`);
        
        try {
            // Process through milestone database
            const stateChanged = await this.milestoneDB.processCommand(commandString);
            
            if (stateChanged) {
                // Broadcast updates via WebSocket
                const newState = await this.milestoneDB.getProjectState();
                const metrics = await this.milestoneDB.getProjectMetrics();
                
                this.io.emit('milestone_state_update', newState);
                this.io.emit('milestone_metrics_update', metrics);
                
                console.log(`🔗 [COMMAND BRIDGE] State updated and broadcast to clients`);
            }
            
            // Send command confirmation
            this.io.emit('command_processed', {
                command: commandString,
                success: true,
                stateChanged: stateChanged,
                timestamp: new Date().toISOString()
            });
            
        } catch (error) {
            console.error(`🔗 [COMMAND BRIDGE] Error processing command "${commandString}":`, error);
            
            this.io.emit('command_processed', {
                command: commandString,
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
    }

    // Method to add command programmatically (for testing)
    addCommand(command) {
        fs.appendFileSync(this.commandFilePath, command + '\n', 'utf8');
        console.log(`🔗 [COMMAND BRIDGE] Added command: ${command}`);
    }

    // Clear command log
    clearCommands() {
        fs.writeFileSync(this.commandFilePath, '', 'utf8');
        this.lastProcessedSize = 0;
        console.log(`🔗 [COMMAND BRIDGE] Command log cleared`);
    }

    // Get command file path for VS Code tasks
    getCommandFilePath() {
        return this.commandFilePath;
    }

    // Get recent commands
    getRecentCommands(limit = 10) {
        try {
            const content = fs.readFileSync(this.commandFilePath, 'utf8');
            const lines = content.split('\n').filter(line => line.trim());
            return lines.slice(-limit);
        } catch (error) {
            console.error('🔗 [COMMAND BRIDGE] Error reading commands:', error);
            return [];
        }
    }
}

module.exports = ANQACommandBridge;
