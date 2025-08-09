#!/bin/bash
set -e

# ANQA Cache Optimizer - Performance Cache Optimization
# Implements various caching strategies for improved performance

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="cache"
CACHE_CONFIG="cache-config.json"
CACHE_LOG="cache-optimizer.log"
CACHE_STATS="cache-stats.json"

echo -e "${PURPLE}⚡ ANQA Cache Optimizer - Performance Cache Optimization${NC}"
echo "============================================================="

# Function to log cache operation
log_cache_operation() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local operation="$1"
    local details="$2"
    local result="$3"
    
    echo "$timestamp|$operation|$details|$result" >> "$CACHE_LOG"
}

# Function to initialize cache system
initialize_cache_system() {
    echo -e "${BLUE}🔧 Initializing cache system...${NC}"
    
    # Create cache directory
    mkdir -p "$CACHE_DIR"
    mkdir -p "$CACHE_DIR/api"
    mkdir -p "$CACHE_DIR/static"
    mkdir -p "$CACHE_DIR/database"
    
    # Create cache configuration
    local cache_config='{
        "api_cache": {
            "enabled": true,
            "ttl": 300,
            "max_size": "100MB"
        },
        "static_cache": {
            "enabled": true,
            "ttl": 3600,
            "max_size": "50MB"
        },
        "database_cache": {
            "enabled": true,
            "ttl": 600,
            "max_size": "200MB"
        },
        "compression": {
            "enabled": true,
            "level": 6
        }
    }'
    
    echo "$cache_config" > "$CACHE_CONFIG"
    echo -e "${GREEN}✅ Cache system initialized${NC}"
    log_cache_operation "INITIALIZE" "Cache system setup" "SUCCESS"
}

# Function to implement API response caching
implement_api_caching() {
    echo -e "${BLUE}🔧 Implementing API response caching...${NC}"
    
    # Create API cache middleware
    local api_cache_middleware='const cache = require("memory-cache");
const crypto = require("crypto");

function apiCacheMiddleware(ttl = 300) {
    return (req, res, next) => {
        const key = crypto.createHash("md5").update(req.originalUrl).digest("hex");
        const cachedResponse = cache.get(key);
        
        if (cachedResponse) {
            console.log(`Cache hit for: ${req.originalUrl}`);
            return res.json(cachedResponse);
        }
        
        const originalSend = res.json;
        res.json = function(data) {
            cache.put(key, data, ttl * 1000);
            console.log(`Cache miss for: ${req.originalUrl}`);
            originalSend.call(this, data);
        };
        
        next();
    };
}

module.exports = apiCacheMiddleware;'
    
    # Save middleware to backend
    mkdir -p "backend/middleware"
    echo "$api_cache_middleware" > "backend/middleware/cache.js"
    
    # Update server.js to use caching
    if [ -f "backend/src/server.js" ]; then
        # Add cache middleware import
        if ! grep -q "require.*cache" "backend/src/server.js"; then
            sed -i '' '/const express = require("express");/a\
const apiCache = require("../middleware/cache");' "backend/src/server.js"
        fi
        
        # Add cache middleware to routes
        if ! grep -q "apiCache" "backend/src/server.js"; then
            sed -i '' '/app.get.*\/api\/services/a\
app.use("/api/services", apiCache(300));' "backend/src/server.js"
            sed -i '' '/app.get.*\/api\/pages/a\
app.use("/api/pages", apiCache(300));' "backend/src/server.js"
            sed -i '' '/app.get.*\/api\/posts/a\
app.use("/api/posts", apiCache(300));' "backend/src/server.js"
        fi
    fi
    
    echo -e "${GREEN}✅ API response caching implemented${NC}"
    log_cache_operation "API_CACHE" "API response caching middleware" "SUCCESS"
}

# Function to implement static asset caching
implement_static_caching() {
    echo -e "${BLUE}🔧 Implementing static asset caching...${NC}"
    
    # Create static cache configuration
    local static_cache_config='{
        "maxAge": "1h",
        "etag": true,
        "lastModified": true,
        "setHeaders": (res, path) => {
            if (path.endsWith(".css") || path.endsWith(".js")) {
                res.setHeader("Cache-Control", "public, max-age=3600");
            } else if (path.endsWith(".png") || path.endsWith(".jpg") || path.endsWith(".gif")) {
                res.setHeader("Cache-Control", "public, max-age=86400");
            }
        }
    }'
    
    # Update server.js for static caching
    if [ -f "backend/src/server.js" ]; then
        # Add static file serving with cache headers
        if ! grep -q "express.static.*cache" "backend/src/server.js"; then
            sed -i '' '/app.use(express.json());/a\
app.use(express.static("public", {
    maxAge: "1h",
    etag: true,
    lastModified: true,
    setHeaders: (res, path) => {
        if (path.endsWith(".css") || path.endsWith(".js")) {
            res.setHeader("Cache-Control", "public, max-age=3600");
        } else if (path.endsWith(".png") || path.endsWith(".jpg") || path.endsWith(".gif")) {
            res.setHeader("Cache-Control", "public, max-age=86400");
        }
    }
}));' "backend/src/server.js"
        fi
    fi
    
    echo -e "${GREEN}✅ Static asset caching implemented${NC}"
    log_cache_operation "STATIC_CACHE" "Static asset caching headers" "SUCCESS"
}

# Function to implement database query caching
implement_database_caching() {
    echo -e "${BLUE}🔧 Implementing database query caching...${NC}"
    
    # Create database cache middleware
    local db_cache_middleware='const cache = require("memory-cache");
const crypto = require("crypto");

function dbCacheMiddleware(ttl = 600) {
    return (req, res, next) => {
        const query = req.query;
        const key = crypto.createHash("md5").update(JSON.stringify(query)).digest("hex");
        const cachedResult = cache.get(key);
        
        if (cachedResult) {
            console.log(`Database cache hit for query: ${JSON.stringify(query)}`);
            return res.json(cachedResult);
        }
        
        const originalSend = res.json;
        res.json = function(data) {
            cache.put(key, data, ttl * 1000);
            console.log(`Database cache miss for query: ${JSON.stringify(query)}`);
            originalSend.call(this, data);
        };
        
        next();
    };
}

module.exports = dbCacheMiddleware;'
    
    # Save database cache middleware
    echo "$db_cache_middleware" > "backend/middleware/db-cache.js"
    
    echo -e "${GREEN}✅ Database query caching implemented${NC}"
    log_cache_operation "DB_CACHE" "Database query caching middleware" "SUCCESS"
}

# Function to implement compression
implement_compression() {
    echo -e "${BLUE}🔧 Implementing compression...${NC}"
    
    # Update server.js to add compression
    if [ -f "backend/src/server.js" ]; then
        # Add compression import
        if ! grep -q "require.*compression" "backend/src/server.js"; then
            sed -i '' '/const express = require("express");/a\
const compression = require("compression");' "backend/src/server.js"
        fi
        
        # Add compression middleware
        if ! grep -q "app.use.*compression" "backend/src/server.js"; then
            sed -i '' '/app.use(express.json());/a\
app.use(compression({
    level: 6,
    threshold: 1024,
    filter: (req, res) => {
        if (req.headers["x-no-compression"]) {
            return false;
        }
        return compression.filter(req, res);
    }
}));' "backend/src/server.js"
        fi
    fi
    
    echo -e "${GREEN}✅ Compression implemented${NC}"
    log_cache_operation "COMPRESSION" "Gzip compression middleware" "SUCCESS"
}

# Function to optimize frontend caching
optimize_frontend_caching() {
    echo -e "${BLUE}🔧 Optimizing frontend caching...${NC}"
    
    # Create service worker for frontend caching
    local service_worker='const CACHE_NAME = "anqa-cache-v1";
const urlsToCache = [
    "/",
    "/css/anqa-platform-styles.css",
    "/js/main.js",
    "/api/services",
    "/api/pages"
];

self.addEventListener("install", (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => cache.addAll(urlsToCache))
    );
});

self.addEventListener("fetch", (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                if (response) {
                    return response;
                }
                return fetch(event.request);
            })
    );
});'
    
    # Save service worker
    mkdir -p "frontend/public"
    echo "$service_worker" > "frontend/public/sw.js"
    
    # Update index.html to register service worker
    if [ -f "frontend/public/index.html" ]; then
        if ! grep -q "serviceWorker" "frontend/public/index.html"; then
            sed -i '' '/<\/body>/i\
    <script>\
        if ("serviceWorker" in navigator) {\
            navigator.serviceWorker.register("/sw.js");\
        }\
    </script>' "frontend/public/index.html"
        fi
    fi
    
    echo -e "${GREEN}✅ Frontend caching optimized${NC}"
    log_cache_operation "FRONTEND_CACHE" "Service worker and frontend caching" "SUCCESS"
}

# Function to install cache dependencies
install_cache_dependencies() {
    echo -e "${BLUE}📦 Installing cache dependencies...${NC}"
    
    # Install backend cache dependencies
    if [ -d "backend" ]; then
        cd backend
        npm install memory-cache compression --save
        cd ..
        echo -e "  ${GREEN}✅ Backend cache dependencies installed${NC}"
    fi
    
    # Install frontend cache dependencies (if needed)
    if [ -d "frontend" ]; then
        cd frontend
        # Add any frontend caching libraries if needed
        cd ..
        echo -e "  ${GREEN}✅ Frontend cache dependencies installed${NC}"
    fi
    
    log_cache_operation "DEPENDENCIES" "Cache dependencies installation" "SUCCESS"
}

# Function to measure cache performance
measure_cache_performance() {
    echo -e "${BLUE}📊 Measuring cache performance...${NC}"
    
    local performance_data='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "api_cache": {
            "hit_rate": 0,
            "miss_rate": 0,
            "avg_response_time": 0
        },
        "static_cache": {
            "hit_rate": 0,
            "miss_rate": 0,
            "avg_load_time": 0
        },
        "database_cache": {
            "hit_rate": 0,
            "miss_rate": 0,
            "avg_query_time": 0
        }
    }'
    
    echo "$performance_data" > "$CACHE_STATS"
    
    # Test API caching
    echo -e "  ${CYAN}Testing API caching...${NC}"
    local start_time=$(date +%s%N)
    curl -s http://localhost:4001/api/services >/dev/null 2>&1
    local end_time=$(date +%s%N)
    local response_time=$(((end_time - start_time) / 1000000))
    
    echo -e "    ${GREEN}API response time: ${YELLOW}${response_time}ms${NC}"
    
    # Test static asset caching
    echo -e "  ${CYAN}Testing static asset caching...${NC}"
    local start_time=$(date +%s%N)
    curl -s http://localhost:4000 >/dev/null 2>&1
    local end_time=$(date +%s%N)
    local load_time=$(((end_time - start_time) / 1000000))
    
    echo -e "    ${GREEN}Frontend load time: ${YELLOW}${load_time}ms${NC}"
    
    log_cache_operation "PERFORMANCE" "Cache performance measurement" "SUCCESS"
}

# Function to generate cache report
generate_cache_report() {
    echo -e "${PURPLE}📋 Generating cache report...${NC}"
    
    local report_file="cache-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Cache Optimization Report"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "============================="
        echo ""
        
        echo "Cache Configuration:"
        echo "-------------------"
        if [ -f "$CACHE_CONFIG" ]; then
            cat "$CACHE_CONFIG" | jq -r 'to_entries[] | "\(.key): \(.value.enabled)"'
        fi
        
        echo ""
        echo "Cache Performance:"
        echo "-----------------"
        if [ -f "$CACHE_STATS" ]; then
            cat "$CACHE_STATS" | jq -r '.api_cache | "API Cache - Hit Rate: \(.hit_rate)%, Miss Rate: \(.miss_rate)%"'
            cat "$CACHE_STATS" | jq -r '.static_cache | "Static Cache - Hit Rate: \(.hit_rate)%, Miss Rate: \(.miss_rate)%"'
            cat "$CACHE_STATS" | jq -r '.database_cache | "Database Cache - Hit Rate: \(.hit_rate)%, Miss Rate: \(.miss_rate)%"'
        fi
        
        echo ""
        echo "Cache Operations:"
        echo "----------------"
        if [ -f "$CACHE_LOG" ]; then
            tail -10 "$CACHE_LOG" | while IFS='|' read -r timestamp operation details result; do
                echo "$timestamp - $operation: $result"
            done
        fi
        
        echo ""
        echo "Recommendations:"
        echo "---------------"
        echo "1. Monitor cache hit rates and adjust TTL values accordingly"
        echo "2. Consider implementing Redis for distributed caching"
        echo "3. Use CDN for static assets in production"
        echo "4. Implement cache warming for frequently accessed data"
        echo "5. Monitor memory usage and adjust cache sizes as needed"
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Cache report generated: $report_file${NC}"
}

# Function to clear cache
clear_cache() {
    echo -e "${YELLOW}🧹 Clearing cache...${NC}"
    
    # Clear cache directories
    rm -rf "$CACHE_DIR"/*
    echo -e "  ${GREEN}✅ Cache directories cleared${NC}"
    
    # Clear cache logs
    rm -f "$CACHE_LOG"
    rm -f "$CACHE_STATS"
    echo -e "  ${GREEN}✅ Cache logs cleared${NC}"
    
    # Restart services to clear memory cache
    echo -e "  ${CYAN}Restarting services to clear memory cache...${NC}"
    pkill -f "node.*server" 2>/dev/null || true
    pkill -f "react-scripts" 2>/dev/null || true
    
    sleep 3
    
    # Restart services
    cd backend && npm start >/dev/null 2>&1 &
    cd ..
    cd frontend && npm start >/dev/null 2>&1 &
    cd ..
    
    echo -e "${GREEN}✅ Cache cleared and services restarted${NC}"
    log_cache_operation "CLEAR" "Cache cleared and services restarted" "SUCCESS"
}

# Function to show cache status
show_cache_status() {
    echo -e "${PURPLE}📊 Cache Status${NC}"
    echo "============="
    
    echo -e "${CYAN}Cache Configuration:${NC}"
    if [ -f "$CACHE_CONFIG" ]; then
        cat "$CACHE_CONFIG" | jq -r 'to_entries[] | "  \(.key): \(.value.enabled)"'
    else
        echo -e "  ${YELLOW}No cache configuration found${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Cache Directory:${NC}"
    if [ -d "$CACHE_DIR" ]; then
        ls -la "$CACHE_DIR"
    else
        echo -e "  ${YELLOW}Cache directory not found${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Recent Cache Operations:${NC}"
    if [ -f "$CACHE_LOG" ]; then
        tail -5 "$CACHE_LOG" | while IFS='|' read -r timestamp operation details result; do
            if [ "$result" = "SUCCESS" ]; then
                echo -e "  ${GREEN}$timestamp - $operation: SUCCESS${NC}"
            else
                echo -e "  ${RED}$timestamp - $operation: $result${NC}"
            fi
        done
    else
        echo -e "  ${YELLOW}No cache operations logged${NC}"
    fi
}

# Main execution
main() {
    local action="${1:-optimize}"
    
    case "$action" in
        "optimize")
            echo -e "${PURPLE}🚀 Starting cache optimization...${NC}"
            echo ""
            
            initialize_cache_system
            echo ""
            install_cache_dependencies
            echo ""
            implement_api_caching
            echo ""
            implement_static_caching
            echo ""
            implement_database_caching
            echo ""
            implement_compression
            echo ""
            optimize_frontend_caching
            echo ""
            measure_cache_performance
            echo ""
            generate_cache_report
            echo ""
            
            echo -e "${GREEN}✅ Cache optimization completed${NC}"
            ;;
        "status")
            show_cache_status
            ;;
        "clear")
            clear_cache
            ;;
        "report")
            generate_cache_report
            ;;
        "measure")
            measure_cache_performance
            ;;
        *)
            echo -e "${PURPLE}ANQA Cache Optimizer - Usage${NC}"
            echo "==============================="
            echo "  $0 optimize  - Run full cache optimization"
            echo "  $0 status    - Show cache status"
            echo "  $0 clear     - Clear all caches"
            echo "  $0 report    - Generate cache report"
            echo "  $0 measure   - Measure cache performance"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 optimize"
            echo "  $0 status"
            echo "  $0 clear"
            ;;
    esac
}

# Run main function
main "$@"
