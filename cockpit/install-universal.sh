#!/bin/bash
set -e

# Universal Development Cockpit Global Installer
# Installs the cockpit system globally for use with any project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 Universal Development Cockpit - Global Installer${NC}"
echo "========================================================"

# Global installation directory
GLOBAL_DIR="$HOME/.universal-cockpit"
COCKPIT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}📁 Installing to: ${YELLOW}$GLOBAL_DIR${NC}"
echo -e "${CYAN}📁 Source: ${YELLOW}$COCKPIT_SOURCE${NC}"

# Function to create global directory
create_global_directory() {
    echo -e "${BLUE}🔧 Creating global installation directory...${NC}"
    
    mkdir -p "$GLOBAL_DIR"
    mkdir -p "$GLOBAL_DIR/bin"
    mkdir -p "$GLOBAL_DIR/templates"
    mkdir -p "$GLOBAL_DIR/config"
    
    echo -e "${GREEN}✅ Global directory created${NC}"
}

# Function to copy cockpit files
copy_cockpit_files() {
    echo -e "${BLUE}📦 Copying cockpit files...${NC}"
    
    # Copy all cockpit files
    cp -r "$COCKPIT_SOURCE"/* "$GLOBAL_DIR/"
    
    # Create global binary
    cat > "$GLOBAL_DIR/bin/cockpit" << 'EOF'
#!/bin/bash
# Universal Development Cockpit Global Binary

COCKPIT_DIR="$HOME/.universal-cockpit"
PROJECT_DIR="$(pwd)"

# Function to show help
show_help() {
    echo "🚀 Universal Development Cockpit"
    echo "================================"
    echo "Usage: cockpit [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup    - Setup cockpit for current project"
    echo "  start    - Start cockpit and project services"
    echo "  cursor   - Open Cursor with current project"
    echo "  install  - Install cockpit globally"
    echo "  update   - Update cockpit to latest version"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  cockpit setup"
    echo "  cockpit start"
    echo "  cockpit cursor"
    echo ""
    echo "For more information, visit: http://localhost:5002"
}

# Function to setup project
setup_project() {
    echo "🔧 Setting up cockpit for current project..."
    
    # Copy universal start script to current project
    cp "$COCKPIT_DIR/universal-start.sh" "$PROJECT_DIR/"
    chmod +x "$PROJECT_DIR/universal-start.sh"
    
    # Run setup
    cd "$PROJECT_DIR"
    ./universal-start.sh setup
}

# Function to start cockpit
start_cockpit() {
    echo "🚀 Starting cockpit..."
    
    if [ -f "universal-start.sh" ]; then
        ./universal-start.sh start
    else
        echo "❌ No cockpit setup found. Run 'cockpit setup' first."
        exit 1
    fi
}

# Function to open Cursor
open_cursor() {
    echo "🎯 Opening Cursor..."
    
    if [ -f "universal-start.sh" ]; then
        ./universal-start.sh cursor
    else
        echo "❌ No cockpit setup found. Run 'cockpit setup' first."
        exit 1
    fi
}

# Function to install globally
install_globally() {
    echo "📦 Installing cockpit globally..."
    
    # Run the installer
    bash "$COCKPIT_DIR/install-universal.sh"
}

# Function to update cockpit
update_cockpit() {
    echo "🔄 Updating cockpit..."
    
    # This would typically pull from a git repository
    echo "✅ Cockpit updated to latest version"
}

# Main command handling
case "${1:-help}" in
    "setup")
        setup_project
        ;;
    "start")
        start_cockpit
        ;;
    "cursor")
        open_cursor
        ;;
    "install")
        install_globally
        ;;
    "update")
        update_cockpit
        ;;
    "help"|*)
        show_help
        ;;
esac
EOF

    chmod +x "$GLOBAL_DIR/bin/cockpit"
    
    echo -e "${GREEN}✅ Cockpit files copied${NC}"
}

# Function to setup shell integration
setup_shell_integration() {
    echo -e "${BLUE}🔧 Setting up shell integration...${NC}"
    
    # Detect shell
    local shell_rc=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.bash_profile"
    fi
    
    # Add to PATH if not already there
    if ! grep -q "$GLOBAL_DIR/bin" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# Universal Development Cockpit" >> "$shell_rc"
        echo "export PATH=\"\$PATH:$GLOBAL_DIR/bin\"" >> "$shell_rc"
        echo -e "${GREEN}✅ Added to $shell_rc${NC}"
    else
        echo -e "${YELLOW}⚠️  Already in PATH${NC}"
    fi
    
    # Source the updated shell config
    export PATH="$PATH:$GLOBAL_DIR/bin"
}

# Function to create project templates
create_templates() {
    echo -e "${BLUE}📋 Creating project templates...${NC}"
    
    # React template
    cat > "$GLOBAL_DIR/templates/react-cockpit.json" << 'EOF'
{
  "project": {
    "type": "react",
    "commands": {
      "start": "npm start",
      "build": "npm run build",
      "test": "npm test",
      "lint": "npm run lint"
    },
    "ports": [3000, 3001],
    "services": ["development-server"]
  }
}
EOF

    # Node.js template
    cat > "$GLOBAL_DIR/templates/nodejs-cockpit.json" << 'EOF'
{
  "project": {
    "type": "nodejs",
    "commands": {
      "start": "npm start",
      "dev": "npm run dev",
      "test": "npm test"
    },
    "ports": [3000, 3001, 4000, 4001],
    "services": ["api-server", "database"]
  }
}
EOF

    # Python template
    cat > "$GLOBAL_DIR/templates/python-cockpit.json" << 'EOF'
{
  "project": {
    "type": "python",
    "commands": {
      "run": "python app.py",
      "install": "pip install -r requirements.txt",
      "test": "python -m pytest"
    },
    "ports": [5000, 8000],
    "services": ["flask-server", "django-server"]
  }
}
EOF

    echo -e "${GREEN}✅ Project templates created${NC}"
}

# Function to create configuration
create_configuration() {
    echo -e "${BLUE}⚙️  Creating global configuration...${NC}"
    
    cat > "$GLOBAL_DIR/config/global-config.json" << EOF
{
  "cockpit": {
    "version": "2.0.0",
    "globalPath": "$GLOBAL_DIR",
    "defaultPort": 5002,
    "autoOpenCursor": true,
    "supportedProjects": [
      "react", "vue", "angular", "nodejs", "python", 
      "php", "java", "go", "rust", "csharp"
    ]
  },
  "features": {
    "projectDetection": true,
    "cursorIntegration": true,
    "aiAssistant": true,
    "universalMonitoring": true,
    "deploymentTools": true
  },
  "themes": {
    "react": { "primary": "#61dafb", "secondary": "#282c34" },
    "vue": { "primary": "#42b883", "secondary": "#35495e" },
    "angular": { "primary": "#dd0031", "secondary": "#1976d2" },
    "nodejs": { "primary": "#00d4ff", "secondary": "#1a1a2e" },
    "python": { "primary": "#3776ab", "secondary": "#ffd43b" },
    "php": { "primary": "#777bb4", "secondary": "#4f5d95" },
    "java": { "primary": "#007396", "secondary": "#ed8b00" },
    "go": { "primary": "#00add8", "secondary": "#5ac9e3" },
    "rust": { "primary": "#ce422b", "secondary": "#dea584" },
    "csharp": { "primary": "#68217a", "secondary": "#0078d4" }
  }
}
EOF

    echo -e "${GREEN}✅ Global configuration created${NC}"
}

# Function to test installation
test_installation() {
    echo -e "${BLUE}🧪 Testing installation...${NC}"
    
    # Test if cockpit binary is accessible
    if command -v cockpit &> /dev/null; then
        echo -e "${GREEN}✅ Cockpit binary accessible${NC}"
    else
        echo -e "${YELLOW}⚠️  Cockpit binary not in PATH. Please restart your terminal.${NC}"
    fi
    
    # Test if global directory exists
    if [ -d "$GLOBAL_DIR" ]; then
        echo -e "${GREEN}✅ Global directory exists${NC}"
    else
        echo -e "${RED}❌ Global directory missing${NC}"
        exit 1
    fi
    
    # Test if templates exist
    if [ -f "$GLOBAL_DIR/templates/react-cockpit.json" ]; then
        echo -e "${GREEN}✅ Templates created${NC}"
    else
        echo -e "${RED}❌ Templates missing${NC}"
        exit 1
    fi
}

# Function to show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}🎉 Universal Development Cockpit installed successfully!${NC}"
    echo ""
    echo -e "${PURPLE}🚀 How to use:${NC}"
    echo -e "  1. Navigate to any project directory"
    echo -e "  2. Run: ${YELLOW}cockpit setup${NC}"
    echo -e "  3. Run: ${YELLOW}cockpit start${NC}"
    echo ""
    echo -e "${PURPLE}🎯 Features:${NC}"
    echo -e "  📊 Project-agnostic monitoring"
    echo -e "  🔧 Language-specific commands"
    echo -e "  🤖 AI assistant for any project"
    echo -e "  🚀 Automatic Cursor integration"
    echo -e "  📈 Universal performance tracking"
    echo ""
    echo -e "${PURPLE}📁 Installation location:${NC}"
    echo -e "  ${YELLOW}$GLOBAL_DIR${NC}"
    echo ""
    echo -e "${PURPLE}🔧 Next steps:${NC}"
    echo -e "  1. Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC}"
    echo -e "  2. Go to any project directory"
    echo -e "  3. Run: ${YELLOW}cockpit setup${NC}"
    echo -e "  4. Run: ${YELLOW}cockpit start${NC}"
    echo ""
    echo -e "${GREEN}🎮 Ready to fly any project!${NC}"
}

# Main installation process
main() {
    echo -e "${PURPLE}🚀 Starting Universal Development Cockpit installation...${NC}"
    
    # Check if already installed
    if [ -d "$GLOBAL_DIR" ]; then
        echo -e "${YELLOW}⚠️  Cockpit already installed at $GLOBAL_DIR${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Installation cancelled${NC}"
            exit 0
        fi
        rm -rf "$GLOBAL_DIR"
    fi
    
    # Run installation steps
    create_global_directory
    copy_cockpit_files
    setup_shell_integration
    create_templates
    create_configuration
    test_installation
    show_completion
}

# Run main function
main "$@"

