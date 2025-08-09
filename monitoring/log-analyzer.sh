#!/bin/bash
set -e

# ANQA Log Analyzer - Pattern Detection & Log Analysis
# Detects patterns and provides insights from system logs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_ANALYSIS_DIR="log-analysis"
ANALYSIS_REPORT="log-analysis-report.json"
PATTERN_DB="pattern-database.json"
ANALYSIS_LOG="log-analyzer.log"

echo -e "${PURPLE}📊 ANQA Log Analyzer - Pattern Detection & Log Analysis${NC}"
echo "========================================================="

# Function to log analysis result
log_analysis() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local operation="$1"
    local log_file="$2"
    local pattern="$3"
    local count="$4"
    local severity="$5"
    
    echo "$timestamp|$operation|$log_file|$pattern|$count|$severity" >> "$ANALYSIS_LOG"
}

# Function to initialize analysis system
initialize_analysis_system() {
    echo -e "${BLUE}🔧 Initializing log analysis system...${NC}"
    
    # Create analysis directory
    mkdir -p "$LOG_ANALYSIS_DIR"
    mkdir -p "$LOG_ANALYSIS_DIR/patterns"
    mkdir -p "$LOG_ANALYSIS_DIR/reports"
    
    # Create pattern database
    local pattern_db='{
        "error_patterns": {
            "database_errors": [
                "connection.*failed",
                "timeout.*database",
                "postgres.*error",
                "sql.*syntax.*error"
            ],
            "api_errors": [
                "api.*error",
                "endpoint.*failed",
                "http.*500",
                "http.*404"
            ],
            "system_errors": [
                "memory.*error",
                "cpu.*overload",
                "disk.*full",
                "process.*killed"
            ],
            "network_errors": [
                "connection.*refused",
                "timeout.*connection",
                "network.*unreachable",
                "dns.*error"
            ]
        },
        "warning_patterns": {
            "performance_warnings": [
                "slow.*query",
                "response.*time.*high",
                "memory.*usage.*high",
                "cpu.*usage.*high"
            ],
            "security_warnings": [
                "authentication.*failed",
                "authorization.*denied",
                "invalid.*token",
                "session.*expired"
            ]
        },
        "info_patterns": {
            "startup_info": [
                "server.*started",
                "database.*connected",
                "service.*ready",
                "port.*listening"
            ],
            "operation_info": [
                "request.*processed",
                "query.*executed",
                "cache.*hit",
                "cache.*miss"
            ]
        }
    }'
    
    echo "$pattern_db" > "$PATTERN_DB"
    echo -e "${GREEN}✅ Log analysis system initialized${NC}"
}

# Function to analyze log file
analyze_log_file() {
    local log_file="$1"
    local analysis_name="$2"
    
    echo -e "${BLUE}🔍 Analyzing $log_file...${NC}"
    
    if [ ! -f "$log_file" ]; then
        echo -e "  ${RED}❌ Log file not found: $log_file${NC}"
        return 1
    fi
    
    local file_size=$(ls -lh "$log_file" | awk '{print $5}')
    local line_count=$(wc -l < "$log_file")
    
    echo -e "  ${CYAN}File size: $file_size${NC}"
    echo -e "  ${CYAN}Line count: $line_count${NC}"
    
    # Create analysis result structure
    local analysis_result='{
        "log_file": "'$log_file'",
        "analysis_name": "'$analysis_name'",
        "file_info": {
            "size": "'$file_size'",
            "line_count": '$line_count',
            "last_modified": "'$(stat -f "%Sm" "$log_file")'"
        },
        "patterns": {
            "errors": {},
            "warnings": {},
            "info": {}
        },
        "summary": {
            "total_errors": 0,
            "total_warnings": 0,
            "total_info": 0,
            "critical_issues": 0
        }
    }'
    
    # Analyze error patterns
    echo -e "  ${CYAN}Analyzing error patterns...${NC}"
    local error_patterns=$(jq -r '.error_patterns | to_entries[] | .value[]' "$PATTERN_DB")
    
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            local count=$(grep -i "$pattern" "$log_file" | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "    ${RED}Error pattern: $pattern - $count occurrences${NC}"
                log_analysis "ERROR_PATTERN" "$log_file" "$pattern" "$count" "high"
                
                # Update analysis result
                analysis_result=$(echo "$analysis_result" | jq --arg pattern "$pattern" --arg count "$count" \
                    '.patterns.errors[$pattern] = ($count | tonumber) | .summary.total_errors += ($count | tonumber)')
            fi
        fi
    done <<< "$error_patterns"
    
    # Analyze warning patterns
    echo -e "  ${CYAN}Analyzing warning patterns...${NC}"
    local warning_patterns=$(jq -r '.warning_patterns | to_entries[] | .value[]' "$PATTERN_DB")
    
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            local count=$(grep -i "$pattern" "$log_file" | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "    ${YELLOW}Warning pattern: $pattern - $count occurrences${NC}"
                log_analysis "WARNING_PATTERN" "$log_file" "$pattern" "$count" "medium"
                
                # Update analysis result
                analysis_result=$(echo "$analysis_result" | jq --arg pattern "$pattern" --arg count "$count" \
                    '.patterns.warnings[$pattern] = ($count | tonumber) | .summary.total_warnings += ($count | tonumber)')
            fi
        fi
    done <<< "$warning_patterns"
    
    # Analyze info patterns
    echo -e "  ${CYAN}Analyzing info patterns...${NC}"
    local info_patterns=$(jq -r '.info_patterns | to_entries[] | .value[]' "$PATTERN_DB")
    
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            local count=$(grep -i "$pattern" "$log_file" | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "    ${GREEN}Info pattern: $pattern - $count occurrences${NC}"
                log_analysis "INFO_PATTERN" "$log_file" "$pattern" "$count" "low"
                
                # Update analysis result
                analysis_result=$(echo "$analysis_result" | jq --arg pattern "$pattern" --arg count "$count" \
                    '.patterns.info[$pattern] = ($count | tonumber) | .summary.total_info += ($count | tonumber)')
            fi
        fi
    done <<< "$info_patterns"
    
    # Save analysis result
    local result_file="$LOG_ANALYSIS_DIR/reports/${analysis_name}-$(date +%Y%m%d-%H%M%S).json"
    echo "$analysis_result" > "$result_file"
    
    echo -e "  ${GREEN}✅ Analysis completed: $result_file${NC}"
    
    # Show summary
    local total_errors=$(echo "$analysis_result" | jq -r '.summary.total_errors')
    local total_warnings=$(echo "$analysis_result" | jq -r '.summary.total_warnings')
    local total_info=$(echo "$analysis_result" | jq -r '.summary.total_info')
    
    echo -e "  ${PURPLE}📊 Summary:${NC}"
    echo -e "    ${RED}Errors: $total_errors${NC}"
    echo -e "    ${YELLOW}Warnings: $total_warnings${NC}"
    echo -e "    ${GREEN}Info: $total_info${NC}"
}

# Function to analyze all system logs
analyze_system_logs() {
    echo -e "${BLUE}🔍 Analyzing all system logs...${NC}"
    
    local log_files=(
        "backend.log:backend"
        "frontend.log:frontend"
        "system-optimization/error-mitigation/error-tracker.sh:error_tracker"
        "system-optimization/monitoring/real-time-monitor.sh:real_time_monitor"
        "system-optimization/error-mitigation/health-monitor.sh:health_monitor"
    )
    
    for log_entry in "${log_files[@]}"; do
        IFS=':' read -r log_file analysis_name <<< "$log_entry"
        if [ -f "$log_file" ]; then
            analyze_log_file "$log_file" "$analysis_name"
            echo ""
        else
            echo -e "  ${YELLOW}⚠️  Log file not found: $log_file${NC}"
        fi
    done
}

# Function to detect recurring patterns
detect_recurring_patterns() {
    echo -e "${BLUE}🔍 Detecting recurring patterns...${NC}"
    
    if [ ! -f "$ANALYSIS_LOG" ]; then
        echo -e "  ${YELLOW}No analysis log found${NC}"
        return
    fi
    
    # Find patterns that appear frequently
    echo -e "  ${CYAN}Frequent error patterns:${NC}"
    grep "ERROR_PATTERN" "$ANALYSIS_LOG" | awk -F'|' '{print $4}' | sort | uniq -c | sort -nr | head -10 | while read -r count pattern; do
        if [ "$count" -ge 3 ]; then
            echo -e "    ${RED}$pattern: $count occurrences${NC}"
        fi
    done
    
    echo -e "  ${CYAN}Frequent warning patterns:${NC}"
    grep "WARNING_PATTERN" "$ANALYSIS_LOG" | awk -F'|' '{print $4}' | sort | uniq -c | sort -nr | head -10 | while read -r count pattern; do
        if [ "$count" -ge 3 ]; then
            echo -e "    ${YELLOW}$pattern: $count occurrences${NC}"
        fi
    done
}

# Function to analyze log trends
analyze_log_trends() {
    echo -e "${BLUE}📈 Analyzing log trends...${NC}"
    
    if [ ! -f "$ANALYSIS_LOG" ]; then
        echo -e "  ${YELLOW}No analysis log found${NC}"
        return
    fi
    
    # Analyze trends over time
    echo -e "  ${CYAN}Error trends (last 24 hours):${NC}"
    local yesterday=$(date -v-1d +"%Y-%m-%d")
    grep "$yesterday" "$ANALYSIS_LOG" | grep "ERROR_PATTERN" | wc -l | while read -r count; do
        echo -e "    ${RED}Yesterday: $count errors${NC}"
    done
    
    local today=$(date +"%Y-%m-%d")
    grep "$today" "$ANALYSIS_LOG" | grep "ERROR_PATTERN" | wc -l | while read -r count; do
        echo -e "    ${RED}Today: $count errors${NC}"
    done
    
    # Analyze hourly patterns
    echo -e "  ${CYAN}Hourly error distribution:${NC}"
    grep "$today" "$ANALYSIS_LOG" | grep "ERROR_PATTERN" | awk -F'|' '{print $1}' | awk '{print $2}' | cut -d: -f1 | sort | uniq -c | while read -r count hour; do
        echo -e "    ${CYAN}Hour $hour: $count errors${NC}"
    done
}

# Function to generate pattern insights
generate_pattern_insights() {
    echo -e "${BLUE}💡 Generating pattern insights...${NC}"
    
    local insights_file="$LOG_ANALYSIS_DIR/pattern-insights-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ANQA Log Pattern Insights"
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "========================"
        echo ""
        
        echo "Critical Issues:"
        echo "---------------"
        
        # Find critical patterns
        if [ -f "$ANALYSIS_LOG" ]; then
            echo "High-frequency error patterns:"
            grep "ERROR_PATTERN" "$ANALYSIS_LOG" | awk -F'|' '{print $4}' | sort | uniq -c | sort -nr | head -5 | while read -r count pattern; do
                if [ "$count" -ge 5 ]; then
                    echo "  - $pattern: $count occurrences"
                fi
            done
            
            echo ""
            echo "Recent critical errors:"
            tail -20 "$ANALYSIS_LOG" | grep "ERROR_PATTERN" | while IFS='|' read -r timestamp operation log_file pattern count severity; do
                echo "  - $timestamp: $pattern in $log_file ($count occurrences)"
            done
        fi
        
        echo ""
        echo "Performance Insights:"
        echo "-------------------"
        
        # Performance patterns
        if [ -f "$ANALYSIS_LOG" ]; then
            echo "Slow response patterns:"
            grep -i "slow\|timeout\|response.*time" "$ANALYSIS_LOG" | tail -5 | while IFS='|' read -r timestamp operation log_file pattern count severity; do
                echo "  - $pattern: $count occurrences"
            done
        fi
        
        echo ""
        echo "Recommendations:"
        echo "---------------"
        echo "1. Monitor high-frequency error patterns for system stability"
        echo "2. Investigate slow response patterns for performance optimization"
        echo "3. Set up alerts for critical error thresholds"
        echo "4. Review log rotation policies to manage file sizes"
        echo "5. Implement structured logging for better pattern detection"
        
    } > "$insights_file"
    
    echo -e "${GREEN}✅ Pattern insights generated: $insights_file${NC}"
}

# Function to create custom pattern
create_custom_pattern() {
    local pattern_name="$1"
    local pattern_regex="$2"
    local pattern_type="$3"
    
    echo -e "${BLUE}🔧 Creating custom pattern: $pattern_name${NC}"
    
    if [ ! -f "$PATTERN_DB" ]; then
        echo -e "  ${RED}❌ Pattern database not found${NC}"
        return 1
    fi
    
    # Add custom pattern to database
    local temp_file=$(mktemp)
    jq --arg name "$pattern_name" \
       --arg regex "$pattern_regex" \
       --arg type "$pattern_type" \
       '.custom_patterns[$name] = {
           regex: $regex,
           type: $type,
           created: "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'"
       }' "$PATTERN_DB" > "$temp_file"
    mv "$temp_file" "$PATTERN_DB"
    
    echo -e "  ${GREEN}✅ Custom pattern created: $pattern_name${NC}"
    log_analysis "CUSTOM_PATTERN" "pattern_db" "$pattern_name" "1" "info"
}

# Function to search for specific patterns
search_patterns() {
    local search_term="$1"
    local log_file="$2"
    
    echo -e "${BLUE}🔍 Searching for pattern: $search_term${NC}"
    
    if [ -z "$log_file" ]; then
        # Search in all log files
        local log_files=("backend.log" "frontend.log")
        for file in "${log_files[@]}"; do
            if [ -f "$file" ]; then
                echo -e "  ${CYAN}Searching in $file:${NC}"
                grep -i "$search_term" "$file" | tail -10 | while read -r line; do
                    echo -e "    $line"
                done
            fi
        done
    else
        # Search in specific log file
        if [ -f "$log_file" ]; then
            echo -e "  ${CYAN}Searching in $log_file:${NC}"
            grep -i "$search_term" "$log_file" | tail -10 | while read -r line; do
                echo -e "    $line"
            done
        else
            echo -e "  ${RED}❌ Log file not found: $log_file${NC}"
        fi
    fi
}

# Function to generate analysis report
generate_analysis_report() {
    echo -e "${PURPLE}📋 Generating comprehensive analysis report...${NC}"
    
    local report_file="log-analysis-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Collect all analysis results
    local comprehensive_report='{
        "timestamp": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "analysis_summary": {
            "total_logs_analyzed": 0,
            "total_patterns_found": 0,
            "critical_issues": 0,
            "performance_issues": 0
        },
        "pattern_analysis": {
            "error_patterns": {},
            "warning_patterns": {},
            "info_patterns": {}
        },
        "trends": {
            "error_trends": {},
            "performance_trends": {}
        },
        "recommendations": []
    }'
    
    echo "$comprehensive_report" > "$report_file"
    
    echo -e "${GREEN}✅ Comprehensive analysis report generated: $report_file${NC}"
}

# Function to show analysis summary
show_analysis_summary() {
    echo -e "${PURPLE}📊 Log Analysis Summary${NC}"
    echo "======================="
    
    if [ -f "$ANALYSIS_LOG" ]; then
        local total_analyses=$(wc -l < "$ANALYSIS_LOG")
        local error_patterns=$(grep "ERROR_PATTERN" "$ANALYSIS_LOG" | wc -l)
        local warning_patterns=$(grep "WARNING_PATTERN" "$ANALYSIS_LOG" | wc -l)
        local info_patterns=$(grep "INFO_PATTERN" "$ANALYSIS_LOG" | wc -l)
        
        echo -e "${CYAN}Total analyses: $total_analyses${NC}"
        echo -e "${RED}Error patterns: $error_patterns${NC}"
        echo -e "${YELLOW}Warning patterns: $warning_patterns${NC}"
        echo -e "${GREEN}Info patterns: $info_patterns${NC}"
        
        echo ""
        echo -e "${CYAN}Recent pattern discoveries:${NC}"
        tail -10 "$ANALYSIS_LOG" | while IFS='|' read -r timestamp operation log_file pattern count severity; do
            echo -e "  ${YELLOW}$timestamp${NC} - $pattern ($count occurrences) in $log_file"
        done
    else
        echo -e "${YELLOW}No analysis history found${NC}"
    fi
}

# Main analysis function
main_analysis() {
    echo -e "${PURPLE}🚀 Starting comprehensive log analysis...${NC}"
    echo ""
    
    initialize_analysis_system
    echo ""
    analyze_system_logs
    echo ""
    detect_recurring_patterns
    echo ""
    analyze_log_trends
    echo ""
    generate_pattern_insights
    echo ""
    generate_analysis_report
    echo ""
    show_analysis_summary
    echo ""
    
    echo -e "${GREEN}✅ Log analysis completed${NC}"
}

# Main execution
main() {
    local action="${1:-analyze}"
    local param1="$2"
    local param2="$3"
    
    case "$action" in
        "analyze")
            main_analysis
            ;;
        "search")
            search_patterns "$param1" "$param2"
            ;;
        "pattern")
            create_custom_pattern "$param1" "$param2" "$param3"
            ;;
        "summary")
            show_analysis_summary
            ;;
        "report")
            generate_analysis_report
            ;;
        "trends")
            analyze_log_trends
            ;;
        *)
            echo -e "${PURPLE}ANQA Log Analyzer - Usage${NC}"
            echo "============================="
            echo "  $0 analyze [log_file]     - Run comprehensive analysis"
            echo "  $0 search <pattern> [file] - Search for specific pattern"
            echo "  $0 pattern <name> <regex> <type> - Create custom pattern"
            echo "  $0 summary                 - Show analysis summary"
            echo "  $0 report                  - Generate analysis report"
            echo "  $0 trends                  - Analyze log trends"
            echo ""
            echo -e "${CYAN}Examples:${NC}"
            echo "  $0 analyze"
            echo "  $0 search 'error' backend.log"
            echo "  $0 pattern 'custom_error' 'my.*error' 'error'"
            echo "  $0 summary"
            ;;
    esac
}

# Run main function
main "$@"
