#!/bin/bash
set -e

# ANQA Performance Baseline - Performance Benchmarking & Monitoring
# Establishes performance baselines and monitors key metrics

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASELINE_FILE="performance-baseline.json"
RESULTS_FILE="performance-results.log"
TARGET_RESPONSE_TIME=200
TARGET_LOAD_TIME=2000
TARGET_CPU_USAGE=80
TARGET_MEMORY_USAGE=70

echo -e "${PURPLE}📊 ANQA Performance Baseline - Performance Benchmarking${NC}"
echo "=============================================================="

# Function to measure API response time
measure_api_response_time() {
    echo -e "${BLUE}🔍 Measuring API response times...${NC}"
    
    local endpoints=(
        "http://localhost:4001/api/health"
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    local total_time=0
    local count=0
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s "$endpoint" >/dev/null 2>&1; then
            local response_time=$(curl -s -w "%{time_total}" -o /dev/null "$endpoint" 2>/dev/null)
            local time_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)
            
            echo -e "  ${CYAN}$endpoint${NC}: ${YELLOW}${time_ms}ms${NC}"
            
            if [ "$time_ms" -gt "$TARGET_RESPONSE_TIME" ]; then
                echo -e "    ${RED}⚠️  Above target ($TARGET_RESPONSE_TIME ms)${NC}"
            else
                echo -e "    ${GREEN}✅ Within target${NC}"
            fi
            
            total_time=$((total_time + time_ms))
            count=$((count + 1))
        else
            echo -e "  ${RED}❌ $endpoint - Not responding${NC}"
        fi
    done
    
    if [ "$count" -gt 0 ]; then
        local avg_time=$((total_time / count))
        echo -e "${PURPLE}📊 Average API response time: ${YELLOW}${avg_time}ms${NC}"
        echo "api_response_time|$avg_time|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    fi
}

# Function to measure frontend load time
measure_frontend_load_time() {
    echo -e "${BLUE}🔍 Measuring frontend load time...${NC}"
    
    if curl -s http://localhost:4000 >/dev/null 2>&1; then
        local start_time=$(date +%s%N)
        curl -s http://localhost:4000 >/dev/null 2>&1
        local end_time=$(date +%s%N)
        
        local load_time=$(((end_time - start_time) / 1000000))
        echo -e "  ${CYAN}Frontend load time${NC}: ${YELLOW}${load_time}ms${NC}"
        
        if [ "$load_time" -gt "$TARGET_LOAD_TIME" ]; then
            echo -e "    ${RED}⚠️  Above target ($TARGET_LOAD_TIME ms)${NC}"
        else
            echo -e "    ${GREEN}✅ Within target${NC}"
        fi
        
        echo "frontend_load_time|$load_time|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    else
        echo -e "  ${RED}❌ Frontend not responding${NC}"
    fi
}

# Function to measure database performance
measure_database_performance() {
    echo -e "${BLUE}🔍 Measuring database performance...${NC}"
    
    if command -v psql >/dev/null 2>&1; then
        # Measure query execution time
        local start_time=$(date +%s%N)
        psql -h localhost -p 5434 -d anqa_website -c "SELECT COUNT(*) FROM pages;" >/dev/null 2>&1
        local end_time=$(date +%s%N)
        
        local query_time=$(((end_time - start_time) / 1000000))
        echo -e "  ${CYAN}Database query time${NC}: ${YELLOW}${query_time}ms${NC}"
        
        # Check database size
        local db_size=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT pg_size_pretty(pg_database_size('anqa_website'));" 2>/dev/null | tr -d ' ')
        echo -e "  ${CYAN}Database size${NC}: ${YELLOW}$db_size${NC}"
        
        # Check active connections
        local connections=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' ')
        echo -e "  ${CYAN}Active connections${NC}: ${YELLOW}$connections${NC}"
        
        echo "database_query_time|$query_time|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
        echo "database_size|$db_size|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
        echo "database_connections|$connections|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    else
        echo -e "  ${RED}❌ PostgreSQL client not available${NC}"
    fi
}

# Function to measure system resources
measure_system_resources() {
    echo -e "${BLUE}🔍 Measuring system resources...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    echo -e "  ${CYAN}CPU usage${NC}: ${YELLOW}${cpu_usage}%${NC}"
    
    if [ "$(echo "$cpu_usage > $TARGET_CPU_USAGE" | bc -l)" -eq 1 ]; then
        echo -e "    ${RED}⚠️  Above target ($TARGET_CPU_USAGE%)${NC}"
    else
        echo -e "    ${GREEN}✅ Within target${NC}"
    fi
    
    # Memory usage
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl hw.memsize | awk '{print $2}')
    local free_memory=$((memory_info * 4096))
    local used_memory=$((total_memory - free_memory))
    local memory_usage=$((used_memory * 100 / total_memory))
    
    echo -e "  ${CYAN}Memory usage${NC}: ${YELLOW}${memory_usage}%${NC}"
    
    if [ "$memory_usage" -gt "$TARGET_MEMORY_USAGE" ]; then
        echo -e "    ${RED}⚠️  Above target ($TARGET_MEMORY_USAGE%)${NC}"
    else
        echo -e "    ${GREEN}✅ Within target${NC}"
    fi
    
    # Disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    echo -e "  ${CYAN}Disk usage${NC}: ${YELLOW}${disk_usage}%${NC}"
    
    echo "cpu_usage|$cpu_usage|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    echo "memory_usage|$memory_usage|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    echo "disk_usage|$disk_usage|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
}

# Function to measure process performance
measure_process_performance() {
    echo -e "${BLUE}🔍 Measuring process performance...${NC}"
    
    # Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)
    echo -e "  ${CYAN}Node.js processes${NC}: ${YELLOW}$node_processes${NC}"
    
    # PostgreSQL process
    local postgres_processes=$(ps aux | grep postgres | grep -v grep | wc -l)
    echo -e "  ${CYAN}PostgreSQL processes${NC}: ${YELLOW}$postgres_processes${NC}"
    
    # Port usage
    local ports_used=0
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            ports_used=$((ports_used + 1))
        fi
    done
    echo -e "  ${CYAN}Required ports active${NC}: ${YELLOW}$ports_used/3${NC}"
    
    echo "node_processes|$node_processes|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    echo "postgres_processes|$postgres_processes|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
    echo "ports_active|$ports_used|$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$RESULTS_FILE"
}

# Function to create performance baseline
create_baseline() {
    echo -e "${PURPLE}📊 Creating performance baseline...${NC}"
    
    local baseline_data='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "targets": {
            "api_response_time_ms": '$TARGET_RESPONSE_TIME',
            "frontend_load_time_ms": '$TARGET_LOAD_TIME',
            "cpu_usage_percent": '$TARGET_CPU_USAGE',
            "memory_usage_percent": '$TARGET_MEMORY_USAGE'
        },
        "current_metrics": {}
    }'
    
    echo "$baseline_data" > "$BASELINE_FILE"
    echo -e "${GREEN}✅ Performance baseline created: $BASELINE_FILE${NC}"
}

# Function to analyze performance trends
analyze_performance_trends() {
    echo -e "${PURPLE}📈 Performance Trend Analysis${NC}"
    echo "================================"
    
    if [ -f "$RESULTS_FILE" ]; then
        echo -e "${CYAN}Recent performance data:${NC}"
        
        # Show last 5 entries for each metric
        local metrics=("api_response_time" "frontend_load_time" "cpu_usage" "memory_usage")
        
        for metric in "${metrics[@]}"; do
            echo -e "${BLUE}$metric:${NC}"
            grep "^$metric|" "$RESULTS_FILE" | tail -5 | while IFS='|' read -r name value timestamp; do
                echo -e "  ${YELLOW}$timestamp${NC}: ${CYAN}${value}${NC}"
            done
        done
        
        # Calculate trends
        echo -e "${PURPLE}📊 Performance Summary:${NC}"
        local total_measurements=$(wc -l < "$RESULTS_FILE")
        echo -e "  ${CYAN}Total measurements: $total_measurements${NC}"
        
        # Check for performance degradation
        local recent_api_times=$(grep "^api_response_time|" "$RESULTS_FILE" | tail -3 | cut -d'|' -f2)
        local avg_recent_api=$(echo "$recent_api_times" | awk '{sum+=$1} END {print sum/NR}')
        
        if [ "$(echo "$avg_recent_api > $TARGET_RESPONSE_TIME" | bc -l)" -eq 1 ]; then
            echo -e "  ${RED}⚠️  API performance degradation detected${NC}"
        else
            echo -e "  ${GREEN}✅ API performance within targets${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No performance data available yet${NC}"
    fi
}

# Function to generate performance report
generate_performance_report() {
    echo -e "${PURPLE}📋 Performance Report${NC}"
    echo "====================="
    
    local report_file="performance-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Performance Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================"
        echo ""
        echo "Target Metrics:"
        echo "- API Response Time: < ${TARGET_RESPONSE_TIME}ms"
        echo "- Frontend Load Time: < ${TARGET_LOAD_TIME}ms"
        echo "- CPU Usage: < ${TARGET_CPU_USAGE}%"
        echo "- Memory Usage: < ${TARGET_MEMORY_USAGE}%"
        echo ""
        echo "Current Status:"
        
        if [ -f "$RESULTS_FILE" ]; then
            echo "Recent measurements:"
            tail -10 "$RESULTS_FILE" | while IFS='|' read -r metric value timestamp; do
                echo "- $metric: $value ($timestamp)"
            done
        fi
        
        echo ""
        echo "Recommendations:"
        echo "1. Monitor API response times for degradation"
        echo "2. Check system resources during peak usage"
        echo "3. Optimize database queries if needed"
        echo "4. Consider caching strategies for improved performance"
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Performance report generated: $report_file${NC}"
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 Starting ANQA Performance Baseline...${NC}"
    echo ""
    
    # Create baseline if it doesn't exist
    if [ ! -f "$BASELINE_FILE" ]; then
        create_baseline
        echo ""
    fi
    
    # Run all measurements
    measure_api_response_time
    echo ""
    measure_frontend_load_time
    echo ""
    measure_database_performance
    echo ""
    measure_system_resources
    echo ""
    measure_process_performance
    echo ""
    
    # Analysis and reporting
    analyze_performance_trends
    echo ""
    generate_performance_report
    echo ""
    
    echo -e "${GREEN}✅ Performance baseline complete${NC}"
    echo -e "${CYAN}📊 Results file: $RESULTS_FILE${NC}"
    echo -e "${CYAN}📊 Baseline file: $BASELINE_FILE${NC}"
}

# Run main function
main "$@"
