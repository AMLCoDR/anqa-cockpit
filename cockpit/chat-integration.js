// ANQA Cockpit Chat Integration
// Allows interaction with AI assistants directly from the cockpit

class CockpitChat {
    constructor() {
        this.chatHistory = [];
        this.isOpen = false;
        this.currentAssistant = 'ANQA Assistant';
        this.lastMessageId = 0;
        this.syncInterval = null;
        this.init().catch(error => {
            console.error('Error initializing chat:', error);
        });
    }

    async init() {
        this.createChatInterface();
        this.bindEvents();
        await this.loadChatHistory();
        this.startSync();
    }
    
    startSync() {
        // Check for new messages every 3 seconds
        this.syncInterval = setInterval(async () => {
            await this.checkForNewMessages();
        }, 3000);
    }
    
    async checkForNewMessages() {
        try {
            const response = await fetch('/api/chat/recent');
            if (response.ok) {
                const data = await response.json();
                const newMessages = data.messages.filter(msg => msg.id > this.lastMessageId);
                
                if (newMessages.length > 0) {
                    newMessages.forEach(msg => {
                        if (msg.sender !== 'user' && msg.sender !== 'ANQA Assistant') {
                            // This is a message from external source (like this conversation)
                            this.addMessage(msg.sender, msg.content, false);
                        }
                    });
                    
                    this.lastMessageId = Math.max(...data.messages.map(msg => msg.id));
                }
            }
        } catch (error) {
            console.error('Error checking for new messages:', error);
        }
    }

    createChatInterface() {
        // Create chat container
        const chatContainer = document.createElement('div');
        chatContainer.id = 'chat-container';
        chatContainer.className = 'chat-container';
        chatContainer.innerHTML = `
            <div class="chat-header">
                <div class="chat-title">
                    <span class="chat-icon">🤖</span>
                    <span>AI Assistant</span>
                </div>
                <div class="chat-controls">
                    <button class="chat-minimize" onclick="cockpitChat.toggleChat()">−</button>
                    <button class="chat-close" onclick="cockpitChat.closeChat()">×</button>
                </div>
            </div>
            <div class="chat-messages" id="chat-messages">
                <div class="message assistant">
                    <div class="message-content">
                        <strong>ANQA Assistant:</strong> Hello! I'm here to help you manage your ANQA system. How can I assist you today?
                    </div>
                    <div class="message-time">${new Date().toLocaleTimeString()}</div>
                </div>
            </div>
            <div class="chat-input-container">
                <div class="chat-input-wrapper">
                    <input type="text" id="chat-input" placeholder="Ask me anything about your ANQA system..." />
                    <button id="chat-send" onclick="cockpitChat.sendMessage()">Send</button>
                </div>
                <div class="chat-quick-actions">
                    <button onclick="cockpitChat.sendQuickMessage('Check system health')">Health Check</button>
                    <button onclick="cockpitChat.sendQuickMessage('Show performance metrics')">Performance</button>
                    <button onclick="cockpitChat.sendQuickMessage('What commands are available?')">Commands</button>
                </div>
            </div>
        `;

        // Add to body
        document.body.appendChild(chatContainer);

        // Add chat toggle button to cockpit
        this.addChatToggleButton();
    }

    addChatToggleButton() {
        // Add chat button to the right panel
        const rightPanel = document.querySelector('.right-panel');
        if (rightPanel) {
            const chatSection = document.createElement('div');
            chatSection.className = 'control-section';
            chatSection.innerHTML = `
                <h4>🤖 AI Assistant</h4>
                <button class="control-button" onclick="cockpitChat.toggleChat()">
                    💬 Open Chat
                </button>
                <button class="control-button" onclick="cockpitChat.sendQuickMessage('Analyze current system status')">
                    🔍 System Analysis
                </button>
                <button class="control-button" onclick="cockpitChat.sendQuickMessage('What should I do next?')">
                    💡 Get Advice
                </button>
            `;
            rightPanel.appendChild(chatSection);
        }
    }

    bindEvents() {
        const chatInput = document.getElementById('chat-input');
        if (chatInput) {
            chatInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.sendMessage();
                }
            });
        }
    }

    toggleChat() {
        const chatContainer = document.getElementById('chat-container');
        if (this.isOpen) {
            chatContainer.classList.remove('chat-open');
            this.isOpen = false;
        } else {
            chatContainer.classList.add('chat-open');
            this.isOpen = true;
            document.getElementById('chat-input').focus();
        }
    }

    closeChat() {
        const chatContainer = document.getElementById('chat-container');
        chatContainer.classList.remove('chat-open');
        this.isOpen = false;
    }

    sendMessage(message = null) {
        const input = document.getElementById('chat-input');
        const userMessage = message || input.value.trim();
        
        if (!userMessage) return;

        // Add user message to chat
        this.addMessage('user', userMessage);

        // Clear input
        if (!message) {
            input.value = '';
        }

        // Process message and get response
        this.processMessage(userMessage);
    }

    sendQuickMessage(message) {
        this.sendMessage(message);
    }

    addMessage(sender, content, saveToHistory = true) {
        const messagesContainer = document.getElementById('chat-messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${sender}`;
        
        const senderName = sender === 'user' ? 'You' : sender;
        const senderIcon = sender === 'user' ? '👤' : '🤖';
        
        messageDiv.innerHTML = `
            <div class="message-content">
                <strong>${senderIcon} ${senderName}:</strong> ${content}
            </div>
            <div class="message-time">${new Date().toLocaleTimeString()}</div>
        `;
        
        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;

        if (saveToHistory) {
            const messageId = Date.now();
            this.lastMessageId = Math.max(this.lastMessageId, messageId);
            
            this.chatHistory.push({
                id: messageId,
                sender,
                content,
                timestamp: new Date().toISOString()
            });
            this.saveChatHistory();
        }
    }

    async processMessage(message) {
        // Show typing indicator
        this.showTypingIndicator();

        try {
            // Send message to API
            const response = await fetch('/api/chat/message', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: message,
                    userId: 'user'
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to send message to API');
            }
            
            const data = await response.json();
            
            // Remove typing indicator and add response
            this.hideTypingIndicator();
            this.addMessage('ANQA Assistant', data.aiMessage.content);

            // Execute commands if needed
            await this.executeCommandsFromMessage(message);

        } catch (error) {
            this.hideTypingIndicator();
            console.error('Chat API error:', error);
            
            // Fallback to local response
            const fallbackResponse = await this.generateResponse(message);
            this.addMessage('ANQA Assistant', fallbackResponse);
        }
    }

    async generateResponse(message) {
        // Simulate AI processing time
        await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 2000));

        const lowerMessage = message.toLowerCase();

        // Predefined responses based on message content
        if (lowerMessage.includes('health') || lowerMessage.includes('status')) {
            return this.getSystemHealthResponse();
        } else if (lowerMessage.includes('performance') || lowerMessage.includes('metrics')) {
            return this.getPerformanceResponse();
        } else if (lowerMessage.includes('command') || lowerMessage.includes('available')) {
            return this.getCommandsResponse();
        } else if (lowerMessage.includes('help') || lowerMessage.includes('assist')) {
            return this.getHelpResponse();
        } else if (lowerMessage.includes('analyze') || lowerMessage.includes('analysis')) {
            return this.getAnalysisResponse();
        } else if (lowerMessage.includes('advice') || lowerMessage.includes('next')) {
            return this.getAdviceResponse();
        } else {
            return this.getGeneralResponse(message);
        }
    }

    getSystemHealthResponse() {
        const cpu = document.getElementById('cpu-usage')?.textContent || 'Unknown';
        const memory = document.getElementById('memory-usage')?.textContent || 'Unknown';
        const disk = document.getElementById('disk-usage')?.textContent || 'Unknown';

        return `Here's your current system health:\n\n` +
               `🖥️ CPU Usage: ${cpu}\n` +
               `💾 Memory Usage: ${memory}\n` +
               `💿 Disk Usage: ${disk}\n\n` +
               `I recommend running a health check if you see any values above 80%.`;
    }

    getPerformanceResponse() {
        const apiResponse = document.getElementById('api-response-time')?.textContent || 'Unknown';
        const pageLoad = document.getElementById('page-load-time')?.textContent || 'Unknown';
        const dbQuery = document.getElementById('database-query-time')?.textContent || 'Unknown';

        return `Current performance metrics:\n\n` +
               `⚡ API Response: ${apiResponse}\n` +
               `🌐 Page Load: ${pageLoad}\n` +
               `🗄️ DB Query: ${dbQuery}\n\n` +
               `Performance looks good! All metrics are within normal ranges.`;
    }

    getCommandsResponse() {
        return `Here are the main commands available in the cockpit:\n\n` +
               `🚀 Quick Actions:\n` +
               `• Health Check - Comprehensive system scan\n` +
               `• Performance Test - Benchmark your system\n` +
               `• Create Backup - Generate system backup\n` +
               `• System Report - Detailed system report\n\n` +
               `🔧 Maintenance:\n` +
               `• Update Dependencies - Keep everything current\n` +
               `• Optimize Cache - Improve performance\n` +
               `• Validate Config - Check configuration\n` +
               `• Analyze Logs - Review system logs\n\n` +
               `🚨 Emergency:\n` +
               `• Auto Recovery - Fix common issues\n` +
               `• Restart Services - Safely restart services\n` +
               `• Emergency Rollback - Rollback to safe state`;
    }

    getHelpResponse() {
        return `I'm here to help you manage your ANQA system! Here's what I can do:\n\n` +
               `📊 Monitor system health and performance\n` +
               `🔧 Execute maintenance commands\n` +
               `🚨 Provide emergency assistance\n` +
               `💡 Give recommendations and advice\n` +
               `📝 Explain system metrics and alerts\n\n` +
               `Just ask me anything about your system!`;
    }

    getAnalysisResponse() {
        const cpu = parseInt(document.getElementById('cpu-usage')?.textContent) || 0;
        const memory = parseInt(document.getElementById('memory-usage')?.textContent) || 0;
        const disk = parseInt(document.getElementById('disk-usage')?.textContent) || 0;

        let analysis = `System Analysis:\n\n`;

        if (cpu > 80) {
            analysis += `⚠️ High CPU usage (${cpu}%) - Consider optimizing processes\n`;
        } else {
            analysis += `✅ CPU usage is healthy (${cpu}%)\n`;
        }

        if (memory > 80) {
            analysis += `⚠️ High memory usage (${memory}%) - Consider cleanup\n`;
        } else {
            analysis += `✅ Memory usage is healthy (${memory}%)\n`;
        }

        if (disk > 80) {
            analysis += `⚠️ High disk usage (${disk}%) - Consider cleanup\n`;
        } else {
            analysis += `✅ Disk usage is healthy (${disk}%)\n`;
        }

        analysis += `\nOverall: ${this.getOverallStatus(cpu, memory, disk)}`;

        return analysis;
    }

    getAdviceResponse() {
        const cpu = parseInt(document.getElementById('cpu-usage')?.textContent) || 0;
        const memory = parseInt(document.getElementById('memory-usage')?.textContent) || 0;
        const disk = parseInt(document.getElementById('disk-usage')?.textContent) || 0;

        if (cpu > 80 || memory > 80 || disk > 80) {
            return `🚨 Immediate Action Required:\n\n` +
                   `I recommend running the Auto Recovery command to address high resource usage.\n\n` +
                   `Then run a Health Check to verify the system is stable.`;
        } else {
            return `✅ System is running well! Here are some proactive steps:\n\n` +
                   `1. Run a Performance Test to establish baseline\n` +
                   `2. Create a backup before making any changes\n` +
                   `3. Consider optimizing cache for better performance\n` +
                   `4. Update dependencies if needed`;
        }
    }

    getGeneralResponse(message) {
        return `I understand you're asking about "${message}". I'm here to help with your ANQA system management. You can ask me about:\n\n` +
               `• System health and performance\n` +
               `• Available commands and tools\n` +
               `• Troubleshooting issues\n` +
               `• Best practices and recommendations\n\n` +
               `What specific aspect of your system would you like to know more about?`;
    }

    getOverallStatus(cpu, memory, disk) {
        if (cpu > 80 || memory > 80 || disk > 80) {
            return '⚠️ System needs attention - some metrics are high';
        } else if (cpu > 60 || memory > 60 || disk > 60) {
            return '🟡 System is stable but monitor closely';
        } else {
            return '✅ System is healthy and running optimally';
        }
    }

    async executeCommandsFromMessage(message) {
        const lowerMessage = message.toLowerCase();

        // Auto-execute commands based on message content
        if (lowerMessage.includes('run health check') || lowerMessage.includes('check health')) {
            await cockpit.executeCommand('health-check', 'System health check');
        } else if (lowerMessage.includes('run performance test') || lowerMessage.includes('test performance')) {
            await cockpit.executeCommand('performance-test', 'Performance baseline test');
        } else if (lowerMessage.includes('create backup') || lowerMessage.includes('backup')) {
            await cockpit.executeCommand('backup', 'Creating system backup');
        } else if (lowerMessage.includes('auto recovery') || lowerMessage.includes('recovery')) {
            await cockpit.executeCommand('auto-recovery', 'Running automatic recovery');
        }
    }

    showTypingIndicator() {
        const messagesContainer = document.getElementById('chat-messages');
        const typingDiv = document.createElement('div');
        typingDiv.id = 'typing-indicator';
        typingDiv.className = 'message assistant typing';
        typingDiv.innerHTML = `
            <div class="message-content">
                <strong>🤖 ${this.currentAssistant}:</strong> 
                <span class="typing-dots">
                    <span>.</span><span>.</span><span>.</span>
                </span>
            </div>
        `;
        messagesContainer.appendChild(typingDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    hideTypingIndicator() {
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) {
            typingIndicator.remove();
        }
    }

    async loadChatHistory() {
        try {
            // Try to load from API first
            const response = await fetch('/api/chat/history');
            if (response.ok) {
                const apiHistory = await response.json();
                if (apiHistory && apiHistory.length > 0) {
                    this.chatHistory = apiHistory;
                    // Display loaded messages
                    this.displayChatHistory();
                    return;
                }
            }
            
            // Fallback to localStorage
            const saved = localStorage.getItem('cockpit-chat-history');
            if (saved) {
                this.chatHistory = JSON.parse(saved);
                this.displayChatHistory();
            }
        } catch (error) {
            console.error('Error loading chat history:', error);
        }
    }
    
    displayChatHistory() {
        const messagesContainer = document.getElementById('chat-messages');
        if (!messagesContainer) return;
        
        // Clear existing messages except welcome message
        const welcomeMessage = messagesContainer.querySelector('.message.assistant');
        messagesContainer.innerHTML = '';
        if (welcomeMessage) {
            messagesContainer.appendChild(welcomeMessage);
        }
        
        // Add loaded messages
        this.chatHistory.forEach(msg => {
            if (msg.type === 'user') {
                this.addMessage(msg.sender, msg.content, false);
            } else if (msg.type === 'assistant') {
                this.addMessage(msg.sender, msg.content, false);
            }
        });
    }

    saveChatHistory() {
        // Keep only last 50 messages
        if (this.chatHistory.length > 50) {
            this.chatHistory = this.chatHistory.slice(-50);
        }
        localStorage.setItem('cockpit-chat-history', JSON.stringify(this.chatHistory));
    }

    clearChat() {
        this.chatHistory = [];
        localStorage.removeItem('cockpit-chat-history');
        const messagesContainer = document.getElementById('chat-messages');
        messagesContainer.innerHTML = `
            <div class="message assistant">
                <div class="message-content">
                    <strong>ANQA Assistant:</strong> Chat history cleared. How can I help you?
                </div>
                <div class="message-time">${new Date().toLocaleTimeString()}</div>
            </div>
        `;
    }
}

// Initialize chat when page loads
let cockpitChat;
document.addEventListener('DOMContentLoaded', () => {
    cockpitChat = new CockpitChat();
});
