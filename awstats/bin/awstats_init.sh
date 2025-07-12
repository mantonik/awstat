#!/bin/bash

# AWStats System Initialization Script
# File: bin/awstats_init.sh
# Version: 2.0.1
# Purpose: One-time system setup, directory creation, and database initialization
# Changes: v2.0.1 - Added configuration hierarchy support and improved validation

VERSION="2.0.1"
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

# Get the base directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Default configuration
CONFIG_FILE="$BASE_DIR/etc/servers.conf"
DB_SCHEMA_FILE="$BASE_DIR/database/awstats_schema.sql"
DB_FILE="$BASE_DIR/database/awstats.db"
HTDOCS_DIR="$BASE_DIR/htdocs"
LOGS_DIR="$BASE_DIR/logs"

# Load configuration if exists
load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        print_color "$BLUE" "Loading configuration from $CONFIG_FILE"
        
        # Parse configuration file for global settings
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            # Look for global settings
            if [[ "$line" =~ ^[[:space:]]*database_file[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                DB_FILE="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*htdocs_dir[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                HTDOCS_DIR="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*logs_dir[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                LOGS_DIR="${BASH_REMATCH[1]}"
            fi
        done < "$CONFIG_FILE"
    fi
    
    # Expand variables
    DB_FILE="${DB_FILE/\$HOME/$HOME}"
    HTDOCS_DIR="${HTDOCS_DIR/\$HOME/$HOME}"
    LOGS_DIR="${LOGS_DIR/\$HOME/$HOME}"
    
    log_message "Configuration loaded:"
    log_message "  Database: $DB_FILE"
    log_message "  Web root: $HTDOCS_DIR"
    log_message "  Logs dir: $LOGS_DIR"
}

# Create directory structure
create_directories() {
    print_color "$BLUE" "=== Creating Directory Structure ==="
    
    local directories=(
        "$BASE_DIR/bin"
        "$BASE_DIR/etc"
        "$BASE_DIR/database"
        "$BASE_DIR/htdocs"
        "$BASE_DIR/htdocs/css"
        "$BASE_DIR/htdocs/js"
        "$BASE_DIR/htdocs/api"
        "$BASE_DIR/htdocs/reports"
        "$BASE_DIR/logs"
        "$BASE_DIR/docs"
        "$(dirname "$DB_FILE")"
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
    chmod 755 "$BASE_DIR/bin"
    chmod 755 "$HTDOCS_DIR"
    chmod 755 "$BASE_DIR/database"
    
    print_color "$GREEN" "✓ Directory structure created successfully"
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
        print_color "$YELLOW" "Creating database from schema: $DB_SCHEMA_FILE"
        sqlite3 "$DB_FILE" < "$DB_SCHEMA_FILE"
    else
        print_color "$RED" "❌ Schema file not found: $DB_SCHEMA_FILE"
        print_color "$YELLOW" "Creating database with embedded schema..."
        create_embedded_schema
    fi
    
    # Verify database creation
    if [[ -f "$DB_FILE" ]]; then
        local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
        print_color "$GREEN" "✓ Database created successfully"
        print_color "$GREEN" "  Tables created: $table_count"
        print_color "$GREEN" "  Database size: $(ls -lh "$DB_FILE" | awk '{print $5}')"
        
        # Set proper permissions
        chmod 664 "$DB_FILE"
    else
        print_color "$RED" "❌ Failed to create database"
        return 1
    fi
}

# Embedded schema fallback
create_embedded_schema() {
    print_color "$YELLOW" "Using embedded schema..."
    
    sqlite3 "$DB_FILE" << 'EOF'
-- Embedded schema for fallback
CREATE TABLE IF NOT EXISTS domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_name TEXT NOT NULL,
    server_display_name TEXT,
    log_path_pattern TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    UNIQUE(domain_id, server_name)
);

CREATE TABLE IF NOT EXISTS api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    api_endpoint TEXT NOT NULL,
    date_day DATE NOT NULL,
    hour INTEGER NOT NULL DEFAULT 0,
    hits INTEGER NOT NULL DEFAULT 0,
    bytes_transferred INTEGER DEFAULT 0,
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    UNIQUE(domain_id, server_id, api_endpoint, date_day, hour)
);

CREATE INDEX IF NOT EXISTS idx_api_usage_domain_date ON api_usage(domain_id, date_day);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON api_usage(api_endpoint);

INSERT OR IGNORE INTO domains (domain_name, display_name) VALUES 
('sbil-api.bos.njtransit.com', 'SBIL API - Boston NJ Transit');

INSERT OR IGNORE INTO servers (domain_id, server_name, server_display_name, log_path_pattern) VALUES 
(1, 'pnjt1sweb1', 'Production Web Server 1', '$BASE_DIR/logs/pnjt1sweb1/access-*.log'),
(1, 'pnjt1sweb2', 'Production Web Server 2', '$BASE_DIR/logs/pnjt1sweb2/access-*.log');
EOF
}

# Create configuration files if they don't exist
create_configuration_files() {
    print_color "$BLUE" "=== Creating Configuration Files ==="
    
    # Create servers.conf from example if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        local example_file="${CONFIG_FILE}.example"
        if [[ -f "$example_file" ]]; then
            cp "$example_file" "$CONFIG_FILE"
            print_color "$GREEN" "✓ Created servers.conf from example"
        else
            print_color "$YELLOW" "Creating default servers.conf..."
            create_default_config
        fi
    else
        print_color "$YELLOW" "  Configuration exists: $CONFIG_FILE"
    fi
}

# Create default configuration
create_default_config() {
    cat > "$CONFIG_FILE" << EOF
# AWStats Servers Configuration
# File: etc/servers.conf
# Version: 2.0.1
# Purpose: Domain and server definitions with hierarchical configuration

[global]
database_file=$DB_FILE
htdocs_dir=$HTDOCS_DIR
logs_dir=$LOGS_DIR
awstats_bin=/usr/local/awstats/wwwroot/cgi-bin/awstats.pl
log_format=4
top_apis_count=25
enabled=yes
archive_processed_logs=yes
compress_archived_logs=yes

[sbil-api.bos.njtransit.com]
display_name=SBIL API - Boston NJ Transit
environment=production
enabled=yes
servers=pnjt1sweb1,pnjt1sweb2

[pnjt1sweb1]
server_display_name=Production Web Server 1
log_directory=$LOGS_DIR/pnjt1sweb1
log_file_pattern=access-*.log
enabled=yes

[pnjt1sweb2]
server_display_name=Production Web Server 2
log_directory=$LOGS_DIR/pnjt1sweb2
log_file_pattern=access-*.log
enabled=yes
EOF
    print_color "$GREEN" "✓ Created default configuration: $CONFIG_FILE"
}

# Create log directories with processed subdirectories
create_log_structure() {
    print_color "$BLUE" "=== Setting Up Log Structure ==="
    
    local server_dirs=("pnjt1sweb1" "pnjt1sweb2")
    
    for server in "${server_dirs[@]}"; do
        local server_dir="$LOGS_DIR/$server"
        local processed_dir="$server_dir/processed"
        
        mkdir -p "$processed_dir"
        
        # Create .gitkeep files to preserve directory structure in git
        touch "$processed_dir/.gitkeep"
        
        print_color "$GREEN" "✓ Created log structure: $server_dir"
    done
    
    # Create main logs .gitkeep
    touch "$LOGS_DIR/.gitkeep"
}

# Verify installation
verify_installation() {
    print_color "$BLUE" "=== Verifying Installation ==="
    
    local errors=0
    
    # Check directories
    local required_dirs=("$BASE_DIR/bin" "$BASE_DIR/etc" "$BASE_DIR/database" "$HTDOCS_DIR")
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
        local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
        if [[ "$table_count" -gt 0 ]]; then
            print_color "$GREEN" "✓ Database tables: $table_count"
        else
            print_color "$RED" "❌ Database has no tables"
            ((errors++))
        fi
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
    echo "2. Test the web interface:"
    echo "   cd $HTDOCS_DIR"
    echo "   php -S localhost:8080"
    echo "   Open: http://localhost:8080"
    echo ""
    echo "3. Validate configuration:"
    echo "   ./bin/config_parser.sh validate"
    echo ""
    echo "4. Add your log files to:"
    echo "   $LOGS_DIR/[server_name]/"
    echo ""
    print_color "$GREEN" "🚀 System ready for Phase 2 (Data Processing)!"
}

# Usage information
usage() {
    echo "AWStats System Initialization v$VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --force          Force recreation of existing database"
    echo "  --config FILE    Use custom configuration file"
    echo "  --help           Show this help message"
    echo ""
    echo "This script will:"
    echo "  • Create directory structure"
    echo "  • Initialize SQLite database"
    echo "  • Create configuration files"
    echo "  • Set up log processing structure"
    echo "  • Verify installation"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_RECREATE=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
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
    echo ""
    
    log_message "Starting initialization process..."
    
    # Execute initialization steps
    load_configuration
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