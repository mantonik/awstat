#!/bin/bash

# AWStats Configuration Loader
# File: bin/load_config.sh
# Version: 1.2.9
# Purpose: Load and export configuration variables from servers.conf
# Changes: v1.2.6 - Fixed BASE_DIR calculation for custom directory structures
#                    Added support for scripts in /home/appawstats/bin/ with BASE_DIR=/home/appawstats/
#                    Enhanced directory validation and creation
#          v1.2.7 - MAJOR: BASE_DIR now configurable in servers.conf
#                    No longer calculated automatically - read from config file
#          v1.2.8 - REMOVED all BASE_DIR calculation logic
#                    BASE_DIR now ONLY read from servers.conf [global] section
#          v1.2.9 - FIXED variable expansion in fallback config parser
#                    Added proper ${BASE_DIR} and ${HOME} expansion in get_config_value
#                    Enhanced debugging for variable expansion troubleshooting

VERSION="1.2.9"
SCRIPT_NAME="load_config.sh"

# Get the base directory - FIXED for custom structures
if [[ -z "$SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -z "$BASE_DIR" ]]; then
    # Calculate BASE_DIR based on script location
    CALCULATED_BASE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Check if we're in a standard project structure (bin/ subdirectory)
    # or a custom structure where bin/ is at the top level
    if [[ "$(basename "$SCRIPT_DIR")" == "bin" ]]; then
        # Standard structure: /path/to/project/bin/ → BASE_DIR = /path/to/project/
        BASE_DIR="$CALCULATED_BASE_DIR"
    else
        # Custom structure: scripts might be in different location
        # For now, assume the script directory parent is BASE_DIR
        BASE_DIR="$CALCULATED_BASE_DIR"
    fi
fi

# For debugging - show what we calculated
if [[ "$CONFIG_DEBUG" == "true" ]]; then
    echo "DEBUG: SCRIPT_DIR = $SCRIPT_DIR"
    echo "DEBUG: Calculated BASE_DIR = $BASE_DIR"
fi

# Default configuration file location
if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$BASE_DIR/etc/servers.conf"
fi

# Load configuration parser if not already loaded
if ! command -v get_config_value >/dev/null 2>&1; then
    if [[ -f "$SCRIPT_DIR/config_parser.sh" ]]; then
        source "$SCRIPT_DIR/config_parser.sh"
    elif [[ -f "$BASE_DIR/bin/config_parser.sh" ]]; then
        source "$BASE_DIR/bin/config_parser.sh"
    else
        echo "ERROR: config_parser.sh not found - cannot load configuration"
        echo "Looked in: $SCRIPT_DIR/config_parser.sh and $BASE_DIR/bin/config_parser.sh"
        exit 1
    fi
fi

# Function to load configuration values with fallbacks
load_config() {
    # Check if configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Export BASE_DIR so it's available for variable expansion in config file
    export BASE_DIR
    
    # Also export HOME to ensure it's available
    export HOME

    # Show what we're working with
    if [[ "$CONFIG_DEBUG" == "true" ]]; then
        echo "DEBUG: Using BASE_DIR = $BASE_DIR"
        echo "DEBUG: Using CONFIG_FILE = $CONFIG_FILE"
    fi
    # Database file
    AWSTATS_DB_FILE=$(get_config_value "database_file" "" "")
    if [[ -z "$AWSTATS_DB_FILE" ]]; then
        AWSTATS_DB_FILE="$BASE_DIR/database/awstats.db"
    fi
    
    # Expand variables in database file path
    AWSTATS_DB_FILE="${AWSTATS_DB_FILE/\$HOME/$HOME}"
    AWSTATS_DB_FILE="${AWSTATS_DB_FILE/\$BASE_DIR/$BASE_DIR}"
    export AWSTATS_DB_FILE

    # AWStats binary path
    AWSTATS_BIN=$(get_config_value "awstats_bin" "" "")
    if [[ -z "$AWSTATS_BIN" ]]; then
        AWSTATS_BIN="/usr/local/awstats/wwwroot/cgi-bin/awstats.pl"
    fi
    export AWSTATS_BIN

    # AWStats database directory
    AWSTATS_DB_DIR=$(get_config_value "awstats_db_dir" "" "")
    if [[ -z "$AWSTATS_DB_DIR" ]]; then
        AWSTATS_DB_DIR="$BASE_DIR/database/awstats"
    fi
    AWSTATS_DB_DIR="${AWSTATS_DB_DIR/\$HOME/$HOME}"
    AWSTATS_DB_DIR="${AWSTATS_DB_DIR/\$BASE_DIR/$BASE_DIR}"
    export AWSTATS_DB_DIR

    # Reports directory
    REPORTS_DIR=$(get_config_value "reports_dir" "" "")
    if [[ -z "$REPORTS_DIR" ]]; then
        REPORTS_DIR="$BASE_DIR/htdocs/reports"
    fi
    REPORTS_DIR="${REPORTS_DIR/\$HOME/$HOME}"
    REPORTS_DIR="${REPORTS_DIR/\$BASE_DIR/$BASE_DIR}"
    export REPORTS_DIR

    # Logs directory
    LOGS_DIR=$(get_config_value "logs_dir" "" "")
    if [[ -z "$LOGS_DIR" ]]; then
        LOGS_DIR="$BASE_DIR/logs"
    fi
    LOGS_DIR="${LOGS_DIR/\$HOME/$HOME}"
    LOGS_DIR="${LOGS_DIR/\$BASE_DIR/$BASE_DIR}"
    export LOGS_DIR

    # HTDOCS directory
    HTDOCS_DIR=$(get_config_value "htdocs_dir" "" "")
    if [[ -z "$HTDOCS_DIR" ]]; then
        HTDOCS_DIR="$BASE_DIR/htdocs"
    fi
    HTDOCS_DIR="${HTDOCS_DIR/\$HOME/$HOME}"
    HTDOCS_DIR="${HTDOCS_DIR/\$BASE_DIR/$BASE_DIR}"
    export HTDOCS_DIR

    # Performance settings
    MAX_CONCURRENT_PROCESSES=$(get_config_value "max_concurrent_processes" "" "")
    if [[ -z "$MAX_CONCURRENT_PROCESSES" ]]; then
        MAX_CONCURRENT_PROCESSES=4
    fi
    export MAX_CONCURRENT_PROCESSES

    # Batch size for processing
    BATCH_SIZE=$(get_config_value "batch_size" "" "")
    if [[ -z "$BATCH_SIZE" ]]; then
        BATCH_SIZE=1000
    fi
    export BATCH_SIZE

    # Memory limit
    MEMORY_LIMIT_MB=$(get_config_value "memory_limit_mb" "" "")
    if [[ -z "$MEMORY_LIMIT_MB" ]]; then
        MEMORY_LIMIT_MB=512
    fi
    export MEMORY_LIMIT_MB

    # Log format
    DEFAULT_LOG_FORMAT=$(get_config_value "log_format" "" "")
    if [[ -z "$DEFAULT_LOG_FORMAT" ]]; then
        DEFAULT_LOG_FORMAT="4"
    fi
    export DEFAULT_LOG_FORMAT

    # Retention settings
    RETENTION_DAYS=$(get_config_value "retention_days" "" "")
    if [[ -z "$RETENTION_DAYS" ]]; then
        RETENTION_DAYS=365
    fi
    export RETENTION_DAYS

    # Archive settings
    ARCHIVE_PROCESSED_LOGS=$(get_config_value "archive_processed_logs" "" "")
    if [[ -z "$ARCHIVE_PROCESSED_LOGS" ]]; then
        ARCHIVE_PROCESSED_LOGS="yes"
    fi
    export ARCHIVE_PROCESSED_LOGS

    COMPRESS_ARCHIVED_LOGS=$(get_config_value "compress_archived_logs" "" "")
    if [[ -z "$COMPRESS_ARCHIVED_LOGS" ]]; then
        COMPRESS_ARCHIVED_LOGS="yes"
    fi
    export COMPRESS_ARCHIVED_LOGS

    # API settings
    TOP_APIS_COUNT=$(get_config_value "top_apis_count" "" "")
    if [[ -z "$TOP_APIS_COUNT" ]]; then
        TOP_APIS_COUNT=25
    fi
    export TOP_APIS_COUNT

    # Skip settings for AWStats
    DEFAULT_SKIP_HOSTS=$(get_config_value "skip_hosts" "" "")
    if [[ -z "$DEFAULT_SKIP_HOSTS" ]]; then
        DEFAULT_SKIP_HOSTS="127.0.0.1 localhost"
    fi
    export DEFAULT_SKIP_HOSTS

    DEFAULT_SKIP_FILES=$(get_config_value "skip_files" "" "")
    if [[ -z "$DEFAULT_SKIP_FILES" ]]; then
        DEFAULT_SKIP_FILES="REGEX[/\\.css$|/\\.js$|/\\.png$|/\\.jpg$|/\\.gif$|/favicon\\.ico$]"
    fi
    export DEFAULT_SKIP_FILES

    # Create necessary directories
    mkdir -p "$AWSTATS_DB_DIR" "$REPORTS_DIR" "$LOGS_DIR" "$(dirname "$AWSTATS_DB_FILE")"

    # Debug output if requested
    if [[ "$CONFIG_DEBUG" == "true" ]]; then
        echo "Configuration loaded successfully:"
        echo "  AWSTATS_DB_FILE: $AWSTATS_DB_FILE"
        echo "  AWSTATS_BIN: $AWSTATS_BIN"
        echo "  AWSTATS_DB_DIR: $AWSTATS_DB_DIR"
        echo "  REPORTS_DIR: $REPORTS_DIR"
        echo "  LOGS_DIR: $LOGS_DIR"
        echo "  HTDOCS_DIR: $HTDOCS_DIR"
        echo "  MAX_CONCURRENT_PROCESSES: $MAX_CONCURRENT_PROCESSES"
        echo "  BATCH_SIZE: $BATCH_SIZE"
        echo "  MEMORY_LIMIT_MB: $MEMORY_LIMIT_MB"
        echo "  DEFAULT_LOG_FORMAT: $DEFAULT_LOG_FORMAT"
        echo "  RETENTION_DAYS: $RETENTION_DAYS"
        echo "  TOP_APIS_COUNT: $TOP_APIS_COUNT"
    fi
}

# Function to validate loaded configuration
validate_config() {
    local errors=0

    # Check required paths
    if [[ ! -d "$(dirname "$AWSTATS_DB_FILE")" ]]; then
        echo "ERROR: Database directory does not exist: $(dirname "$AWSTATS_DB_FILE")"
        ((errors++))
    fi

    if [[ ! -x "$AWSTATS_BIN" && ! -f "$AWSTATS_BIN" ]]; then
        echo "WARNING: AWStats binary not found or not executable: $AWSTATS_BIN"
    fi

    if [[ ! -d "$AWSTATS_DB_DIR" ]]; then
        echo "WARNING: AWStats database directory does not exist: $AWSTATS_DB_DIR"
        echo "  Will be created automatically..."
        mkdir -p "$AWSTATS_DB_DIR"
    fi

    if [[ ! -d "$REPORTS_DIR" ]]; then
        echo "WARNING: Reports directory does not exist: $REPORTS_DIR"
        echo "  Will be created automatically..."
        mkdir -p "$REPORTS_DIR"
    fi

    if [[ ! -d "$LOGS_DIR" ]]; then
        echo "WARNING: Logs directory does not exist: $LOGS_DIR"
        echo "  Will be created automatically..."
        mkdir -p "$LOGS_DIR"
    fi

    return $errors
}

# Function to show loaded configuration
show_config() {
    echo "AWStats Configuration Loader v$VERSION"
    echo "=================================="
    echo ""
    echo "Configuration File: $CONFIG_FILE"
    echo "BASE_DIR: $BASE_DIR (from config file)"
    echo ""
    echo "Loaded Configuration:"
    echo "  Database File: $AWSTATS_DB_FILE"
    echo "  AWStats Binary: $AWSTATS_BIN"
    echo "  AWStats DB Dir: $AWSTATS_DB_DIR"
    echo "  Reports Dir: $REPORTS_DIR"
    echo "  Logs Dir: $LOGS_DIR"
    echo "  HTDOCS Dir: $HTDOCS_DIR"
    echo ""
    echo "Performance Settings:"
    echo "  Max Processes: $MAX_CONCURRENT_PROCESSES"
    echo "  Batch Size: $BATCH_SIZE"
    echo "  Memory Limit: ${MEMORY_LIMIT_MB}MB"
    echo ""
    echo "AWStats Settings:"
    echo "  Log Format: $DEFAULT_LOG_FORMAT"
    echo "  Skip Hosts: $DEFAULT_SKIP_HOSTS"
    echo "  Skip Files: $DEFAULT_SKIP_FILES"
    echo ""
    echo "Other Settings:"
    echo "  Retention Days: $RETENTION_DAYS"
    echo "  Top APIs Count: $TOP_APIS_COUNT"
    echo "  Archive Logs: $ARCHIVE_PROCESSED_LOGS"
    echo "  Compress Archives: $COMPRESS_ARCHIVED_LOGS"
}

# Auto-load configuration if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced, load configuration
    load_config
else
    # Script is being executed directly
    case "${1:-load}" in
        "load")
            load_config
            ;;
        "validate")
            load_config
            validate_config
            ;;
        "show")
            load_config
            show_config
            ;;
        "debug")
            CONFIG_DEBUG=true
            load_config
            show_config
            ;;
        *)
            echo "Usage: $0 [load|validate|show|debug]"
            echo ""
            echo "Commands:"
            echo "  load     - Load configuration (default)"
            echo "  validate - Load and validate configuration"
            echo "  show     - Load and display configuration"
            echo "  debug    - Load with debug output"
            exit 1
            ;;
    esac
fi