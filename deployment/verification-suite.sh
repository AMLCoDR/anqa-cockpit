#!/bin/bash
set -e

# ANQA Verification Suite - Post-Deployment Verification
# Comprehensive validation of all system components after deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VERIFICATION_LOG="verification.log"
VERIFICATION_REPORT="verification-report.json"
VERIFICATION_TIMEOUT=30

echo -e "${PURPLE}✅ ANQA Verification Suite - Post-Deployment Verification${NC}"
echo "============================================================="

# Function to log verification result
log_verification() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local component="$1"
    local check="$2"
    local status="$3"
    local details="$4"
    local duration="$5"
    
    echo "$timestamp|$component|$check|$status|$details|$duration" >> "$VERIFICATION_LOG"
}

# Function to verify service startup
verify_service_startup() {
    echo -e "${BLUE}🔍 Verifying service startup...${NC}"
    
    local verification_passed=true
    
    # Verify backend startup
    echo -e "  ${CYAN}Checking backend service...${NC}"
    local backend_start=$(date +%s%N)
    local backend_ready=false
    
    for i in {1..30}; do
        if curl -s http://localhost:4001/api/health >/dev/null 2>&1; then
            backend_ready=true
            break
        fi
        sleep 1
    done
    
    local backend_end=$(date +%s%N)
    local backend_duration=$(((backend_end - backend_start) / 1000000))
    
    if [ "$backend_ready" = true ]; then
        echo -e "    ${GREEN}✅ Backend service started (${backend_duration}ms)${NC}"
        log_verification "SERVICE" "BACKEND_STARTUP" "SUCCESS" "Backend service started" "${backend_duration}ms"
    else
        echo -e "    ${RED}❌ Backend service failed to start${NC}"
        log_verification "SERVICE" "BACKEND_STARTUP" "FAILED" "Backend service failed to start" "${backend_duration}ms"
        verification_passed=false
    fi
    
    # Verify frontend startup
    echo -e "  ${CYAN}Checking frontend service...${NC}"
    local frontend_start=$(date +%s%N)
    local frontend_ready=false
    
    for i in {1..30}; do
        if curl -s http://localhost:4000 >/dev/null 2>&1; then
            frontend_ready=true
            break
        fi
        sleep 1
    done
    
    local frontend_end=$(date +%s%N)
    local frontend_duration=$(((frontend_end - frontend_start) / 1000000))
    
    if [ "$frontend_ready" = true ]; then
        echo -e "    ${GREEN}✅ Frontend service started (${frontend_duration}ms)${NC}"
        log_verification "SERVICE" "FRONTEND_STARTUP" "SUCCESS" "Frontend service started" "${frontend_duration}ms"
    else
        echo -e "    ${RED}❌ Frontend service failed to start${NC}"
        log_verification "SERVICE" "FRONTEND_STARTUP" "FAILED" "Frontend service failed to start" "${frontend_duration}ms"
        verification_passed=false
    fi
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify API endpoints
verify_api_endpoints() {
    echo -e "${BLUE}🔍 Verifying API endpoints...${NC}"
    
    local verification_passed=true
    local endpoints=(
        "http://localhost:4001/api/health"
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo -e "  ${CYAN}Checking $endpoint...${NC}"
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        
        if [ "$response" = "200" ]; then
            echo -e "    ${GREEN}✅ $endpoint: HTTP $response (${duration}ms)${NC}"
            log_verification "API" "ENDPOINT_$endpoint" "SUCCESS" "HTTP $response" "${duration}ms"
        else
            echo -e "    ${RED}❌ $endpoint: HTTP $response (${duration}ms)${NC}"
            log_verification "API" "ENDPOINT_$endpoint" "FAILED" "HTTP $response" "${duration}ms"
            verification_passed=false
        fi
    done
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify database connectivity
verify_database_connectivity() {
    echo -e "${BLUE}🔍 Verifying database connectivity...${NC}"
    
    local verification_passed=true
    
    # Check database connection
    echo -e "  ${CYAN}Checking database connection...${NC}"
    local start_time=$(date +%s%N)
    
    if psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        echo -e "    ${GREEN}✅ Database connection successful (${duration}ms)${NC}"
        log_verification "DATABASE" "CONNECTION" "SUCCESS" "Database connection successful" "${duration}ms"
    else
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        echo -e "    ${RED}❌ Database connection failed (${duration}ms)${NC}"
        log_verification "DATABASE" "CONNECTION" "FAILED" "Database connection failed" "${duration}ms"
        verification_passed=false
    fi
    
    # Check database content
    if [ "$verification_passed" = true ]; then
        echo -e "  ${CYAN}Checking database content...${NC}"
        local start_time=$(date +%s%N)
        
        local page_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM pages;" 2>/dev/null | tr -d ' ')
        local service_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM services;" 2>/dev/null | tr -d ' ')
        local post_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM posts;" 2>/dev/null | tr -d ' ')
        
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        
        if [ "$page_count" -ge 200 ] && [ "$service_count" -ge 5 ] && [ "$post_count" -ge 30 ]; then
            echo -e "    ${GREEN}✅ Database content verified (${duration}ms)${NC}"
            echo -e "      Pages: $page_count, Services: $service_count, Posts: $post_count"
            log_verification "DATABASE" "CONTENT" "SUCCESS" "Content verified - Pages: $page_count, Services: $service_count, Posts: $post_count" "${duration}ms"
        else
            echo -e "    ${RED}❌ Database content incomplete (${duration}ms)${NC}"
            echo -e "      Pages: $page_count, Services: $service_count, Posts: $post_count"
            log_verification "DATABASE" "CONTENT" "FAILED" "Content incomplete - Pages: $page_count, Services: $service_count, Posts: $post_count" "${duration}ms"
            verification_passed=false
        fi
    fi
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify frontend functionality
verify_frontend_functionality() {
    echo -e "${BLUE}🔍 Verifying frontend functionality...${NC}"
    
    local verification_passed=true
    
    # Check frontend accessibility
    echo -e "  ${CYAN}Checking frontend accessibility...${NC}"
    local start_time=$(date +%s%N)
    local frontend_content=$(curl -s http://localhost:4000)
    local end_time=$(date +%s%N)
    local duration=$(((end_time - start_time) / 1000000))
    
    if [ -n "$frontend_content" ]; then
        echo -e "    ${GREEN}✅ Frontend accessible (${duration}ms)${NC}"
        log_verification "FRONTEND" "ACCESSIBILITY" "SUCCESS" "Frontend accessible" "${duration}ms"
        
        # Check for ANQA content
        if echo "$frontend_content" | grep -i "anqa\|compliance" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ ANQA content detected${NC}"
            log_verification "FRONTEND" "CONTENT" "SUCCESS" "ANQA content detected" "0ms"
        else
            echo -e "    ${RED}❌ ANQA content not detected${NC}"
            log_verification "FRONTEND" "CONTENT" "FAILED" "ANQA content not detected" "0ms"
            verification_passed=false
        fi
    else
        echo -e "    ${RED}❌ Frontend not accessible (${duration}ms)${NC}"
        log_verification "FRONTEND" "ACCESSIBILITY" "FAILED" "Frontend not accessible" "${duration}ms"
        verification_passed=false
    fi
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify port configurations
verify_port_configurations() {
    echo -e "${BLUE}🔍 Verifying port configurations...${NC}"
    
    local verification_passed=true
    
    # Check required ports
    for port in 4000 4001 5434; do
        echo -e "  ${CYAN}Checking port $port...${NC}"
        local start_time=$(date +%s%N)
        
        if lsof -i ":$port" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${GREEN}✅ Port $port: Active (${duration}ms)${NC}"
            log_verification "PORTS" "PORT_$port" "SUCCESS" "Port $port active" "${duration}ms"
        else
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${RED}❌ Port $port: Inactive (${duration}ms)${NC}"
            log_verification "PORTS" "PORT_$port" "FAILED" "Port $port inactive" "${duration}ms"
            verification_passed=false
        fi
    done
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify process status
verify_process_status() {
    echo -e "${BLUE}🔍 Verifying process status...${NC}"
    
    local verification_passed=true
    
    # Check Node.js processes
    echo -e "  ${CYAN}Checking Node.js processes...${NC}"
    local start_time=$(date +%s%N)
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | wc -l)
    local end_time=$(date +%s%N)
    local duration=$(((end_time - start_time) / 1000000))
    
    if [ "$node_processes" -gt 0 ] && [ "$node_processes" -le 4 ]; then
        echo -e "    ${GREEN}✅ Node.js processes: $node_processes (${duration}ms)${NC}"
        log_verification "PROCESSES" "NODE_PROCESSES" "SUCCESS" "$node_processes Node.js processes" "${duration}ms"
    else
        echo -e "    ${RED}❌ Node.js processes: $node_processes (${duration}ms)${NC}"
        log_verification "PROCESSES" "NODE_PROCESSES" "FAILED" "$node_processes Node.js processes" "${duration}ms"
        verification_passed=false
    fi
    
    # Check PostgreSQL processes
    echo -e "  ${CYAN}Checking PostgreSQL processes...${NC}"
    local start_time=$(date +%s%N)
    local postgres_processes=$(ps aux | grep postgres | grep -v grep | wc -l)
    local end_time=$(date +%s%N)
    local duration=$(((end_time - start_time) / 1000000))
    
    if [ "$postgres_processes" -gt 0 ]; then
        echo -e "    ${GREEN}✅ PostgreSQL processes: $postgres_processes (${duration}ms)${NC}"
        log_verification "PROCESSES" "POSTGRES_PROCESSES" "SUCCESS" "$postgres_processes PostgreSQL processes" "${duration}ms"
    else
        echo -e "    ${RED}❌ PostgreSQL processes: $postgres_processes (${duration}ms)${NC}"
        log_verification "PROCESSES" "POSTGRES_PROCESSES" "FAILED" "$postgres_processes PostgreSQL processes" "${duration}ms"
        verification_passed=false
    fi
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify configuration compliance
verify_configuration_compliance() {
    echo -e "${BLUE}🔍 Verifying configuration compliance...${NC}"
    
    local verification_passed=true
    
    # Check frontend configuration
    echo -e "  ${CYAN}Checking frontend configuration...${NC}"
    local start_time=$(date +%s%N)
    
    if [ -f "frontend/.env" ]; then
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "not_found")
        if [ "$vite_api_url" = "http://localhost:4001" ]; then
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${GREEN}✅ Frontend API URL: $vite_api_url (${duration}ms)${NC}"
            log_verification "CONFIG" "FRONTEND_API_URL" "SUCCESS" "API URL correctly configured" "${duration}ms"
        else
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${RED}❌ Frontend API URL: $vite_api_url (${duration}ms)${NC}"
            log_verification "CONFIG" "FRONTEND_API_URL" "FAILED" "API URL incorrectly configured" "${duration}ms"
            verification_passed=false
        fi
    else
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        echo -e "    ${RED}❌ Frontend .env not found (${duration}ms)${NC}"
        log_verification "CONFIG" "FRONTEND_ENV" "FAILED" ".env file not found" "${duration}ms"
        verification_passed=false
    fi
    
    # Check backend configuration
    echo -e "  ${CYAN}Checking backend configuration...${NC}"
    local start_time=$(date +%s%N)
    
    if [ -f "backend/.env" ]; then
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 | tr -d '"' || echo "not_found")
        if [ "$backend_port" = "4001" ]; then
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${GREEN}✅ Backend port: $backend_port (${duration}ms)${NC}"
            log_verification "CONFIG" "BACKEND_PORT" "SUCCESS" "Port correctly configured" "${duration}ms"
        else
            local end_time=$(date +%s%N)
            local duration=$(((end_time - start_time) / 1000000))
            echo -e "    ${RED}❌ Backend port: $backend_port (${duration}ms)${NC}"
            log_verification "CONFIG" "BACKEND_PORT" "FAILED" "Port incorrectly configured" "${duration}ms"
            verification_passed=false
        fi
    else
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        echo -e "    ${RED}❌ Backend .env not found (${duration}ms)${NC}"
        log_verification "CONFIG" "BACKEND_ENV" "FAILED" ".env file not found" "${duration}ms"
        verification_passed=false
    fi
    
    return $([ "$verification_passed" = true ] && echo 0 || echo 1)
}

# Function to verify performance metrics
verify_performance_metrics() {
    echo -e "${BLUE}🔍 Verifying performance metrics...${NC}"
    
    local verification_passed=true
    
    # Check API response times
    echo -e "  ${CYAN}Checking API response times...${NC}"
    local endpoints=("http://localhost:4001/api/health" "http://localhost:4001/api/services")
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        curl -s "$endpoint" >/dev/null 2>&1
        local end_time=$(date +%s%N)
        local duration=$(((end_time - start_time) / 1000000))
        
        if [ "$duration" -le 200 ]; then
            echo -e "    ${GREEN}✅ $endpoint: ${duration}ms${NC}"
            log_verification "PERFORMANCE" "API_RESPONSE_$endpoint" "SUCCESS" "Response time ${duration}ms" "${duration}ms"
        else
            echo -e "    ${YELLOW}⚠️  $endpoint: ${duration}ms (slow)${NC}"
            log_verification "PERFORMANCE" "API_RESPONSE_$endpoint" "WARNING" "Slow response time ${duration}ms" "${duration}ms"
        fi
    done
    
    # Check frontend load time
    echo -e "  ${CYAN}Checking frontend load time...${NC}"
    local start_time=$(date +%s%N)
    curl -s http://localhost:4000 >/dev/null 2>&1
    local end_time=$(date +%s%N)
    local duration=$(((end_time - start_time) / 1000000))
    
    if [ "$duration" -le 2000 ]; then
        echo -e "    ${GREEN}✅ Frontend load time: ${duration}ms${NC}"
        log_verification "PERFORMANCE" "FRONTEND_LOAD" "SUCCESS" "Load time ${duration}ms" "${duration}ms"
    else
        echo -e "    ${YELLOW}⚠️  Frontend load time: ${duration}ms (slow)${NC}"
        log_verification "PERFORMANCE" "FRONTEND_LOAD" "WARNING" "Slow load time ${duration}ms" "${duration}ms"
    fi
    
    return 0
}

# Function to generate verification report
generate_verification_report() {
    echo -e "${PURPLE}📋 Generating verification report...${NC}"
    
    local report_file="verification-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Collect verification results
    local verification_data='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "verification_results": {
            "service_startup": {
                "status": "unknown",
                "details": []
            },
            "api_endpoints": {
                "status": "unknown",
                "details": []
            },
            "database_connectivity": {
                "status": "unknown",
                "details": []
            },
            "frontend_functionality": {
                "status": "unknown",
                "details": []
            },
            "port_configurations": {
                "status": "unknown",
                "details": []
            },
            "process_status": {
                "status": "unknown",
                "details": []
            },
            "configuration_compliance": {
                "status": "unknown",
                "details": []
            },
            "performance_metrics": {
                "status": "unknown",
                "details": []
            }
        },
        "summary": {
            "total_checks": 0,
            "successful_checks": 0,
            "failed_checks": 0,
            "warning_checks": 0
        }
    }'
    
    echo "$verification_data" > "$report_file"
    
    echo -e "${GREEN}✅ Verification report generated: $report_file${NC}"
}

# Function to show verification summary
show_verification_summary() {
    echo -e "${PURPLE}📊 Verification Summary${NC}"
    echo "====================="
    
    if [ -f "$VERIFICATION_LOG" ]; then
        local total_checks=$(wc -l < "$VERIFICATION_LOG")
        local successful_checks=$(grep "|SUCCESS|" "$VERIFICATION_LOG" | wc -l)
        local failed_checks=$(grep "|FAILED|" "$VERIFICATION_LOG" | wc -l)
        local warning_checks=$(grep "|WARNING|" "$VERIFICATION_LOG" | wc -l)
        
        echo -e "${CYAN}Total checks: $total_checks${NC}"
        echo -e "${GREEN}Successful: $successful_checks${NC}"
        echo -e "${RED}Failed: $failed_checks${NC}"
        echo -e "${YELLOW}Warnings: $warning_checks${NC}"
        
        # Show recent failures
        if [ "$failed_checks" -gt 0 ]; then
            echo -e "${RED}Recent verification failures:${NC}"
            grep "|FAILED|" "$VERIFICATION_LOG" | tail -5 | while IFS='|' read -r timestamp component check status details duration; do
                echo -e "  ${YELLOW}$timestamp${NC} - ${RED}$component: $check${NC}"
                echo -e "    $details (${duration})"
            done
        fi
        
        # Show recent warnings
        if [ "$warning_checks" -gt 0 ]; then
            echo -e "${YELLOW}Recent verification warnings:${NC}"
            grep "|WARNING|" "$VERIFICATION_LOG" | tail -5 | while IFS='|' read -r timestamp component check status details duration; do
                echo -e "  ${YELLOW}$timestamp${NC} - ${YELLOW}$component: $check${NC}"
                echo -e "    $details (${duration})"
            done
        fi
    else
        echo -e "${YELLOW}No verification history found${NC}"
    fi
}

# Main verification function
main_verification() {
    echo -e "${PURPLE}🚀 Starting comprehensive verification...${NC}"
    echo ""
    
    local total_failures=0
    
    # Run all verifications
    verify_service_startup
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_api_endpoints
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_database_connectivity
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_frontend_functionality
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_port_configurations
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_process_status
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_configuration_compliance
    total_failures=$((total_failures + $?))
    echo ""
    
    verify_performance_metrics
    echo ""
    
    # Generate report
    generate_verification_report
    echo ""
    
    # Show summary
    show_verification_summary
    echo ""
    
    if [ "$total_failures" -eq 0 ]; then
        echo -e "${GREEN}✅ All verifications passed - System is ready${NC}"
        return 0
    else
        echo -e "${RED}❌ $total_failures verification failures detected${NC}"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-verify}"
    
    case "$action" in
        "verify")
            main_verification
            ;;
        "summary")
            show_verification_summary
            ;;
        "report")
            generate_verification_report
            ;;
        *)
            echo -e "${PURPLE}ANQA Verification Suite - Usage${NC}"
            echo "================================="
            echo "  $0 verify   - Run comprehensive verification"
            echo "  $0 summary  - Show verification summary"
            echo "  $0 report   - Generate verification report"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 verify"
            echo "  $0 summary"
            echo "  $0 report"
            ;;
    esac
}

# Run main function
main "$@"
