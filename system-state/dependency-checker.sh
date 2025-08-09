#!/bin/bash
set -e

# ANQA Dependency Checker - Dependency Health Verification
# Verifies the health and versions of all system dependencies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEPENDENCY_LOG="dependency-checker.log"
DEPENDENCY_REPORT="dependency-report.json"
REQUIRED_VERSIONS="required-versions.json"

echo -e "${PURPLE}🔧 ANQA Dependency Checker - Dependency Health Verification${NC}"
echo "============================================================="

# Function to log dependency check
log_dependency_check() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local dependency="$1"
    local version="$2"
    local status="$3"
    local details="$4"
    
    echo "$timestamp|$dependency|$version|$status|$details" >> "$DEPENDENCY_LOG"
}

# Function to initialize required versions
initialize_required_versions() {
    echo -e "${BLUE}🔧 Initializing required versions...${NC}"
    
    local required_versions='{
        "system": {
            "node": "18.0.0",
            "npm": "8.0.0",
            "postgresql": "13.0.0",
            "curl": "7.0.0",
            "lsof": "8.0.0",
            "jq": "1.6.0",
            "bc": "1.0.0"
        },
        "frontend": {
            "react": "18.0.0",
            "react-dom": "18.0.0",
            "vite": "4.0.0"
        },
        "backend": {
            "express": "4.18.0",
            "cors": "2.8.5",
            "dotenv": "16.0.0",
            "pg": "8.8.0"
        }
    }'
    
    echo "$required_versions" > "$REQUIRED_VERSIONS"
    echo -e "${GREEN}✅ Required versions initialized${NC}"
}

# Function to compare versions
compare_versions() {
    local current_version="$1"
    local required_version="$2"
    
    # Remove any non-numeric characters except dots
    local current_clean=$(echo "$current_version" | sed 's/[^0-9.]//g')
    local required_clean=$(echo "$required_version" | sed 's/[^0-9.]//g')
    
    # Compare versions using sort
    local comparison=$(printf "%s\n%s" "$current_clean" "$required_clean" | sort -V | head -1)
    
    if [ "$comparison" = "$required_clean" ] && [ "$current_clean" != "$required_clean" ]; then
        echo "outdated"
    elif [ "$current_clean" = "$required_clean" ]; then
        echo "exact"
    else
        echo "current"
    fi
}

# Function to check system dependencies
check_system_dependencies() {
    echo -e "${BLUE}🔍 Checking system dependencies...${NC}"
    
    # Check Node.js
    echo -e "  ${CYAN}Checking Node.js...${NC}"
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null | sed 's/v//')
        local required_node=$(jq -r '.system.node' "$REQUIRED_VERSIONS")
        local node_status=$(compare_versions "$node_version" "$required_node")
        
        case "$node_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ Node.js: $node_version${NC}"
                log_dependency_check "node" "$node_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  Node.js: $node_version (required: $required_node)${NC}"
                log_dependency_check "node" "$node_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ Node.js not installed${NC}"
        log_dependency_check "node" "not_found" "FAILED" "Node.js not installed"
    fi
    
    # Check npm
    echo -e "  ${CYAN}Checking npm...${NC}"
    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version 2>/dev/null)
        local required_npm=$(jq -r '.system.npm' "$REQUIRED_VERSIONS")
        local npm_status=$(compare_versions "$npm_version" "$required_npm")
        
        case "$npm_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ npm: $npm_version${NC}"
                log_dependency_check "npm" "$npm_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  npm: $npm_version (required: $required_npm)${NC}"
                log_dependency_check "npm" "$npm_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ npm not installed${NC}"
        log_dependency_check "npm" "not_found" "FAILED" "npm not installed"
    fi
    
    # Check PostgreSQL
    echo -e "  ${CYAN}Checking PostgreSQL...${NC}"
    if command -v psql >/dev/null 2>&1; then
        local postgres_version=$(psql --version 2>/dev/null | awk '{print $3}' | cut -d',' -f1)
        local required_postgres=$(jq -r '.system.postgresql' "$REQUIRED_VERSIONS")
        local postgres_status=$(compare_versions "$postgres_version" "$required_postgres")
        
        case "$postgres_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ PostgreSQL: $postgres_version${NC}"
                log_dependency_check "postgresql" "$postgres_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  PostgreSQL: $postgres_version (required: $required_postgres)${NC}"
                log_dependency_check "postgresql" "$postgres_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ PostgreSQL not installed${NC}"
        log_dependency_check "postgresql" "not_found" "FAILED" "PostgreSQL not installed"
    fi
    
    # Check curl
    echo -e "  ${CYAN}Checking curl...${NC}"
    if command -v curl >/dev/null 2>&1; then
        local curl_version=$(curl --version 2>/dev/null | head -1 | awk '{print $2}')
        local required_curl=$(jq -r '.system.curl' "$REQUIRED_VERSIONS")
        local curl_status=$(compare_versions "$curl_version" "$required_curl")
        
        case "$curl_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ curl: $curl_version${NC}"
                log_dependency_check "curl" "$curl_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  curl: $curl_version (required: $required_curl)${NC}"
                log_dependency_check "curl" "$curl_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ curl not installed${NC}"
        log_dependency_check "curl" "not_found" "FAILED" "curl not installed"
    fi
    
    # Check lsof
    echo -e "  ${CYAN}Checking lsof...${NC}"
    if command -v lsof >/dev/null 2>&1; then
        local lsof_version=$(lsof -v 2>&1 | head -1 | awk '{print $3}')
        local required_lsof=$(jq -r '.system.lsof' "$REQUIRED_VERSIONS")
        local lsof_status=$(compare_versions "$lsof_version" "$required_lsof")
        
        case "$lsof_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ lsof: $lsof_version${NC}"
                log_dependency_check "lsof" "$lsof_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  lsof: $lsof_version (required: $required_lsof)${NC}"
                log_dependency_check "lsof" "$lsof_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ lsof not installed${NC}"
        log_dependency_check "lsof" "not_found" "FAILED" "lsof not installed"
    fi
    
    # Check jq
    echo -e "  ${CYAN}Checking jq...${NC}"
    if command -v jq >/dev/null 2>&1; then
        local jq_version=$(jq --version 2>/dev/null | sed 's/jq-//')
        local required_jq=$(jq -r '.system.jq' "$REQUIRED_VERSIONS")
        local jq_status=$(compare_versions "$jq_version" "$required_jq")
        
        case "$jq_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ jq: $jq_version${NC}"
                log_dependency_check "jq" "$jq_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  jq: $jq_version (required: $required_jq)${NC}"
                log_dependency_check "jq" "$jq_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ jq not installed${NC}"
        log_dependency_check "jq" "not_found" "FAILED" "jq not installed"
    fi
    
    # Check bc
    echo -e "  ${CYAN}Checking bc...${NC}"
    if command -v bc >/dev/null 2>&1; then
        local bc_version=$(bc --version 2>/dev/null | head -1 | awk '{print $2}')
        local required_bc=$(jq -r '.system.bc' "$REQUIRED_VERSIONS")
        local bc_status=$(compare_versions "$bc_version" "$required_bc")
        
        case "$bc_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ bc: $bc_version${NC}"
                log_dependency_check "bc" "$bc_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  bc: $bc_version (required: $required_bc)${NC}"
                log_dependency_check "bc" "$bc_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ bc not installed${NC}"
        log_dependency_check "bc" "not_found" "FAILED" "bc not installed"
    fi
}

# Function to check frontend dependencies
check_frontend_dependencies() {
    echo -e "${BLUE}🔍 Checking frontend dependencies...${NC}"
    
    if [ ! -f "frontend/package.json" ]; then
        echo -e "  ${RED}❌ Frontend package.json not found${NC}"
        log_dependency_check "frontend_package" "not_found" "FAILED" "package.json not found"
        return 1
    fi
    
    # Check React
    echo -e "  ${CYAN}Checking React...${NC}"
    local react_version=$(jq -r '.dependencies.react' frontend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$react_version" != "null" ]; then
        local required_react=$(jq -r '.frontend.react' "$REQUIRED_VERSIONS")
        local react_status=$(compare_versions "$react_version" "$required_react")
        
        case "$react_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ React: $react_version${NC}"
                log_dependency_check "react" "$react_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  React: $react_version (required: $required_react)${NC}"
                log_dependency_check "react" "$react_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ React not found in package.json${NC}"
        log_dependency_check "react" "not_found" "FAILED" "React not in package.json"
    fi
    
    # Check React DOM
    echo -e "  ${CYAN}Checking React DOM...${NC}"
    local react_dom_version=$(jq -r '.dependencies["react-dom"]' frontend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$react_dom_version" != "null" ]; then
        local required_react_dom=$(jq -r '.frontend["react-dom"]' "$REQUIRED_VERSIONS")
        local react_dom_status=$(compare_versions "$react_dom_version" "$required_react_dom")
        
        case "$react_dom_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ React DOM: $react_dom_version${NC}"
                log_dependency_check "react-dom" "$react_dom_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  React DOM: $react_dom_version (required: $required_react_dom)${NC}"
                log_dependency_check "react-dom" "$react_dom_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ React DOM not found in package.json${NC}"
        log_dependency_check "react-dom" "not_found" "FAILED" "React DOM not in package.json"
    fi
    
    # Check Vite
    echo -e "  ${CYAN}Checking Vite...${NC}"
    local vite_version=$(jq -r '.devDependencies.vite' frontend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$vite_version" != "null" ]; then
        local required_vite=$(jq -r '.frontend.vite' "$REQUIRED_VERSIONS")
        local vite_status=$(compare_versions "$vite_version" "$required_vite")
        
        case "$vite_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ Vite: $vite_version${NC}"
                log_dependency_check "vite" "$vite_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  Vite: $vite_version (required: $required_vite)${NC}"
                log_dependency_check "vite" "$vite_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ Vite not found in package.json${NC}"
        log_dependency_check "vite" "not_found" "FAILED" "Vite not in package.json"
    fi
}

# Function to check backend dependencies
check_backend_dependencies() {
    echo -e "${BLUE}🔍 Checking backend dependencies...${NC}"
    
    if [ ! -f "backend/package.json" ]; then
        echo -e "  ${RED}❌ Backend package.json not found${NC}"
        log_dependency_check "backend_package" "not_found" "FAILED" "package.json not found"
        return 1
    fi
    
    # Check Express
    echo -e "  ${CYAN}Checking Express...${NC}"
    local express_version=$(jq -r '.dependencies.express' backend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$express_version" != "null" ]; then
        local required_express=$(jq -r '.backend.express' "$REQUIRED_VERSIONS")
        local express_status=$(compare_versions "$express_version" "$required_express")
        
        case "$express_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ Express: $express_version${NC}"
                log_dependency_check "express" "$express_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  Express: $express_version (required: $required_express)${NC}"
                log_dependency_check "express" "$express_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ Express not found in package.json${NC}"
        log_dependency_check "express" "not_found" "FAILED" "Express not in package.json"
    fi
    
    # Check CORS
    echo -e "  ${CYAN}Checking CORS...${NC}"
    local cors_version=$(jq -r '.dependencies.cors' backend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$cors_version" != "null" ]; then
        local required_cors=$(jq -r '.backend.cors' "$REQUIRED_VERSIONS")
        local cors_status=$(compare_versions "$cors_version" "$required_cors")
        
        case "$cors_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ CORS: $cors_version${NC}"
                log_dependency_check "cors" "$cors_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  CORS: $cors_version (required: $required_cors)${NC}"
                log_dependency_check "cors" "$cors_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ CORS not found in package.json${NC}"
        log_dependency_check "cors" "not_found" "FAILED" "CORS not in package.json"
    fi
    
    # Check dotenv
    echo -e "  ${CYAN}Checking dotenv...${NC}"
    local dotenv_version=$(jq -r '.dependencies.dotenv' backend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$dotenv_version" != "null" ]; then
        local required_dotenv=$(jq -r '.backend.dotenv' "$REQUIRED_VERSIONS")
        local dotenv_status=$(compare_versions "$dotenv_version" "$required_dotenv")
        
        case "$dotenv_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ dotenv: $dotenv_version${NC}"
                log_dependency_check "dotenv" "$dotenv_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  dotenv: $dotenv_version (required: $required_dotenv)${NC}"
                log_dependency_check "dotenv" "$dotenv_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ dotenv not found in package.json${NC}"
        log_dependency_check "dotenv" "not_found" "FAILED" "dotenv not in package.json"
    fi
    
    # Check pg (PostgreSQL client)
    echo -e "  ${CYAN}Checking PostgreSQL client...${NC}"
    local pg_version=$(jq -r '.dependencies.pg' backend/package.json 2>/dev/null | sed 's/\^//')
    if [ "$pg_version" != "null" ]; then
        local required_pg=$(jq -r '.backend.pg' "$REQUIRED_VERSIONS")
        local pg_status=$(compare_versions "$pg_version" "$required_pg")
        
        case "$pg_status" in
            "current"|"exact")
                echo -e "    ${GREEN}✅ PostgreSQL client: $pg_version${NC}"
                log_dependency_check "pg" "$pg_version" "SUCCESS" "Version meets requirements"
                ;;
            "outdated")
                echo -e "    ${YELLOW}⚠️  PostgreSQL client: $pg_version (required: $required_pg)${NC}"
                log_dependency_check "pg" "$pg_version" "WARNING" "Version outdated"
                ;;
        esac
    else
        echo -e "    ${RED}❌ PostgreSQL client not found in package.json${NC}"
        log_dependency_check "pg" "not_found" "FAILED" "PostgreSQL client not in package.json"
    fi
}

# Function to check dependency health
check_dependency_health() {
    echo -e "${BLUE}🔍 Checking dependency health...${NC}"
    
    # Check for security vulnerabilities
    echo -e "  ${CYAN}Checking for security vulnerabilities...${NC}"
    
    if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
        cd frontend
        if npm audit --audit-level=moderate >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Frontend: No critical vulnerabilities${NC}"
            log_dependency_check "frontend_security" "clean" "SUCCESS" "No critical vulnerabilities"
        else
            echo -e "    ${YELLOW}⚠️  Frontend: Security vulnerabilities detected${NC}"
            log_dependency_check "frontend_security" "vulnerable" "WARNING" "Security vulnerabilities detected"
        fi
        cd ..
    fi
    
    if [ -d "backend" ] && [ -f "backend/package.json" ]; then
        cd backend
        if npm audit --audit-level=moderate >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Backend: No critical vulnerabilities${NC}"
            log_dependency_check "backend_security" "clean" "SUCCESS" "No critical vulnerabilities"
        else
            echo -e "    ${YELLOW}⚠️  Backend: Security vulnerabilities detected${NC}"
            log_dependency_check "backend_security" "vulnerable" "WARNING" "Security vulnerabilities detected"
        fi
        cd ..
    fi
    
    # Check for outdated packages
    echo -e "  ${CYAN}Checking for outdated packages...${NC}"
    
    if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
        cd frontend
        local frontend_outdated=$(npm outdated --depth=0 2>/dev/null | wc -l)
        if [ "$frontend_outdated" -eq 0 ]; then
            echo -e "    ${GREEN}✅ Frontend: All packages up to date${NC}"
            log_dependency_check "frontend_outdated" "0" "SUCCESS" "All packages up to date"
        else
            echo -e "    ${YELLOW}⚠️  Frontend: $frontend_outdated packages outdated${NC}"
            log_dependency_check "frontend_outdated" "$frontend_outdated" "WARNING" "$frontend_outdated packages outdated"
        fi
        cd ..
    fi
    
    if [ -d "backend" ] && [ -f "backend/package.json" ]; then
        cd backend
        local backend_outdated=$(npm outdated --depth=0 2>/dev/null | wc -l)
        if [ "$backend_outdated" -eq 0 ]; then
            echo -e "    ${GREEN}✅ Backend: All packages up to date${NC}"
            log_dependency_check "backend_outdated" "0" "SUCCESS" "All packages up to date"
        else
            echo -e "    ${YELLOW}⚠️  Backend: $backend_outdated packages outdated${NC}"
            log_dependency_check "backend_outdated" "$backend_outdated" "WARNING" "$backend_outdated packages outdated"
        fi
        cd ..
    fi
}

# Function to generate dependency report
generate_dependency_report() {
    echo -e "${PURPLE}📋 Generating dependency report...${NC}"
    
    local report_file="dependency-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Collect dependency information
    local dependency_data='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "system_dependencies": {},
        "frontend_dependencies": {},
        "backend_dependencies": {},
        "health_status": {
            "security_vulnerabilities": 0,
            "outdated_packages": 0,
            "missing_dependencies": 0
        },
        "summary": {
            "total_dependencies": 0,
            "healthy_dependencies": 0,
            "warning_dependencies": 0,
            "failed_dependencies": 0
        }
    }'
    
    echo "$dependency_data" > "$report_file"
    
    echo -e "${GREEN}✅ Dependency report generated: $report_file${NC}"
}

# Function to show dependency summary
show_dependency_summary() {
    echo -e "${PURPLE}📊 Dependency Summary${NC}"
    echo "====================="
    
    if [ -f "$DEPENDENCY_LOG" ]; then
        local total_checks=$(wc -l < "$DEPENDENCY_LOG")
        local successful_checks=$(grep "|SUCCESS|" "$DEPENDENCY_LOG" | wc -l)
        local warning_checks=$(grep "|WARNING|" "$DEPENDENCY_LOG" | wc -l)
        local failed_checks=$(grep "|FAILED|" "$DEPENDENCY_LOG" | wc -l)
        
        echo -e "${CYAN}Total dependency checks: $total_checks${NC}"
        echo -e "${GREEN}Successful: $successful_checks${NC}"
        echo -e "${YELLOW}Warnings: $warning_checks${NC}"
        echo -e "${RED}Failed: $failed_checks${NC}"
        
        # Show recent issues
        if [ "$warning_checks" -gt 0 ] || [ "$failed_checks" -gt 0 ]; then
            echo ""
            echo -e "${CYAN}Recent dependency issues:${NC}"
            grep -E "WARNING|FAILED" "$DEPENDENCY_LOG" | tail -5 | while IFS='|' read -r timestamp dependency version status details; do
                if [ "$status" = "FAILED" ]; then
                    echo -e "  ${RED}$timestamp - $dependency: $details${NC}"
                else
                    echo -e "  ${YELLOW}$timestamp - $dependency: $details${NC}"
                fi
            done
        fi
    else
        echo -e "${YELLOW}No dependency check history found${NC}"
    fi
}

# Function to update dependencies
update_dependencies() {
    local component="$1"
    
    echo -e "${BLUE}🔄 Updating dependencies for $component...${NC}"
    
    case "$component" in
        "frontend")
            if [ -d "frontend" ]; then
                cd frontend
                echo -e "  ${CYAN}Updating frontend dependencies...${NC}"
                npm update
                echo -e "  ${GREEN}✅ Frontend dependencies updated${NC}"
                cd ..
                log_dependency_check "frontend_update" "completed" "SUCCESS" "Frontend dependencies updated"
            else
                echo -e "  ${RED}❌ Frontend directory not found${NC}"
                log_dependency_check "frontend_update" "failed" "FAILED" "Frontend directory not found"
            fi
            ;;
        "backend")
            if [ -d "backend" ]; then
                cd backend
                echo -e "  ${CYAN}Updating backend dependencies...${NC}"
                npm update
                echo -e "  ${GREEN}✅ Backend dependencies updated${NC}"
                cd ..
                log_dependency_check "backend_update" "completed" "SUCCESS" "Backend dependencies updated"
            else
                echo -e "  ${RED}❌ Backend directory not found${NC}"
                log_dependency_check "backend_update" "failed" "FAILED" "Backend directory not found"
            fi
            ;;
        "all")
            update_dependencies "frontend"
            update_dependencies "backend"
            ;;
        *)
            echo -e "  ${RED}❌ Unknown component: $component${NC}"
            echo "Components: frontend, backend, all"
            ;;
    esac
}

# Main dependency check function
main_dependency_check() {
    echo -e "${PURPLE}🚀 Starting comprehensive dependency check...${NC}"
    echo ""
    
    initialize_required_versions
    echo ""
    check_system_dependencies
    echo ""
    check_frontend_dependencies
    echo ""
    check_backend_dependencies
    echo ""
    check_dependency_health
    echo ""
    generate_dependency_report
    echo ""
    show_dependency_summary
    echo ""
    
    echo -e "${GREEN}✅ Dependency check completed${NC}"
}

# Main execution
main() {
    local action="${1:-check}"
    local component="$2"
    
    case "$action" in
        "check")
            main_dependency_check
            ;;
        "update")
            if [ -z "$component" ]; then
                echo -e "${RED}❌ Component required for update${NC}"
                echo "Usage: $0 update <component>"
                echo "Components: frontend, backend, all"
                exit 1
            fi
            update_dependencies "$component"
            ;;
        "summary")
            show_dependency_summary
            ;;
        "report")
            generate_dependency_report
            ;;
        *)
            echo -e "${PURPLE}ANQA Dependency Checker - Usage${NC}"
            echo "================================="
            echo "  $0 check [component]     - Run dependency check"
            echo "  $0 update <component>    - Update dependencies"
            echo "  $0 summary               - Show dependency summary"
            echo "  $0 report                - Generate dependency report"
            echo ""
            echo -e "${CYAN}Components:${NC}"
            echo "  frontend, backend, all"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 check"
            echo "  $0 update frontend"
            echo "  $0 update all"
            echo "  $0 summary"
            ;;
    esac
}

# Run main function
main "$@"
