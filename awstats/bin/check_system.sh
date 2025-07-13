#!/bin/bash

# System Dependencies Check
# File: bin/check_system.sh  
# Version: 2.1.0
# Purpose: Validate system requirements before testing
# Changes: v2.1.0 - Comprehensive dependency validation

VERSION="2.1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

print_color "$PURPLE" "🔍 System Dependencies Check v$VERSION"
print_color "$BLUE" "============================================"

# Check required commands
dependencies=(
    "sqlite3:SQLite database"
    "php:PHP runtime"
    "curl:HTTP client"
    "bc:Calculator for benchmarks"
    "awk:Text processing"
    "find:File operations"
    "date:Date operations"
)

missing_deps=()
all_good=true

for dep in "${dependencies[@]}"; do
    cmd=$(echo "$dep" | cut -d':' -f1)
    desc=$(echo "$dep" | cut -d':' -f2)
    
    if command -v "$cmd" >/dev/null 2>&1; then
        print_color "$GREEN" "✅ $desc ($cmd)"
    else
        print_color "$RED" "❌ $desc ($cmd) - MISSING"
        missing_deps+=("$cmd")
        all_good=false
    fi
done

# Check PHP extensions
print_color "$BLUE" "\n📦 PHP Extensions:"
php_extensions=("sqlite3" "pdo" "json")

for ext in "${php_extensions[@]}"; do
    if php -m | grep -q "$ext"; then
        print_color "$GREEN" "✅ PHP $ext extension"
    else
        print_color "$RED" "❌ PHP $ext extension - MISSING"
        all_goo