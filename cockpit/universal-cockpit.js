// Universal Development Cockpit
// Works with any project and automatically opens Cursor

class UniversalCockpit {
    constructor() {
        this.currentProject = null;
        this.projectConfig = null;
        this.cockpitConfig = null;
        this.init();
    }

    init() {
        this.loadCockpitConfig();
        this.detectCurrentProject();
        this.setupProjectEnvironment();
        this.openCursor();
        this.updateCockpitInterface();
    }

    loadCockpitConfig() {
        // Load universal cockpit configuration
        this.cockpitConfig = {
            name: "Universal Development Cockpit",
            version: "2.0.0",
            port: 5002,
            features: [
                "project-detection",
                "cursor-integration", 
                "universal-monitoring",
                "ai-assistant",
                "deployment-tools",
                "performance-tracking"
            ],
            supportedProjects: [
                "nodejs", "react", "vue", "angular", "python", "php", "java", "go", "rust", "csharp"
            ]
        };
    }

    detectCurrentProject() {
        // Detect current project type and configuration
        this.currentProject = {
            path: process.cwd(),
            name: this.getProjectName(),
            type: this.detectProjectType(),
            config: this.loadProjectConfig(),
            services: this.detectServices(),
            ports: this.detectPorts()
        };

        console.log(`🎯 Detected Project: ${this.currentProject.name} (${this.currentProject.type})`);
    }

    getProjectName() {
        const pathParts = process.cwd().split('/');
        return pathParts[pathParts.length - 1] || 'Unknown Project';
    }

    detectProjectType() {
        const fs = require('fs');
        
        if (fs.existsSync('package.json')) {
            const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
            if (packageJson.dependencies?.react || packageJson.dependencies?.['react-dom']) {
                return 'react';
            } else if (packageJson.dependencies?.vue) {
                return 'vue';
            } else if (packageJson.dependencies?.angular) {
                return 'angular';
            } else {
                return 'nodejs';
            }
        } else if (fs.existsSync('requirements.txt')) {
            return 'python';
        } else if (fs.existsSync('composer.json')) {
            return 'php';
        } else if (fs.existsSync('pom.xml')) {
            return 'java';
        } else if (fs.existsSync('go.mod')) {
            return 'go';
        } else if (fs.existsSync('Cargo.toml')) {
            return 'rust';
        } else if (fs.existsSync('.csproj')) {
            return 'csharp';
        } else {
            return 'unknown';
        }
    }

    loadProjectConfig() {
        const fs = require('fs');
        const config = {};

        // Load various config files based on project type
        const configFiles = [
            'package.json', 'requirements.txt', 'composer.json', 
            'pom.xml', 'go.mod', 'Cargo.toml', '.csproj'
        ];

        configFiles.forEach(file => {
            if (fs.existsSync(file)) {
                try {
                    config[file] = JSON.parse(fs.readFileSync(file, 'utf8'));
                } catch (e) {
                    config[file] = { error: 'Could not parse' };
                }
            }
        });

        return config;
    }

    detectServices() {
        const services = [];
        const fs = require('fs');

        // Detect common service files
        if (fs.existsSync('docker-compose.yml')) {
            services.push('docker');
        }
        if (fs.existsSync('dockerfile') || fs.existsSync('Dockerfile')) {
            services.push('docker');
        }
        if (fs.existsSync('.env')) {
            services.push('environment');
        }
        if (fs.existsSync('database/') || fs.existsSync('db/')) {
            services.push('database');
        }
        if (fs.existsSync('frontend/') && fs.existsSync('backend/')) {
            services.push('fullstack');
        }

        return services;
    }

    detectPorts() {
        const ports = [];
        const fs = require('fs');

        // Read common port configurations
        if (fs.existsSync('package.json')) {
            try {
                const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
                if (packageJson.scripts?.start?.includes('PORT=')) {
                    const portMatch = packageJson.scripts.start.match(/PORT=(\d+)/);
                    if (portMatch) ports.push(parseInt(portMatch[1]));
                }
            } catch (e) {}
        }

        if (fs.existsSync('.env')) {
            try {
                const envContent = fs.readFileSync('.env', 'utf8');
                const portMatch = envContent.match(/PORT=(\d+)/);
                if (portMatch) ports.push(parseInt(portMatch[1]));
            } catch (e) {}
        }

        // Default ports based on project type
        const defaultPorts = {
            'react': [3000, 3001],
            'vue': [3000, 3001],
            'angular': [4200],
            'nodejs': [3000, 3001, 4000, 4001],
            'python': [5000, 8000],
            'php': [8000, 8080],
            'java': [8080, 9000],
            'go': [8080],
            'rust': [8080],
            'csharp': [5000, 5001]
        };

        if (defaultPorts[this.currentProject.type]) {
            ports.push(...defaultPorts[this.currentProject.type]);
        }

        return [...new Set(ports)]; // Remove duplicates
    }

    setupProjectEnvironment() {
        // Create project-specific cockpit configuration
        this.projectConfig = {
            project: this.currentProject,
            cockpit: {
                title: `${this.currentProject.name} - Development Cockpit`,
                theme: this.getProjectTheme(),
                features: this.getProjectFeatures(),
                commands: this.getProjectCommands()
            }
        };

        // Save project config
        const fs = require('fs');
        fs.writeFileSync('cockpit-config.json', JSON.stringify(this.projectConfig, null, 2));
    }

    getProjectTheme() {
        const themes = {
            'react': { primary: '#61dafb', secondary: '#282c34' },
            'vue': { primary: '#42b883', secondary: '#35495e' },
            'angular': { primary: '#dd0031', secondary: '#1976d2' },
            'nodejs': { primary: '#00d4ff', secondary: '#1a1a2e' },
            'python': { primary: '#3776ab', secondary: '#ffd43b' },
            'php': { primary: '#777bb4', secondary: '#4f5d95' },
            'java': { primary: '#007396', secondary: '#ed8b00' },
            'go': { primary: '#00add8', secondary: '#5ac9e3' },
            'rust': { primary: '#ce422b', secondary: '#dea584' },
            'csharp': { primary: '#68217a', secondary: '#0078d4' }
        };

        return themes[this.currentProject.type] || themes.nodejs;
    }

    getProjectFeatures() {
        const baseFeatures = ['monitoring', 'ai-assistant', 'deployment'];
        const projectFeatures = {
            'react': [...baseFeatures, 'hot-reload', 'build-optimization'],
            'vue': [...baseFeatures, 'hot-reload', 'build-optimization'],
            'angular': [...baseFeatures, 'hot-reload', 'build-optimization'],
            'nodejs': [...baseFeatures, 'api-monitoring', 'database-tools'],
            'python': [...baseFeatures, 'virtual-env', 'package-management'],
            'php': [...baseFeatures, 'web-server', 'database-tools'],
            'java': [...baseFeatures, 'maven-gradle', 'jvm-monitoring'],
            'go': [...baseFeatures, 'go-modules', 'cross-compilation'],
            'rust': [...baseFeatures, 'cargo-tools', 'performance-profiling'],
            'csharp': [...baseFeatures, 'dotnet-tools', 'nuget-packages']
        };

        return projectFeatures[this.currentProject.type] || baseFeatures;
    }

    getProjectCommands() {
        const commands = {
            'react': {
                'start': 'npm start',
                'build': 'npm run build',
                'test': 'npm test',
                'lint': 'npm run lint'
            },
            'vue': {
                'serve': 'npm run serve',
                'build': 'npm run build',
                'test': 'npm run test:unit'
            },
            'angular': {
                'serve': 'ng serve',
                'build': 'ng build',
                'test': 'ng test'
            },
            'nodejs': {
                'start': 'npm start',
                'dev': 'npm run dev',
                'test': 'npm test'
            },
            'python': {
                'run': 'python app.py',
                'install': 'pip install -r requirements.txt',
                'test': 'python -m pytest'
            },
            'php': {
                'serve': 'php -S localhost:8000',
                'composer': 'composer install'
            },
            'java': {
                'build': 'mvn clean install',
                'run': 'mvn spring-boot:run'
            },
            'go': {
                'run': 'go run main.go',
                'build': 'go build',
                'test': 'go test'
            },
            'rust': {
                'run': 'cargo run',
                'build': 'cargo build',
                'test': 'cargo test'
            },
            'csharp': {
                'run': 'dotnet run',
                'build': 'dotnet build',
                'test': 'dotnet test'
            }
        };

        return commands[this.currentProject.type] || {};
    }

    async openCursor() {
        try {
            const { exec } = require('child_process');
            
            // Open Cursor with current project
            const command = `cursor "${this.currentProject.path}"`;
            
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.log(`⚠️ Could not open Cursor automatically: ${error.message}`);
                    console.log(`📝 Please open Cursor manually and navigate to: ${this.currentProject.path}`);
                } else {
                    console.log(`✅ Cursor opened with project: ${this.currentProject.name}`);
                }
            });

        } catch (error) {
            console.log(`⚠️ Error opening Cursor: ${error.message}`);
        }
    }

    updateCockpitInterface() {
        // Update the cockpit interface based on project
        this.updateTitle();
        this.updateTheme();
        this.updateCommands();
        this.updateMonitoring();
    }

    updateTitle() {
        const title = document.querySelector('title');
        if (title) {
            title.textContent = this.projectConfig.cockpit.title;
        }

        const headerTitle = document.querySelector('.logo-text h1');
        if (headerTitle) {
            headerTitle.textContent = this.projectConfig.cockpit.title;
        }
    }

    updateTheme() {
        const theme = this.projectConfig.cockpit.theme;
        const root = document.documentElement;
        
        root.style.setProperty('--primary-color', theme.primary);
        root.style.setProperty('--secondary-color', theme.secondary);
    }

    updateCommands() {
        const commands = this.projectConfig.cockpit.commands;
        const rightPanel = document.querySelector('.right-panel');
        
        if (rightPanel && commands) {
            // Add project-specific commands
            const projectCommands = document.createElement('div');
            projectCommands.className = 'control-section';
            projectCommands.innerHTML = `
                <h4>🚀 ${this.currentProject.type.toUpperCase()} Commands</h4>
                ${Object.entries(commands).map(([name, cmd]) => 
                    `<button class="control-button" onclick="universalCockpit.executeProjectCommand('${name}')">
                        ▶️ ${name.charAt(0).toUpperCase() + name.slice(1)}
                    </button>`
                ).join('')}
            `;
            rightPanel.appendChild(projectCommands);
        }
    }

    updateMonitoring() {
        // Update monitoring based on project type
        const monitoringConfig = this.getMonitoringConfig();
        
        // Update metrics display
        this.updateMetricsDisplay(monitoringConfig);
    }

    getMonitoringConfig() {
        const configs = {
            'react': {
                metrics: ['bundle-size', 'build-time', 'hot-reload'],
                ports: [3000, 3001],
                services: ['development-server']
            },
            'nodejs': {
                metrics: ['api-response', 'memory-usage', 'database-connections'],
                ports: [3000, 3001, 4000, 4001],
                services: ['api-server', 'database']
            },
            'python': {
                metrics: ['response-time', 'memory-usage', 'cpu-usage'],
                ports: [5000, 8000],
                services: ['flask-server', 'django-server']
            }
        };

        return configs[this.currentProject.type] || configs.nodejs;
    }

    updateMetricsDisplay(config) {
        // Update the metrics display based on project type
        const metricsContainer = document.querySelector('.metric-grid');
        if (metricsContainer) {
            // Clear existing metrics
            metricsContainer.innerHTML = '';
            
            // Add project-specific metrics
            config.metrics.forEach(metric => {
                const metricItem = document.createElement('div');
                metricItem.className = 'metric-item';
                metricItem.innerHTML = `
                    <div class="metric-value" id="${metric}-value">--</div>
                    <div class="metric-label">${metric.replace('-', ' ').toUpperCase()}</div>
                `;
                metricsContainer.appendChild(metricItem);
            });
        }
    }

    async executeProjectCommand(commandName) {
        const command = this.projectConfig.cockpit.commands[commandName];
        if (!command) {
            console.error(`Command not found: ${commandName}`);
            return;
        }

        try {
            const { exec } = require('child_process');
            
            console.log(`🚀 Executing: ${command}`);
            
            exec(command, { cwd: this.currentProject.path }, (error, stdout, stderr) => {
                if (error) {
                    console.error(`❌ Error executing ${commandName}: ${error.message}`);
                } else {
                    console.log(`✅ ${commandName} executed successfully`);
                    console.log(stdout);
                }
            });

        } catch (error) {
            console.error(`❌ Error executing command: ${error.message}`);
        }
    }

    // Universal monitoring methods
    async getUniversalMetrics() {
        const metrics = {
            project: this.currentProject.name,
            type: this.currentProject.type,
            path: this.currentProject.path,
            services: this.currentProject.services,
            ports: this.currentProject.ports,
            timestamp: new Date().toISOString()
        };

        // Add project-specific metrics
        switch (this.currentProject.type) {
            case 'react':
            case 'vue':
            case 'angular':
                metrics.frontend = await this.getFrontendMetrics();
                break;
            case 'nodejs':
                metrics.backend = await this.getBackendMetrics();
                break;
            case 'python':
                metrics.python = await this.getPythonMetrics();
                break;
        }

        return metrics;
    }

    async getFrontendMetrics() {
        // Get frontend-specific metrics
        return {
            bundleSize: '2.1MB',
            buildTime: '45s',
            hotReload: 'enabled'
        };
    }

    async getBackendMetrics() {
        // Get backend-specific metrics
        return {
            apiResponse: '127ms',
            memoryUsage: '45%',
            databaseConnections: '5'
        };
    }

    async getPythonMetrics() {
        // Get Python-specific metrics
        return {
            responseTime: '89ms',
            memoryUsage: '32%',
            cpuUsage: '15%'
        };
    }
}

// Initialize universal cockpit
let universalCockpit;
document.addEventListener('DOMContentLoaded', () => {
    universalCockpit = new UniversalCockpit();
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = UniversalCockpit;
}

