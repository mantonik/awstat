#!/bin/bash

# Configuration Parser with Hierarchy Support
# File: bin/config_parser.sh
# Version: 1.2.7
# Purpose: Parse configuration with global → domain → server hierarchy
# Changes: v1.2.7 - FIXED variable expansion issues throughout validation
#                    Now properly expands ${BASE_DIR}, ${HOME}, $LOGS_DIR variables
#                    Uses load_config.sh for consistent variable handling
#                    Shows actual expanded paths instead of literals

VERSION="1.2.7"

# Load configuration system to get proper variable expansion
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${CONFIG_FILE:-$BASE_DIR/etc/servers.conf}"

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

# Load configuration to get properly expanded variables
load_configuration_system() {
    # Load configuration system if available
    if [[ -f "$SCRIPT_DIR/load_config.sh" ]]; then
        source "$SCRIPT_DIR/load_config.sh" 2>/dev/null || true
    fi
}

# Function to expand variables in a config value
expand_config_variables() {
    local value="$1"
    
    # Make sure BASE_DIR and other variables are available
    if [[ -z "$BASE_DIR" ]]; then
        BASE_DIR="$(dirname "$SCRIPT_DIR")"
    fi
    
    # Expand all possible variable formats
    value="${value//\$\{HOME\}/$HOME}"
    value="${value//\$HOME/$HOME}"
    value="${value//\$\{BASE_DIR\}/$BASE_DIR}"
    value="${value//\$BASE_DIR/$BASE_DIR}"
    
    # If LOGS_DIR is available, expand it too
    if [[ -n "$LOGS_DIR" ]]; then
        value="${value//\$\{LOGS_DIR\}/$LOGS_DIR}"
        value="${value//\$LOGS_DIR/$LOGS_DIR}"
    fi
    
    echo "$value"
}

# Function to get configuration value with hierarchy and variable expansion
get_config_value() {
    local key="$1"
    local server_name="$2"
    local domain_name="$3"
    local config_file="${CONFIG_FILE}"
    
    local value=""
    
    # First, try to get server-specific value (highest priority)
    if [[ -n "$server_name" ]]; then
        value=$(get_section_value "$config_file" "$server_name" "$key")
        if [[ -n "$value" ]]; then
            echo "$(expand_config_variables "$value")"
            return 0
        fi
    fi
    
    # Second, try to get domain-specific value (medium priority)
    if [[ -n "$domain_name" ]]; then
        value=$(get_section_value "$config_file" "$domain_name" "$key")
        if [[ -n "$value" ]]; then
            echo "$(expand_config_variables "$value")"
            return 0
        fi
    fi
    
    # Finally, get global value (default/fallback)
    value=$(get_section_value "$config_file" "global" "$key")
    if [[ -n "$value" ]]; then
        echo "$(expand_config_variables "$value")"
    fi
}

# Function to get value from specific section
get_section_value() {
    local config_file="$1"
    local section="$2"
    local key="$3"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    local in_section=false
    local value=""
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            local current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi
        
        # Parse key=value in target section
        if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=]+)=[[:space:]]*(.*)$ ]]; then
            local config_key="${BASH_REMATCH[1]// /}"
            local config_value="${BASH_REMATCH[2]}"
            
            if [[ "$config_key" == "$key" ]]; then
                echo "$config_value"
                return 0
            fi
        fi
    done < "$config_file"
    
    return 1
}

# Function to get all sections from config file
get_all_sections() {
    local config_file="${CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    grep '^\[.*\]$' "$config_file" | sed 's/^\[\(.*\)\]$/\1/' | grep -v '^global$'
}

# Function to get servers for a domain
get_domain_servers() {
    local domain="$1"
    local servers_string=$(get_section_value "$CONFIG_FILE" "$domain" "servers")
    
    if [[ -n "$servers_string" ]]; then
        echo "$servers_string" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    fi
}

# Function to check if a section exists
section_exists() {
    local section="$1"
    local config_file="${CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    grep -q "^\[$section\]$" "$config_file"
}

# Function to get all keys in a section
get_section_keys() {
    local section="$1"
    local config_file="${CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    local in_section=false
    local keys=()
    
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            local current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi
        
        if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=]+)=[[:space:]]*(.*)$ ]]; then
            local config_key="${BASH_REMATCH[1]// /}"
            keys+=("$config_key")
        fi
    done < "$config_file"
    
    printf '%s\n' "${keys[@]}" | sort -u
}

# Function to get all effective configuration for a server
get_server_config() {
    local server_name="$1"
    local domain_name="$2"
    
    # Define all possible configuration keys
    local config_keys=(
        "database_file"
        "htdocs_dir"
        "logs_dir"
        "awstats_bin"
        "log_format"
        "skip_hosts" 
        "skip_files"
        "log_directory"
        "log_file_pattern"
        "enabled"
        "server_type"
        "server_display_name"
        "site_domain"
        "retention_days"
        "max_concurrent_processes"
        "archive_processed_logs"
        "compress_archived_logs"
        "top_apis_count"
        "environment"
        "display_name"
    )
    
    echo "# Effective Configuration for Server: $server_name"
    if [[ -n "$domain_name" ]]; then
        echo "# Domain: $domain_name"
    fi
    echo "# Resolved using hierarchy: server → domain → global"
    echo "# Generated by: config_parser.sh v$VERSION"
    echo "# Date: $(date)"
    echo ""
    
    for key in "${config_keys[@]}"; do
        local value
        value=$(get_config_value "$key" "$server_name" "$domain_name")
        if [[ -n "$value" ]]; then
            # Show source of value
            local source=""
            if [[ -n "$(get_section_value "$CONFIG_FILE" "$server_name" "$key")" ]]; then
                source="[server]"
            elif [[ -n "$domain_name" && -n "$(get_section_value "$CONFIG_FILE" "$domain_name" "$key")" ]]; then
                source="[domain]"
            else
                source="[global]"
            fi
            
            printf "%-25s = %-30s # %s\n" "$key" "$value" "$source"
        fi
    done
}

# Function to validate configuration file
validate_config() {
    local config_file="${CONFIG_FILE}"
    local errors=0
    local warnings=0
    
    print_color "$BLUE" "🔍 Validating configuration file: $config_file"
    echo ""
    
    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
        print_color "$RED" "❌ Configuration file not found: $config_file"
        return 1
    fi
    
    # Check file permissions
    if [[ ! -r "$config_file" ]]; then
        print_color "$RED" "❌ Configuration file not readable: $config_file"
        ((errors++))
    fi
    
    # Check for global section
    if ! section_exists "global"; then
        print_color "$RED" "❌ Missing [global] section"
        ((errors++))
    else
        print_color "$GREEN" "✅ [global] section found"
    fi
    
    # Validate global settings with FIXED variable expansion
    local required_global_keys=("database_file" "logs_dir" "awstats_bin")
    for key in "${required_global_keys[@]}"; do
        local value=$(get_section_value "$config_file" "global" "$key")
        if [[ -z "$value" ]]; then
            print_color "$RED" "❌ Missing required global setting: $key"
            ((errors++))
        else
            # FIXED: Use our expand function instead of simple substitution
            local expanded_value=$(expand_config_variables "$value")
            print_color "$GREEN" "✅ Global $key: $expanded_value"
            
            if [[ "$key" =~ (file|dir|bin)$ ]]; then
                if [[ "$key" == *"file" || "$key" == *"bin" ]]; then
                    # Check if parent directory exists for files and binaries
                    local parent_dir=$(dirname "$expanded_value")
                    if [[ ! -d "$parent_dir" ]]; then
                        print_color "$YELLOW" "⚠️  Parent directory doesn't exist for $key: $parent_dir"
                        ((warnings++))
                    fi
                elif [[ "$key" == *"dir" ]]; then
                    # Check if directory exists
                    if [[ ! -d "$expanded_value" ]]; then
                        print_color "$YELLOW" "⚠️  Directory doesn't exist for $key: $expanded_value"
                        ((warnings++))
                    fi
                fi
            fi
        fi
    done
    
    # Get all domains
    local domains=()
    while IFS= read -r section; do
        if [[ "$section" != "global" ]]; then
            local servers=$(get_section_value "$config_file" "$section" "servers")
            if [[ -n "$servers" ]]; then
                domains+=("$section")
            fi
        fi
    done < <(get_all_sections)
    
    if [[ ${#domains[@]} -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  No domains configured"
        ((warnings++))
    else
        print_color "$GREEN" "✅ Found ${#domains[@]} domain(s): $(IFS=', '; echo "${domains[*]}")"
        
        # Validate each domain
        for domain in "${domains[@]}"; do
            print_color "$CYAN" "🌐 Validating domain: $domain"
            
            local enabled=$(get_config_value "enabled" "" "$domain")
            local display_name=$(get_config_value "display_name" "" "$domain")
            local servers=$(get_config_value "servers" "" "$domain")
            
            if [[ -n "$servers" ]]; then
                print_color "$GREEN" "  ✅ Servers: $servers"
                
                # Validate each server
                IFS=',' read -ra server_list <<< "$servers"
                for server in "${server_list[@]}"; do
                    server=$(echo "$server" | xargs)
                    print_color "$CYAN" "    🖥️  Validating server: $server"
                    
                    if ! section_exists "$server"; then
                        print_color "$RED" "    ❌ Server section [$server] not found"
                        ((errors++))
                        continue
                    fi
                    
                    # Check server settings with FIXED variable expansion
                    local server_enabled=$(get_config_value "enabled" "$server" "$domain")
                    local log_directory=$(get_config_value "log_directory" "$server" "$domain")
                    
                    if [[ "$server_enabled" != "yes" ]]; then
                        print_color "$YELLOW" "    ⚠️  Server '$server' is not enabled"
                        ((warnings++))
                    fi
                    
                    if [[ -z "$log_directory" ]]; then
                        print_color "$RED" "    ❌ Server '$server' missing log_directory"
                        ((errors++))
                    else
                        # FIXED: Use our expand function for proper variable expansion
                        local expanded_log_dir=$(expand_config_variables "$log_directory")
                        
                        if [[ ! -d "$expanded_log_dir" ]]; then
                            print_color "$YELLOW" "    ⚠️  Log directory doesn't exist: $expanded_log_dir"
                            ((warnings++))
                        else
                            print_color "$GREEN" "    ✅ Log directory: $expanded_log_dir"
                        fi
                    fi
                done
            fi
            
            if [[ -z "$display_name" ]]; then
                print_color "$YELLOW" "  ⚠️  Domain '$domain' missing display_name"
                ((warnings++))
            else
                print_color "$GREEN" "  ✅ Display name: $display_name"
            fi
        done
    fi
    
    # Check for orphaned server sections
    echo ""
    print_color "$CYAN" "🔍 Checking for orphaned server sections..."
    
    local all_sections=()
    while IFS= read -r section; do
        all_sections+=("$section")
    done < <(get_all_sections)
    
    local referenced_servers=()
    for domain in "${domains[@]}"; do
        local domain_servers=$(get_config_value "servers" "" "$domain")
        if [[ -n "$domain_servers" ]]; then
            IFS=',' read -ra server_list <<< "$domain_servers"
            for server in "${server_list[@]}"; do
                server=$(echo "$server" | xargs)
                referenced_servers+=("$server")
            done
        fi
    done
    
    for section in "${all_sections[@]}"; do
        # Skip domains and global
        local is_domain=false
        for domain in "${domains[@]}"; do
            if [[ "$section" == "$domain" ]]; then
                is_domain=true
                break
            fi
        done
        
        if [[ "$is_domain" == false ]]; then
            # Check if this server is referenced by any domain
            local is_referenced=false
            for referenced_server in "${referenced_servers[@]}"; do
                if [[ "$section" == "$referenced_server" ]]; then
                    is_referenced=true
                    break
                fi
            done
            
            if [[ "$is_referenced" == false ]]; then
                print_color "$YELLOW" "⚠️  Orphaned server section: [$section] (not referenced by any domain)"
                ((warnings++))
            fi
        fi
    done
    
    # Summary
    echo ""
    print_color "$BLUE" "📊 Validation Summary:"
    
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        print_color "$GREEN" "✅ Configuration is valid - no issues found!"
        return 0
    elif [[ $errors -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  Configuration is valid with $warnings warning(s)"
        return 0
    else
        print_color "$RED" "❌ Configuration has $errors error(s) and $warnings warning(s)"
        return 1
    fi
}

# Function to show configuration overview
show_config_overview() {
    local config_file="${CONFIG_FILE}"
    
    print_color "$BLUE" "📋 Configuration Overview: $config_file"
    echo ""
    
    if [[ ! -f "$config_file" ]]; then
        print_color "$RED" "❌ Configuration file not found"
        return 1
    fi
    
    # Global settings with FIXED variable expansion
    print_color "$CYAN" "🌍 Global Settings:"
    local global_keys=($(get_section_keys "global"))
    for key in "${global_keys[@]}"; do
        local value=$(get_section_value "$config_file" "global" "$key")
        local expanded_value=$(expand_config_variables "$value")
        printf "  %-20s = %s\n" "$key" "$expanded_value"
    done
    
    echo ""
    
    # Domains and servers
    print_color "$CYAN" "🌐 Domains and Servers:"
    
    local domains=()
    while IFS= read -r section; do
        if [[ "$section" != "global" ]]; then
            local servers=$(get_section_value "$config_file" "$section" "servers")
            if [[ -n "$servers" ]]; then
                domains+=("$section")
            fi
        fi
    done < <(get_all_sections)
    
    for domain in "${domains[@]}"; do
        local display_name=$(get_config_value "display_name" "" "$domain")
        local enabled=$(get_config_value "enabled" "" "$domain")
        local servers=$(get_config_value "servers" "" "$domain")
        
        print_color "$GREEN" "  📡 $domain"
        echo "    Display Name: $display_name"
        echo "    Enabled: $enabled"
        echo "    Servers: $servers"
        
        # Show server details with FIXED variable expansion
        if [[ -n "$servers" ]]; then
            IFS=',' read -ra server_list <<< "$servers"
            for server in "${server_list[@]}"; do
                server=$(echo "$server" | xargs)
                local server_display=$(get_config_value "server_display_name" "$server" "$domain")
                local server_enabled=$(get_config_value "enabled" "$server" "$domain")
                local log_dir=$(get_config_value "log_directory" "$server" "$domain")
                
                echo "     🖥️  $server: $server_display (enabled: $server_enabled)"
                echo "        Log Dir: $log_dir"
            done
        fi
        echo ""
    done
}

# Function to test configuration for specific server
test_server_config() {
    local server_name="$1"
    local domain_name="$2"
    
    if [[ -z "$server_name" ]]; then
        print_color "$RED" "❌ Server name required"
        return 1
    fi
    
    print_color "$BLUE" "🧪 Testing configuration for server: $server_name"
    if [[ -n "$domain_name" ]]; then
        print_color "$BLUE" "Domain: $domain_name"
    fi
    echo ""
    
    # Show effective configuration
    get_server_config "$server_name" "$domain_name"
    
    echo ""
    print_color "$CYAN" "🔍 Configuration Tests:"
    
    # Test log directory with FIXED variable expansion
    local log_directory=$(get_config_value "log_directory" "$server_name" "$domain_name")
    if [[ -n "$log_directory" ]]; then
        if [[ -d "$log_directory" ]]; then
            print_color "$GREEN" "✅ Log directory exists: $log_directory"
            
            # Check for log files
            local log_pattern=$(get_config_value "log_file_pattern" "$server_name" "$domain_name")
            log_pattern="${log_pattern:-access-*.log}"
            
            local log_files=$(find "$log_directory" -name "$log_pattern" 2>/dev/null | wc -l)
            if [[ $log_files -gt 0 ]]; then
                print_color "$GREEN" "✅ Found $log_files log files matching pattern: $log_pattern"
            else
                print_color "$YELLOW" "⚠️  No log files found matching pattern: $log_pattern"
            fi
        else
            print_color "$RED" "❌ Log directory not found: $log_directory"
        fi
    else
        print_color "$RED" "❌ No log directory configured"
    fi
    
    # Test AWStats binary
    local awstats_bin=$(get_config_value "awstats_bin" "$server_name" "$domain_name")
    if [[ -n "$awstats_bin" ]]; then
        if command -v "$awstats_bin" >/dev/null 2>&1; then
            print_color "$GREEN" "✅ AWStats binary found: $awstats_bin"
        else
            print_color "$RED" "❌ AWStats binary not found: $awstats_bin"
        fi
    else
        print_color "$RED" "❌ No AWStats binary configured"
    fi
    
    # Test database file
    local database_file=$(get_config_value "database_file" "$server_name" "$domain_name")
    if [[ -n "$database_file" ]]; then
        if [[ -f "$database_file" ]]; then
            print_color "$GREEN" "✅ Database file exists: $database_file"
        else
            print_color "$YELLOW" "⚠️  Database file not found: $database_file"
        fi
    else
        print_color "$RED" "❌ No database file configured"
    fi
}

# Function to show usage
usage() {
    echo "Configuration Parser v$VERSION"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  get KEY [SERVER] [DOMAIN]     Get configuration value with hierarchy"
    echo "  test SERVER [DOMAIN]          Test configuration for specific server"
    echo "  validate                      Validate entire configuration file"
    echo "  overview                      Show configuration overview"
    echo "  servers DOMAIN                List servers for a domain"
    echo "  sections                      List all configuration sections"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 get database_file"
    echo "  $0 get log_directory web1 example.com"
    echo "  $0 test web1 example.com"
    echo "  $0 validate"
    echo "  $0 overview"
    echo ""
}

# Load configuration system first
load_configuration_system

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "get")
            get_config_value "$2" "$3" "$4"
            ;;
        "test")
            test_server_config "$2" "$3"
            ;;
        "validate")
            validate_config
            ;;
        "overview")
            show_config_overview
            ;;
        "servers")
            get_domain_servers "$2"
            ;;
        "sections")
            get_all_sections
            ;;
        "help"|*)
            usage
            ;;
    esac
fi