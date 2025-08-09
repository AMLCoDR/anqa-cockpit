# ANQA Cockpit - AI Development Monitoring System

[![Deploy ANQA Cockpit](https://github.com/AMLCoDR/anqa-cockpit/actions/workflows/deploy.yml/badge.svg)](https://github.com/AMLCoDR/anqa-cockpit/actions/workflows/deploy.yml)
[![Security Scan](https://github.com/AMLCoDR/anqa-cockpit/actions/workflows/security-scan.yml/badge.svg)](https://github.com/AMLCoDR/anqa-cockpit/actions/workflows/security-scan.yml)

> **A comprehensive AI development monitoring and management cockpit with real-time oversight, milestone tracking, and integrated development tools.**

## 🚀 Live Demo

- **Cockpit Dashboard:** [https://amlcodr.github.io/anqa-cockpit](https://amlcodr.github.io/anqa-cockpit)

## ✨ Features

### 🤖 AI Development Monitor
- **Real-time file monitoring** with intelligent change detection across development directories
- **Milestone tracking** with visual progress indicators and phase-based organization
- **Cursor IDE integration** with command bridge system for seamless workflow
- **Regression detection** and automated alerting for test failures

### 🎛️ Cockpit Dashboard
- **Live system monitoring** (CPU, memory, disk, network status)
- **Two-way chat integration** with autonomous AI responses
- **File oversight dashboard** with activity tracking and important file detection
- **Emergency controls** and automated recovery procedures

### 📊 Project Management
- **Visual milestone timeline** with completion tracking
- **Progress metrics** showing completed, in-progress, and pending tasks
- **Command history** and integration status monitoring
- **Performance monitoring** and system optimization

### 🔒 Data Protection
- **GitHub-based deployment** for secure hosting and version control
- **Automated backups** with comprehensive data protection
- **Security scanning** and vulnerability detection
- **Environment-based configuration** for sensitive data management

## 📁 Project Structure

```
system-optimization/
├── .github/
│   └── workflows/          # GitHub Actions for CI/CD
│       ├── deploy.yml      # Deployment pipeline
│       └── security-scan.yml # Security monitoring
├── cockpit/               # Main cockpit system
│   ├── index.html         # Cockpit dashboard interface
│   ├── cockpit-api.js     # Backend API server
│   ├── file-monitor.js    # Real-time file monitoring
│   ├── milestone-database.js # Milestone tracking system
│   ├── command-bridge.js  # Cursor integration
│   └── chat-integration.js # AI chat system
├── monitoring/            # System monitoring tools
├── performance/          # Performance optimization
├── deployment/           # Deployment scripts
└── error-mitigation/     # Error handling and recovery
```

## 🛠 Installation & Setup

### Prerequisites
- Node.js 18+ 
- npm 8+

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/AMLCoDR/anqa-cockpit.git
   cd anqa-cockpit
   ```

2. **Install dependencies**
   ```bash
   cd cockpit
   npm install
   ```

3. **Start the cockpit system**
   ```bash
   ./start-cockpit.sh
   ```

4. **Access the cockpit**
   - Dashboard: http://localhost:5002
   - API Status: http://localhost:5002/api/status
   - File Monitoring: http://localhost:5002/api/files/recent

## 🎯 Usage

### Cockpit Dashboard
1. Open http://localhost:5002 in your browser
2. Navigate through the enhanced AI Development Monitor with three tabs:
   - **📁 Files:** Monitor real-time file changes across development directories
   - **🎯 Progress:** Track project milestones with visual progress indicators
   - **🔗 Commands:** Use Cursor IDE integration and view command history

### Cursor IDE Integration
1. Open your project in Cursor IDE
2. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
3. Type "Tasks: Run Task"
4. Select from available ANQA commands:
   - **ANQA: Mark Task as Complete**
   - **ANQA: Mark Test as Passed/Failed**
   - **ANQA: Start/Complete Milestone**
   - **ANQA: Open Cockpit Dashboard**

### File Monitoring
- Automatically monitors development directories for changes
- Highlights important files (.js, .json, .md, .sql, .sh)
- Shows real-time activity with timestamps and change types
- Categorizes file operations (CREATED, MODIFIED, DELETED)

### Milestone Tracking
- Visual progress metrics showing completed, in-progress, and pending milestones
- Phase-based organization (Phase 1-4) with status indicators
- Integration with command bridge for automated progress updates
- Regression detection for test failures and system issues

## 🔒 Security & Data Protection

### Automated Security
- **Daily security scans** checking for vulnerabilities
- **Sensitive data detection** preventing credential exposure
- **Dependency auditing** for known security issues
- **File permissions validation** ensuring proper access

### Environment Configuration
- **No hardcoded credentials** in repository
- **Environment variable** based configuration
- **GitHub Secrets** for sensitive deployment data
- **Local .env files** for development (excluded from Git)

## 📈 System Monitoring

### Real-time Metrics
- CPU, memory, disk, and network status monitoring
- API response times and performance tracking
- WebSocket connections for live updates
- Health checks and system status validation

### Development Analytics
- File change frequency and patterns
- Milestone completion tracking
- Command usage statistics from Cursor integration
- Error detection and regression analysis

## 🚀 Deployment

The cockpit automatically deploys to GitHub Pages when changes are pushed to the `main` branch.

### Manual Deployment
```bash
# Build and deploy
npm run build
npm run deploy
```

### Environment Variables
Set these in GitHub repository settings > Secrets:
- `GITHUB_TOKEN` (automatically provided)
- Any custom API endpoints or configurations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Roadmap

### ✅ Completed Features
- [x] Cockpit system development with real-time monitoring
- [x] Two-way chat integration with autonomous AI responses
- [x] File oversight system with intelligent change detection
- [x] Milestone database with progress tracking
- [x] Cursor command bridge for IDE integration
- [x] Regression detection and alerting system
- [x] Enhanced UI with tabbed interface
- [x] GitHub deployment pipeline with data protection

### 🎯 Future Enhancements
- [ ] Advanced analytics dashboard with detailed metrics
- [ ] Multi-project support for managing multiple codebases
- [ ] API integrations with external development tools
- [ ] Mobile-responsive design for on-the-go monitoring
- [ ] Team collaboration features and shared dashboards

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues:** [GitHub Issues](https://github.com/AMLCoDR/anqa-cockpit/issues)
- **Discussions:** [GitHub Discussions](https://github.com/AMLCoDR/anqa-cockpit/discussions)

## 🙏 Acknowledgments

- Built for AI development workflow optimization
- Integrated with Cursor IDE for enhanced productivity
- Deployed on GitHub Pages for reliable hosting
- Secured with automated monitoring and protection

---

**Version:** 1.0.0  
**Status:** Production Ready - AI Development Monitoring System  
**Repository:** [https://github.com/AMLCoDR/anqa-cockpit](https://github.com/AMLCoDR/anqa-cockpit)