#!/bin/bash
set -e

# ANQA Auto Recovery - Automatic Error Recovery
# Automatically fixes common issues based on known error patterns

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RECOVERY_LOG="auto-recovery.log"
ERROR_PATTERNS_FILE="error-patterns.json"

echo -e "${PURPLE}🔄 ANQA Auto Recovery - Automatic Error Recovery${NC}"
echo "========================================================"

# Function to log recovery action
log_recovery() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local action="$1"
    local result="$2"
    local details="$3"
    
    echo "$timestamp|$action|$result|$details" >> "$RECOVERY_LOG"
}

# Function to detect port conflicts
detect_port_conflicts() {
    echo -e "${BLUE}🔍 Detecting port conflicts...${NC}"
    
    local conflicts=0
    local ports=(4000 4001 5434)
    
    for port in "${ports[@]}"; do
        local processes=$(lsof -i ":$port" 2>/dev/null | grep LISTEN | wc -l)
        if [ "$processes" -gt 1 ]; then
            echo -e "  ${RED}❌ Port $port has $processes processes${NC}"
            conflicts=$((conflicts + 1))
        else
            echo -e "  ${GREEN}✅ Port $port is clean${NC}"
        fi
    done
    
    if [ "$conflicts" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to fix port conflicts
fix_port_conflicts() {
    echo -e "${YELLOW}🔧 Fixing port conflicts...${NC}"
    
    # Kill Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | awk '{print $2}')
    if [ -n "$node_processes" ]; then
        echo -e "  ${CYAN}Killing Node.js processes...${NC}"
        echo "$node_processes" | xargs kill -TERM 2>/dev/null || true
        sleep 3
        
        # Force kill if still running
        local remaining=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | awk '{print $2}')
        if [ -n "$remaining" ]; then
            echo -e "  ${CYAN}Force killing remaining processes...${NC}"
            echo "$remaining" | xargs kill -KILL 2>/dev/null || true
        fi
    fi
    
    # Verify ports are free
    local ports_free=true
    for port in 4000 4001; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            echo -e "  ${RED}❌ Port $port still in use${NC}"
            ports_free=false
        else
            echo -e "  ${GREEN}✅ Port $port is free${NC}"
        fi
    done
    
    if [ "$ports_free" = true ]; then
        echo -e "${GREEN}✅ Port conflicts resolved${NC}"
        log_recovery "PORT_CONFLICT" "SUCCESS" "Killed conflicting processes"
        return 0
    else
        echo -e "${RED}❌ Failed to resolve port conflicts${NC}"
        log_recovery "PORT_CONFLICT" "FAILED" "Ports still in use after cleanup"
        return 1
    fi
}

# Function to detect database issues
detect_database_issues() {
    echo -e "${BLUE}🔍 Detecting database issues...${NC}"
    
    # Check database connection
    if ! psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "  ${RED}❌ Database connection failed${NC}"
        return 1
    fi
    
    # Check for expected content
    local page_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM pages;" 2>/dev/null | tr -d ' ')
    local service_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM services;" 2>/dev/null | tr -d ' ')
    
    if [ "$page_count" -lt 200 ] || [ "$service_count" -lt 5 ]; then
        echo -e "  ${RED}❌ Database content incomplete - Pages: $page_count, Services: $service_count${NC}"
        return 1
    fi
    
    echo -e "  ${GREEN}✅ Database is healthy${NC}"
    return 0
}

# Function to fix database issues
fix_database_issues() {
    echo -e "${YELLOW}🔧 Fixing database issues...${NC}"
    
    # Check if database file exists
    if [ ! -f "database/02-data.sql" ]; then
        echo -e "  ${RED}❌ Database file not found: database/02-data.sql${NC}"
        log_recovery "DATABASE_CONTENT" "FAILED" "Database file not found"
        return 1
    fi
    
    # Load database content
    echo -e "  ${CYAN}Loading database content...${NC}"
    if psql -h localhost -p 5434 -d anqa_website -f database/02-data.sql >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Database content loaded successfully${NC}"
        log_recovery "DATABASE_CONTENT" "SUCCESS" "Loaded database content from 02-data.sql"
        return 0
    else
        echo -e "  ${RED}❌ Failed to load database content${NC}"
        log_recovery "DATABASE_CONTENT" "FAILED" "Failed to load database content"
        return 1
    fi
}

# Function to detect API issues
detect_api_issues() {
    echo -e "${BLUE}🔍 Detecting API issues...${NC}"
    
    # Check backend API
    local backend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    if [ "$backend_response" != "200" ]; then
        echo -e "  ${RED}❌ Backend API not responding (HTTP $backend_response)${NC}"
        return 1
    fi
    
    # Check frontend
    local frontend_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    if [ "$frontend_response" != "200" ]; then
        echo -e "  ${RED}❌ Frontend not responding (HTTP $frontend_response)${NC}"
        return 1
    fi
    
    echo -e "  ${GREEN}✅ APIs are healthy${NC}"
    return 0
}

# Function to fix API issues
fix_api_issues() {
    echo -e "${YELLOW}🔧 Fixing API issues...${NC}"
    
    # Start backend
    echo -e "  ${CYAN}Starting backend...${NC}"
    cd backend && npm start >/dev/null 2>&1 &
    local backend_pid=$!
    cd ..
    
    # Wait for backend to start
    local backend_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:4001/api/health >/dev/null 2>&1; then
            backend_ready=true
            break
        fi
        sleep 1
    done
    
    if [ "$backend_ready" = false ]; then
        echo -e "  ${RED}❌ Backend failed to start${NC}"
        kill $backend_pid 2>/dev/null || true
        log_recovery "API_BACKEND" "FAILED" "Backend failed to start"
        return 1
    fi
    
    echo -e "  ${GREEN}✅ Backend started successfully${NC}"
    
    # Start frontend
    echo -e "  ${CYAN}Starting frontend...${NC}"
    cd frontend && npm start >/dev/null 2>&1 &
    local frontend_pid=$!
    cd ..
    
    # Wait for frontend to start
    local frontend_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:4000 >/dev/null 2>&1; then
            frontend_ready=true
            break
        fi
        sleep 1
    done
    
    if [ "$frontend_ready" = false ]; then
        echo -e "  ${RED}❌ Frontend failed to start${NC}"
        kill $frontend_pid 2>/dev/null || true
        log_recovery "API_FRONTEND" "FAILED" "Frontend failed to start"
        return 1
    fi
    
    echo -e "  ${GREEN}✅ Frontend started successfully${NC}"
    log_recovery "API_SERVICES" "SUCCESS" "Started backend and frontend services"
    return 0
}

# Function to detect configuration issues
detect_configuration_issues() {
    echo -e "${BLUE}🔍 Detecting configuration issues...${NC}"
    
    local issues=0
    
    # Check frontend configuration
    if [ -f "frontend/.env" ]; then
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "")
        if [ "$vite_api_url" != "http://localhost:4001" ]; then
            echo -e "  ${RED}❌ Frontend API URL incorrect: $vite_api_url${NC}"
            issues=$((issues + 1))
        else
            echo -e "  ${GREEN}✅ Frontend configuration correct${NC}"
        fi
    else
        echo -e "  ${RED}❌ Frontend .env file missing${NC}"
        issues=$((issues + 1))
    fi
    
    # Check backend configuration
    if [ -f "backend/.env" ]; then
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 || echo "")
        if [ "$backend_port" != "4001" ]; then
            echo -e "  ${RED}❌ Backend port incorrect: $backend_port${NC}"
            issues=$((issues + 1))
        else
            echo -e "  ${GREEN}✅ Backend configuration correct${NC}"
        fi
    else
        echo -e "  ${RED}❌ Backend .env file missing${NC}"
        issues=$((issues + 1))
    fi
    
    if [ "$issues" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to fix configuration issues
fix_configuration_issues() {
    echo -e "${YELLOW}🔧 Fixing configuration issues...${NC}"
    
    # Fix frontend configuration
    if [ ! -f "frontend/.env" ]; then
        echo -e "  ${CYAN}Creating frontend .env file...${NC}"
        echo "VITE_API_BASE_URL=http://localhost:4001" > frontend/.env
        echo -e "  ${GREEN}✅ Frontend .env created${NC}"
    else
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "")
        if [ "$vite_api_url" != "http://localhost:4001" ]; then
            echo -e "  ${CYAN}Fixing frontend API URL...${NC}"
            sed -i '' 's|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=http://localhost:4001|' frontend/.env
            echo -e "  ${GREEN}✅ Frontend API URL fixed${NC}"
        fi
    fi
    
    # Fix backend configuration
    if [ ! -f "backend/.env" ]; then
        echo -e "  ${CYAN}Creating backend .env file...${NC}"
        echo 'PORT="4001"' > backend/.env
        echo 'DATABASE_URL="postgresql://danielrogers@localhost:5434/anqa_website"' >> backend/.env
        echo -e "  ${GREEN}✅ Backend .env created${NC}"
    else
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 || echo "")
        if [ "$backend_port" != "4001" ]; then
            echo -e "  ${CYAN}Fixing backend port...${NC}"
            sed -i '' 's|PORT=.*|PORT="4001"|' backend/.env
            echo -e "  ${GREEN}✅ Backend port fixed${NC}"
        fi
    fi
    
    log_recovery "CONFIGURATION" "SUCCESS" "Fixed configuration files"
    return 0
}

# Function to run comprehensive recovery
run_comprehensive_recovery() {
    echo -e "${PURPLE}🚀 Running comprehensive recovery...${NC}"
    echo ""
    
    local recovery_success=true
    
    # Step 1: Fix port conflicts
    if ! detect_port_conflicts; then
        echo -e "${YELLOW}⚠️  Port conflicts detected, attempting to fix...${NC}"
        if ! fix_port_conflicts; then
            recovery_success=false
        fi
    fi
    echo ""
    
    # Step 2: Fix database issues
    if ! detect_database_issues; then
        echo -e "${YELLOW}⚠️  Database issues detected, attempting to fix...${NC}"
        if ! fix_database_issues; then
            recovery_success=false
        fi
    fi
    echo ""
    
    # Step 3: Fix configuration issues
    if ! detect_configuration_issues; then
        echo -e "${YELLOW}⚠️  Configuration issues detected, attempting to fix...${NC}"
        if ! fix_configuration_issues; then
            recovery_success=false
        fi
    fi
    echo ""
    
    # Step 4: Fix API issues
    if ! detect_api_issues; then
        echo -e "${YELLOW}⚠️  API issues detected, attempting to fix...${NC}"
        if ! fix_api_issues; then
            recovery_success=false
        fi
    fi
    echo ""
    
    # Final verification
    echo -e "${BLUE}🔍 Running final verification...${NC}"
    if detect_port_conflicts && detect_database_issues && detect_configuration_issues && detect_api_issues; then
        echo -e "${GREEN}✅ All systems recovered successfully${NC}"
        log_recovery "COMPREHENSIVE" "SUCCESS" "All systems recovered"
        return 0
    else
        echo -e "${RED}❌ Some issues remain after recovery${NC}"
        log_recovery "COMPREHENSIVE" "PARTIAL" "Some issues remain"
        return 1
    fi
}

# Function to show recovery history
show_recovery_history() {
    echo -e "${PURPLE}📋 Recovery History${NC}"
    echo "=================="
    
    if [ -f "$RECOVERY_LOG" ]; then
        echo -e "${CYAN}Recent recovery actions:${NC}"
        tail -10 "$RECOVERY_LOG" | while IFS='|' read -r timestamp action result details; do
            if [ "$result" = "SUCCESS" ]; then
                echo -e "  ${GREEN}$timestamp - $action: SUCCESS${NC}"
            else
                echo -e "  ${RED}$timestamp - $action: $result${NC}"
            fi
            echo -e "    Details: $details"
        done
    else
        echo -e "${YELLOW}No recovery history found${NC}"
    fi
}

# Function to generate recovery report
generate_recovery_report() {
    echo -e "${PURPLE}📋 Generating recovery report...${NC}"
    
    local report_file="recovery-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Auto Recovery Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================"
        echo ""
        
        echo "System Status:"
        echo "-------------"
        
        # Port status
        echo "Port Status:"
        for port in 4000 4001 5434; do
            if lsof -i ":$port" >/dev/null 2>&1; then
                echo "  Port $port: Active"
            else
                echo "  Port $port: Inactive"
            fi
        done
        echo ""
        
        # Service status
        echo "Service Status:"
        local backend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
        local frontend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
        local db_status=$(psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1 && echo "Connected" || echo "Disconnected")
        
        echo "  Backend: HTTP $backend_status"
        echo "  Frontend: HTTP $frontend_status"
        echo "  Database: $db_status"
        echo ""
        
        # Recovery history
        if [ -f "$RECOVERY_LOG" ]; then
            echo "Recent Recovery Actions:"
            echo "----------------------"
            tail -5 "$RECOVERY_LOG" | while IFS='|' read -r timestamp action result details; do
                echo "  $timestamp - $action: $result"
                echo "    $details"
            done
        fi
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Recovery report generated: $report_file${NC}"
}

# Main execution
main() {
    local action="${1:-comprehensive}"
    
    case "$action" in
        "comprehensive")
            run_comprehensive_recovery
            ;;
        "ports")
            if ! detect_port_conflicts; then
                fix_port_conflicts
            fi
            ;;
        "database")
            if ! detect_database_issues; then
                fix_database_issues
            fi
            ;;
        "api")
            if ! detect_api_issues; then
                fix_api_issues
            fi
            ;;
        "config")
            if ! detect_configuration_issues; then
                fix_configuration_issues
            fi
            ;;
        "history")
            show_recovery_history
            ;;
        "report")
            generate_recovery_report
            ;;
        *)
            echo -e "${PURPLE}ANQA Auto Recovery - Usage${NC}"
            echo "============================="
            echo "  $0 comprehensive  - Run comprehensive recovery"
            echo "  $0 ports          - Fix port conflicts only"
            echo "  $0 database       - Fix database issues only"
            echo "  $0 api            - Fix API issues only"
            echo "  $0 config         - Fix configuration issues only"
            echo "  $0 history        - Show recovery history"
            echo "  $0 report         - Generate recovery report"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 comprehensive"
            echo "  $0 ports"
            echo "  $0 history"
            ;;
    esac
}

# Run main function
main "$@"
