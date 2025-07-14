#!/bin/bash

# AWStats System Initialization Script
# File: bin/awstats_init.sh
# Version: 1.2.6
# Purpose: One-time system setup, directory creation, and database initialization
# Changes: v1.2.6 - UPDATED to use new configuration system
#                    Now reads BASE_DIR from servers.conf instead of calculating
#                    Uses load_config.sh for all path configuration
#                    Reads database schema from file as expected

VERSION="1.2.6"
SCRIPT_NAME="awstats_init.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration system - this sets all the path variables
print_color "$BLUE" "🔧 Loading configuration system..."

# Load configuration parser first
if [[ -f "$SCRIPT_DIR/config_parser.sh" ]]; then
    source "$SCRIPT_DIR/config_parser.sh"
else
    print_color "$RED" "❌ Error: config_parser.sh not found"
    exit 1
fi

# Load configuration - this will set BASE_DIR, DB_FILE, HTDOCS_DIR, etc.
if [[ -f "$SCRIPT_DIR/load_config.sh" ]]; then
    source "$SCRIPT_DIR/load_config.sh"
else
    print_color "$RED" "❌ Error: load_config.sh not found"
    exit 1
fi

# Verify configuration was loaded
if [[ -z "$BASE_DIR" ]]; then
    print_color "$RED" "❌ Error: BASE_DIR not loaded from configuration"
    exit 1
fi

# Set file paths using loaded configuration
CONFIG_FILE="$BASE_DIR/etc/servers.conf"
DB_SCHEMA_FILE="$BASE_DIR/database/awstats_schema.sql"
DB_FILE="$AWSTATS_DB_FILE"  # From load_config.sh
HTDOCS_DIR="$HTDOCS_DIR"    # From load_config.sh
LOGS_DIR="$LOGS_DIR"        # From load_config.sh

print_color "$GREEN" "✅ Configuration loaded successfully"
print_color "$CYAN" "   BASE_DIR: $BASE_DIR"
print_color "$CYAN" "   DB_FILE: $DB_FILE"
print_color "$CYAN" "   HTDOCS_DIR: $HTDOCS_DIR"

# Create directory structure
create_directories() {
    print_color "$BLUE" "=== Creating Directory Structure ==="
    
    local directories=(
        "$BASE_DIR/bin"
        "$BASE_DIR/etc"
        "$(dirname "$DB_FILE")"          # Database directory
        "$HTDOCS_DIR"
        "$HTDOCS_DIR/css"
        "$HTDOCS_DIR/js"
        "$HTDOCS_DIR/api"
        "$HTDOCS_DIR/reports"
        "$LOGS_DIR"
        "$BASE_DIR/docs"
        "$AWSTATS_DB_DIR"                # AWStats data directory
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_color "$GREEN" "✓ Created: $dir"
        else
            print_color "$YELLOW" "  Exists: $dir"
        fi
    done
    
    # Set proper permissions
    chmod 755 "$BASE_DIR/bin" 2>/dev/null || true
    chmod 755 "$HTDOCS_DIR" 2>/dev/null || true
    chmod 755 "$(dirname "$DB_FILE")" 2>/dev/null || true
    
    print_color "$GREEN" "✓ Directory structure created successfully"
}

# Create embedded schema if file not found
create_embedded_schema() {
    print_color "$YELLOW" "Creating database with embedded schema..."
    
    sqlite3 "$DB_FILE" << 'EOF'
-- AWStats Analytics Database Schema
-- Version: 2.1.0

-- Domains table
CREATE TABLE domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    environment TEXT DEFAULT 'production',
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Servers table
CREATE TABLE servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_name TEXT NOT NULL,
    server_display_name TEXT,
    server_type TEXT DEFAULT 'web',
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id),
    UNIQUE(domain_id, server_name)
);

-- API Usage tracking
CREATE TABLE api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    hits INTEGER DEFAULT 0,
    bytes INTEGER DEFAULT 0,
    response_code INTEGER DEFAULT 200,
    date_day DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id),
    FOREIGN KEY (server_id) REFERENCES servers(id)
);

-- Daily summaries
CREATE TABLE daily_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    date_day DATE NOT NULL,
    total_hits INTEGER DEFAULT 0,
    total_pages INTEGER DEFAULT 0,
    total_visits INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    total_bytes INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id),
    FOREIGN KEY (server_id) REFERENCES servers(id),
    UNIQUE(domain_id, server_id, date_day)
);

-- Monthly summaries
CREATE TABLE monthly_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_hits INTEGER DEFAULT 0,
    total_pages INTEGER DEFAULT 0,
    total_visits INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    total_bytes INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id),
    FOREIGN KEY (server_id) REFERENCES servers(id),
    UNIQUE(domain_id, server_id, year, month)
);

-- Processing log
CREATE TABLE processing_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    log_file TEXT NOT NULL,
    processed_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    records_processed INTEGER DEFAULT 0,
    processing_time_seconds INTEGER DEFAULT 0,
    status TEXT DEFAULT 'completed',
    FOREIGN KEY (domain_id) REFERENCES domains(id),
    FOREIGN KEY (server_id) REFERENCES servers(id)
);

-- Indexes for performance
CREATE INDEX idx_api_usage_domain_server ON api_usage(domain_id, server_id);
CREATE INDEX idx_api_usage_date ON api_usage(date_day);
CREATE INDEX idx_api_usage_endpoint ON api_usage(endpoint);
CREATE INDEX idx_daily_summaries_date ON daily_summaries(date_day);
CREATE INDEX idx_monthly_summaries_year_month ON monthly_summaries(year, month);

-- Views for easy querying
CREATE VIEW v_domain_stats AS
SELECT 
    d.domain_name,
    d.display_name,
    COUNT(DISTINCT s.id) as server_count,
    COALESCE(SUM(ms.total_hits), 0) as total_hits,
    COALESCE(SUM(ms.total_pages), 0) as total_pages,
    COALESCE(SUM(ms.total_visits), 0) as total_visits,
    COALESCE(SUM(ms.unique_visitors), 0) as unique_visitors,
    COALESCE(SUM(ms.total_bytes), 0) as total_bytes
FROM domains d
LEFT JOIN servers s ON d.id = s.domain_id AND s.enabled = 1
LEFT JOIN monthly_summaries ms ON s.id = ms.server_id
WHERE d.enabled = 1
GROUP BY d.id, d.domain_name, d.display_name;

CREATE VIEW v_server_stats AS
SELECT 
    d.domain_name,
    s.server_name,
    s.server_display_name,
    COALESCE(SUM(ms.total_hits), 0) as total_hits,
    COALESCE(SUM(ms.total_pages), 0) as total_pages,
    COALESCE(SUM(ms.total_visits), 0) as total_visits,
    COALESCE(SUM(ms.unique_visitors), 0) as unique_visitors,
    COALESCE(SUM(ms.total_bytes), 0) as total_bytes,
    COUNT(DISTINCT ms.year || '-' || ms.month) as months_with_data
FROM domains d
JOIN servers s ON d.id = s.domain_id
LEFT JOIN monthly_summaries ms ON s.id = ms.server_id
WHERE d.enabled = 1 AND s.enabled = 1
GROUP BY d.id, s.id, d.domain_name, s.server_name, s.server_display_name;
EOF

    print_color "$GREEN" "✓ Database schema created successfully"
}

# Initialize SQLite database
initialize_database() {
    print_color "$BLUE" "=== Initializing SQLite Database ==="
    
    # Check if database already exists
    if [[ -f "$DB_FILE" ]]; then
        print_color "$YELLOW" "⚠️  Database already exists: $DB_FILE"
        if [[ "$FORCE_RECREATE" == "true" ]]; then
            print_color "$YELLOW" "Force mode: Recreating database"
            rm -f "$DB_FILE"
        else
            read -p "Do you want to recreate it? This will delete all existing data! (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_color "$BLUE" "Keeping existing database"
                return 0
            fi
            rm -f "$DB_FILE"
        fi
    fi
    
    # Create database directory if needed
    local db_dir=$(dirname "$DB_FILE")
    mkdir -p "$db_dir"
    
    # Initialize database with schema
    if [[ -f "$DB_SCHEMA_FILE" ]]; then
        print_color "$CYAN" "📁 Using schema file: $DB_SCHEMA_FILE"
        sqlite3 "$DB_FILE" < "$DB_SCHEMA_FILE"
        print_color "$GREEN" "✓ Database created from schema file"
    else
        print_color "$YELLOW" "⚠️  Schema file not found: $DB_SCHEMA_FILE"
        print_color "$YELLOW" "Creating database with embedded schema..."
        create_embedded_schema
    fi
    
    # Verify database creation
    if [[ -f "$DB_FILE" ]]; then
        local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
        print_color "$GREEN" "✓ Database created successfully"
        print_color "$GREEN" "  Location: $DB_FILE"
        print_color "$GREEN" "  Tables created: $table_count"
        print_color "$GREEN" "  Database size: $(ls -lh "$DB_FILE" | awk '{print $5}')"
        
        # Set proper permissions
        chmod 664 "$DB_FILE" 2>/dev/null || true
    else
        print_color "$RED" "❌ Failed to create database"
        return 1
    fi
}

# Create default configuration files
create_configuration_files() {
    print_color "$BLUE" "=== Creating Configuration Files ==="
    
    # Create servers.conf if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_color "$CYAN" "Creating default configuration file: $CONFIG_FILE"
        
        cat > "$CONFIG_FILE" << EOF
# AWStats Configuration File
# File: etc/servers.conf
# Version: 1.2.6
# Created by: awstats_init.sh v$VERSION

[global]
# === BASE DIRECTORY SETTING ===
BASE_DIR=\${HOME}

# === DATABASE SETTINGS ===
database_file=\${BASE_DIR}/database/awstats.db
awstats_db_dir=\${BASE_DIR}/database/awstats

# === DIRECTORY SETTINGS ===
htdocs_dir=\${BASE_DIR}/htdocs
logs_dir=\${BASE_DIR}/logs
reports_dir=\${BASE_DIR}/htdocs/reports

# === AWSTATS SETTINGS ===
awstats_bin=/usr/local/awstats/wwwroot/cgi-bin/awstats.pl
log_format=4
skip_hosts=127.0.0.1 localhost
skip_files=REGEX[/\\.css$|/\\.js$|/\\.png$|/\\.jpg$|/\\.gif$|/favicon\\.ico$]

# === PERFORMANCE SETTINGS ===
max_concurrent_processes=4
batch_size=1000
memory_limit_mb=512

# === OTHER SETTINGS ===
retention_days=365
archive_processed_logs=yes
compress_archived_logs=yes
top_apis_count=25
enabled=yes

# === EXAMPLE DOMAIN CONFIGURATION ===
# [your-domain.com]
# display_name=Your Domain Name
# environment=production
# enabled=yes
# servers=web1,web2

# [web1]
# server_display_name=Web Server 1
# log_directory=\${BASE_DIR}/logs/web1
# log_file_pattern=access-*.log
# enabled=yes
EOF
        
        print_color "$GREEN" "✓ Configuration file created"
        print_color "$YELLOW" "  Please edit $CONFIG_FILE to configure your domains and servers"
    else
        print_color "$GREEN" "✓ Configuration file exists: $CONFIG_FILE"
    fi
}

# Create log structure based on configuration
create_log_structure() {
    print_color "$BLUE" "=== Creating Log Structure ==="
    
    # Create base logs directory
    mkdir -p "$LOGS_DIR"
    
    # Create example log directories if configuration has domains
    local domains=()
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r section; do
            if [[ "$section" != "global" ]]; then
                local servers=$(get_config_value "servers" "" "$section" 2>/dev/null || true)
                if [[ -n "$servers" ]]; then
                    domains+=("$section")
                fi
            fi
        done < <(get_all_sections 2>/dev/null || true)
    fi
    
    if [[ ${#domains[@]} -gt 0 ]]; then
        print_color "$CYAN" "Creating log directories for configured domains..."
        
        for domain in "${domains[@]}"; do
            local servers=$(get_config_value "servers" "" "$domain" 2>/dev/null || true)
            if [[ -n "$servers" ]]; then
                IFS=',' read -ra server_list <<< "$servers"
                for server in "${server_list[@]}"; do
                    server=$(echo "$server" | xargs)
                    local log_dir="$LOGS_DIR/$server"
                    mkdir -p "$log_dir"
                    print_color "$GREEN" "  ✓ Created: $log_dir"
                    
                    # Create a README file
                    cat > "$log_dir/README.txt" << EOF
# Log Directory for Server: $server
# Domain: $domain
# 
# Place your Apache/Nginx log files here.
# Supported formats:
# - access-YYYY-MM-DD.log
# - access_log-YYYYMMDD
# - access.log-YYYYMMDD
#
# Example:
# access-2024-07-01.log
# access-2024-07-02.log
EOF
                done
            fi
        done
    else
        print_color "$YELLOW" "  No domains configured yet - create example structure"
        mkdir -p "$LOGS_DIR/example_server"
        print_color "$GREEN" "  ✓ Created example: $LOGS_DIR/example_server"
    fi
    
    print_color "$GREEN" "✓ Log structure created"
}

# Verify installation
verify_installation() {
    print_color "$BLUE" "=== Verifying Installation ==="
    
    local errors=0
    
    # Check directories - FIXED variable expansion
    local required_dirs=("$BASE_DIR/bin" "$BASE_DIR/etc" "$(dirname "$DB_FILE")" "$HTDOCS_DIR" "$LOGS_DIR" "$AWSTATS_DB_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_color "$GREEN" "✓ Directory: $dir"
        else
            print_color "$RED" "❌ Missing directory: $dir"
            ((errors++))
        fi
    done
    
    # Check files
    local required_files=("$CONFIG_FILE" "$DB_FILE")
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_color "$GREEN" "✓ File: $file"
        else
            print_color "$RED" "❌ Missing file: $file"
            ((errors++))
        fi
    done
    
    # Check database
    if [[ -f "$DB_FILE" ]]; then
        local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
        if [[ "$table_count" -gt 0 ]]; then
            print_color "$GREEN" "✓ Database tables: $table_count"
        else
            print_color "$RED" "❌ Database has no tables"
            ((errors++))
        fi
    fi
    
    # Check configuration loading
    if command -v get_config_value >/dev/null 2>&1; then
        print_color "$GREEN" "✓ Configuration parser loaded"
    else
        print_color "$RED" "❌ Configuration parser not working"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_color "$GREEN" "✅ Installation verification completed successfully!"
        return 0
    else
        print_color "$RED" "❌ Installation verification failed with $errors errors"
        return 1
    fi
}

# Show next steps
show_next_steps() {
    print_color "$PURPLE" "🎉 AWStats System Initialization Complete!"
    echo ""
    print_color "$BLUE" "📋 Next Steps:"
    echo "1. Review and customize configuration:"
    echo "   nano $CONFIG_FILE"
    echo ""
    echo "2. Test configuration loading:"
    echo "   $SCRIPT_DIR/load_config.sh debug"
    echo ""
    echo "3. Validate configuration:"
    echo "   $SCRIPT_DIR/config_parser.sh validate"
    echo ""
    echo "4. Add your log files to:"
    echo "   $LOGS_DIR/[server_name]/"
    echo ""
    echo "5. Test the web interface:"
    echo "   cd $HTDOCS_DIR"
    echo "   php -S localhost:8080"
    echo "   Open: http://localhost:8080"
    echo ""
    echo "6. Process logs:"
    echo "   $SCRIPT_DIR/awstats_processor.sh --all --months 3"
    echo ""
    print_color "$GREEN" "🚀 System ready for log processing!"
}

# Usage information
usage() {
    echo "AWStats System Initialization v$VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --force          Force recreation of existing database"
    echo "  --help           Show this help message"
    echo ""
    echo "This script will:"
    echo "  • Load configuration from servers.conf"
    echo "  • Create directory structure"
    echo "  • Initialize SQLite database from schema file"
    echo "  • Create default configuration files"
    echo "  • Set up log processing structure"
    echo "  • Verify installation"
    echo ""
    echo "Configuration:"
    echo "  BASE_DIR: $BASE_DIR"
    echo "  Database: $DB_FILE"
    echo "  HTDOCS: $HTDOCS_DIR"
    echo "  Logs: $LOGS_DIR"
    echo ""
}

# Parse command line arguments
FORCE_RECREATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_RECREATE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_color "$PURPLE" "🚀 AWStats System Initialization v$VERSION"
    print_color "$PURPLE" "Using configuration-driven setup (no hardcoded paths!)"
    echo ""
    
    log_message "Starting initialization process..."
    
    # Execute initialization steps
    create_directories
    initialize_database
    create_configuration_files
    create_log_structure
    
    echo ""
    verify_installation
    echo ""
    show_next_steps
    
    log_message "Initialization completed"
}

# Execute main function
main "$@"