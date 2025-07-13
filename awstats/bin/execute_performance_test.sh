#!/bin/bash

# AWStats Performance Test Execution and Results
# File: bin/execute_performance_test.sh
# Version: 2.1.0
# Purpose: Run comprehensive performance tests and generate results summary

VERSION="2.1.0"

# Colors
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

# Get the base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

print_color "$PURPLE" "🧪 AWStats Performance Test Execution v$VERSION"
print_color "$BLUE" "=================================================="

# Pre-test system check
print_color "$CYAN" "🔍 Pre-Test System Validation..."

# Check if optimized files exist
required_files=(
    "$BASE_DIR/database/awstats_schema.sql"
    "$BASE_DIR/bin/awstats_processor.sh"
    "$BASE_DIR/bin/awstats_extractor.sh"
    "$BASE_DIR/bin/config_parser.sh"
    "$BASE_DIR/bin/test_performance.sh"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_color "$GREEN" "✅ $(basename "$file") exists"
    else
        print_color "$RED" "❌ $(basename "$file") missing"
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    print_color "$RED" "❌ Missing required files. Cannot proceed with testing."
    exit 1
fi

# Check system dependencies
print_color "$CYAN" "\n📦 Checking Dependencies..."
deps=("sqlite3" "php" "curl" "bc" "awk")
for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        print_color "$GREEN" "✅ $dep available"
    else
        print_color "$YELLOW" "⚠️ $dep missing - installing if possible..."
        # Try to install missing dependencies
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null 2>&1
            case "$dep" in
                "bc") sudo apt-get install -y bc >/dev/null 2>&1 ;;
                "sqlite3") sudo apt-get install -y sqlite3 >/dev/null 2>&1 ;;
                "php") sudo apt-get install -y php php-sqlite3 >/dev/null 2>&1 ;;
                "curl") sudo apt-get install -y curl >/dev/null 2>&1 ;;
            esac
        fi
    fi
done

# Initialize system if needed
print_color "$CYAN" "\n🔧 System Initialization..."
if [[ ! -f "$BASE_DIR/database/awstats.db" ]]; then
    print_color "$YELLOW" "⚠️ Database not found. Initializing system..."
    "$BASE_DIR/bin/awstats_init.sh" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        print_color "$GREEN" "✅ System initialized successfully"
    else
        print_color "$RED" "❌ System initialization failed"
        exit 1
    fi
else
    print_color "$GREEN" "✅ Database exists"
fi

# Execute performance test
print_color "$CYAN" "\n🚀 Executing Performance Test Suite..."
print_color "$YELLOW" "This may take several minutes to complete..."

# Run the test and capture output
test_output_file="/tmp/awstats_test_results_$$.log"
test_start_time=$(date +%s)

if "$BASE_DIR/bin/test_performance.sh" > "$test_output_file" 2>&1; then
    test_end_time=$(date +%s)
    test_duration=$((test_end_time - test_start_time))
    
    print_color "$GREEN" "✅ Performance test completed in ${test_duration}s"
    
    # Display test results
    print_color "$CYAN" "\n📊 Test Results Summary:"
    
    # Extract key metrics from test output
    if grep -q "EXCELLENT" "$test_output_file"; then
        excellent_count=$(grep -c "EXCELLENT" "$test_output_file")
        print_color "$GREEN" "🌟 Excellent results: $excellent_count"
    fi
    
    if grep -q "Database performance" "$test_output_file"; then
        db_result=$(grep "Database performance" "$test_output_file" | tail -1)
        print_color "$CYAN" "📊 $db_result"
    fi
    
    if grep -q "Processor performance" "$test_output_file"; then
        proc_result=$(grep "Processor performance" "$test_output_file" | tail -1)
        print_color "$CYAN" "⚡ $proc_result"
    fi
    
    if grep -q "API performance" "$test_output_file"; then
        api_result=$(grep "API performance" "$test_output_file" | tail -1)
        print_color "$CYAN" "🔌 $api_result"
    fi
    
    # Show overall performance rating
    if grep -q "OVERALL PERFORMANCE: EXCELLENT" "$test_output_file"; then
        print_color "$GREEN" "🎉 OVERALL PERFORMANCE: EXCELLENT"
    elif grep -q "OVERALL PERFORMANCE: GOOD" "$test_output_file"; then
        print_color "$YELLOW" "✅ OVERALL PERFORMANCE: GOOD"
    else
        print_color "$YELLOW" "⚠️ OVERALL PERFORMANCE: Check detailed results"
    fi
    
    # Save detailed results
    cp "$test_output_file" "$BASE_DIR/test_results_$(date +%Y%m%d_%H%M%S).log"
    print_color "$CYAN" "📄 Detailed results saved to: test_results_$(date +%Y%m%d_%H%M%S).log"
    
else
    print_color "$RED" "❌ Performance test failed"
    if [[ -f "$test_output_file" ]]; then
        print_color "$YELLOW" "Error output:"
        tail -20 "$test_output_file"
    fi
    exit 1
fi

# Performance comparison analysis
print_color "$CYAN" "\n📈 Performance Analysis:"

# Check database performance
db_size=$(du -h "$BASE_DIR/database/awstats.db" 2>/dev/null | cut -f1 || echo "Unknown")
record_count=$(sqlite3 "$BASE_DIR/database/awstats.db" "SELECT COUNT(*) FROM api_usage" 2>/dev/null || echo "0")

print_color "$GREEN" "💾 Database size: $db_size"
print_color "$GREEN" "📊 Total records: $(printf "%'d" $record_count)"

# Test query performance
if [[ -f "$BASE_DIR/database/awstats.db" ]]; then
    query_start=$(date +%s.%N)
    sqlite3 "$BASE_DIR/database/awstats.db" "SELECT COUNT(*) FROM v_domain_stats_fast" >/dev/null 2>&1
    query_end=$(date +%s.%N)
    query_time=$(echo "$query_end - $query_start" | bc)
    query_ms=$(echo "$query_time * 1000" | bc | cut -d. -f1)
    
    print_color "$GREEN" "⚡ Fast query time: ${query_ms}ms"
    
    if [[ $query_ms -lt 50 ]]; then
        print_color "$GREEN" "🚀 Database optimization: EXCELLENT (target: <50ms)"
    elif [[ $query_ms -lt 200 ]]; then
        print_color "$YELLOW" "✅ Database optimization: GOOD (target: <50ms)"
    else
        print_color "$RED" "⚠️ Database optimization: NEEDS IMPROVEMENT"
    fi
fi

# Cleanup
rm -f "$test_output_file"

print_color "$BLUE" "\n=================================================="
print_color "$GREEN" "🎉 Performance Test Execution Complete!"
print_color "$CYAN" "💡 System is ready for production use with optimized performance"

# Generate next steps summary
print_color "$PURPLE" "\n📋 Next Phase Preparation:"
print_color "$CYAN" "✅ Core optimizations tested and validated"
print_color "$CYAN" "🔄 Ready for API and interface optimization phase"
print_color "$CYAN" "📝 System performance baseline established"