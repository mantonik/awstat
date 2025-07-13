#!/bin/bash

# AWStats Performance Test Suite
# File: bin/test_performance.sh
# Version: 2.1.0
# Purpose: Comprehensive testing of optimized AWStats system
# Changes: v2.1.0 - Performance validation and benchmarking

VERSION="2.1.0"
SCRIPT_NAME="test_performance.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Get the base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_DIR="$BASE_DIR/test_data"
TEST_LOGS_DIR="$TEST_DIR/logs"
BACKUP_DIR="$TEST_DIR/backup"
CONFIG_FILE="$BASE_DIR/etc/servers.conf"
DB_FILE="$BASE_DIR/database/awstats.db"

# Performance tracking
declare -A test_results
declare -A benchmark_times

# Test data generation
generate_test_logs() {
    local domain="$1"
    local server="$2"
    local log_count="$3"
    
    print_color "$BLUE" "📝 Generating test logs for $domain-$server..."
    
    local server_log_dir="$TEST_LOGS_DIR/$server"
    mkdir -p "$server_log_dir"
    
    # API endpoints for realistic testing
    local api_endpoints=(
        "/api/v1/users"
        "/api/v1/orders"
        "/api/v1/products"
        "/api/v1/auth/login"
        "/api/v1/auth/logout"
        "/api/v2/analytics"
        "/api/v2/reports"
        "/api/v2/dashboard"
        "/api/v1/notifications"
        "/api/v1/settings"
    )
    
    # Generate multiple months of log files
    for ((month=1; month<=log_count; month++)); do
        local log_date=$(date -d "$(date +%Y-%m-01) -$month month" +%Y-%m)
        local year=$(echo "$log_date" | cut -d'-' -f1)
        local mon=$(echo "$log_date" | cut -d'-' -f2)
        
        local log_file="$server_log_dir/access-${log_date}-01.log"
        
        print_color "$CYAN" "  📄 Creating: $(basename "$log_file")"
        
        # Generate realistic log entries
        {
            # Generate 1000-5000 log entries per file for realistic testing
            local entry_count=$((1000 + RANDOM % 4000))
            
            for ((i=1; i<=entry_count; i++)); do
                # Random timestamp within the month
                local day=$((1 + RANDOM % 28))
                local hour=$((RANDOM % 24))
                local minute=$((RANDOM % 60))
                local second=$((RANDOM % 60))
                
                # Random IP address
                local ip="192.168.$((RANDOM % 255)).$((RANDOM % 255))"
                
                # Random API endpoint
                local endpoint="${api_endpoints[$((RANDOM % ${#api_endpoints[@]}))]}"
                
                # Add query parameters sometimes
                if [[ $((RANDOM % 3)) -eq 0 ]]; then
                    endpoint="${endpoint}?id=$((RANDOM % 1000))"
                fi
                
                # Random HTTP method and status
                local methods=("GET" "POST" "PUT" "DELETE")
                local method="${methods[$((RANDOM % 4))]}"
                
                local statuses=("200" "200" "200" "201" "404" "500")  # Weighted toward success
                local status="${statuses[$((RANDOM % 6))]}"
                
                # Random response size
                local size=$((100 + RANDOM % 10000))
                
                # Random user agent
                local user_agents=(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
                    "curl/7.68.0"
                    "PostmanRuntime/7.28.4"
                )
                local user_agent="${user_agents[$((RANDOM % 4))]}"
                
                # Generate Combined Log Format entry
                local timestamp="${year}-${mon}-$(printf '%02d' $day) $(printf '%02d' $hour):$(printf '%02d' $minute):$(printf '%02d' $second)"
                
                echo "$ip - - [$timestamp +0000] \"$method $endpoint HTTP/1.1\" $status $size \"-\" \"$user_agent\""
                
                # Show progress for large files
                if [[ $((i % 1000)) -eq 0 ]]; then
                    printf "\r    Progress: %d/%d entries" "$i" "$entry_count"
                fi
            done
            printf "\n"
            
        } > "$log_file"
        
        print_color "$GREEN" "    ✅ Generated $(wc -l < "$log_file") log entries"
    done
    
    print_color "$GREEN" "✅ Test logs generated for $domain-$server"
}

# Backup current system state
backup_system() {
    print_color "$BLUE" "💾 Backing up current system state..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup database
    if [[ -f "$DB_FILE" ]]; then
        cp "$DB_FILE" "$BACKUP_DIR/awstats.db.backup"
        print_color "$GREEN" "  ✅ Database backed up"
    fi
    
    # Backup configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$BACKUP_DIR/servers.conf.backup"
        print_color "$GREEN" "  ✅ Configuration backed up"
    fi
    
    # Backup existing reports
    if [[ -d "$BASE_DIR/htdocs/reports" ]]; then
        cp -r "$BASE_DIR/htdocs/reports" "$BACKUP_DIR/reports.backup" 2>/dev/null || true
        print_color "$GREEN" "  ✅ Reports backed up"
    fi
}

# Restore system state
restore_system() {
    print_color "$BLUE" "🔄 Restoring system state..."
    
    # Restore database
    if [[ -f "$BACKUP_DIR/awstats.db.backup" ]]; then
        cp "$BACKUP_DIR/awstats.db.backup" "$DB_FILE"
        print_color "$GREEN" "  ✅ Database restored"
    fi
    
    # Restore configuration
    if [[ -f "$BACKUP_DIR/servers.conf.backup" ]]; then
        cp "$BACKUP_DIR/servers.conf.backup" "$CONFIG_FILE"
        print_color "$GREEN" "  ✅ Configuration restored"
    fi
    
    # Restore reports
    if [[ -d "$BACKUP_DIR/reports.backup" ]]; then
        rm -rf "$BASE_DIR/htdocs/reports"
        cp -r "$BACKUP_DIR/reports.backup" "$BASE_DIR/htdocs/reports" 2>/dev/null || true
        print_color "$GREEN" "  ✅ Reports restored"
    fi
}

# Create test configuration
create_test_config() {
    print_color "$BLUE" "⚙️ Creating test configuration..."
    
    # Update servers.conf with test paths
    cat > "$CONFIG_FILE" << EOF
# AWStats Test Configuration
# Generated by: $SCRIPT_NAME v$VERSION

[global]
database_file=$DB_FILE
htdocs_dir=$BASE_DIR/htdocs
logs_dir=$TEST_LOGS_DIR
awstats_bin=/usr/local/awstats/wwwroot/cgi-bin/awstats.pl
log_format=4
top_apis_count=25
enabled=yes
archive_processed_logs=yes
compress_archived_logs=yes
max_concurrent_processes=4

[test-api.performance.local]
display_name=Performance Test API
environment=test
enabled=yes
servers=test-web1,test-web2

[test-web1]
server_display_name=Test Web Server 1
log_directory=$TEST_LOGS_DIR/test-web1
log_file_pattern=access-*.log
enabled=yes

[test-web2]
server_display_name=Test Web Server 2
log_directory=$TEST_LOGS_DIR/test-web2
log_file_pattern=access-*.log
enabled=yes
EOF
    
    print_color "$GREEN" "✅ Test configuration created"
}

# Test database performance
test_database_performance() {
    print_color "$BLUE" "🗄️ Testing database performance..."
    
    local start_time=$(date +%s.%N)
    
    # Test basic queries
    local query_tests=(
        "SELECT COUNT(*) FROM domains"
        "SELECT COUNT(*) FROM servers"
        "SELECT COUNT(*) FROM api_usage"
        "SELECT * FROM v_domain_stats_fast LIMIT 10"
        "SELECT * FROM v_recent_activity_fast LIMIT 10"
        "SELECT * FROM v_top_apis_fast LIMIT 10"
    )
    
    local query_count=0
    local total_query_time=0
    
    for query in "${query_tests[@]}"; do
        local query_start=$(date +%s.%N)
        local result=$(sqlite3 "$DB_FILE" "$query" 2>/dev/null)
        local query_end=$(date +%s.%N)
        local query_time=$(echo "$query_end - $query_start" | bc)
        
        total_query_time=$(echo "$total_query_time + $query_time" | bc)
        ((query_count++))
        
        print_color "$CYAN" "  📊 Query $query_count: ${query_time}s"
    done
    
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc)
    local avg_query_time=$(echo "scale=4; $total_query_time / $query_count" | bc)
    
    benchmark_times["database_total"]="$total_time"
    benchmark_times["database_avg_query"]="$avg_query_time"
    
    print_color "$GREEN" "✅ Database performance test completed"
    print_color "$GREEN" "  ⏱️ Total time: ${total_time}s"
    print_color "$GREEN" "  📊 Average query time: ${avg_query_time}s"
    
    # Test if queries are fast enough (under 100ms average)
    local avg_ms=$(echo "$avg_query_time * 1000" | bc | cut -d. -f1)
    if [[ $avg_ms -lt 100 ]]; then
        test_results["database_performance"]="PASS"
        print_color "$GREEN" "  ✅ Database performance: EXCELLENT (${avg_ms}ms avg)"
    elif [[ $avg_ms -lt 500 ]]; then
        test_results["database_performance"]="PASS"
        print_color "$YELLOW" "  ⚠️ Database performance: GOOD (${avg_ms}ms avg)"
    else
        test_results["database_performance"]="FAIL"
        print_color "$RED" "  ❌ Database performance: POOR (${avg_ms}ms avg)"
    fi
}

# Test processor performance
test_processor_performance() {
    print_color "$BLUE" "⚡ Testing processor performance..."
    
    local start_time=$(date +%s)
    
    # Run processor with performance monitoring
    print_color "$CYAN" "  🚀 Running optimized processor..."
    
    if "$BASE_DIR/bin/awstats_processor.sh" --all --parallel 4 >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local processing_time=$((end_time - start_time))
        
        benchmark_times["processor_time"]="$processing_time"
        
        # Count processed records
        local total_records=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM api_usage" 2>/dev/null || echo "0")
        local total_files=$(find "$TEST_LOGS_DIR" -name "*.log" | wc -l)
        
        print_color "$GREEN" "✅ Processor performance test completed"
        print_color "$GREEN" "  ⏱️ Processing time: ${processing_time}s"
        print_color "$GREEN" "  📁 Files processed: $total_files"
        print_color "$GREEN" "  📊 Records created: $(printf "%'d" $total_records)"
        
        if [[ $total_records -gt 0 && $processing_time -gt 0 ]]; then
            local records_per_second=$((total_records / processing_time))
            print_color "$GREEN" "  🚀 Processing rate: $(printf "%'d" $records_per_second) records/sec"
            
            # Test processing rate (should be > 1000 records/sec with optimization)
            if [[ $records_per_second -gt 5000 ]]; then
                test_results["processor_performance"]="EXCELLENT"
                print_color "$GREEN" "  ✅ Processor performance: EXCELLENT"
            elif [[ $records_per_second -gt 1000 ]]; then
                test_results["processor_performance"]="GOOD"
                print_color "$YELLOW" "  ⚠️ Processor performance: GOOD"
            else
                test_results["processor_performance"]="POOR"
                print_color "$RED" "  ❌ Processor performance: NEEDS IMPROVEMENT"
            fi
        else
            test_results["processor_performance"]="FAIL"
            print_color "$RED" "  ❌ No records processed"
        fi
    else
        test_results["processor_performance"]="FAIL"
        print_color "$RED" "  ❌ Processor failed to run"
    fi
}

# Test API performance
test_api_performance() {
    print_color "$BLUE" "🔌 Testing API performance..."
    
    # Start PHP server for testing
    local php_pid=""
    cd "$BASE_DIR/htdocs"
    php -S localhost:8081 >/dev/null 2>&1 &
    php_pid=$!
    cd - >/dev/null
    
    # Wait for server to start
    sleep 2
    
    local api_tests=(
        "system_status"
        "dashboard_stats"
        "domain_stats&domain=test-api.performance.local"
        "recent_activity&limit=10"
        "top_apis&limit=10"
    )
    
    local total_api_time=0
    local api_count=0
    
    for test in "${api_tests[@]}"; do
        local api_start=$(date +%s.%N)
        local response=$(curl -s "http://localhost:8081/api/data.php?action=$test")
        local api_end=$(date +%s.%N)
        local api_time=$(echo "$api_end - $api_start" | bc)
        
        total_api_time=$(echo "$total_api_time + $api_time" | bc)
        ((api_count++))
        
        # Check if response is valid JSON
        if echo "$response" | jq . >/dev/null 2>&1; then
            print_color "$CYAN" "  📡 API $api_count ($(echo "$test" | cut -d'&' -f1)): ${api_time}s ✅"
        else
            print_color "$RED" "  📡 API $api_count ($(echo "$test" | cut -d'&' -f1)): ${api_time}s ❌"
        fi
    done
    
    # Cleanup PHP server
    if [[ -n "$php_pid" ]]; then
        kill $php_pid 2>/dev/null || true
    fi
    
    local avg_api_time=$(echo "scale=4; $total_api_time / $api_count" | bc)
    benchmark_times["api_avg_time"]="$avg_api_time"
    
    print_color "$GREEN" "✅ API performance test completed"
    print_color "$GREEN" "  ⏱️ Average API response time: ${avg_api_time}s"
    
    # Test API performance (should be under 1 second)
    local avg_ms=$(echo "$avg_api_time * 1000" | bc | cut -d. -f1)
    if [[ $avg_ms -lt 200 ]]; then
        test_results["api_performance"]="EXCELLENT"
        print_color "$GREEN" "  ✅ API performance: EXCELLENT (${avg_ms}ms avg)"
    elif [[ $avg_ms -lt 1000 ]]; then
        test_results["api_performance"]="GOOD"
        print_color "$YELLOW" "  ⚠️ API performance: GOOD (${avg_ms}ms avg)"
    else
        test_results["api_performance"]="POOR"
        print_color "$RED" "  ❌ API performance: NEEDS OPTIMIZATION (${avg_ms}ms avg)"
    fi
}

# Test memory usage
test_memory_usage() {
    print_color "$BLUE" "🧠 Testing memory usage..."
    
    # Get current memory usage
    local memory_before=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # Run a memory-intensive operation
    local start_time=$(date +%s)
    "$BASE_DIR/bin/awstats_extractor.sh" --all >/dev/null 2>&1
    local end_time=$(date +%s)
    
    local memory_after=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local memory_diff=$(echo "$memory_after - $memory_before" | bc)
    local extraction_time=$((end_time - start_time))
    
    benchmark_times["extraction_time"]="$extraction_time"
    
    print_color "$GREEN" "✅ Memory usage test completed"
    print_color "$GREEN" "  💾 Memory before: ${memory_before}%"
    print_color "$GREEN" "  💾 Memory after: ${memory_after}%"
    print_color "$GREEN" "  📈 Memory increase: ${memory_diff}%"
    print_color "$GREEN" "  ⏱️ Extraction time: ${extraction_time}s"
    
    # Test memory efficiency (should be under 10% increase)
    local memory_int=$(echo "$memory_diff" | cut -d. -f1)
    if [[ ${memory_int#-} -lt 5 ]]; then
        test_results["memory_usage"]="EXCELLENT"
        print_color "$GREEN" "  ✅ Memory usage: EXCELLENT"
    elif [[ ${memory_int#-} -lt 15 ]]; then
        test_results["memory_usage"]="GOOD"
        print_color "$YELLOW" "  ⚠️ Memory usage: ACCEPTABLE"
    else
        test_results["memory_usage"]="POOR"
        print_color "$RED" "  ❌ Memory usage: HIGH"
    fi
}

# Test dashboard rendering
test_dashboard_performance() {
    print_color "$BLUE" "🌐 Testing dashboard performance..."
    
    # Start PHP server
    local php_pid=""
    cd "$BASE_DIR/htdocs"
    php -S localhost:8082 >/dev/null 2>&1 &
    php_pid=$!
    cd - >/dev/null
    
    sleep 2
    
    # Test dashboard loading time
    local start_time=$(date +%s.%N)
    local dashboard_response=$(curl -s "http://localhost:8082/")
    local end_time=$(date +%s.%N)
    local dashboard_time=$(echo "$end_time - $start_time" | bc)
    
    # Cleanup PHP server
    if [[ -n "$php_pid" ]]; then
        kill $php_pid 2>/dev/null || true
    fi
    
    benchmark_times["dashboard_time"]="$dashboard_time"
    
    # Check if dashboard loaded successfully
    if echo "$dashboard_response" | grep -q "AWStats Analytics Dashboard"; then
        print_color "$GREEN" "✅ Dashboard loaded successfully"
        print_color "$GREEN" "  ⏱️ Load time: ${dashboard_time}s"
        
        local load_ms=$(echo "$dashboard_time * 1000" | bc | cut -d. -f1)
        if [[ $load_ms -lt 500 ]]; then
            test_results["dashboard_performance"]="EXCELLENT"
            print_color "$GREEN" "  ✅ Dashboard performance: EXCELLENT (${load_ms}ms)"
        elif [[ $load_ms -lt 2000 ]]; then
            test_results["dashboard_performance"]="GOOD"
            print_color "$YELLOW" "  ⚠️ Dashboard performance: GOOD (${load_ms}ms)"
        else
            test_results["dashboard_performance"]="POOR"
            print_color "$RED" "  ❌ Dashboard performance: SLOW (${load_ms}ms)"
        fi
    else
        test_results["dashboard_performance"]="FAIL"
        print_color "$RED" "  ❌ Dashboard failed to load"
    fi
}

# Generate performance report
generate_performance_report() {
    print_color "$PURPLE" "📊 Performance Test Report"
    print_color "$BLUE" "=================================================="
    
    local total_tests=0
    local passed_tests=0
    local excellent_tests=0
    
    echo ""
    print_color "$CYAN" "📋 TEST RESULTS:"
    
    for test_name in "${!test_results[@]}"; do
        local result="${test_results[$test_name]}"
        ((total_tests++))
        
        case "$result" in
            "EXCELLENT")
                print_color "$GREEN" "  ✅ $test_name: EXCELLENT"
                ((passed_tests++))
                ((excellent_tests++))
                ;;
            "GOOD"|"PASS")
                print_color "$YELLOW" "  ⚠️  $test_name: GOOD"
                ((passed_tests++))
                ;;
            "POOR")
                print_color "$RED" "  ❌ $test_name: NEEDS IMPROVEMENT"
                ;;
            "FAIL")
                print_color "$RED" "  ❌ $test_name: FAILED"
                ;;
        esac
    done
    
    echo ""
    print_color "$CYAN" "⏱️ PERFORMANCE BENCHMARKS:"
    for benchmark in "${!benchmark_times[@]}"; do
        local time="${benchmark_times[$benchmark]}"
        print_color "$GREEN" "  📊 $benchmark: ${time}s"
    done
    
    echo ""
    print_color "$CYAN" "📈 SUMMARY:"
    local pass_rate=$((passed_tests * 100 / total_tests))
    local excellence_rate=$((excellent_tests * 100 / total_tests))
    
    print_color "$GREEN" "  🎯 Tests passed: $passed_tests/$total_tests ($pass_rate%)"
    print_color "$GREEN" "  ⭐ Excellent results: $excellent_tests/$total_tests ($excellence_rate%)"
    
    if [[ $pass_rate -ge 80 ]]; then
        print_color "$GREEN" "  ✅ OVERALL PERFORMANCE: EXCELLENT"
    elif [[ $pass_rate -ge 60 ]]; then
        print_color "$YELLOW" "  ⚠️ OVERALL PERFORMANCE: GOOD"
    else
        print_color "$RED" "  ❌ OVERALL PERFORMANCE: NEEDS IMPROVEMENT"
    fi
    
    echo ""
    print_color "$PURPLE" "🚀 OPTIMIZATION IMPACT:"
    print_color "$CYAN" "  📊 Database queries should be 5-10x faster with indexes"
    print_color "$CYAN" "  ⚡ Processing should be 3-5x faster with parallel execution"
    print_color "$CYAN" "  💾 Memory usage should be optimized with batch operations"
    print_color "$CYAN" "  🌐 Dashboard should load near-instantly with materialized views"
    
    print_color "$BLUE" "=================================================="
}

# Cleanup test data
cleanup_test_data() {
    print_color "$BLUE" "🧹 Cleaning up test data..."
    
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        print_color "$GREEN" "  ✅ Test data removed"
    fi
    
    print_color "$GREEN" "✅ Cleanup completed"
}

# Main test execution
main() {
    print_color "$PURPLE" "🧪 AWStats Performance Test Suite v$VERSION"
    print_color "$BLUE" "=================================================="
    
    # Check dependencies
    if ! command -v bc >/dev/null 2>&1; then
        print_color "$RED" "❌ bc (calculator) is required for benchmarking"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        print_color "$YELLOW" "⚠️ jq is recommended for JSON testing (installing...)"
        # Attempt to install jq if possible
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y jq bc >/dev/null 2>&1 || true
        fi
    fi
    
    print_color "$YELLOW" "⚠️ This test will temporarily modify your system"
    print_color "$YELLOW" "Original data will be backed up and restored"
    echo ""
    
    # Execute test sequence
    backup_system
    
    # Initialize test environment
    create_test_config
    "$BASE_DIR/bin/awstats_init.sh" >/dev/null 2>&1 || true
    
    # Generate test data
    generate_test_logs "test-api.performance.local" "test-web1" 3
    generate_test_logs "test-api.performance.local" "test-web2" 3
    
    echo ""
    print_color "$BLUE" "🚀 Starting Performance Tests..."
    echo ""
    
    # Run performance tests
    test_database_performance
    echo ""
    
    test_processor_performance
    echo ""
    
    test_api_performance
    echo ""
    
    test_memory_usage
    echo ""
    
    test_dashboard_performance
    echo ""
    
    # Generate comprehensive report
    generate_performance_report
    
    # Restore original system
    restore_system
    cleanup_test_data
    
    echo ""
    print_color "$GREEN" "🎉 Performance testing completed!"
    print_color "$CYAN" "💡 System has been restored to original state"
}

# Parse command line arguments
SKIP_RESTORE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-restore)
            SKIP_RESTORE=true
            shift
            ;;
        --help|-h)
            echo "AWStats Performance Test Suite v$VERSION"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --skip-restore    Don't restore original system after testing"
            echo "  --help            Show this help message"
            echo ""
            echo "This test suite will:"
            echo "  • Generate realistic test data"
            echo "  • Test database performance with optimized indexes"
            echo "  • Test processor performance with parallel execution"
            echo "  • Test API response times"
            echo "  • Test memory usage and efficiency"
            echo "  • Test dashboard loading performance"
            echo "  • Generate comprehensive performance report"
            echo ""
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute main test
main

log_message "Performance testing completed"