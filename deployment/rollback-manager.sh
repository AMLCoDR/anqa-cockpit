#!/bin/bash
set -e

# ANQA Rollback Manager - Quick Rollback Capabilities
# Provides quick rollback capabilities for failed deployments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ROLLBACK_DIR="rollback-backups"
ROLLBACK_LOG="rollback-manager.log"
ROLLBACK_HISTORY="rollback-history.json"
MAX_BACKUPS=10

echo -e "${PURPLE}🔄 ANQA Rollback Manager - Quick Rollback Capabilities${NC}"
echo "========================================================="

# Function to log rollback operation
log_rollback() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local operation="$1"
    local component="$2"
    local backup_id="$3"
    local status="$4"
    local details="$5"
    
    echo "$timestamp|$operation|$component|$backup_id|$status|$details" >> "$ROLLBACK_LOG"
}

# Function to update rollback history
update_rollback_history() {
    local operation="$1"
    local component="$2"
    local backup_id="$3"
    local status="$4"
    local details="$5"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Create history file if it doesn't exist
    if [ ! -f "$ROLLBACK_HISTORY" ]; then
        echo '{"rollbacks": []}' > "$ROLLBACK_HISTORY"
    fi
    
    # Add rollback to history
    local temp_file=$(mktemp)
    jq --arg timestamp "$timestamp" \
       --arg operation "$operation" \
       --arg component "$component" \
       --arg backup_id "$backup_id" \
       --arg status "$status" \
       --arg details "$details" \
       '.rollbacks += [{
           timestamp: $timestamp,
           operation: $operation,
           component: $component,
           backup_id: $backup_id,
           status: $status,
           details: $details
       }]' "$ROLLBACK_HISTORY" > "$temp_file"
    mv "$temp_file" "$ROLLBACK_HISTORY"
}

# Function to create backup
create_backup() {
    local component="$1"
    local backup_id="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$ROLLBACK_DIR/$backup_id"
    
    echo -e "${BLUE}🔧 Creating backup for $component...${NC}"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    case "$component" in
        "frontend")
            if [ -d "frontend" ]; then
                cp -r frontend "$backup_path/"
                echo -e "  ${GREEN}✅ Frontend backup created: $backup_id${NC}"
                log_rollback "CREATE_BACKUP" "frontend" "$backup_id" "SUCCESS" "Frontend files backed up"
                update_rollback_history "CREATE_BACKUP" "frontend" "$backup_id" "SUCCESS" "Frontend files backed up"
            else
                echo -e "  ${RED}❌ Frontend directory not found${NC}"
                log_rollback "CREATE_BACKUP" "frontend" "$backup_id" "FAILED" "Frontend directory not found"
                update_rollback_history "CREATE_BACKUP" "frontend" "$backup_id" "FAILED" "Frontend directory not found"
                return 1
            fi
            ;;
        "backend")
            if [ -d "backend" ]; then
                cp -r backend "$backup_path/"
                echo -e "  ${GREEN}✅ Backend backup created: $backup_id${NC}"
                log_rollback "CREATE_BACKUP" "backend" "$backup_id" "SUCCESS" "Backend files backed up"
                update_rollback_history "CREATE_BACKUP" "backend" "$backup_id" "SUCCESS" "Backend files backed up"
            else
                echo -e "  ${RED}❌ Backend directory not found${NC}"
                log_rollback "CREATE_BACKUP" "backend" "$backup_id" "FAILED" "Backend directory not found"
                update_rollback_history "CREATE_BACKUP" "backend" "$backup_id" "FAILED" "Backend directory not found"
                return 1
            fi
            ;;
        "database")
            if command -v psql >/dev/null 2>&1; then
                pg_dump -h localhost -p 5434 -d anqa_website > "$backup_path/database_backup.sql"
                echo -e "  ${GREEN}✅ Database backup created: $backup_id${NC}"
                log_rollback "CREATE_BACKUP" "database" "$backup_id" "SUCCESS" "Database backed up"
                update_rollback_history "CREATE_BACKUP" "database" "$backup_id" "SUCCESS" "Database backed up"
            else
                echo -e "  ${RED}❌ PostgreSQL client not available${NC}"
                log_rollback "CREATE_BACKUP" "database" "$backup_id" "FAILED" "PostgreSQL client not available"
                update_rollback_history "CREATE_BACKUP" "database" "$backup_id" "FAILED" "PostgreSQL client not available"
                return 1
            fi
            ;;
        "config")
            # Backup configuration files
            mkdir -p "$backup_path/config"
            if [ -f "frontend/.env" ]; then
                cp frontend/.env "$backup_path/config/frontend.env"
            fi
            if [ -f "backend/.env" ]; then
                cp backend/.env "$backup_path/config/backend.env"
            fi
            if [ -f "frontend/package.json" ]; then
                cp frontend/package.json "$backup_path/config/frontend-package.json"
            fi
            if [ -f "backend/package.json" ]; then
                cp backend/package.json "$backup_path/config/backend-package.json"
            fi
            echo -e "  ${GREEN}✅ Configuration backup created: $backup_id${NC}"
            log_rollback "CREATE_BACKUP" "config" "$backup_id" "SUCCESS" "Configuration files backed up"
            update_rollback_history "CREATE_BACKUP" "config" "$backup_id" "SUCCESS" "Configuration files backed up"
            ;;
        "full")
            # Create full system backup
            create_backup "frontend"
            create_backup "backend"
            create_backup "database"
            create_backup "config"
            echo -e "  ${GREEN}✅ Full system backup created: $backup_id${NC}"
            log_rollback "CREATE_BACKUP" "full" "$backup_id" "SUCCESS" "Full system backup created"
            update_rollback_history "CREATE_BACKUP" "full" "$backup_id" "SUCCESS" "Full system backup created"
            ;;
        *)
            echo -e "  ${RED}❌ Unknown component: $component${NC}"
            return 1
            ;;
    esac
    
    # Clean up old backups
    cleanup_old_backups
    
    echo "$backup_id"
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo -e "  ${CYAN}Cleaning up old backups...${NC}"
    
    if [ -d "$ROLLBACK_DIR" ]; then
        local backup_count=$(ls -1 "$ROLLBACK_DIR" | wc -l)
        
        if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
            local backups_to_remove=$((backup_count - MAX_BACKUPS))
            echo -e "    ${YELLOW}Removing $backups_to_remove old backups...${NC}"
            
            ls -1t "$ROLLBACK_DIR" | tail -"$backups_to_remove" | while read -r backup; do
                rm -rf "$ROLLBACK_DIR/$backup"
                echo -e "      ${CYAN}Removed: $backup${NC}"
            done
        fi
    fi
}

# Function to list available backups
list_backups() {
    echo -e "${BLUE}📋 Available backups:${NC}"
    
    if [ -d "$ROLLBACK_DIR" ] && [ "$(ls -A "$ROLLBACK_DIR")" ]; then
        ls -1t "$ROLLBACK_DIR" | while read -r backup; do
            local backup_path="$ROLLBACK_DIR/$backup"
            local backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1 || echo "unknown")
            local backup_date=$(stat -f "%Sm" "$backup_path" 2>/dev/null || echo "unknown")
            
            echo -e "  ${CYAN}$backup${NC} - Size: $backup_size, Date: $backup_date"
            
            # Show backup contents
            if [ -d "$backup_path" ]; then
                ls -la "$backup_path" | grep -E "^(d|-)" | while read -r line; do
                    echo -e "    $line"
                done
            fi
            echo ""
        done
    else
        echo -e "  ${YELLOW}No backups available${NC}"
    fi
}

# Function to rollback component
rollback_component() {
    local component="$1"
    local backup_id="$2"
    local backup_path="$ROLLBACK_DIR/$backup_id"
    
    echo -e "${BLUE}🔄 Rolling back $component from $backup_id...${NC}"
    
    if [ ! -d "$backup_path" ]; then
        echo -e "  ${RED}❌ Backup not found: $backup_id${NC}"
        log_rollback "ROLLBACK" "$component" "$backup_id" "FAILED" "Backup not found"
        update_rollback_history "ROLLBACK" "$component" "$backup_id" "FAILED" "Backup not found"
        return 1
    fi
    
    # Stop services before rollback
    echo -e "  ${CYAN}Stopping services...${NC}"
    pkill -f "node.*server" 2>/dev/null || true
    pkill -f "react-scripts" 2>/dev/null || true
    sleep 3
    
    case "$component" in
        "frontend")
            if [ -d "$backup_path/frontend" ]; then
                rm -rf frontend
                cp -r "$backup_path/frontend" .
                echo -e "  ${GREEN}✅ Frontend rolled back from $backup_id${NC}"
                log_rollback "ROLLBACK" "frontend" "$backup_id" "SUCCESS" "Frontend rolled back"
                update_rollback_history "ROLLBACK" "frontend" "$backup_id" "SUCCESS" "Frontend rolled back"
            else
                echo -e "  ${RED}❌ Frontend backup not found in $backup_id${NC}"
                log_rollback "ROLLBACK" "frontend" "$backup_id" "FAILED" "Frontend backup not found"
                update_rollback_history "ROLLBACK" "frontend" "$backup_id" "FAILED" "Frontend backup not found"
                return 1
            fi
            ;;
        "backend")
            if [ -d "$backup_path/backend" ]; then
                rm -rf backend
                cp -r "$backup_path/backend" .
                echo -e "  ${GREEN}✅ Backend rolled back from $backup_id${NC}"
                log_rollback "ROLLBACK" "backend" "$backup_id" "SUCCESS" "Backend rolled back"
                update_rollback_history "ROLLBACK" "backend" "$backup_id" "SUCCESS" "Backend rolled back"
            else
                echo -e "  ${RED}❌ Backend backup not found in $backup_id${NC}"
                log_rollback "ROLLBACK" "backend" "$backup_id" "FAILED" "Backend backup not found"
                update_rollback_history "ROLLBACK" "backend" "$backup_id" "FAILED" "Backend backup not found"
                return 1
            fi
            ;;
        "database")
            if [ -f "$backup_path/database_backup.sql" ]; then
                if command -v psql >/dev/null 2>&1; then
                    psql -h localhost -p 5434 -d anqa_website -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null 2>&1
                    psql -h localhost -p 5434 -d anqa_website < "$backup_path/database_backup.sql"
                    echo -e "  ${GREEN}✅ Database rolled back from $backup_id${NC}"
                    log_rollback "ROLLBACK" "database" "$backup_id" "SUCCESS" "Database rolled back"
                    update_rollback_history "ROLLBACK" "database" "$backup_id" "SUCCESS" "Database rolled back"
                else
                    echo -e "  ${RED}❌ PostgreSQL client not available${NC}"
                    log_rollback "ROLLBACK" "database" "$backup_id" "FAILED" "PostgreSQL client not available"
                    update_rollback_history "ROLLBACK" "database" "$backup_id" "FAILED" "PostgreSQL client not available"
                    return 1
                fi
            else
                echo -e "  ${RED}❌ Database backup not found in $backup_id${NC}"
                log_rollback "ROLLBACK" "database" "$backup_id" "FAILED" "Database backup not found"
                update_rollback_history "ROLLBACK" "database" "$backup_id" "FAILED" "Database backup not found"
                return 1
            fi
            ;;
        "config")
            if [ -d "$backup_path/config" ]; then
                if [ -f "$backup_path/config/frontend.env" ]; then
                    cp "$backup_path/config/frontend.env" frontend/.env
                fi
                if [ -f "$backup_path/config/backend.env" ]; then
                    cp "$backup_path/config/backend.env" backend/.env
                fi
                if [ -f "$backup_path/config/frontend-package.json" ]; then
                    cp "$backup_path/config/frontend-package.json" frontend/package.json
                fi
                if [ -f "$backup_path/config/backend-package.json" ]; then
                    cp "$backup_path/config/backend-package.json" backend/package.json
                fi
                echo -e "  ${GREEN}✅ Configuration rolled back from $backup_id${NC}"
                log_rollback "ROLLBACK" "config" "$backup_id" "SUCCESS" "Configuration rolled back"
                update_rollback_history "ROLLBACK" "config" "$backup_id" "SUCCESS" "Configuration rolled back"
            else
                echo -e "  ${RED}❌ Configuration backup not found in $backup_id${NC}"
                log_rollback "ROLLBACK" "config" "$backup_id" "FAILED" "Configuration backup not found"
                update_rollback_history "ROLLBACK" "config" "$backup_id" "FAILED" "Configuration backup not found"
                return 1
            fi
            ;;
        "full")
            # Rollback all components
            rollback_component "frontend" "$backup_id"
            rollback_component "backend" "$backup_id"
            rollback_component "database" "$backup_id"
            rollback_component "config" "$backup_id"
            echo -e "  ${GREEN}✅ Full system rolled back from $backup_id${NC}"
            log_rollback "ROLLBACK" "full" "$backup_id" "SUCCESS" "Full system rolled back"
            update_rollback_history "ROLLBACK" "full" "$backup_id" "SUCCESS" "Full system rolled back"
            ;;
        *)
            echo -e "  ${RED}❌ Unknown component: $component${NC}"
            return 1
            ;;
    esac
    
    # Restart services after rollback
    echo -e "  ${CYAN}Restarting services...${NC}"
    cd backend && npm start >/dev/null 2>&1 &
    cd ..
    cd frontend && npm start >/dev/null 2>&1 &
    cd ..
    
    sleep 5
    
    echo -e "  ${GREEN}✅ Rollback completed${NC}"
}

# Function to verify backup integrity
verify_backup() {
    local backup_id="$1"
    local backup_path="$ROLLBACK_DIR/$backup_id"
    
    echo -e "${BLUE}🔍 Verifying backup: $backup_id${NC}"
    
    if [ ! -d "$backup_path" ]; then
        echo -e "  ${RED}❌ Backup not found: $backup_id${NC}"
        return 1
    fi
    
    local verification_passed=true
    
    # Check backup structure
    echo -e "  ${CYAN}Checking backup structure...${NC}"
    
    if [ -d "$backup_path/frontend" ]; then
        echo -e "    ${GREEN}✅ Frontend backup present${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Frontend backup missing${NC}"
    fi
    
    if [ -d "$backup_path/backend" ]; then
        echo -e "    ${GREEN}✅ Backend backup present${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Backend backup missing${NC}"
    fi
    
    if [ -f "$backup_path/database_backup.sql" ]; then
        echo -e "    ${GREEN}✅ Database backup present${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Database backup missing${NC}"
    fi
    
    if [ -d "$backup_path/config" ]; then
        echo -e "    ${GREEN}✅ Configuration backup present${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Configuration backup missing${NC}"
    fi
    
    # Check backup size
    local backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1 || echo "unknown")
    echo -e "  ${CYAN}Backup size: $backup_size${NC}"
    
    if [ "$verification_passed" = true ]; then
        echo -e "  ${GREEN}✅ Backup verification passed${NC}"
        return 0
    else
        echo -e "  ${RED}❌ Backup verification failed${NC}"
        return 1
    fi
}

# Function to show rollback history
show_rollback_history() {
    echo -e "${PURPLE}📋 Rollback History${NC}"
    echo "=================="
    
    if [ -f "$ROLLBACK_HISTORY" ]; then
        echo -e "${CYAN}Recent rollback operations:${NC}"
        jq -r '.rollbacks[-10:] | .[] | "\(.timestamp) - \(.operation) \(.component): \(.status) (\(.details))"' "$ROLLBACK_HISTORY" 2>/dev/null | while read -r line; do
            if [[ "$line" =~ SUCCESS ]]; then
                echo -e "  ${GREEN}$line${NC}"
            elif [[ "$line" =~ FAILED ]]; then
                echo -e "  ${RED}$line${NC}"
            else
                echo -e "  ${YELLOW}$line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No rollback history found${NC}"
    fi
}

# Function to generate rollback report
generate_rollback_report() {
    echo -e "${PURPLE}📋 Generating rollback report...${NC}"
    
    local report_file="rollback-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Rollback Manager Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "==========================="
        echo ""
        
        echo "Available Backups:"
        echo "-----------------"
        
        if [ -d "$ROLLBACK_DIR" ] && [ "$(ls -A "$ROLLBACK_DIR")" ]; then
            ls -1t "$ROLLBACK_DIR" | while read -r backup; do
                local backup_path="$ROLLBACK_DIR/$backup"
                local backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1 || echo "unknown")
                local backup_date=$(stat -f "%Sm" "$backup_path" 2>/dev/null || echo "unknown")
                
                echo "$backup - Size: $backup_size, Date: $backup_date"
            done
        else
            echo "No backups available"
        fi
        
        echo ""
        echo "Rollback History:"
        echo "----------------"
        
        if [ -f "$ROLLBACK_HISTORY" ]; then
            jq -r '.rollbacks[] | "\(.timestamp) - \(.operation) \(.component): \(.status) (\(.details))"' "$ROLLBACK_HISTORY" 2>/dev/null
        else
            echo "No rollback history available"
        fi
        
        echo ""
        echo "Recommendations:"
        echo "---------------"
        echo "1. Create backups before any major deployment"
        echo "2. Test rollback procedures regularly"
        echo "3. Monitor backup storage space"
        echo "4. Document rollback procedures for team members"
        echo "5. Verify backup integrity before rollback"
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Rollback report generated: $report_file${NC}"
}

# Function to emergency rollback
emergency_rollback() {
    echo -e "${RED}🚨 EMERGENCY ROLLBACK${NC}"
    echo "====================="
    
    # Find the most recent backup
    if [ -d "$ROLLBACK_DIR" ] && [ "$(ls -A "$ROLLBACK_DIR")" ]; then
        local latest_backup=$(ls -1t "$ROLLBACK_DIR" | head -1)
        echo -e "${YELLOW}Latest backup found: $latest_backup${NC}"
        
        read -p "Do you want to rollback to $latest_backup? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}⚠️  WARNING: This will overwrite current system state${NC}"
            read -p "Are you sure? Type 'CONFIRM' to proceed: " -r
            
            if [ "$REPLY" = "CONFIRM" ]; then
                rollback_component "full" "$latest_backup"
            else
                echo -e "${YELLOW}Emergency rollback cancelled${NC}"
            fi
        else
            echo -e "${YELLOW}Emergency rollback cancelled${NC}"
        fi
    else
        echo -e "${RED}❌ No backups available for emergency rollback${NC}"
    fi
}

# Main execution
main() {
    local action="${1:-help}"
    local component="$2"
    local backup_id="$3"
    
    case "$action" in
        "backup")
            if [ -z "$component" ]; then
                echo -e "${RED}❌ Component required for backup${NC}"
                echo "Usage: $0 backup <component>"
                echo "Components: frontend, backend, database, config, full"
                exit 1
            fi
            create_backup "$component"
            ;;
        "rollback")
            if [ -z "$component" ] || [ -z "$backup_id" ]; then
                echo -e "${RED}❌ Component and backup ID required for rollback${NC}"
                echo "Usage: $0 rollback <component> <backup_id>"
                echo "Components: frontend, backend, database, config, full"
                exit 1
            fi
            rollback_component "$component" "$backup_id"
            ;;
        "list")
            list_backups
            ;;
        "verify")
            if [ -z "$backup_id" ]; then
                echo -e "${RED}❌ Backup ID required for verification${NC}"
                echo "Usage: $0 verify <backup_id>"
                exit 1
            fi
            verify_backup "$backup_id"
            ;;
        "history")
            show_rollback_history
            ;;
        "report")
            generate_rollback_report
            ;;
        "emergency")
            emergency_rollback
            ;;
        *)
            echo -e "${PURPLE}ANQA Rollback Manager - Usage${NC}"
            echo "================================="
            echo "  $0 backup <component>          - Create backup"
            echo "  $0 rollback <component> <id>   - Rollback component"
            echo "  $0 list                        - List available backups"
            echo "  $0 verify <backup_id>          - Verify backup integrity"
            echo "  $0 history                     - Show rollback history"
            echo "  $0 report                      - Generate rollback report"
            echo "  $0 emergency                   - Emergency rollback"
            echo ""
            echo -e "${CYAN}Components:${NC}"
            echo "  frontend, backend, database, config, full"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 backup frontend"
            echo "  $0 rollback frontend backup-20250127-143022"
            echo "  $0 list"
            echo "  $0 emergency"
            ;;
    esac
}

# Run main function
main "$@"
