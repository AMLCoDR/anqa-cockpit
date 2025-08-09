#!/bin/bash
set -e

# ANQA Health Monitor - Real-Time System Health Monitoring
# Continuously monitors system health and provides real-time status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
HEALTH_LOG="health-monitor.log"
HEALTH_STATUS="health-status.json"
MONITOR_INTERVAL=30
ALERT_THRESHOLD=3

echo -e "${PURPLE}🏥 ANQA Health Monitor - Real-Time System Health Monitoring${NC}"
echo "==============================================================="

# Function to log health status
log_health_status() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local component="$1"
    local status="$2"
    local details="$3"
    local metrics="$4"
    
    echo "$timestamp|$component|$status|$details|$metrics" >> "$HEALTH_LOG"
}

# Function to update health status JSON
update_health_status() {
    local component="$1"
    local status="$2"
    local details="$3"
    local metrics="$4"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Create status file if it doesn't exist
    if [ ! -f "$HEALTH_STATUS" ]; then
        echo '{"components": {}, "last_update": "", "overall_status": "unknown"}' > "$HEALTH_STATUS"
    fi
    
    # Update component status
    local temp_file=$(mktemp)
    jq --arg component "$component" \
       --arg status "$status" \
       --arg details "$details" \
       --arg metrics "$metrics" \
       --arg timestamp "$timestamp" \
       '.components[$component] = {
           status: $status,
           details: $details,
           metrics: $metrics,
           last_check: $timestamp
       } | .last_update = $timestamp' "$HEALTH_STATUS" > "$temp_file"
    mv "$temp_file" "$HEALTH_STATUS"
}

# Function to check system resources
check_system_resources() {
    echo -e "${BLUE}🔍 Checking system resources...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    local cpu_status="healthy"
    local cpu_details="CPU usage normal"
    
    if [ "$(echo "$cpu_usage >= 80" | bc -l)" -eq 1 ]; then
        cpu_status="warning"
        cpu_details="High CPU usage detected"
    elif [ "$(echo "$cpu_usage >= 90" | bc -l)" -eq 1 ]; then
        cpu_status="critical"
        cpu_details="Critical CPU usage detected"
    fi
    
    echo -e "  ${CYAN}CPU: ${YELLOW}$cpu_usage%${NC} - ${cpu_details}"
    log_health_status "SYSTEM" "CPU" "$cpu_status" "$cpu_details" "$cpu_usage%"
    update_health_status "cpu" "$cpu_status" "$cpu_details" "$cpu_usage%"
    
    # Memory usage
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    local memory_status="healthy"
    local memory_details="Memory usage normal"
    
    if [ "$memory_usage" -ge 80 ]; then
        memory_status="warning"
        memory_details="High memory usage detected"
    elif [ "$memory_usage" -ge 90 ]; then
        memory_status="critical"
        memory_details="Critical memory usage detected"
    fi
    
    echo -e "  ${CYAN}Memory: ${YELLOW}$memory_usage%${NC} - ${memory_details}"
    log_health_status "SYSTEM" "MEMORY" "$memory_status" "$memory_details" "$memory_usage%"
    update_health_status "memory" "$memory_status" "$memory_details" "$memory_usage%"
    
    # Disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_status="healthy"
    local disk_details="Disk usage normal"
    
    if [ "$disk_usage" -ge 80 ]; then
        disk_status="warning"
        disk_details="High disk usage detected"
    elif [ "$disk_usage" -ge 90 ]; then
        disk_status="critical"
        disk_details="Critical disk usage detected"
    fi
    
    echo -e "  ${CYAN}Disk: ${YELLOW}$disk_usage%${NC} - ${disk_details}"
    log_health_status "SYSTEM" "DISK" "$disk_status" "$disk_details" "$disk_usage%"
    update_health_status "disk" "$disk_status" "$disk_details" "$disk_usage%"
}

# Function to check service health
check_service_health() {
    echo -e "${BLUE}🔍 Checking service health...${NC}"
    
    # Backend service
    local backend_start=$(date +%s%N)
    local backend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    local backend_end=$(date +%s%N)
    local backend_time=$(((backend_end - backend_start) / 1000000))
    
    local backend_status="healthy"
    local backend_details="Backend service responding normally"
    
    if [ "$backend_response" != "200" ]; then
        backend_status="critical"
        backend_details="Backend service not responding (HTTP $backend_response)"
    elif [ "$backend_time" -ge 500 ]; then
        backend_status="warning"
        backend_details="Backend service slow response (${backend_time}ms)"
    fi
    
    echo -e "  ${CYAN}Backend: ${YELLOW}HTTP $backend_response${NC} (${backend_time}ms) - ${backend_details}"
    log_health_status "SERVICE" "BACKEND" "$backend_status" "$backend_details" "HTTP $backend_response (${backend_time}ms)"
    update_health_status "backend" "$backend_status" "$backend_details" "HTTP $backend_response (${backend_time}ms)"
    
    # Frontend service
    local frontend_start=$(date +%s%N)
    local frontend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    local frontend_end=$(date +%s%N)
    local frontend_time=$(((frontend_end - frontend_start) / 1000000))
    
    local frontend_status="healthy"
    local frontend_details="Frontend service responding normally"
    
    if [ "$frontend_response" != "200" ]; then
        frontend_status="critical"
        frontend_details="Frontend service not responding (HTTP $frontend_response)"
    elif [ "$frontend_time" -ge 3000 ]; then
        frontend_status="warning"
        frontend_details="Frontend service slow response (${frontend_time}ms)"
    fi
    
    echo -e "  ${CYAN}Frontend: ${YELLOW}HTTP $frontend_response${NC} (${frontend_time}ms) - ${frontend_details}"
    log_health_status "SERVICE" "FRONTEND" "$frontend_status" "$frontend_details" "HTTP $frontend_response (${frontend_time}ms)"
    update_health_status "frontend" "$frontend_status" "$frontend_details" "HTTP $frontend_response (${frontend_time}ms)"
}

# Function to check database health
check_database_health() {
    echo -e "${BLUE}🔍 Checking database health...${NC}"
    
    local db_start=$(date +%s%N)
    local db_connected=false
    local db_status="critical"
    local db_details="Database connection failed"
    local db_metrics="disconnected"
    
    if psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        db_connected=true
        db_status="healthy"
        db_details="Database connection successful"
        
        # Check database performance
        local query_start=$(date +%s%N)
        psql -h localhost -p 5434 -d anqa_website -c "SELECT COUNT(*) FROM pages;" >/dev/null 2>&1
        local query_end=$(date +%s%N)
        local query_time=$(((query_end - query_start) / 1000000))
        
        if [ "$query_time" -ge 200 ]; then
            db_status="warning"
            db_details="Database query performance slow (${query_time}ms)"
        fi
        
        db_metrics="connected (${query_time}ms)"
    fi
    
    local db_end=$(date +%s%N)
    local db_time=$(((db_end - db_start) / 1000000))
    
    echo -e "  ${CYAN}Database: ${YELLOW}$db_metrics${NC} (${db_time}ms) - ${db_details}"
    log_health_status "DATABASE" "CONNECTION" "$db_status" "$db_details" "$db_metrics (${db_time}ms)"
    update_health_status "database" "$db_status" "$db_details" "$db_metrics (${db_time}ms)"
}

# Function to check process health
check_process_health() {
    echo -e "${BLUE}🔍 Checking process health...${NC}"
    
    # Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)
    local node_status="healthy"
    local node_details="Node.js processes running normally"
    
    if [ "$node_processes" -eq 0 ]; then
        node_status="critical"
        node_details="No Node.js processes running"
    elif [ "$node_processes" -gt 4 ]; then
        node_status="warning"
        node_details="Too many Node.js processes ($node_processes)"
    fi
    
    echo -e "  ${CYAN}Node.js: ${YELLOW}$node_processes processes${NC} - ${node_details}"
    log_health_status "PROCESS" "NODE" "$node_status" "$node_details" "$node_processes processes"
    update_health_status "node_processes" "$node_status" "$node_details" "$node_processes processes"
    
    # PostgreSQL processes
    local postgres_processes=$(ps aux | grep postgres | grep -v grep | wc -l)
    local postgres_status="healthy"
    local postgres_details="PostgreSQL processes running normally"
    
    if [ "$postgres_processes" -eq 0 ]; then
        postgres_status="critical"
        postgres_details="No PostgreSQL processes running"
    fi
    
    echo -e "  ${CYAN}PostgreSQL: ${YELLOW}$postgres_processes processes${NC} - ${postgres_details}"
    log_health_status "PROCESS" "POSTGRES" "$postgres_status" "$postgres_details" "$postgres_processes processes"
    update_health_status "postgres_processes" "$postgres_status" "$postgres_details" "$postgres_processes processes"
}

# Function to check port health
check_port_health() {
    echo -e "${BLUE}🔍 Checking port health...${NC}"
    
    local ports_status="healthy"
    local ports_details="All required ports active"
    local active_ports=0
    
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            active_ports=$((active_ports + 1))
            echo -e "  ${CYAN}Port $port: ${GREEN}Active${NC}"
        else
            echo -e "  ${CYAN}Port $port: ${RED}Inactive${NC}"
            ports_status="critical"
            ports_details="Port $port is inactive"
        fi
    done
    
    if [ "$active_ports" -eq 3 ]; then
        echo -e "  ${GREEN}✅ All ports active${NC}"
    else
        echo -e "  ${RED}❌ Only $active_ports/3 ports active${NC}"
    fi
    
    log_health_status "PORTS" "AVAILABILITY" "$ports_status" "$ports_details" "$active_ports/3 active"
    update_health_status "ports" "$ports_status" "$ports_details" "$active_ports/3 active"
}

# Function to check API endpoints
check_api_endpoints() {
    echo -e "${BLUE}🔍 Checking API endpoints...${NC}"
    
    local endpoints=(
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    local api_status="healthy"
    local api_details="All API endpoints responding"
    local failed_endpoints=0
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        
        if [ "$response" = "200" ]; then
            echo -e "  ${CYAN}$endpoint: ${GREEN}HTTP $response${NC} (${duration}ms)"
        else
            echo -e "  ${CYAN}$endpoint: ${RED}HTTP $response${NC} (${duration}ms)"
            failed_endpoints=$((failed_endpoints + 1))
            api_status="critical"
            api_details="API endpoint $endpoint failed (HTTP $response)"
        fi
    done
    
    if [ "$failed_endpoints" -eq 0 ]; then
        echo -e "  ${GREEN}✅ All API endpoints healthy${NC}"
    else
        echo -e "  ${RED}❌ $failed_endpoints API endpoints failed${NC}"
    fi
    
    log_health_status "API" "ENDPOINTS" "$api_status" "$api_details" "$failed_endpoints failed"
    update_health_status "api_endpoints" "$api_status" "$api_details" "$failed_endpoints failed"
}

# Function to calculate overall health status
calculate_overall_status() {
    local critical_count=0
    local warning_count=0
    local healthy_count=0
    
    if [ -f "$HEALTH_STATUS" ]; then
        critical_count=$(jq -r '.components | to_entries[] | select(.value.status == "critical") | .key' "$HEALTH_STATUS" | wc -l)
        warning_count=$(jq -r '.components | to_entries[] | select(.value.status == "warning") | .key' "$HEALTH_STATUS" | wc -l)
        healthy_count=$(jq -r '.components | to_entries[] | select(.value.status == "healthy") | .key' "$HEALTH_STATUS" | wc -l)
    fi
    
    local overall_status="unknown"
    if [ "$critical_count" -gt 0 ]; then
        overall_status="critical"
    elif [ "$warning_count" -gt 0 ]; then
        overall_status="warning"
    elif [ "$healthy_count" -gt 0 ]; then
        overall_status="healthy"
    fi
    
    # Update overall status
    local temp_file=$(mktemp)
    jq --arg status "$overall_status" \
       --arg critical "$critical_count" \
       --arg warning "$warning_count" \
       --arg healthy "$healthy_count" \
       '.overall_status = $status | .summary = {
           critical: ($critical | tonumber),
           warning: ($warning | tonumber),
           healthy: ($healthy | tonumber)
       }' "$HEALTH_STATUS" > "$temp_file"
    mv "$temp_file" "$HEALTH_STATUS"
    
    echo -e "${PURPLE}📊 Overall Health Status: ${overall_status^^}${NC}"
    echo -e "  ${RED}Critical: $critical_count${NC}"
    echo -e "  ${YELLOW}Warning: $warning_count${NC}"
    echo -e "  ${GREEN}Healthy: $healthy_count${NC}"
}

# Function to display health dashboard
display_health_dashboard() {
    clear
    echo -e "${PURPLE}🏥 ANQA Health Monitor Dashboard${NC}"
    echo "====================================="
    echo -e "Last Update: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    
    if [ -f "$HEALTH_STATUS" ]; then
        echo -e "${CYAN}Component Status:${NC}"
        jq -r '.components | to_entries[] | "  \(.key): \(.value.status) - \(.value.details)"' "$HEALTH_STATUS" | while read -r line; do
            if [[ "$line" =~ critical ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" =~ warning ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${GREEN}$line${NC}"
            fi
        done
        
        echo ""
        local overall_status=$(jq -r '.overall_status' "$HEALTH_STATUS")
        echo -e "${CYAN}Overall Status: ${overall_status^^}${NC}"
    else
        echo -e "${YELLOW}No health status data available${NC}"
    fi
}

# Function to generate health report
generate_health_report() {
    echo -e "${PURPLE}📋 Generating health report...${NC}"
    
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Health Monitor Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================="
        echo ""
        
        echo "System Health Summary:"
        echo "---------------------"
        
        if [ -f "$HEALTH_STATUS" ]; then
            local overall_status=$(jq -r '.overall_status' "$HEALTH_STATUS")
            local summary=$(jq -r '.summary' "$HEALTH_STATUS")
            
            echo "Overall Status: $overall_status"
            echo "Summary: $summary"
            
            echo ""
            echo "Component Details:"
            echo "-----------------"
            jq -r '.components | to_entries[] | "\(.key):\n  Status: \(.value.status)\n  Details: \(.value.details)\n  Metrics: \(.value.metrics)\n  Last Check: \(.value.last_check)\n"' "$HEALTH_STATUS"
        else
            echo "No health status data available"
        fi
        
        echo ""
        echo "Recent Health Logs:"
        echo "------------------"
        
        if [ -f "$HEALTH_LOG" ]; then
            tail -20 "$HEALTH_LOG" | while IFS='|' read -r timestamp component check status details metrics; do
                echo "$timestamp - $component $check: $status - $details ($metrics)"
            done
        else
            echo "No health logs available"
        fi
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Health report generated: $report_file${NC}"
}

# Function to show health summary
show_health_summary() {
    echo -e "${PURPLE}📊 Health Summary${NC}"
    echo "==============="
    
    if [ -f "$HEALTH_STATUS" ]; then
        local overall_status=$(jq -r '.overall_status' "$HEALTH_STATUS")
        local summary=$(jq -r '.summary' "$HEALTH_STATUS")
        
        echo -e "${CYAN}Overall Status: ${overall_status^^}${NC}"
        echo -e "${CYAN}Summary: $summary${NC}"
        
        echo ""
        echo -e "${CYAN}Component Status:${NC}"
        jq -r '.components | to_entries[] | "  \(.key): \(.value.status) - \(.value.details)"' "$HEALTH_STATUS" | while read -r line; do
            if [[ "$line" =~ critical ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" =~ warning ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${GREEN}$line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No health status data available${NC}"
    fi
}

# Main monitoring loop
main_monitoring() {
    echo -e "${PURPLE}🚀 Starting health monitoring...${NC}"
    echo -e "${CYAN}Monitor interval: ${YELLOW}${MONITOR_INTERVAL} seconds${NC}"
    echo -e "${CYAN}Health log: ${YELLOW}$HEALTH_LOG${NC}"
    echo ""
    
    # Create log file if it doesn't exist
    touch "$HEALTH_LOG"
    
    # Start monitoring loop
    while true; do
        echo -e "${CYAN}=== Health Check: $(date -u +"%Y-%m-%d %H:%M:%S UTC") ===${NC}"
        
        check_system_resources
        echo ""
        check_service_health
        echo ""
        check_database_health
        echo ""
        check_process_health
        echo ""
        check_port_health
        echo ""
        check_api_endpoints
        echo ""
        calculate_overall_status
        echo ""
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Main execution
main() {
    local action="${1:-monitor}"
    
    case "$action" in
        "monitor")
            main_monitoring
            ;;
        "dashboard")
            display_health_dashboard
            ;;
        "summary")
            show_health_summary
            ;;
        "report")
            generate_health_report
            ;;
        "check")
            echo -e "${PURPLE}🔍 Running single health check...${NC}"
            echo ""
            check_system_resources
            echo ""
            check_service_health
            echo ""
            check_database_health
            echo ""
            check_process_health
            echo ""
            check_port_health
            echo ""
            check_api_endpoints
            echo ""
            calculate_overall_status
            ;;
        *)
            echo -e "${PURPLE}ANQA Health Monitor - Usage${NC}"
            echo "============================="
            echo "  $0 monitor   - Start continuous monitoring"
            echo "  $0 dashboard - Display health dashboard"
            echo "  $0 summary   - Show health summary"
            echo "  $0 report    - Generate health report"
            echo "  $0 check     - Run single health check"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 monitor"
            echo "  $0 dashboard"
            echo "  $0 check"
            ;;
    esac
}

# Handle script interruption
trap 'echo -e "\n${GREEN}✅ Health monitor stopped${NC}"; exit 0' INT

# Run main function
main "$@"
