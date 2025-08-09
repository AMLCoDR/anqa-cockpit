#!/bin/bash
set -e

# ANQA Cockpit Startup Script
# Starts the mission control dashboard

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 ANQA System Cockpit - Mission Control${NC}"
echo "============================================="

# Check if we're in the right directory
if [ ! -f "cockpit-api.js" ]; then
    echo -e "${RED}❌ Error: cockpit-api.js not found${NC}"
    echo -e "${YELLOW}Please run this script from the cockpit directory${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed${NC}"
    echo -e "${YELLOW}Please install Node.js to run the cockpit${NC}"
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}📦 Installing dependencies...${NC}"
    npm install
fi

# Check if port 5002 is available
if lsof -i :5002 >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Port 5002 is already in use${NC}"
    echo -e "${CYAN}Stopping existing cockpit process...${NC}"
    pkill -f "cockpit-api.js" 2>/dev/null || true
    sleep 2
fi

# Start the cockpit API
echo -e "${BLUE}🚀 Starting ANQA Cockpit API...${NC}"
node cockpit-api.js &
COCKPIT_PID=$!

# Wait a moment for the server to start
sleep 3

# Check if the server started successfully
if curl -s http://localhost:5002/api/status >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Cockpit API started successfully${NC}"
    echo -e "${CYAN}📊 Dashboard URL: ${YELLOW}http://localhost:5002${NC}"
    echo -e "${CYAN}🔧 API Endpoint: ${YELLOW}http://localhost:5002/api${NC}"
    echo ""
    echo -e "${PURPLE}🎯 Cockpit Features:${NC}"
    echo -e "  📊 Real-time system monitoring"
    echo -e "  🔧 One-click maintenance actions"
    echo -e "  🚨 Emergency controls"
    echo -e "  📈 Performance metrics"
    echo -e "  📝 Live system logs"
    echo -e "  🚀 Quick deployment tools"
    echo ""
    echo -e "${GREEN}🎮 Ready to fly the plane!${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the cockpit${NC}"
    
    # Save PID for cleanup
    echo $COCKPIT_PID > cockpit.pid
    
    # Wait for user to stop
    wait $COCKPIT_PID
else
    echo -e "${RED}❌ Failed to start cockpit API${NC}"
    kill $COCKPIT_PID 2>/dev/null || true
    exit 1
fi

# Cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping ANQA Cockpit...${NC}"
    if [ -f "cockpit.pid" ]; then
        PID=$(cat cockpit.pid)
        kill $PID 2>/dev/null || true
        rm -f cockpit.pid
    fi
    echo -e "${GREEN}✅ Cockpit stopped${NC}"
    exit 0
}

# Handle script interruption
trap cleanup INT TERM

# Keep script running
wait
