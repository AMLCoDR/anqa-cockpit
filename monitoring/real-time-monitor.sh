#!/bin/bash
set -e

# ANQA Real-Time Monitor - Live System Monitoring
# Continuously monitors system health, performance, and alerts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MONITOR_LOG="monitor.log"
ALERT_LOG="alerts.log"
METRICS_FILE="metrics.json"
CHECK_INTERVAL=30
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=70
ALERT_THRESHOLD_RESPONSE_TIME=200

echo -e "${PURPLE}📊 ANQA Real-Time Monitor - Live System Monitoring${NC}"
echo "=========================================================="

# Function to log metrics
log_metrics() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local metrics="$1"
    echo "$timestamp|$metrics" >> "$MONITOR_LOG"
}

# Function to log alerts
log_alert() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local alert_type="$1"
    local message="$2"
    local severity="$3"
    
    echo -e "${RED}🚨 ALERT: $alert_type - $message${NC}"
    echo "$timestamp|$alert_type|$severity|$message" >> "$ALERT_LOG"
}

# Function to check system resources
check_system_resources() {
    echo -e "${BLUE}🔍 Checking system resources...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    echo -e "  ${CYAN}CPU: ${YELLOW}${cpu_usage}%${NC}"
    
    if [ "$(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l)" -eq 1 ]; then
        log_alert "HIGH_CPU" "CPU usage at ${cpu_usage}%" "WARNING"
    fi
    
    # Memory usage
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    
    echo -e "  ${CYAN}Memory: ${YELLOW}${memory_usage}%${NC}"
    
    if [ "$memory_usage" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        log_alert "HIGH_MEMORY" "Memory usage at ${memory_usage}%" "WARNING"
    fi
    
    # Disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    echo -e "  ${CYAN}Disk: ${YELLOW}${disk_usage}%${NC}"
    
    if [ "$disk_usage" -gt 90 ]; then
        log_alert "HIGH_DISK" "Disk usage at ${disk_usage}%" "CRITICAL"
    fi
    
    # Log metrics
    log_metrics "system|cpu:$cpu_usage|memory:$memory_usage|disk:$disk_usage"
}

# Function to check service health
check_service_health() {
    echo -e "${BLUE}🔍 Checking service health...${NC}"
    
    # Check backend API
    local backend_start=$(date +%s%N)
    local backend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    local backend_end=$(date +%s%N)
    local backend_time=$(((backend_end - backend_start) / 1000000))
    
    if [ "$backend_response" = "200" ]; then
        echo -e "  ${GREEN}✅ Backend API: ${YELLOW}${backend_time}ms${NC}"
        if [ "$backend_time" -gt "$ALERT_THRESHOLD_RESPONSE_TIME" ]; then
            log_alert "SLOW_BACKEND" "Backend response time: ${backend_time}ms" "WARNING"
        fi
    else
        echo -e "  ${RED}❌ Backend API: HTTP $backend_response${NC}"
        log_alert "BACKEND_DOWN" "Backend API not responding" "CRITICAL"
    fi
    
    # Check frontend
    local frontend_start=$(date +%s%N)
    local frontend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    local frontend_end=$(date +%s%N)
    local frontend_time=$(((frontend_end - frontend_start) / 1000000))
    
    if [ "$frontend_response" = "200" ]; then
        echo -e "  ${GREEN}✅ Frontend: ${YELLOW}${frontend_time}ms${NC}"
        if [ "$frontend_time" -gt 2000 ]; then
            log_alert "SLOW_FRONTEND" "Frontend response time: ${frontend_time}ms" "WARNING"
        fi
    else
        echo -e "  ${RED}❌ Frontend: HTTP $frontend_response${NC}"
        log_alert "FRONTEND_DOWN" "Frontend not responding" "CRITICAL"
    fi
    
    # Check database
    if psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Database: Connected${NC}"
    else
        echo -e "  ${RED}❌ Database: Connection failed${NC}"
        log_alert "DATABASE_DOWN" "Database connection failed" "CRITICAL"
    fi
    
    # Log metrics
    log_metrics "services|backend:$backend_time|frontend:$frontend_time|backend_status:$backend_response|frontend_status:$frontend_response"
}

# Function to check process status
check_process_status() {
    echo -e "${BLUE}🔍 Checking process status...${NC}"
    
    # Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)
    echo -e "  ${CYAN}Node.js processes: ${YELLOW}$node_processes${NC}"
    
    if [ "$node_processes" -eq 0 ]; then
        log_alert "NO_NODE_PROCESSES" "No Node.js processes running" "CRITICAL"
    elif [ "$node_processes" -gt 4 ]; then
        log_alert "TOO_MANY_NODE_PROCESSES" "$node_processes Node.js processes running" "WARNING"
    fi
    
    # PostgreSQL processes
    local postgres_processes=$(ps aux | grep postgres | grep -v grep | wc -l)
    echo -e "  ${CYAN}PostgreSQL processes: ${YELLOW}$postgres_processes${NC}"
    
    if [ "$postgres_processes" -eq 0 ]; then
        log_alert "NO_POSTGRES_PROCESSES" "No PostgreSQL processes running" "CRITICAL"
    fi
    
    # Port usage
    local ports_active=0
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            ports_active=$((ports_active + 1))
        fi
    done
    echo -e "  ${CYAN}Active ports: ${YELLOW}$ports_active/3${NC}"
    
    if [ "$ports_active" -lt 3 ]; then
        log_alert "MISSING_PORTS" "Only $ports_active/3 required ports active" "WARNING"
    fi
    
    # Log metrics
    log_metrics "processes|node:$node_processes|postgres:$postgres_processes|ports:$ports_active"
}

# Function to check API endpoints
check_api_endpoints() {
    echo -e "${BLUE}🔍 Checking API endpoints...${NC}"
    
    local endpoints=(
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    local total_time=0
    local count=0
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local response_time=$(((end_time - start_time) / 1000000))
        
        if [ "$response" = "200" ]; then
            echo -e "  ${GREEN}✅ $endpoint: ${YELLOW}${response_time}ms${NC}"
            total_time=$((total_time + response_time))
            count=$((count + 1))
            
            if [ "$response_time" -gt "$ALERT_THRESHOLD_RESPONSE_TIME" ]; then
                log_alert "SLOW_API" "$endpoint response time: ${response_time}ms" "WARNING"
            fi
        else
            echo -e "  ${RED}❌ $endpoint: HTTP $response${NC}"
            log_alert "API_ERROR" "$endpoint returned HTTP $response" "ERROR"
        fi
    done
    
    if [ "$count" -gt 0 ]; then
        local avg_time=$((total_time / count))
        echo -e "  ${PURPLE}📊 Average API response time: ${YELLOW}${avg_time}ms${NC}"
        log_metrics "api|avg_response_time:$avg_time|endpoints_checked:$count"
    fi
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
        
        echo -e "  ${CYAN}Query time: ${YELLOW}${query_time}ms${NC}"
        
        if [ "$query_time" -gt 100 ]; then
            log_alert "SLOW_DATABASE" "Database query time: ${query_time}ms" "WARNING"
        fi
        
        # Check database size
        local db_size=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT pg_size_pretty(pg_database_size('anqa_website'));" 2>/dev/null | tr -d ' ')
        echo -e "  ${CYAN}Database size: ${YELLOW}$db_size${NC}"
        
        # Check active connections
        local connections=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' ')
        echo -e "  ${CYAN}Active connections: ${YELLOW}$connections${NC}"
        
        if [ "$connections" -gt 20 ]; then
            log_alert "HIGH_DB_CONNECTIONS" "$connections active database connections" "WARNING"
        fi
        
        # Log metrics
        log_metrics "database|query_time:$query_time|size:$db_size|connections:$connections"
    else
        echo -e "  ${YELLOW}⚠️  PostgreSQL client not available${NC}"
    fi
}

# Function to generate metrics summary
generate_metrics_summary() {
    echo -e "${PURPLE}📊 Metrics Summary${NC}"
    echo "================"
    
    if [ -f "$MONITOR_LOG" ]; then
        # Get latest metrics
        local latest_metrics=$(tail -1 "$MONITOR_LOG" | cut -d'|' -f2)
        echo -e "${CYAN}Latest metrics: $latest_metrics${NC}"
        
        # Count alerts in last hour
        local recent_alerts=$(grep "$(date -d '1 hour ago' +"%Y-%m-%d %H")" "$ALERT_LOG" 2>/dev/null | wc -l || echo "0")
        echo -e "${CYAN}Alerts in last hour: $recent_alerts${NC}"
        
        # System uptime
        local uptime=$(uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')
        echo -e "${CYAN}System uptime: $uptime${NC}"
    else
        echo -e "${YELLOW}⚠️  No metrics data available${NC}"
    fi
}

# Function to save metrics to JSON
save_metrics_json() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Get current metrics
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Check service status
    local backend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    local frontend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    local db_status=$(psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1 && echo "connected" || echo "disconnected")
    
    # Create JSON metrics
    local metrics_json='{
        "timestamp": "'$timestamp'",
        "system": {
            "cpu_usage": '$cpu_usage',
            "memory_usage": '$memory_usage',
            "disk_usage": '$disk_usage'
        },
        "services": {
            "backend": "'$backend_status'",
            "frontend": "'$frontend_status'",
            "database": "'$db_status'"
        },
        "processes": {
            "node": '$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)',
            "postgres": '$(ps aux | grep postgres | grep -v grep | wc -l)'
        }
    }'
    
    echo "$metrics_json" > "$METRICS_FILE"
}

# Function to display real-time dashboard
display_dashboard() {
    clear
    echo -e "${PURPLE}📊 ANQA Real-Time Monitor Dashboard${NC}"
    echo "============================================="
    echo -e "${CYAN}Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}"
    echo ""
    
    # System resources
    echo -e "${BLUE}🖥️  System Resources${NC}"
    echo "-----------------"
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo -e "CPU:    ${YELLOW}${cpu_usage}%${NC}"
    echo -e "Memory: ${YELLOW}${memory_usage}%${NC}"
    echo -e "Disk:   ${YELLOW}${disk_usage}%${NC}"
    echo ""
    
    # Service status
    echo -e "${BLUE}🔧 Service Status${NC}"
    echo "---------------"
    local backend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    local frontend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    local db_status=$(psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1 && echo "connected" || echo "disconnected")
    
    if [ "$backend_status" = "200" ]; then
        echo -e "Backend:  ${GREEN}✅ Online${NC}"
    else
        echo -e "Backend:  ${RED}❌ Offline${NC}"
    fi
    
    if [ "$frontend_status" = "200" ]; then
        echo -e "Frontend: ${GREEN}✅ Online${NC}"
    else
        echo -e "Frontend: ${RED}❌ Offline${NC}"
    fi
    
    if [ "$db_status" = "connected" ]; then
        echo -e "Database: ${GREEN}✅ Connected${NC}"
    else
        echo -e "Database: ${RED}❌ Disconnected${NC}"
    fi
    echo ""
    
    # Recent alerts
    echo -e "${BLUE}🚨 Recent Alerts${NC}"
    echo "---------------"
    if [ -f "$ALERT_LOG" ]; then
        tail -5 "$ALERT_LOG" | while IFS='|' read -r timestamp alert_type severity message; do
            echo -e "${YELLOW}$timestamp${NC} - ${RED}$alert_type${NC}: $message"
        done
    else
        echo -e "${GREEN}✅ No recent alerts${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}Press Ctrl+C to stop monitoring${NC}"
}

# Main monitoring loop
main() {
    echo -e "${PURPLE}🚀 Starting ANQA Real-Time Monitor...${NC}"
    echo -e "${CYAN}Monitoring interval: ${YELLOW}${CHECK_INTERVAL} seconds${NC}"
    echo -e "${CYAN}Log files: ${YELLOW}$MONITOR_LOG${NC} and ${YELLOW}$ALERT_LOG${NC}"
    echo ""
    
    # Create log files if they don't exist
    touch "$MONITOR_LOG"
    touch "$ALERT_LOG"
    
    # Initial check
    echo -e "${BLUE}🔍 Running initial system check...${NC}"
    check_system_resources
    check_service_health
    check_process_status
    check_api_endpoints
    check_database_performance
    echo ""
    
    # Start monitoring loop
    while true; do
        # Display dashboard
        display_dashboard
        
        # Run all checks
        check_system_resources
        check_service_health
        check_process_status
        check_api_endpoints
        check_database_performance
        
        # Save metrics to JSON
        save_metrics_json
        
        # Generate summary
        generate_metrics_summary
        
        # Wait for next check
        sleep "$CHECK_INTERVAL"
    done
}

# Handle script interruption
trap 'echo -e "\n${GREEN}✅ Monitoring stopped${NC}"; exit 0' INT

# Run main function
main "$@"
