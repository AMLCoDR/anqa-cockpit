#!/bin/bash
set -e

# ANQA System State Snapshot - Complete System State Capture
# Captures comprehensive system state for analysis and troubleshooting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SNAPSHOT_DIR="system-snapshots"
SNAPSHOT_FILE="system-state-$(date +%Y%m%d-%H%M%S).json"
LOG_FILE="state-snapshot.log"

echo -e "${PURPLE}📸 ANQA System State Snapshot - Complete State Capture${NC}"
echo "============================================================="

# Function to capture system information
capture_system_info() {
    echo -e "${BLUE}🔍 Capturing system information...${NC}"
    
    local system_info='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "hostname": "'$(hostname)'",
        "os": "'$(uname -s)'",
        "os_version": "'$(uname -r)'",
        "architecture": "'$(uname -m)'",
        "uptime": "'$(uptime)'",
        "load_average": "'$(uptime | awk -F'load average:' '{print $2}')'"
    }'
    
    echo "$system_info" > "$SNAPSHOT_DIR/system-info.json"
    echo -e "${GREEN}✅ System information captured${NC}"
}

# Function to capture process information
capture_process_info() {
    echo -e "${BLUE}🔍 Capturing process information...${NC}"
    
    local processes=()
    
    # Node.js processes
    local node_processes=$(ps aux | grep -E "node.*server|react-scripts" | grep -v grep)
    if [ -n "$node_processes" ]; then
        while IFS= read -r line; do
            local pid=$(echo "$line" | awk '{print $2}')
            local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
            local cpu=$(echo "$line" | awk '{print $3}')
            local mem=$(echo "$line" | awk '{print $4}')
            
            processes+=("{\"pid\": \"$pid\", \"command\": \"$cmd\", \"cpu\": \"$cpu\", \"memory\": \"$mem\", \"type\": \"node\"}")
        done <<< "$node_processes"
    fi
    
    # PostgreSQL processes
    local postgres_processes=$(ps aux | grep postgres | grep -v grep)
    if [ -n "$postgres_processes" ]; then
        while IFS= read -r line; do
            local pid=$(echo "$line" | awk '{print $2}')
            local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
            local cpu=$(echo "$line" | awk '{print $3}')
            local mem=$(echo "$line" | awk '{print $4}')
            
            processes+=("{\"pid\": \"$pid\", \"command\": \"$cmd\", \"cpu\": \"$cpu\", \"memory\": \"$mem\", \"type\": \"postgres\"}")
        done <<< "$postgres_processes"
    fi
    
    # Create JSON array
    local processes_json="["
    local first=true
    for process in "${processes[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            processes_json="$processes_json,"
        fi
        processes_json="$processes_json$process"
    done
    processes_json="$processes_json]"
    
    echo "$processes_json" > "$SNAPSHOT_DIR/processes.json"
    echo -e "${GREEN}✅ Process information captured (${#processes[@]} processes)${NC}"
}

# Function to capture port information
capture_port_info() {
    echo -e "${BLUE}🔍 Capturing port information...${NC}"
    
    local ports=()
    local required_ports=(4000 4001 5434)
    
    for port in "${required_ports[@]}"; do
        local port_info=$(lsof -i ":$port" 2>/dev/null | grep LISTEN || echo "")
        if [ -n "$port_info" ]; then
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    local command=$(echo "$line" | awk '{print $1}')
                    local pid=$(echo "$line" | awk '{print $2}')
                    local user=$(echo "$line" | awk '{print $3}')
                    
                    ports+=("{\"port\": \"$port\", \"command\": \"$command\", \"pid\": \"$pid\", \"user\": \"$user\", \"status\": \"active\"}")
                fi
            done <<< "$port_info"
        else
            ports+=("{\"port\": \"$port\", \"command\": \"\", \"pid\": \"\", \"user\": \"\", \"status\": \"inactive\"}")
        fi
    done
    
    # Create JSON array
    local ports_json="["
    local first=true
    for port in "${ports[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            ports_json="$ports_json,"
        fi
        ports_json="$ports_json$port"
    done
    ports_json="$ports_json]"
    
    echo "$ports_json" > "$SNAPSHOT_DIR/ports.json"
    echo -e "${GREEN}✅ Port information captured${NC}"
}

# Function to capture database state
capture_database_state() {
    echo -e "${BLUE}🔍 Capturing database state...${NC}"
    
    local db_state='{}'
    
    if command -v psql >/dev/null 2>&1; then
        # Check database connection
        if psql -h localhost -p 5434 -d anqa_website -c "SELECT 1;" >/dev/null 2>&1; then
            # Get table counts
            local pages_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM pages;" 2>/dev/null | tr -d ' ')
            local posts_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM posts;" 2>/dev/null | tr -d ' ')
            local services_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM services;" 2>/dev/null | tr -d ' ')
            local resources_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM resources;" 2>/dev/null | tr -d ' ')
            local media_count=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT COUNT(*) FROM media;" 2>/dev/null | tr -d ' ')
            
            # Get database size
            local db_size=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT pg_size_pretty(pg_database_size('anqa_website'));" 2>/dev/null | tr -d ' ')
            
            # Get active connections
            local connections=$(psql -h localhost -p 5434 -d anqa_website -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' ')
            
            db_state="{
                \"status\": \"connected\",
                \"tables\": {
                    \"pages\": $pages_count,
                    \"posts\": $posts_count,
                    \"services\": $services_count,
                    \"resources\": $resources_count,
                    \"media\": $media_count
                },
                \"size\": \"$db_size\",
                \"connections\": $connections
            }"
        else
            db_state='{"status": "disconnected", "error": "Database connection failed"}'
        fi
    else
        db_state='{"status": "unavailable", "error": "PostgreSQL client not found"}'
    fi
    
    echo "$db_state" > "$SNAPSHOT_DIR/database.json"
    echo -e "${GREEN}✅ Database state captured${NC}"
}

# Function to capture API state
capture_api_state() {
    echo -e "${BLUE}🔍 Capturing API state...${NC}"
    
    local api_state='{}'
    local endpoints=(
        "http://localhost:4001/api/health"
        "http://localhost:4001/api/services"
        "http://localhost:4001/api/pages"
        "http://localhost:4001/api/posts"
    )
    
    local api_endpoints='[]'
    local first=true
    
    for endpoint in "${endpoints[@]}"; do
        local response=$(curl -s -w "%{http_code}|%{time_total}" -o /dev/null "$endpoint" 2>/dev/null || echo "000|0")
        local status_code=$(echo "$response" | cut -d'|' -f1)
        local response_time=$(echo "$response" | cut -d'|' -f2)
        
        local endpoint_json="{\"url\": \"$endpoint\", \"status_code\": \"$status_code\", \"response_time\": \"$response_time\"}"
        
        if [ "$first" = true ]; then
            first=false
            api_endpoints="[$endpoint_json"
        else
            api_endpoints="$api_endpoints,$endpoint_json"
        fi
    done
    
    api_endpoints="$api_endpoints]"
    
    # Check frontend
    local frontend_status="disconnected"
    local frontend_content=""
    if curl -s http://localhost:4000 >/dev/null 2>&1; then
        frontend_status="connected"
        frontend_content=$(curl -s http://localhost:4000 | head -c 200)
    fi
    
    api_state="{
        \"backend\": {
            \"status\": \"$(curl -s http://localhost:4001/api/health >/dev/null 2>&1 && echo 'connected' || echo 'disconnected')\",
            \"endpoints\": $api_endpoints
        },
        \"frontend\": {
            \"status\": \"$frontend_status\",
            \"content_preview\": \"$frontend_content\"
        }
    }"
    
    echo "$api_state" > "$SNAPSHOT_DIR/api.json"
    echo -e "${GREEN}✅ API state captured${NC}"
}

# Function to capture configuration state
capture_configuration_state() {
    echo -e "${BLUE}🔍 Capturing configuration state...${NC}"
    
    local config_state='{}'
    
    # Check frontend configuration
    local frontend_config='{}'
    if [ -f "frontend/.env" ]; then
        local vite_api_url=$(grep "VITE_API_BASE_URL" frontend/.env | cut -d'=' -f2 || echo "not_found")
        frontend_config="{\"VITE_API_BASE_URL\": \"$vite_api_url\"}"
    else
        frontend_config='{"error": "frontend/.env not found"}'
    fi
    
    # Check backend configuration
    local backend_config='{}'
    if [ -f "backend/.env" ]; then
        local backend_port=$(grep "PORT" backend/.env | cut -d'=' -f2 || echo "not_found")
        local db_url=$(grep "DATABASE_URL" backend/.env | cut -d'=' -f2 || echo "not_found")
        backend_config="{\"PORT\": \"$backend_port\", \"DATABASE_URL\": \"$db_url\"}"
    else
        backend_config='{"error": "backend/.env not found"}'
    fi
    
    # Check package.json configurations
    local frontend_package_port=$(grep -A 5 '"start"' frontend/package.json | grep "PORT=" | cut -d'=' -f2 | tr -d '"' || echo "not_found")
    
    config_state="{
        \"frontend\": {
            \"env\": $frontend_config,
            \"package_port\": \"$frontend_package_port\"
        },
        \"backend\": {
            \"env\": $backend_config
        },
        \"permanent_config\": {
            \"frontend_port\": \"4000\",
            \"backend_port\": \"4001\",
            \"database_port\": \"5434\"
        }
    }"
    
    echo "$config_state" > "$SNAPSHOT_DIR/configuration.json"
    echo -e "${GREEN}✅ Configuration state captured${NC}"
}

# Function to capture file system state
capture_filesystem_state() {
    echo -e "${BLUE}🔍 Capturing file system state...${NC}"
    
    local filesystem_state='{}'
    
    # Check key directories and files
    local directories=("frontend" "backend" "database" "scripts")
    local files=("frontend/package.json" "backend/package.json" "database/02-data.sql" "PERMANENT_CONFIG.md" "SYSTEM_CHANGELOG.md")
    
    local dir_status='{}'
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            local file_count=$(find "$dir" -type f | wc -l)
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
            dir_status=$(echo "$dir_status" | jq --arg dir "$dir" --arg count "$file_count" --arg size "$size" '.[$dir] = {"exists": true, "file_count": $count, "size": $size}')
        else
            dir_status=$(echo "$dir_status" | jq --arg dir "$dir" '.[$dir] = {"exists": false}')
        fi
    done
    
    local file_status='{}'
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(ls -lh "$file" | awk '{print $5}')
            local modified=$(stat -f "%Sm" "$file" 2>/dev/null || echo "unknown")
            file_status=$(echo "$file_status" | jq --arg file "$file" --arg size "$size" --arg modified "$modified" '.[$file] = {"exists": true, "size": $size, "modified": $modified}')
        else
            file_status=$(echo "$file_status" | jq --arg file "$file" '.[$file] = {"exists": false}')
        fi
    done
    
    filesystem_state="{
        \"directories\": $dir_status,
        \"files\": $file_status,
        \"disk_usage\": \"$(df -h . | tail -1 | awk '{print $5}')\"
    }"
    
    echo "$filesystem_state" > "$SNAPSHOT_DIR/filesystem.json"
    echo -e "${GREEN}✅ File system state captured${NC}"
}

# Function to create comprehensive snapshot
create_comprehensive_snapshot() {
    echo -e "${PURPLE}📸 Creating comprehensive system snapshot...${NC}"
    
    # Create snapshot directory
    mkdir -p "$SNAPSHOT_DIR"
    
    # Capture all state information
    capture_system_info
    capture_process_info
    capture_port_info
    capture_database_state
    capture_api_state
    capture_configuration_state
    capture_filesystem_state
    
    # Combine all snapshots into one comprehensive file
    local comprehensive_snapshot='{
        "snapshot_timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "system_info": '$(cat "$SNAPSHOT_DIR/system-info.json")',
        "processes": '$(cat "$SNAPSHOT_DIR/processes.json")',
        "ports": '$(cat "$SNAPSHOT_DIR/ports.json")',
        "database": '$(cat "$SNAPSHOT_DIR/database.json")',
        "api": '$(cat "$SNAPSHOT_DIR/api.json")',
        "configuration": '$(cat "$SNAPSHOT_DIR/configuration.json")',
        "filesystem": '$(cat "$SNAPSHOT_DIR/filesystem.json")'
    }'
    
    echo "$comprehensive_snapshot" > "$SNAPSHOT_FILE"
    
    echo -e "${GREEN}✅ Comprehensive snapshot created: $SNAPSHOT_FILE${NC}"
}

# Function to analyze snapshot
analyze_snapshot() {
    echo -e "${PURPLE}🔍 Analyzing system snapshot...${NC}"
    
    if [ -f "$SNAPSHOT_FILE" ]; then
        echo -e "${CYAN}System Status Summary:${NC}"
        
        # Check database status
        local db_status=$(jq -r '.database.status' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")
        if [ "$db_status" = "connected" ]; then
            echo -e "  ${GREEN}✅ Database: Connected${NC}"
        else
            echo -e "  ${RED}❌ Database: $db_status${NC}"
        fi
        
        # Check API status
        local api_status=$(jq -r '.api.backend.status' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")
        if [ "$api_status" = "connected" ]; then
            echo -e "  ${GREEN}✅ Backend API: Connected${NC}"
        else
            echo -e "  ${RED}❌ Backend API: $api_status${NC}"
        fi
        
        local frontend_status=$(jq -r '.api.frontend.status' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")
        if [ "$frontend_status" = "connected" ]; then
            echo -e "  ${GREEN}✅ Frontend: Connected${NC}"
        else
            echo -e "  ${RED}❌ Frontend: $frontend_status${NC}"
        fi
        
        # Check port status
        local active_ports=$(jq -r '.ports[] | select(.status == "active") | .port' "$SNAPSHOT_FILE" 2>/dev/null | wc -l)
        echo -e "  ${CYAN}Active ports: $active_ports/3${NC}"
        
        # Check process count
        local node_processes=$(jq -r '.processes[] | select(.type == "node") | .pid' "$SNAPSHOT_FILE" 2>/dev/null | wc -l)
        local postgres_processes=$(jq -r '.processes[] | select(.type == "postgres") | .pid' "$SNAPSHOT_FILE" 2>/dev/null | wc -l)
        echo -e "  ${CYAN}Node.js processes: $node_processes${NC}"
        echo -e "  ${CYAN}PostgreSQL processes: $postgres_processes${NC}"
        
        # Check configuration compliance
        local frontend_port=$(jq -r '.configuration.frontend.package_port' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")
        local backend_port=$(jq -r '.configuration.backend.env.PORT' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")
        
        if [ "$frontend_port" = "4000" ]; then
            echo -e "  ${GREEN}✅ Frontend port: Correct (4000)${NC}"
        else
            echo -e "  ${RED}❌ Frontend port: $frontend_port (expected 4000)${NC}"
        fi
        
        if [ "$backend_port" = "4001" ]; then
            echo -e "  ${GREEN}✅ Backend port: Correct (4001)${NC}"
        else
            echo -e "  ${RED}❌ Backend port: $backend_port (expected 4001)${NC}"
        fi
    else
        echo -e "${RED}❌ Snapshot file not found${NC}"
    fi
}

# Function to generate state report
generate_state_report() {
    echo -e "${PURPLE}📋 Generating state report...${NC}"
    
    local report_file="state-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA System State Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================"
        echo ""
        echo "Snapshot File: $SNAPSHOT_FILE"
        echo ""
        
        if [ -f "$SNAPSHOT_FILE" ]; then
            echo "System Information:"
            jq -r '.system_info | "  Hostname: \(.hostname)"' "$SNAPSHOT_FILE"
            jq -r '.system_info | "  OS: \(.os) \(.os_version)"' "$SNAPSHOT_FILE"
            jq -r '.system_info | "  Uptime: \(.uptime)"' "$SNAPSHOT_FILE"
            echo ""
            
            echo "Service Status:"
            jq -r '.database | "  Database: \(.status)"' "$SNAPSHOT_FILE"
            jq -r '.api.backend | "  Backend API: \(.status)"' "$SNAPSHOT_FILE"
            jq -r '.api.frontend | "  Frontend: \(.status)"' "$SNAPSHOT_FILE"
            echo ""
            
            echo "Configuration:"
            jq -r '.configuration.frontend.package_port | "  Frontend Port: \(.)"' "$SNAPSHOT_FILE"
            jq -r '.configuration.backend.env.PORT | "  Backend Port: \(.)"' "$SNAPSHOT_FILE"
            echo ""
            
            echo "Issues Found:"
            # Check for configuration drift
            local frontend_port=$(jq -r '.configuration.frontend.package_port' "$SNAPSHOT_FILE")
            local backend_port=$(jq -r '.configuration.backend.env.PORT' "$SNAPSHOT_FILE")
            
            if [ "$frontend_port" != "4000" ]; then
                echo "- Frontend port configuration drift: $frontend_port (expected 4000)"
            fi
            
            if [ "$backend_port" != "4001" ]; then
                echo "- Backend port configuration drift: $backend_port (expected 4001)"
            fi
            
            local db_status=$(jq -r '.database.status' "$SNAPSHOT_FILE")
            if [ "$db_status" != "connected" ]; then
                echo "- Database connection issue: $db_status"
            fi
            
            local api_status=$(jq -r '.api.backend.status' "$SNAPSHOT_FILE")
            if [ "$api_status" != "connected" ]; then
                echo "- Backend API issue: $api_status"
            fi
        fi
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ State report generated: $report_file${NC}"
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 Starting ANQA System State Snapshot...${NC}"
    echo ""
    
    # Create comprehensive snapshot
    create_comprehensive_snapshot
    echo ""
    
    # Analyze snapshot
    analyze_snapshot
    echo ""
    
    # Generate report
    generate_state_report
    echo ""
    
    echo -e "${GREEN}✅ System state snapshot complete${NC}"
    echo -e "${CYAN}📊 Snapshot file: $SNAPSHOT_FILE${NC}"
    echo -e "${CYAN}📊 Snapshot directory: $SNAPSHOT_DIR${NC}"
}

# Run main function
main "$@"
