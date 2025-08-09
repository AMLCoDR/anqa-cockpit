#!/bin/bash
set -e

# ANQA Config Validator - Configuration Drift Detection
# Detects configuration drift and ensures compliance with permanent settings

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VALIDATION_LOG="config-validation.log"
DRIFT_REPORT="config-drift-report.json"
PERMANENT_CONFIG="PERMANENT_CONFIG.md"

echo -e "${PURPLE}🔍 ANQA Config Validator - Configuration Drift Detection${NC}"
echo "============================================================="

# Function to log validation result
log_validation() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local component="$1"
    local check="$2"
    local status="$3"
    local details="$4"
    
    echo "$timestamp|$component|$check|$status|$details" >> "$VALIDATION_LOG"
}

# Function to validate port configurations
validate_port_configurations() {
    echo -e "${BLUE}🔍 Validating port configurations...${NC}"
    
    local drift_detected=false
    
    # Check frontend port in package.json
    if [ -f "frontend/package.json" ]; then
        local frontend_port=$(grep -A 5 '"start"' frontend/package.json | grep "PORT=" | cut -d'=' -f2 | tr -d '"' || echo "not_found")
        if [ "$frontend_port" = "4000" ]; then
            echo -e "  ${GREEN}✅ Frontend port: 4000${NC}"
            log_validation "FRONTEND" "PORT_CONFIG" "COMPLIANT" "Port 4000 correctly configured"
        else
            echo -e "  ${RED}❌ Frontend port drift: $frontend_port (expected 4000)${NC}"
            log_validation "FRONTEND" "PORT_CONFIG" "DRIFT" "Port $frontend_port instead of 4000"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ Frontend package.json not found${NC}"
        log_validation "FRONTEND" "PORT_CONFIG" "MISSING" "package.json file not found"
        drift_detected=true
    fi
    
    # Check backend port in .env
    if [ -f "backend/.env" ]; then
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 | tr -d '"' || echo "not_found")
        if [ "$backend_port" = "4001" ]; then
            echo -e "  ${GREEN}✅ Backend port: 4001${NC}"
            log_validation "BACKEND" "PORT_CONFIG" "COMPLIANT" "Port 4001 correctly configured"
        else
            echo -e "  ${RED}❌ Backend port drift: $backend_port (expected 4001)${NC}"
            log_validation "BACKEND" "PORT_CONFIG" "DRIFT" "Port $backend_port instead of 4001"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ Backend .env not found${NC}"
        log_validation "BACKEND" "PORT_CONFIG" "MISSING" ".env file not found"
        drift_detected=true
    fi
    
    # Check database port (should be 5434)
    echo -e "  ${CYAN}Database port: 5434 (PostgreSQL default)${NC}"
    log_validation "DATABASE" "PORT_CONFIG" "COMPLIANT" "Port 5434 correctly configured"
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to validate environment configurations
validate_environment_configurations() {
    echo -e "${BLUE}🔍 Validating environment configurations...${NC}"
    
    local drift_detected=false
    
    # Check frontend environment
    if [ -f "frontend/.env" ]; then
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "not_found")
        if [ "$vite_api_url" = "http://localhost:4001" ]; then
            echo -e "  ${GREEN}✅ Frontend API URL: $vite_api_url${NC}"
            log_validation "FRONTEND" "ENV_CONFIG" "COMPLIANT" "API URL correctly configured"
        else
            echo -e "  ${RED}❌ Frontend API URL drift: $vite_api_url (expected http://localhost:4001)${NC}"
            log_validation "FRONTEND" "ENV_CONFIG" "DRIFT" "API URL $vite_api_url instead of http://localhost:4001"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ Frontend .env not found${NC}"
        log_validation "FRONTEND" "ENV_CONFIG" "MISSING" ".env file not found"
        drift_detected=true
    fi
    
    # Check backend environment
    if [ -f "backend/.env" ]; then
        local db_url=$(grep "DATABASE_URL" backend/.env | cut -d'=' -f2 || echo "not_found")
        if [[ "$db_url" == *"localhost:5434/anqa_website"* ]]; then
            echo -e "  ${GREEN}✅ Backend database URL: $db_url${NC}"
            log_validation "BACKEND" "ENV_CONFIG" "COMPLIANT" "Database URL correctly configured"
        else
            echo -e "  ${RED}❌ Backend database URL drift: $db_url${NC}"
            log_validation "BACKEND" "ENV_CONFIG" "DRIFT" "Database URL $db_url"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ Backend .env not found${NC}"
        log_validation "BACKEND" "ENV_CONFIG" "MISSING" ".env file not found"
        drift_detected=true
    fi
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to validate server configurations
validate_server_configurations() {
    echo -e "${BLUE}🔍 Validating server configurations...${NC}"
    
    local drift_detected=false
    
    # Check backend server.js
    if [ -f "backend/src/server.js" ]; then
        # Check for dotenv configuration
        if grep -q "require.*dotenv" "backend/src/server.js"; then
            echo -e "  ${GREEN}✅ Backend dotenv configuration present${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "COMPLIANT" "dotenv configuration present"
        else
            echo -e "  ${RED}❌ Backend dotenv configuration missing${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "DRIFT" "dotenv configuration missing"
            drift_detected=true
        fi
        
        # Check for CORS configuration
        if grep -q "cors" "backend/src/server.js"; then
            echo -e "  ${GREEN}✅ Backend CORS configuration present${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "COMPLIANT" "CORS configuration present"
        else
            echo -e "  ${RED}❌ Backend CORS configuration missing${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "DRIFT" "CORS configuration missing"
            drift_detected=true
        fi
        
        # Check for environment variable usage
        if grep -q "process.env.PORT" "backend/src/server.js"; then
            echo -e "  ${GREEN}✅ Backend environment variable usage correct${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "COMPLIANT" "Environment variable usage correct"
        else
            echo -e "  ${RED}❌ Backend environment variable usage incorrect${NC}"
            log_validation "BACKEND" "SERVER_CONFIG" "DRIFT" "Environment variable usage incorrect"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ Backend server.js not found${NC}"
        log_validation "BACKEND" "SERVER_CONFIG" "MISSING" "server.js file not found"
        drift_detected=true
    fi
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to validate database configurations
validate_database_configurations() {
    echo -e "${BLUE}🔍 Validating database configurations...${NC}"
    
    local drift_detected=false
    
    # Check database file existence
    if [ -f "database/02-data.sql" ]; then
        local file_size=$(ls -lh "database/02-data.sql" | awk '{print $5}')
        echo -e "  ${GREEN}✅ Database file: database/02-data.sql ($file_size)${NC}"
        log_validation "DATABASE" "FILE_CONFIG" "COMPLIANT" "Database file present ($file_size)"
    else
        echo -e "  ${RED}❌ Database file missing: database/02-data.sql${NC}"
        log_validation "DATABASE" "FILE_CONFIG" "MISSING" "Database file not found"
        drift_detected=true
    fi
    
    # Check database connection
    if command -v psql >/dev/null 2>&1; then
        if psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Database connection successful${NC}"
            log_validation "DATABASE" "CONNECTION_CONFIG" "COMPLIANT" "Database connection successful"
            
            # Check database content
            local page_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM pages;" 2>/dev/null | tr -d ' ')
            local service_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM services;" 2>/dev/null | tr -d ' ')
            
            if [ "$page_count" -ge 200 ] && [ "$service_count" -ge 5 ]; then
                echo -e "  ${GREEN}✅ Database content: $page_count pages, $service_count services${NC}"
                log_validation "DATABASE" "CONTENT_CONFIG" "COMPLIANT" "Database content complete"
            else
                echo -e "  ${RED}❌ Database content incomplete: $page_count pages, $service_count services${NC}"
                log_validation "DATABASE" "CONTENT_CONFIG" "DRIFT" "Database content incomplete"
                drift_detected=true
            fi
        else
            echo -e "  ${RED}❌ Database connection failed${NC}"
            log_validation "DATABASE" "CONNECTION_CONFIG" "DRIFT" "Database connection failed"
            drift_detected=true
        fi
    else
        echo -e "  ${RED}❌ PostgreSQL client not available${NC}"
        log_validation "DATABASE" "CONNECTION_CONFIG" "MISSING" "PostgreSQL client not available"
        drift_detected=true
    fi
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to validate file structure
validate_file_structure() {
    echo -e "${BLUE}🔍 Validating file structure...${NC}"
    
    local drift_detected=false
    
    # Required directories
    local required_dirs=("frontend" "backend" "database" "scripts")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✅ Directory: $dir${NC}"
            log_validation "STRUCTURE" "DIRECTORY" "COMPLIANT" "Directory $dir present"
        else
            echo -e "  ${RED}❌ Directory missing: $dir${NC}"
            log_validation "STRUCTURE" "DIRECTORY" "MISSING" "Directory $dir not found"
            drift_detected=true
        fi
    done
    
    # Required files
    local required_files=("PERMANENT_CONFIG.md" "SYSTEM_CHANGELOG.md" "README.md")
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "  ${GREEN}✅ File: $file${NC}"
            log_validation "STRUCTURE" "FILE" "COMPLIANT" "File $file present"
        else
            echo -e "  ${RED}❌ File missing: $file${NC}"
            log_validation "STRUCTURE" "FILE" "MISSING" "File $file not found"
            drift_detected=true
        fi
    done
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to validate service configurations
validate_service_configurations() {
    echo -e "${BLUE}🔍 Validating service configurations...${NC}"
    
    local drift_detected=false
    
    # Check if services are running
    local backend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4001/api/health 2>/dev/null || echo "000")
    if [ "$backend_status" = "200" ]; then
        echo -e "  ${GREEN}✅ Backend service: Running (HTTP $backend_status)${NC}"
        log_validation "SERVICE" "BACKEND_STATUS" "COMPLIANT" "Backend service running"
    else
        echo -e "  ${RED}❌ Backend service: Not running (HTTP $backend_status)${NC}"
        log_validation "SERVICE" "BACKEND_STATUS" "DRIFT" "Backend service not running"
        drift_detected=true
    fi
    
    local frontend_status=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:4000 2>/dev/null || echo "000")
    if [ "$frontend_status" = "200" ]; then
        echo -e "  ${GREEN}✅ Frontend service: Running (HTTP $frontend_status)${NC}"
        log_validation "SERVICE" "FRONTEND_STATUS" "COMPLIANT" "Frontend service running"
    else
        echo -e "  ${RED}❌ Frontend service: Not running (HTTP $frontend_status)${NC}"
        log_validation "SERVICE" "FRONTEND_STATUS" "DRIFT" "Frontend service not running"
        drift_detected=true
    fi
    
    # Check port usage
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Port $port: Active${NC}"
            log_validation "SERVICE" "PORT_STATUS" "COMPLIANT" "Port $port active"
        else
            echo -e "  ${RED}❌ Port $port: Inactive${NC}"
            log_validation "SERVICE" "PORT_STATUS" "DRIFT" "Port $port inactive"
            drift_detected=true
        fi
    done
    
    return $([ "$drift_detected" = true ] && echo 1 || echo 0)
}

# Function to generate drift report
generate_drift_report() {
    echo -e "${PURPLE}📋 Generating configuration drift report...${NC}"
    
    local report_file="config-drift-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Collect all validation results
    local drift_data='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "validation_results": {
            "port_configurations": {
                "status": "unknown",
                "drifts": []
            },
            "environment_configurations": {
                "status": "unknown",
                "drifts": []
            },
            "server_configurations": {
                "status": "unknown",
                "drifts": []
            },
            "database_configurations": {
                "status": "unknown",
                "drifts": []
            },
            "file_structure": {
                "status": "unknown",
                "drifts": []
            },
            "service_configurations": {
                "status": "unknown",
                "drifts": []
            }
        },
        "summary": {
            "total_checks": 0,
            "compliant_checks": 0,
            "drift_checks": 0,
            "missing_checks": 0
        }
    }'
    
    echo "$drift_data" > "$report_file"
    
    echo -e "${GREEN}✅ Configuration drift report generated: $report_file${NC}"
}

# Function to show validation summary
show_validation_summary() {
    echo -e "${PURPLE}📊 Configuration Validation Summary${NC}"
    echo "====================================="
    
    if [ -f "$VALIDATION_LOG" ]; then
        local total_checks=$(wc -l < "$VALIDATION_LOG")
        local compliant_checks=$(grep "|COMPLIANT|" "$VALIDATION_LOG" | wc -l)
        local drift_checks=$(grep "|DRIFT|" "$VALIDATION_LOG" | wc -l)
        local missing_checks=$(grep "|MISSING|" "$VALIDATION_LOG" | wc -l)
        
        echo -e "${CYAN}Total checks: $total_checks${NC}"
        echo -e "${GREEN}Compliant: $compliant_checks${NC}"
        echo -e "${RED}Drift detected: $drift_checks${NC}"
        echo -e "${YELLOW}Missing: $missing_checks${NC}"
        
        # Show recent drifts
        if [ "$drift_checks" -gt 0 ]; then
            echo -e "${RED}Recent configuration drifts:${NC}"
            grep "|DRIFT|" "$VALIDATION_LOG" | tail -5 | while IFS='|' read -r timestamp component check status details; do
                echo -e "  ${YELLOW}$timestamp${NC} - ${RED}$component: $check${NC}"
                echo -e "    $details"
            done
        fi
        
        # Show missing configurations
        if [ "$missing_checks" -gt 0 ]; then
            echo -e "${YELLOW}Missing configurations:${NC}"
            grep "|MISSING|" "$VALIDATION_LOG" | tail -5 | while IFS='|' read -r timestamp component check status details; do
                echo -e "  ${YELLOW}$timestamp${NC} - ${RED}$component: $check${NC}"
                echo -e "    $details"
            done
        fi
    else
        echo -e "${YELLOW}No validation history found${NC}"
    fi
}

# Function to fix configuration drifts
fix_configuration_drifts() {
    echo -e "${YELLOW}🔧 Fixing configuration drifts...${NC}"
    
    local fixes_applied=0
    
    # Fix frontend port configuration
    if [ -f "frontend/package.json" ]; then
        local frontend_port=$(grep -A 5 '"start"' frontend/package.json | grep "PORT=" | cut -d'=' -f2 | tr -d '"' || echo "not_found")
        if [ "$frontend_port" != "4000" ]; then
            echo -e "  ${CYAN}Fixing frontend port configuration...${NC}"
            sed -i '' 's|PORT=[0-9]*|PORT=4000|' frontend/package.json
            echo -e "  ${GREEN}✅ Frontend port fixed to 4000${NC}"
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    # Fix backend port configuration
    if [ -f "backend/.env" ]; then
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 | tr -d '"' || echo "not_found")
        if [ "$backend_port" != "4001" ]; then
            echo -e "  ${CYAN}Fixing backend port configuration...${NC}"
            sed -i '' 's|PORT=.*|PORT="4001"|' backend/.env
            echo -e "  ${GREEN}✅ Backend port fixed to 4001${NC}"
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    # Fix frontend API URL
    if [ -f "frontend/.env" ]; then
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "not_found")
        if [ "$vite_api_url" != "http://localhost:4001" ]; then
            echo -e "  ${CYAN}Fixing frontend API URL...${NC}"
            sed -i '' 's|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=http://localhost:4001|' frontend/.env
            echo -e "  ${GREEN}✅ Frontend API URL fixed${NC}"
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    # Fix backend database URL
    if [ -f "backend/.env" ]; then
        local db_url=$(grep "DATABASE_URL" backend/.env | cut -d'=' -f2 || echo "not_found")
        if [[ "$db_url" != *"localhost:5434/anqa_website"* ]]; then
            echo -e "  ${CYAN}Fixing backend database URL...${NC}"
            sed -i '' 's|DATABASE_URL=.*|DATABASE_URL="postgresql://danielrogers@localhost:5434/anqa_website"|' backend/.env
            echo -e "  ${GREEN}✅ Backend database URL fixed${NC}"
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    if [ "$fixes_applied" -gt 0 ]; then
        echo -e "${GREEN}✅ Applied $fixes_applied configuration fixes${NC}"
        log_validation "AUTO_FIX" "CONFIGURATION_FIXES" "SUCCESS" "Applied $fixes_applied fixes"
    else
        echo -e "${CYAN}✅ No configuration fixes needed${NC}"
        log_validation "AUTO_FIX" "CONFIGURATION_FIXES" "SUCCESS" "No fixes needed"
    fi
}

# Main validation function
main_validation() {
    echo -e "${PURPLE}🚀 Starting configuration validation...${NC}"
    echo ""
    
    local total_drifts=0
    
    # Run all validations
    validate_port_configurations
    total_drifts=$((total_drifts + $?))
    echo ""
    
    validate_environment_configurations
    total_drifts=$((total_drifts + $?))
    echo ""
    
    validate_server_configurations
    total_drifts=$((total_drifts + $?))
    echo ""
    
    validate_database_configurations
    total_drifts=$((total_drifts + $?))
    echo ""
    
    validate_file_structure
    total_drifts=$((total_drifts + $?))
    echo ""
    
    validate_service_configurations
    total_drifts=$((total_drifts + $?))
    echo ""
    
    # Generate report
    generate_drift_report
    echo ""
    
    # Show summary
    show_validation_summary
    echo ""
    
    if [ "$total_drifts" -eq 0 ]; then
        echo -e "${GREEN}✅ All configurations are compliant${NC}"
        return 0
    else
        echo -e "${RED}❌ $total_drifts configuration drifts detected${NC}"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-validate}"
    
    case "$action" in
        "validate")
            main_validation
            ;;
        "fix")
            fix_configuration_drifts
            ;;
        "summary")
            show_validation_summary
            ;;
        "report")
            generate_drift_report
            ;;
        *)
            echo -e "${PURPLE}ANQA Config Validator - Usage${NC}"
            echo "==============================="
            echo "  $0 validate  - Run full configuration validation"
            echo "  $0 fix       - Fix configuration drifts automatically"
            echo "  $0 summary   - Show validation summary"
            echo "  $0 report    - Generate drift report"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 validate"
            echo "  $0 fix"
            echo "  $0 summary"
            ;;
    esac
}

# Run main function
main "$@"
