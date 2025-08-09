# 🚀 ANQA System Cockpit - Mission Control

A comprehensive web-based dashboard for monitoring, managing, and controlling your ANQA system. Think of it as your mission control center for "flying the plane."

## 🎯 Overview

The ANQA Cockpit provides a single-screen interface to:

- **📊 Monitor** system health in real-time
- **🔧 Execute** maintenance tasks with one click
- **🚨 Respond** to emergencies instantly
- **📈 Track** performance metrics
- **📝 View** live system logs
- **🚀 Deploy** and manage services

## 🚀 Quick Start

### 1. Start the Cockpit

```bash
cd system-optimization/cockpit
chmod +x start-cockpit.sh
./start-cockpit.sh
```

### 2. Access the Dashboard

Open your browser and navigate to:
```
http://localhost:5002
```

## 🎮 Dashboard Features

### 📊 **Left Panel - System Status**
- **CPU Usage**: Real-time CPU monitoring with color-coded alerts
- **Memory Usage**: Memory consumption tracking
- **Disk Usage**: Storage utilization monitoring
- **Network Status**: Connection health
- **Service Status**: Frontend, Backend, and Database status

### 🎯 **Center Panel - Main Dashboard**
- **Performance Metrics**: API response times, page load times, database queries
- **System Health**: Error counts, warnings, active processes, cache hit rates
- **Real-time Monitoring**: Live charts and graphs
- **Recent Activity**: System events timeline

### 🔧 **Right Panel - Controls**
- **Quick Actions**: Health checks, performance tests, backups, reports
- **Maintenance**: Dependency updates, cache optimization, config validation
- **Emergency Controls**: Auto recovery, service restart, emergency rollback

### 📝 **Bottom Panel - Logs & Alerts**
- **System Logs**: Real-time log streaming
- **Active Alerts**: Current warnings and critical issues
- **Quick Stats**: Key performance indicators

## 🔧 API Endpoints

The cockpit is powered by a REST API running on port 5002:

### System Metrics
```bash
GET /api/metrics          # Get all system metrics
GET /api/status           # Get overall system status
```

### Command Execution
```bash
POST /api/execute         # Execute cockpit commands
```

### Logs and Alerts
```bash
GET /api/logs             # Get system logs
GET /api/alerts           # Get active alerts
```

## 🎮 Control Commands

### Quick Actions
- **Health Check**: Run comprehensive system health check
- **Performance Test**: Execute performance baseline testing
- **Create Backup**: Generate full system backup
- **System Report**: Generate detailed system report

### Maintenance
- **Update Dependencies**: Update all system dependencies
- **Optimize Cache**: Run cache optimization
- **Validate Config**: Check configuration compliance
- **Analyze Logs**: Perform log analysis

### Emergency Controls
- **Auto Recovery**: Run automatic error recovery
- **Restart Services**: Safely restart all services
- **Emergency Rollback**: Rollback to last known good state
- **Emergency Stop**: Stop all system services

## 🎨 UI Features

### 🎯 **Real-time Updates**
- Metrics update every 5 seconds
- Live log streaming
- Instant status changes
- Color-coded alerts

### 🎨 **Modern Design**
- Dark theme optimized for monitoring
- Responsive layout
- Smooth animations
- Professional cockpit aesthetic

### 📱 **Responsive**
- Works on desktop, tablet, and mobile
- Adaptive layout for different screen sizes
- Touch-friendly controls

## 🔧 Technical Details

### Architecture
- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Backend**: Node.js with Express
- **Real-time**: Polling-based updates
- **API**: RESTful JSON endpoints

### Dependencies
```json
{
  "express": "^4.18.2",
  "cors": "^2.8.5"
}
```

### Port Configuration
- **Dashboard**: Port 5002
- **API**: Port 5002
- **Static Files**: Served from same port

## 🚀 Advanced Usage

### Custom Commands
You can extend the cockpit by adding new commands to `cockpit-api.js`:

```javascript
case 'custom-command':
    result = await executeCustomCommand();
    break;
```

### Custom Metrics
Add new metrics by extending the `updateSystemMetrics()` function:

```javascript
// Add custom metric
systemMetrics.custom = await getCustomMetric();
```

### Custom Alerts
Define new alert conditions in the `/api/alerts` endpoint:

```javascript
if (systemMetrics.custom > threshold) {
    alerts.push({
        type: 'warning',
        message: 'Custom alert message',
        timestamp: new Date().toISOString()
    });
}
```

## 🔒 Security Considerations

- **Local Access**: Dashboard runs on localhost only
- **No Authentication**: Designed for local system management
- **Command Validation**: All commands are validated before execution
- **Error Handling**: Comprehensive error handling and logging

## 🛠️ Troubleshooting

### Common Issues

**Port 5002 Already in Use**
```bash
# Find and kill the process
lsof -ti:5002 | xargs kill -9
```

**Dashboard Not Loading**
```bash
# Check if API is running
curl http://localhost:5002/api/status
```

**Commands Not Working**
```bash
# Check system-optimization scripts are executable
chmod +x ../error-mitigation/*.sh
chmod +x ../performance/*.sh
chmod +x ../deployment/*.sh
```

### Logs
- **API Logs**: Check console output when starting cockpit
- **System Logs**: Available in the dashboard bottom panel
- **Error Logs**: Displayed in real-time on the dashboard

## 🎯 Best Practices

### Daily Operations
1. **Start cockpit** at the beginning of your work session
2. **Monitor metrics** regularly throughout the day
3. **Run health checks** before making changes
4. **Create backups** before deployments
5. **Use emergency controls** only when necessary

### Maintenance Schedule
- **Daily**: Quick health check, monitor alerts
- **Weekly**: Performance tests, dependency updates
- **Monthly**: Full system reports, configuration validation

### Emergency Procedures
1. **Assess the situation** using dashboard metrics
2. **Try auto recovery** first
3. **Use emergency rollback** if needed
4. **Restart services** as a last resort
5. **Monitor recovery** through the dashboard

## 🚀 Future Enhancements

### Planned Features
- **WebSocket Support**: Real-time bidirectional communication
- **User Authentication**: Multi-user support with roles
- **Custom Dashboards**: User-configurable layouts
- **Mobile App**: Native mobile application
- **Integration**: Third-party monitoring tools
- **Analytics**: Historical data analysis
- **Notifications**: Email/SMS alerts

### Extensibility
- **Plugin System**: Custom command plugins
- **API Extensions**: Additional endpoints
- **Custom Metrics**: User-defined monitoring
- **Theme Support**: Customizable UI themes

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review system logs in the dashboard
3. Verify all system-optimization scripts are working
4. Ensure proper permissions on all files

---

**🎮 Ready to fly the plane? Start the cockpit and take control of your ANQA system!**
