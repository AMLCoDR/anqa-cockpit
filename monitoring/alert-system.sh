#!/bin/bash
set -e

# ANQA Alert System - Automated Alerting & Notifications
# Monitors for critical issues and sends automated alerts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ALERT_LOG="alerts.log"
ALERT_HISTORY="alert-history.json"
NOTIFICATION_LOG="notifications.log"
CHECK_INTERVAL=60

# Alert thresholds
CRITICAL_CPU=90
WARNING_CPU=80
CRITICAL_MEMORY=85
WARNING_MEMORY=70
CRITICAL_DISK=95
WARNING_DISK=85
CRITICAL_RESPONSE_TIME=500
WARNING_RESPONSE_TIME=200

echo -e "${PURPLE}🚨 ANQA Alert System - Automated Alerting & Notifications${NC}"
echo "=============================================================="

# Function to log alert
log_alert() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local severity="$1"
    local category="$2"
    local message="$3"
    local value="$4"
    
    echo "$timestamp|$severity|$category|$message|$value" >> "$ALERT_LOG"
    
    # Update alert history
    update_alert_history "$severity" "$category" "$message" "$value"
}

# Function to update alert history
update_alert_history() {
    local severity="$1"
    local category="$2"
    local message="$3"
    local value="$4"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Create history file if it doesn't exist
    if [ ! -f "$ALERT_HISTORY" ]; then
        echo '{"alerts": []}' > "$ALERT_HISTORY"
    fi
    
    # Add alert to history
    local temp_file=$(mktemp)
    jq --arg timestamp "$timestamp" \
       --arg severity "$severity" \
       --arg category "$category" \
       --arg message "$message" \
       --arg value "$value" \
       '.alerts += [{
           timestamp: $timestamp,
           severity: $severity,
           category: $category,
           message: $message,
           value: $value
       }]' "$ALERT_HISTORY" > "$temp_file"
    mv "$temp_file" "$ALERT_HISTORY"
}

# Function to send notification
send_notification() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Log notification
    echo "$timestamp|$severity|$message" >> "$NOTIFICATION_LOG"
    
    # Display notification based on severity
    case "$severity" in
        "CRITICAL")
            echo -e "${RED}🚨 CRITICAL ALERT: $message${NC}"
            # Add sound alert for critical issues
            echo -e "\a"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO: $message${NC}"
            ;;
    esac
}

# Function to check system resources
check_system_resources() {
    echo -e "${BLUE}🔍 Checking system resources...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    if [ "$(echo "$cpu_usage >= $CRITICAL_CPU" | bc -l)" -eq 1 ]; then
        log_alert "CRITICAL" "CPU" "CPU usage critical" "$cpu_usage%"
        send_notification "CRITICAL" "CPU usage at $cpu_usage% - System may be overloaded"
    elif [ "$(echo "$cpu_usage >= $WARNING_CPU" | bc -l)" -eq 1 ]; then
        log_alert "WARNING" "CPU" "CPU usage high" "$cpu_usage%"
        send_notification "WARNING" "CPU usage at $cpu_usage% - Monitor system performance"
    fi
    
    # Memory usage
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    
    if [ "$memory_usage" -ge "$CRITICAL_MEMORY" ]; then
        log_alert "CRITICAL" "MEMORY" "Memory usage critical" "$memory_usage%"
        send_notification "CRITICAL" "Memory usage at $memory_usage% - System may become unresponsive"
    elif [ "$memory_usage" -ge "$WARNING_MEMORY" ]; then
        log_alert "WARNING" "MEMORY" "Memory usage high" "$memory_usage%"
        send_notification "WARNING" "Memory usage at $memory_usage% - Consider cleanup"
    fi
    
    # Disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -ge "$CRITICAL_DISK" ]; then
        log_alert "CRITICAL" "DISK" "Disk usage critical" "$disk_usage%"
        send_notification "CRITICAL" "Disk usage at $disk_usage% - System may fail"
    elif [ "$disk_usage" -ge "$WARNING_DISK" ]; then
        log_alert "WARNING" "DISK" "Disk usage high" "$disk_usage%"
        send_notification "WARNING" "Disk usage at $disk_usage% - Consider cleanup"
    fi
}

# Function to check service health
check_service_health() {
    echo -e "${BLUE}🔍 Checking service health...${NC}"
    
    # Check backend API
    local backend_start=$(date +%s%N)
    local backend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    local backend_end=$(date +%s%N)
    local backend_time=$(((backend_end - backend_start) / 1000000))
    
    if [ "$backend_response" != "200" ]; then
        log_alert "CRITICAL" "SERVICE" "Backend API down" "HTTP $backend_response"
        send_notification "CRITICAL" "Backend API is down (HTTP $backend_response)"
    elif [ "$backend_time" -ge "$CRITICAL_RESPONSE_TIME" ]; then
        log_alert "CRITICAL" "PERFORMANCE" "Backend response time critical" "${backend_time}ms"
        send_notification "CRITICAL" "Backend response time critical: ${backend_time}ms"
    elif [ "$backend_time" -ge "$WARNING_RESPONSE_TIME" ]; then
        log_alert "WARNING" "PERFORMANCE" "Backend response time slow" "${backend_time}ms"
        send_notification "WARNING" "Backend response time slow: ${backend_time}ms"
    fi
    
    # Check frontend
    local frontend_start=$(date +%s%N)
    local frontend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    local frontend_end=$(date +%s%N)
    local frontend_time=$(((frontend_end - frontend_start) / 1000000))
    
    if [ "$frontend_response" != "200" ]; then
        log_alert "CRITICAL" "SERVICE" "Frontend down" "HTTP $frontend_response"
        send_notification "CRITICAL" "Frontend is down (HTTP $frontend_response)"
    elif [ "$frontend_time" -ge 3000 ]; then
        log_alert "WARNING" "PERFORMANCE" "Frontend response time slow" "${frontend_time}ms"
        send_notification "WARNING" "Frontend response time slow: ${frontend_time}ms"
    fi
    
    # Check database
    if ! psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        log_alert "CRITICAL" "DATABASE" "Database connection failed" "disconnected"
        send_notification "CRITICAL" "Database connection failed"
    fi
}

# Function to check process status
check_process_status() {
    echo -e "${BLUE}🔍 Checking process status...${NC}"
    
    # Check Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)
    if [ "$node_processes" -eq 0 ]; then
        log_alert "CRITICAL" "PROCESS" "No Node.js processes running" "0 processes"
        send_notification "CRITICAL" "No Node.js processes running - Services may be down"
    elif [ "$node_processes" -gt 4 ]; then
        log_alert "WARNING" "PROCESS" "Too many Node.js processes" "$node_processes processes"
        send_notification "WARNING" "Too many Node.js processes: $node_processes"
    fi
    
    # Check PostgreSQL processes
    local postgres_processes=$(ps aux | grep postgres | grep -v grep | wc -l)
    if [ "$postgres_processes" -eq 0 ]; then
        log_alert "CRITICAL" "PROCESS" "No PostgreSQL processes running" "0 processes"
        send_notification "CRITICAL" "No PostgreSQL processes running - Database may be down"
    fi
    
    # Check port availability
    local ports_active=0
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            ports_active=$((ports_active + 1))
        fi
    done
    
    if [ "$ports_active" -lt 3 ]; then
        log_alert "CRITICAL" "PORTS" "Missing required ports" "$ports_active/3 active"
        send_notification "CRITICAL" "Missing required ports: only $ports_active/3 active"
    fi
}

# Function to check API endpoints
check_api_endpoints() {
    echo -e "${BLUE}🔍 Checking API endpoints...${NC}"
    
    local endpoints=(
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local response_time=$(((end_time - start_time) / 1000000))
        
        if [ "$response" != "200" ]; then
            log_alert "CRITICAL" "API" "API endpoint failed" "$endpoint - HTTP $response"
            send_notification "CRITICAL" "API endpoint failed: $endpoint (HTTP $response)"
        elif [ "$response_time" -ge "$CRITICAL_RESPONSE_TIME" ]; then
            log_alert "CRITICAL" "API" "API endpoint critical response time" "$endpoint - ${response_time}ms"
            send_notification "CRITICAL" "API endpoint critical response time: $endpoint (${response_time}ms)"
        elif [ "$response_time" -ge "$WARNING_RESPONSE_TIME" ]; then
            log_alert "WARNING" "API" "API endpoint slow response time" "$endpoint - ${response_time}ms"
            send_notification "WARNING" "API endpoint slow response time: $endpoint (${response_time}ms)"
        fi
    done
}

# Function to check database performance
check_database_performance() {
    echo -e "${BLUE}🔍 Checking database performance...${NC}"
    
    if command -v psql >/dev/null 2>&1; then
        # Check query performance
        local start_time=$(date +%s%N)
        psql -h localhost -p 5434 -d anqa_website -c "SELECT COUNT(*) FROM pages;" >/dev/null 2>&1
        local end_time=$(date +%s%N)
        local query_time=$(((end_time - start_time) / 1000000))
        
        if [ "$query_time" -ge 200 ]; then
            log_alert "CRITICAL" "DATABASE" "Database query critical response time" "${query_time}ms"
            send_notification "CRITICAL" "Database query critical response time: ${query_time}ms"
        elif [ "$query_time" -ge 100 ]; then
            log_alert "WARNING" "DATABASE" "Database query slow response time" "${query_time}ms"
            send_notification "WARNING" "Database query slow response time: ${query_time}ms"
        fi
        
        # Check active connections
        local connections=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' ')
        if [ "$connections" -gt 30 ]; then
            log_alert "WARNING" "DATABASE" "High database connections" "$connections connections"
            send_notification "WARNING" "High database connections: $connections"
        fi
    fi
}

# Function to check for error patterns
check_error_patterns() {
    echo -e "${BLUE}🔍 Checking for error patterns...${NC}"
    
    # Check for recent errors in logs
    if [ -f "backend.log" ]; then
        local recent_errors=$(tail -100 backend.log | grep -i "error\|exception\|failed" | wc -l)
        if [ "$recent_errors" -gt 10 ]; then
            log_alert "WARNING" "LOGS" "High error rate in backend logs" "$recent_errors errors"
            send_notification "WARNING" "High error rate in backend logs: $recent_errors errors"
        fi
    fi
    
    if [ -f "frontend.log" ]; then
        local recent_errors=$(tail -100 frontend.log | grep -i "error\|exception\|failed" | wc -l)
        if [ "$recent_errors" -gt 10 ]; then
            log_alert "WARNING" "LOGS" "High error rate in frontend logs" "$recent_errors errors"
            send_notification "WARNING" "High error rate in frontend logs: $recent_errors errors"
        fi
    fi
}

# Function to generate alert summary
generate_alert_summary() {
    echo -e "${PURPLE}📊 Alert Summary${NC}"
    echo "==============="
    
    if [ -f "$ALERT_LOG" ]; then
        # Count alerts by severity
        local critical_count=$(grep "|CRITICAL|" "$ALERT_LOG" | wc -l)
        local warning_count=$(grep "|WARNING|" "$ALERT_LOG" | wc -l)
        
        echo -e "${CYAN}Total alerts: $((critical_count + warning_count))${NC}"
        echo -e "${RED}Critical alerts: $critical_count${NC}"
        echo -e "${YELLOW}Warning alerts: $warning_count${NC}"
        
        # Show recent critical alerts
        if [ "$critical_count" -gt 0 ]; then
            echo -e "${RED}Recent critical alerts:${NC}"
            grep "|CRITICAL|" "$ALERT_LOG" | tail -3 | while IFS='|' read -r timestamp severity category message value; do
                echo -e "  ${YELLOW}$timestamp${NC} - ${RED}$category${NC}: $message ($value)"
            done
        fi
    else
        echo -e "${GREEN}✅ No alerts recorded${NC}"
    fi
}

# Function to show alert history
show_alert_history() {
    echo -e "${PURPLE}📋 Alert History${NC}"
    echo "==============="
    
    if [ -f "$ALERT_HISTORY" ]; then
        echo -e "${CYAN}Recent alerts:${NC}"
        jq -r '.alerts[-10:] | .[] | "\(.timestamp) - \(.severity) \(.category): \(.message) (\(.value))"' "$ALERT_HISTORY" 2>/dev/null | while read -r line; do
            if [[ "$line" =~ CRITICAL ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" =~ WARNING ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${BLUE}$line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No alert history found${NC}"
    fi
}

# Function to generate alert report
generate_alert_report() {
    echo -e "${PURPLE}📋 Generating alert report...${NC}"
    
    local report_file="alert-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Alert System Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================"
        echo ""
        
        echo "Alert Statistics:"
        echo "----------------"
        
        if [ -f "$ALERT_LOG" ]; then
            local total_alerts=$(wc -l < "$ALERT_LOG")
            local critical_alerts=$(grep "|CRITICAL|" "$ALERT_LOG" | wc -l)
            local warning_alerts=$(grep "|WARNING|" "$ALERT_LOG" | wc -l)
            
            echo "Total alerts: $total_alerts"
            echo "Critical alerts: $critical_alerts"
            echo "Warning alerts: $warning_alerts"
        else
            echo "No alerts recorded"
        fi
        
        echo ""
        echo "Current System Status:"
        echo "---------------------"
        
        # Current resource usage
        local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
        local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local total_memory=$(sysctl hw.memsize | awk '{print $2}')
        local free_memory=$((memory_info * 4096))
        local used_memory=$((total_memory - free_memory))
        local memory_usage=$((used_memory * 100 / total_memory))
        local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
        
        echo "CPU usage: $cpu_usage%"
        echo "Memory usage: $memory_usage%"
        echo "Disk usage: $disk_usage%"
        
        echo ""
        echo "Service Status:"
        echo "---------------"
        
        local backend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
        local frontend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
        local db_status=$(psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1 && echo "Connected" || echo "Disconnected")
        
        echo "Backend: HTTP $backend_status"
        echo "Frontend: HTTP $frontend_status"
        echo "Database: $db_status"
        
        echo ""
        echo "Recent Alerts:"
        echo "--------------"
        
        if [ -f "$ALERT_LOG" ]; then
            tail -10 "$ALERT_LOG" | while IFS='|' read -r timestamp severity category message value; do
                echo "$timestamp - $severity $category: $message ($value)"
            done
        fi
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Alert report generated: $report_file${NC}"
}

# Main monitoring loop
main() {
    local action="${1:-monitor}"
    
    case "$action" in
        "monitor")
            echo -e "${PURPLE}🚀 Starting ANQA Alert System...${NC}"
            echo -e "${CYAN}Check interval: ${YELLOW}${CHECK_INTERVAL} seconds${NC}"
            echo -e "${CYAN}Alert log: ${YELLOW}$ALERT_LOG${NC}"
            echo ""
            
            # Create log files if they don't exist
            touch "$ALERT_LOG"
            touch "$NOTIFICATION_LOG"
            
            # Start monitoring loop
            while true; do
                echo -e "${CYAN}=== Alert Check: $(date -u +"%Y-%m-%d %H:%M:%S UTC") ===${NC}"
                
                check_system_resources
                check_service_health
                check_process_status
                check_api_endpoints
                check_database_performance
                check_error_patterns
                
                generate_alert_summary
                echo ""
                
                sleep "$CHECK_INTERVAL"
            done
            ;;
        "history")
            show_alert_history
            ;;
        "report")
            generate_alert_report
            ;;
        "test")
            echo -e "${PURPLE}🧪 Testing alert system...${NC}"
            send_notification "CRITICAL" "This is a test critical alert"
            send_notification "WARNING" "This is a test warning alert"
            send_notification "INFO" "This is a test info alert"
            echo -e "${GREEN}✅ Test notifications sent${NC}"
            ;;
        *)
            echo -e "${PURPLE}ANQA Alert System - Usage${NC}"
            echo "============================="
            echo "  $0 monitor  - Start continuous monitoring"
            echo "  $0 history  - Show alert history"
            echo "  $0 report   - Generate alert report"
            echo "  $0 test     - Test notification system"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 monitor"
            echo "  $0 history"
            echo "  $0 test"
            ;;
    esac
}

# Handle script interruption
trap 'echo -e "\n${GREEN}✅ Alert system stopped${NC}"; exit 0' INT

# Run main function
main "$@"
