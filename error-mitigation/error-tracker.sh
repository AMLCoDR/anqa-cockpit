#!/bin/bash
set -e

# ANQA Error Tracker - Automated Error Detection & Tracking
# Based on SYSTEM_CHANGELOG.md known issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="error-tracker.log"
ERROR_DB="error-database.json"
ALERT_THRESHOLD=3
CRITICAL_THRESHOLD=5

# Error patterns from SYSTEM_CHANGELOG.md
declare -A ERROR_PATTERNS=(
    ["PORT_CONFLICT"]="address already in use|EADDRINUSE"
    ["DB_CONNECTION"]="connection refused|No resource with given URL found|ECONNREFUSED"
    ["CSS_FAILURE"]="CSS changes not visible|styles not applied"
    ["DB_CONTENT_MISSING"]="database appears empty|only basic services"
    ["API_MISMATCH"]="frontend can't connect to backend|CORS error"
    ["TEST_FAILURE"]="tests skipped|Docker vs Podman"
)

# Error severity levels
declare -A ERROR_SEVERITY=(
    ["PORT_CONFLICT"]="HIGH"
    ["DB_CONNECTION"]="CRITICAL"
    ["CSS_FAILURE"]="MEDIUM"
    ["DB_CONTENT_MISSING"]="CRITICAL"
    ["API_MISMATCH"]="HIGH"
    ["TEST_FAILURE"]="MEDIUM"
)

echo -e "${PURPLE}🔍 ANQA Error Tracker - Automated Error Detection${NC}"
echo "=================================================="

# Function to log error
log_error() {
    local error_type="$1"
    local error_message="$2"
    local severity="${ERROR_SEVERITY[$error_type]}"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    echo -e "${RED}🚨 ERROR DETECTED: $error_type${NC}"
    echo -e "${YELLOW}   Severity: $severity${NC}"
    echo -e "${CYAN}   Message: $error_message${NC}"
    echo -e "${BLUE}   Time: $timestamp${NC}"
    
    # Log to file
    echo "$timestamp|$error_type|$severity|$error_message" >> "$LOG_FILE"
    
    # Update error database
    update_error_db "$error_type" "$severity" "$timestamp"
}

# Function to update error database
update_error_db() {
    local error_type="$1"
    local severity="$2"
    local timestamp="$3"
    
    # Create error database if it doesn't exist
    if [ ! -f "$ERROR_DB" ]; then
        echo '{}' > "$ERROR_DB"
    fi
    
    # Update error count and last occurrence
    local temp_file=$(mktemp)
    jq --arg type "$error_type" \
       --arg severity "$severity" \
       --arg time "$timestamp" \
       '.[$type] = {
           count: (.[$type].count // 0) + 1,
           severity: $severity,
           last_occurrence: $time,
           first_occurrence: (.[$type].first_occurrence // $time)
       }' "$ERROR_DB" > "$temp_file"
    mv "$temp_file" "$ERROR_DB"
}

# Function to check port conflicts
check_port_conflicts() {
    echo -e "${BLUE}🔍 Checking for port conflicts...${NC}"
    
    local ports=(4000 4001 5434)
    local conflicts=0
    
    for port in "${ports[@]}"; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            local processes=$(lsof -i ":$port" | grep LISTEN | wc -l)
            if [ "$processes" -gt 1 ]; then
                log_error "PORT_CONFLICT" "Multiple processes on port $port ($processes processes)"
                conflicts=$((conflicts + 1))
            fi
        fi
    done
    
    if [ "$conflicts" -eq 0 ]; then
        echo -e "${GREEN}✅ No port conflicts detected${NC}"
    fi
}

# Function to check database connection
check_database_connection() {
    echo -e "${BLUE}🔍 Checking database connection...${NC}"
    
    if ! psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "DB_CONNECTION" "Database connection failed - PostgreSQL not responding"
        return 1
    fi
    
    # Check for expected content
    local page_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM pages;" 2>/dev/null | tr -d ' ')
    local service_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM services;" 2>/dev/null | tr -d ' ')
    
    if [ "$page_count" -lt 200 ] || [ "$service_count" -lt 5 ]; then
        log_error "DB_CONTENT_MISSING" "Database content incomplete - Pages: $page_count, Services: $service_count"
    else
        echo -e "${GREEN}✅ Database connection and content verified${NC}"
    fi
}

# Function to check API connectivity
check_api_connectivity() {
    echo -e "${BLUE}🔍 Checking API connectivity...${NC}"
    
    # Check backend API
    if ! curl -s http://localhost:4001/api/health >/dev/null 2>&1; then
        log_error "API_MISMATCH" "Backend API not responding on port 4001"
        return 1
    fi
    
    # Check services endpoint
    local services_response=$(curl -s http://localhost:4001/api/services 2>/dev/null)
    if [ -z "$services_response" ] || ! echo "$services_response" | jq -e '.services' >/dev/null 2>&1; then
        log_error "API_MISMATCH" "Services API endpoint not returning valid JSON"
    else
        echo -e "${GREEN}✅ API connectivity verified${NC}"
    fi
}

# Function to check frontend status
check_frontend_status() {
    echo -e "${BLUE}🔍 Checking frontend status...${NC}"
    
    if ! curl -s http://localhost:4000 >/dev/null 2>&1; then
        log_error "API_MISMATCH" "Frontend not responding on port 4000"
        return 1
    fi
    
    # Check for ANQA content in response
    local frontend_content=$(curl -s http://localhost:4000)
    if ! echo "$frontend_content" | grep -i "anqa\|compliance" >/dev/null 2>&1; then
        log_error "CSS_FAILURE" "Frontend not displaying expected ANQA content"
    else
        echo -e "${GREEN}✅ Frontend status verified${NC}"
    fi
}

# Function to check test infrastructure
check_test_infrastructure() {
    echo -e "${BLUE}🔍 Checking test infrastructure...${NC}"
    
    if [ -d "backend/tests" ]; then
        if ! cd backend && npm test >/dev/null 2>&1; then
            log_error "TEST_FAILURE" "Backend tests failing"
        else
            echo -e "${GREEN}✅ Test infrastructure verified${NC}"
        fi
        cd ..
    else
        echo -e "${YELLOW}⚠️  Test directory not found${NC}"
    fi
}

# Function to analyze error patterns
analyze_error_patterns() {
    echo -e "${PURPLE}📊 Error Pattern Analysis${NC}"
    echo "=========================="
    
    if [ -f "$ERROR_DB" ]; then
        local total_errors=$(jq 'reduce (.[] | .count) as $count (0; . + $count)' "$ERROR_DB")
        echo -e "${CYAN}Total errors tracked: $total_errors${NC}"
        
        # Show most frequent errors
        echo -e "${BLUE}Most frequent errors:${NC}"
        jq -r 'to_entries | sort_by(.value.count) | reverse | .[0:3] | .[] | "  \(.key): \(.value.count) occurrences (last: \(.value.last_occurrence))"' "$ERROR_DB" 2>/dev/null || echo "  No error data available"
        
        # Check for alert thresholds
        jq -r 'to_entries | .[] | select(.value.count >= '$ALERT_THRESHOLD') | "🚨 ALERT: \(.key) has occurred \(.value.count) times"' "$ERROR_DB" 2>/dev/null || true
    else
        echo -e "${GREEN}✅ No errors tracked yet${NC}"
    fi
}

# Function to generate error report
generate_error_report() {
    echo -e "${PURPLE}📋 Error Report${NC}"
    echo "=============="
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}Recent errors (last 10):${NC}"
        tail -10 "$LOG_FILE" | while IFS='|' read -r timestamp type severity message; do
            echo -e "  ${YELLOW}$timestamp${NC} - ${RED}$type${NC} ($severity): $message"
        done
    else
        echo -e "${GREEN}✅ No error log found${NC}"
    fi
}

# Function to provide recovery suggestions
provide_recovery_suggestions() {
    echo -e "${PURPLE}🔧 Recovery Suggestions${NC}"
    echo "======================"
    
    if [ -f "$ERROR_DB" ]; then
        jq -r 'to_entries | .[] | select(.value.count > 0) | "  \(.key): \(.value.count) occurrences"' "$ERROR_DB" | while read -r error_info; do
            if [[ "$error_info" =~ PORT_CONFLICT ]]; then
                echo -e "${YELLOW}  For PORT_CONFLICT:${NC}"
                echo -e "    Run: pkill -f 'node src/server.js' && pkill -f 'react-scripts'"
                echo -e "    Then: ./scripts/start-environment.sh"
            elif [[ "$error_info" =~ DB_CONNECTION ]]; then
                echo -e "${YELLOW}  For DB_CONNECTION:${NC}"
                echo -e "    Run: psql -h localhost -p 5434 -d anqa_website -f database/02-data.sql"
            elif [[ "$error_info" =~ API_MISMATCH ]]; then
                echo -e "${YELLOW}  For API_MISMATCH:${NC}"
                echo -e "    Check: cat frontend/.env && cat backend/.env"
                echo -e "    Verify: VITE_API_BASE_URL=http://localhost:4001"
            fi
        done
    fi
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 Starting ANQA Error Tracker...${NC}"
    echo ""
    
    # Run all checks
    check_port_conflicts
    echo ""
    check_database_connection
    echo ""
    check_api_connectivity
    echo ""
    check_frontend_status
    echo ""
    check_test_infrastructure
    echo ""
    
    # Analysis and reporting
    analyze_error_patterns
    echo ""
    generate_error_report
    echo ""
    provide_recovery_suggestions
    echo ""
    
    echo -e "${GREEN}✅ Error tracking complete${NC}"
    echo -e "${CYAN}📊 Log file: $LOG_FILE${NC}"
    echo -e "${CYAN}📊 Error database: $ERROR_DB${NC}"
}

# Run main function
main "$@"
