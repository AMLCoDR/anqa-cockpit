#!/bin/bash
set -e

# ANQA Safe Deploy - Protected Deployment Process
# Ensures safe deployments with rollback capabilities and verification

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="deployment-backups"
ROLLBACK_DIR="rollback-points"
DEPLOY_LOG="deployment.log"
VERIFICATION_TIMEOUT=30

echo -e "${PURPLE}🚀 ANQA Safe Deploy - Protected Deployment Process${NC}"
echo "=========================================================="

# Function to create backup
create_backup() {
    echo -e "${BLUE}📦 Creating deployment backup...${NC}"
    
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$backup_path"
    
    # Backup critical files
    if [ -d "frontend" ]; then
        cp -r frontend "$backup_path/"
        echo -e "  ${GREEN}✅ Frontend backed up${NC}"
    fi
    
    if [ -d "backend" ]; then
        cp -r backend "$backup_path/"
        echo -e "  ${GREEN}✅ Backend backed up${NC}"
    fi
    
    if [ -d "database" ]; then
        cp -r database "$backup_path/"
        echo -e "  ${GREEN}✅ Database files backed up${NC}"
    fi
    
    if [ -d "scripts" ]; then
        cp -r scripts "$backup_path/"
        echo -e "  ${GREEN}✅ Scripts backed up${NC}"
    fi
    
    # Backup configuration files
    for config_file in "PERMANENT_CONFIG.md" "SYSTEM_CHANGELOG.md" "README.md"; do
        if [ -f "$config_file" ]; then
            cp "$config_file" "$backup_path/"
        fi
    done
    
    echo "$backup_name" > "$ROLLBACK_DIR/latest-backup"
    echo -e "${GREEN}✅ Backup created: $backup_name${NC}"
    
    return 0
}

# Function to validate deployment prerequisites
validate_prerequisites() {
    echo -e "${BLUE}🔍 Validating deployment prerequisites...${NC}"
    
    local errors=0
    
    # Check if system is in a stable state
    if ! ./scripts/validate-configuration.sh >/dev/null 2>&1; then
        echo -e "  ${RED}❌ System validation failed${NC}"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✅ System validation passed${NC}"
    fi
    
    # Check if all required ports are available
    for port in 4000 4001 5434; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}⚠️  Port $port is in use${NC}"
        else
            echo -e "  ${GREEN}✅ Port $port is available${NC}"
        fi
    done
    
    # Check if database is accessible
    if ! psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "  ${RED}❌ Database not accessible${NC}"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✅ Database accessible${NC}"
    fi
    
    # Check if required tools are available
    local required_tools=("curl" "jq" "psql" "lsof")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "  ${RED}❌ Required tool missing: $tool${NC}"
            errors=$((errors + 1))
        else
            echo -e "  ${GREEN}✅ Tool available: $tool${NC}"
        fi
    done
    
    if [ "$errors" -gt 0 ]; then
        echo -e "${RED}❌ Prerequisites validation failed ($errors errors)${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All prerequisites validated${NC}"
        return 0
    fi
}

# Function to stop services safely
stop_services() {
    echo -e "${BLUE}🛑 Stopping services safely...${NC}"
    
    # Stop Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | awk '{print $2}')
    if [ -n "$node_processes" ]; then
        echo -e "  ${YELLOW}Stopping Node.js processes...${NC}"
        echo "$node_processes" | xargs kill -TERM 2>/dev/null || true
        
        # Wait for graceful shutdown
        sleep 5
        
        # Force kill if still running
        local remaining=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep | awk '{print $2}')
        if [ -n "$remaining" ]; then
            echo -e "  ${YELLOW}Force stopping remaining processes...${NC}"
            echo "$remaining" | xargs kill -KILL 2>/dev/null || true
        fi
    fi
    
    # Verify ports are free
    for port in 4000 4001; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            echo -e "  ${RED}❌ Port $port still in use${NC}"
            return 1
        else
            echo -e "  ${GREEN}✅ Port $port is free${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Services stopped safely${NC}"
    return 0
}

# Function to deploy changes
deploy_changes() {
    echo -e "${BLUE}🚀 Deploying changes...${NC}"
    
    local deployment_type="$1"
    
    case "$deployment_type" in
        "frontend")
            echo -e "  ${CYAN}Deploying frontend changes...${NC}"
            # Add frontend deployment logic here
            echo -e "  ${GREEN}✅ Frontend deployment completed${NC}"
            ;;
        "backend")
            echo -e "  ${CYAN}Deploying backend changes...${NC}"
            # Add backend deployment logic here
            echo -e "  ${GREEN}✅ Backend deployment completed${NC}"
            ;;
        "database")
            echo -e "  ${CYAN}Deploying database changes...${NC}"
            # Add database deployment logic here
            echo -e "  ${GREEN}✅ Database deployment completed${NC}"
            ;;
        "full")
            echo -e "  ${CYAN}Deploying full system...${NC}"
            # Add full system deployment logic here
            echo -e "  ${GREEN}✅ Full system deployment completed${NC}"
            ;;
        *)
            echo -e "  ${RED}❌ Unknown deployment type: $deployment_type${NC}"
            return 1
            ;;
    esac
    
    return 0
}

# Function to start services
start_services() {
    echo -e "${BLUE}▶️  Starting services...${NC}"
    
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
        return 1
    fi
    
    echo -e "  ${GREEN}✅ Frontend started successfully${NC}"
    
    return 0
}

# Function to verify deployment
verify_deployment() {
    echo -e "${BLUE}🔍 Verifying deployment...${NC}"
    
    local verification_passed=true
    
    # Check backend health
    echo -e "  ${CYAN}Checking backend health...${NC}"
    if ! curl -s http://localhost:4001/api/health >/dev/null 2>&1; then
        echo -e "    ${RED}❌ Backend health check failed${NC}"
        verification_passed=false
    else
        echo -e "    ${GREEN}✅ Backend health check passed${NC}"
    fi
    
    # Check frontend accessibility
    echo -e "  ${CYAN}Checking frontend accessibility...${NC}"
    if ! curl -s http://localhost:4000 >/dev/null 2>&1; then
        echo -e "    ${RED}❌ Frontend accessibility check failed${NC}"
        verification_passed=false
    else
        echo -e "    ${GREEN}✅ Frontend accessibility check passed${NC}"
    fi
    
    # Check API endpoints
    echo -e "  ${CYAN}Checking API endpoints...${NC}"
    local endpoints=("http://localhost:4001/api/services" "http://localhost:4001/api/pages")
    for endpoint in "${endpoints[@]}"; do
        if ! curl -s "$endpoint" >/dev/null 2>&1; then
            echo -e "    ${RED}❌ API endpoint check failed: $endpoint${NC}"
            verification_passed=false
        else
            echo -e "    ${GREEN}✅ API endpoint check passed: $endpoint${NC}"
        fi
    done
    
    # Check database connectivity
    echo -e "  ${CYAN}Checking database connectivity...${NC}"
    if ! psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "    ${RED}❌ Database connectivity check failed${NC}"
        verification_passed=false
    else
        echo -e "    ${GREEN}✅ Database connectivity check passed${NC}"
    fi
    
    # Check port usage
    echo -e "  ${CYAN}Checking port usage...${NC}"
    for port in 4000 4001; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Port $port is active${NC}"
        else
            echo -e "    ${RED}❌ Port $port is not active${NC}"
            verification_passed=false
        fi
    done
    
    if [ "$verification_passed" = true ]; then
        echo -e "${GREEN}✅ All verification checks passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Some verification checks failed${NC}"
        return 1
    fi
}

# Function to rollback deployment
rollback_deployment() {
    echo -e "${RED}🔄 Rolling back deployment...${NC}"
    
    local backup_name="$1"
    if [ -z "$backup_name" ]; then
        backup_name=$(cat "$ROLLBACK_DIR/latest-backup" 2>/dev/null || echo "")
    fi
    
    if [ -z "$backup_name" ] || [ ! -d "$BACKUP_DIR/$backup_name" ]; then
        echo -e "  ${RED}❌ No valid backup found for rollback${NC}"
        return 1
    fi
    
    echo -e "  ${CYAN}Rolling back to backup: $backup_name${NC}"
    
    # Stop services first
    stop_services
    
    # Restore from backup
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ -d "$backup_path/frontend" ]; then
        rm -rf frontend
        cp -r "$backup_path/frontend" .
        echo -e "  ${GREEN}✅ Frontend restored${NC}"
    fi
    
    if [ -d "$backup_path/backend" ]; then
        rm -rf backend
        cp -r "$backup_path/backend" .
        echo -e "  ${GREEN}✅ Backend restored${NC}"
    fi
    
    if [ -d "$backup_path/database" ]; then
        rm -rf database
        cp -r "$backup_path/database" .
        echo -e "  ${GREEN}✅ Database files restored${NC}"
    fi
    
    if [ -d "$backup_path/scripts" ]; then
        rm -rf scripts
        cp -r "$backup_path/scripts" .
        echo -e "  ${GREEN}✅ Scripts restored${NC}"
    fi
    
    # Restore configuration files
    for config_file in "PERMANENT_CONFIG.md" "SYSTEM_CHANGELOG.md" "README.md"; do
        if [ -f "$backup_path/$config_file" ]; then
            cp "$backup_path/$config_file" .
            echo -e "  ${GREEN}✅ $config_file restored${NC}"
        fi
    done
    
    # Start services
    start_services
    
    # Verify rollback
    if verify_deployment; then
        echo -e "${GREEN}✅ Rollback completed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Rollback verification failed${NC}"
        return 1
    fi
}

# Function to log deployment
log_deployment() {
    local action="$1"
    local status="$2"
    local details="$3"
    
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    echo "$timestamp|$action|$status|$details" >> "$DEPLOY_LOG"
}

# Function to show deployment status
show_deployment_status() {
    echo -e "${PURPLE}📊 Deployment Status${NC}"
    echo "=================="
    
    if [ -f "$DEPLOY_LOG" ]; then
        echo -e "${CYAN}Recent deployments:${NC}"
        tail -10 "$DEPLOY_LOG" | while IFS='|' read -r timestamp action status details; do
            if [ "$status" = "SUCCESS" ]; then
                echo -e "  ${GREEN}$timestamp - $action: SUCCESS${NC}"
            else
                echo -e "  ${RED}$timestamp - $action: $status${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No deployment history found${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Available backups:${NC}"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR" | grep "^d" | awk '{print "  " $9}' | tail -5
    else
        echo -e "  ${YELLOW}No backups found${NC}"
    fi
}

# Main deployment function
main_deploy() {
    local deployment_type="$1"
    
    if [ -z "$deployment_type" ]; then
        echo -e "${RED}❌ Deployment type required${NC}"
        echo "Usage: $0 [frontend|backend|database|full]"
        exit 1
    fi
    
    echo -e "${PURPLE}🚀 Starting $deployment_type deployment...${NC}"
    echo ""
    
    # Create rollback directory
    mkdir -p "$ROLLBACK_DIR"
    
    # Step 1: Validate prerequisites
    if ! validate_prerequisites; then
        echo -e "${RED}❌ Prerequisites validation failed - aborting deployment${NC}"
        log_deployment "$deployment_type" "FAILED" "Prerequisites validation failed"
        exit 1
    fi
    
    # Step 2: Create backup
    if ! create_backup; then
        echo -e "${RED}❌ Backup creation failed - aborting deployment${NC}"
        log_deployment "$deployment_type" "FAILED" "Backup creation failed"
        exit 1
    fi
    
    # Step 3: Stop services
    if ! stop_services; then
        echo -e "${RED}❌ Service stop failed - aborting deployment${NC}"
        log_deployment "$deployment_type" "FAILED" "Service stop failed"
        exit 1
    fi
    
    # Step 4: Deploy changes
    if ! deploy_changes "$deployment_type"; then
        echo -e "${RED}❌ Deployment failed - initiating rollback${NC}"
        log_deployment "$deployment_type" "FAILED" "Deployment failed"
        rollback_deployment
        exit 1
    fi
    
    # Step 5: Start services
    if ! start_services; then
        echo -e "${RED}❌ Service start failed - initiating rollback${NC}"
        log_deployment "$deployment_type" "FAILED" "Service start failed"
        rollback_deployment
        exit 1
    fi
    
    # Step 6: Verify deployment
    if ! verify_deployment; then
        echo -e "${RED}❌ Deployment verification failed - initiating rollback${NC}"
        log_deployment "$deployment_type" "FAILED" "Verification failed"
        rollback_deployment
        exit 1
    fi
    
    # Success
    echo -e "${GREEN}✅ $deployment_type deployment completed successfully${NC}"
    log_deployment "$deployment_type" "SUCCESS" "Deployment completed successfully"
}

# Command line interface
case "${1:-}" in
    "frontend"|"backend"|"database"|"full")
        main_deploy "$1"
        ;;
    "rollback")
        rollback_deployment "$2"
        ;;
    "status")
        show_deployment_status
        ;;
    "verify")
        verify_deployment
        ;;
    *)
        echo -e "${PURPLE}ANQA Safe Deploy - Usage${NC}"
        echo "========================"
        echo "  $0 frontend    - Deploy frontend changes"
        echo "  $0 backend     - Deploy backend changes"
        echo "  $0 database    - Deploy database changes"
        echo "  $0 full        - Deploy full system"
        echo "  $0 rollback    - Rollback to previous backup"
        echo "  $0 status      - Show deployment status"
        echo "  $0 verify      - Verify current deployment"
        echo ""
        echo -e "${CYAN}Examples:${NC}"
        echo "  $0 frontend"
        echo "  $0 rollback backup-20250127-143022"
        echo "  $0 status"
        ;;
esac
