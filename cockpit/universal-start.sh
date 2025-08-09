#!/bin/bash
set -e

# Universal Development Cockpit Startup Script
# Works with ANY project and automatically opens Cursor

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 Universal Development Cockpit - Flight Deck${NC}"
echo "=================================================="

# Function to detect project type
detect_project_type() {
    if [ -f "package.json" ]; then
        if grep -q '"react"' package.json || grep -q '"react-dom"' package.json; then
            echo "react"
        elif grep -q '"vue"' package.json; then
            echo "vue"
        elif grep -q '"@angular"' package.json; then
            echo "angular"
        else
            echo "nodejs"
        fi
    elif [ -f "requirements.txt" ]; then
        echo "python"
    elif [ -f "composer.json" ]; then
        echo "php"
    elif [ -f "pom.xml" ]; then
        echo "java"
    elif [ -f "go.mod" ]; then
        echo "go"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    elif [ -f "*.csproj" ]; then
        echo "csharp"
    else
        echo "unknown"
    fi
}

# Function to get project name
get_project_name() {
    basename "$(pwd)"
}

# Function to check if Cursor is installed
check_cursor() {
    if command -v cursor &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to open Cursor
open_cursor() {
    local project_path="$(pwd)"
    local project_name="$(get_project_name)"
    
    if check_cursor; then
        echo -e "${BLUE}🎯 Opening Cursor with project: ${YELLOW}$project_name${NC}"
        cursor "$project_path" &
        echo -e "${GREEN}✅ Cursor opened successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Cursor not found in PATH${NC}"
        echo -e "${CYAN}📝 Please install Cursor or open it manually${NC}"
        echo -e "${CYAN}   Project path: ${YELLOW}$project_path${NC}"
    fi
}

# Function to setup project-specific cockpit
setup_project_cockpit() {
    local project_type="$1"
    local project_name="$2"
    
    echo -e "${BLUE}🔧 Setting up cockpit for ${YELLOW}$project_type${NC} project: ${YELLOW}$project_name${NC}"
    
    # Create project-specific cockpit directory
    local cockpit_dir=".cockpit"
    mkdir -p "$cockpit_dir"
    
    # Copy universal cockpit files from global installation
    cp -r "$HOME/.universal-cockpit"/* "$cockpit_dir/"
    
    # Create project-specific configuration
    cat > "$cockpit_dir/project-config.json" << EOF
{
  "project": {
    "name": "$project_name",
    "type": "$project_type",
    "path": "$(pwd)",
    "detected": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  },
  "cockpit": {
    "title": "$project_name - Development Cockpit",
    "port": 5002,
    "autoOpenCursor": true,
    "features": ["monitoring", "ai-assistant", "deployment", "project-specific"]
  }
}
EOF
    
    echo -e "${GREEN}✅ Project cockpit configured${NC}"
}

# Function to start project-specific services
start_project_services() {
    local project_type="$1"
    
    echo -e "${BLUE}🚀 Starting project services...${NC}"
    
    case "$project_type" in
        "react"|"vue"|"angular")
            if [ -f "package.json" ]; then
                echo -e "${CYAN}📦 Installing dependencies...${NC}"
                npm install
                echo -e "${CYAN}🚀 Starting development server...${NC}"
                npm start &
            fi
            ;;
        "nodejs")
            if [ -f "package.json" ]; then
                echo -e "${CYAN}📦 Installing dependencies...${NC}"
                npm install
                if grep -q '"dev"' package.json; then
                    echo -e "${CYAN}🚀 Starting development server...${NC}"
                    npm run dev &
                elif grep -q '"start"' package.json; then
                    echo -e "${CYAN}🚀 Starting application...${NC}"
                    npm start &
                fi
            fi
            ;;
        "python")
            if [ -f "requirements.txt" ]; then
                echo -e "${CYAN}📦 Installing dependencies...${NC}"
                pip install -r requirements.txt
            fi
            if [ -f "app.py" ]; then
                echo -e "${CYAN}🚀 Starting Python application...${NC}"
                python app.py &
            elif [ -f "manage.py" ]; then
                echo -e "${CYAN}🚀 Starting Django application...${NC}"
                python manage.py runserver &
            fi
            ;;
        "php")
            if [ -f "composer.json" ]; then
                echo -e "${CYAN}📦 Installing dependencies...${NC}"
                composer install
            fi
            echo -e "${CYAN}🚀 Starting PHP server...${NC}"
            php -S localhost:8000 &
            ;;
        "java")
            if [ -f "pom.xml" ]; then
                echo -e "${CYAN}📦 Building project...${NC}"
                mvn clean install
                echo -e "${CYAN}🚀 Starting Spring Boot application...${NC}"
                mvn spring-boot:run &
            fi
            ;;
        "go")
            if [ -f "go.mod" ]; then
                echo -e "${CYAN}📦 Installing dependencies...${NC}"
                go mod tidy
                echo -e "${CYAN}🚀 Starting Go application...${NC}"
                go run main.go &
            fi
            ;;
        "rust")
            if [ -f "Cargo.toml" ]; then
                echo -e "${CYAN}📦 Building project...${NC}"
                cargo build
                echo -e "${CYAN}🚀 Starting Rust application...${NC}"
                cargo run &
            fi
            ;;
        "csharp")
            if [ -f "*.csproj" ]; then
                echo -e "${CYAN}📦 Restoring packages...${NC}"
                dotnet restore
                echo -e "${CYAN}🚀 Starting .NET application...${NC}"
                dotnet run &
            fi
            ;;
    esac
    
    echo -e "${GREEN}✅ Project services started${NC}"
}

# Function to start cockpit
start_cockpit() {
    local cockpit_dir=".cockpit"
    
    if [ ! -d "$cockpit_dir" ]; then
        echo -e "${RED}❌ Cockpit not found. Please run setup first.${NC}"
        exit 1
    fi
    
    cd "$cockpit_dir"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js is required to run the cockpit${NC}"
        exit 1
    fi
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo -e "${BLUE}📦 Installing cockpit dependencies...${NC}"
        npm install
    fi
    
    # Check if port 5002 is available
    if lsof -i :5002 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port 5002 is already in use${NC}"
        echo -e "${CYAN}Stopping existing cockpit process...${NC}"
        pkill -f "cockpit-api.js" 2>/dev/null || true
        sleep 2
    fi
    
    # Start the cockpit
    echo -e "${BLUE}🚀 Starting Universal Development Cockpit...${NC}"
    node cockpit-api.js &
    COCKPIT_PID=$!
    
    # Wait for cockpit to start
    sleep 3
    
    # Check if cockpit started successfully
    if curl -s http://localhost:5002/api/status >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Universal Development Cockpit started successfully${NC}"
        echo -e "${CYAN}📊 Dashboard URL: ${YELLOW}http://localhost:5002${NC}"
        echo -e "${CYAN}🔧 API Endpoint: ${YELLOW}http://localhost:5002/api${NC}"
        echo ""
        echo -e "${PURPLE}🎯 Universal Features:${NC}"
        echo -e "  📊 Project-agnostic monitoring"
        echo -e "  🔧 Language-specific commands"
        echo -e "  🤖 AI assistant for any project"
        echo -e "  🚀 Automatic Cursor integration"
        echo -e "  📈 Universal performance tracking"
        echo -e "  🛠️  Cross-platform development tools"
        echo ""
        echo -e "${GREEN}🎮 Ready to fly any project!${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop the cockpit${NC}"
        
        # Save PID for cleanup
        echo $COCKPIT_PID > cockpit.pid
        
        # Wait for user to stop
        wait $COCKPIT_PID
    else
        echo -e "${RED}❌ Failed to start cockpit${NC}"
        kill $COCKPIT_PID 2>/dev/null || true
        exit 1
    fi
}

# Main execution
main() {
    local action="${1:-start}"
    
    case "$action" in
        "setup")
            echo -e "${PURPLE}🔧 Setting up Universal Development Cockpit...${NC}"
            
            # Detect project
            local project_type=$(detect_project_type)
            local project_name=$(get_project_name)
            
            echo -e "${CYAN}📁 Project: ${YELLOW}$project_name${NC}"
            echo -e "${CYAN}🔧 Type: ${YELLOW}$project_type${NC}"
            
            # Setup project cockpit
            setup_project_cockpit "$project_type" "$project_name"
            
            # Open Cursor
            open_cursor
            
            echo -e "${GREEN}✅ Setup complete! Run './universal-start.sh start' to launch cockpit${NC}"
            ;;
            
        "start")
            echo -e "${PURPLE}🚀 Starting Universal Development Cockpit...${NC}"
            
            # Detect project
            local project_type=$(detect_project_type)
            local project_name=$(get_project_name)
            
            echo -e "${CYAN}📁 Project: ${YELLOW}$project_name${NC}"
            echo -e "${CYAN}🔧 Type: ${YELLOW}$project_type${NC}"
            
            # Start project services
            start_project_services "$project_type"
            
            # Open Cursor
            open_cursor
            
            # Start cockpit
            start_cockpit
            ;;
            
        "cursor")
            echo -e "${PURPLE}🎯 Opening Cursor...${NC}"
            open_cursor
            ;;
            
        "help")
            echo -e "${PURPLE}Universal Development Cockpit - Usage${NC}"
            echo "========================================="
            echo "  $0 setup   - Setup cockpit for current project"
            echo "  $0 start   - Start cockpit and project services"
            echo "  $0 cursor  - Open Cursor with current project"
            echo "  $0 help    - Show this help message"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 setup"
            echo "  $0 start"
            echo "  $0 cursor"
            ;;
            
        *)
            echo -e "${RED}❌ Unknown action: $action${NC}"
            echo -e "${CYAN}Run '$0 help' for usage information${NC}"
            exit 1
            ;;
    esac
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping Universal Development Cockpit...${NC}"
    
    # Stop cockpit
    if [ -f ".cockpit/cockpit.pid" ]; then
        PID=$(cat .cockpit/cockpit.pid)
        kill $PID 2>/dev/null || true
        rm -f .cockpit/cockpit.pid
    fi
    
    # Stop project services
    pkill -f "npm start" 2>/dev/null || true
    pkill -f "npm run dev" 2>/dev/null || true
    pkill -f "python app.py" 2>/dev/null || true
    pkill -f "python manage.py" 2>/dev/null || true
    pkill -f "php -S" 2>/dev/null || true
    pkill -f "mvn spring-boot:run" 2>/dev/null || true
    pkill -f "go run" 2>/dev/null || true
    pkill -f "cargo run" 2>/dev/null || true
    pkill -f "dotnet run" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Universal Development Cockpit stopped${NC}"
    exit 0
}

# Handle script interruption
trap cleanup INT TERM

# Run main function
main "$@"
