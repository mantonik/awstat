#!/bin/bash

# Configuration Parser with Hierarchy Support
# File: bin/config_parser.sh
# Version: 2.0.1
# Purpose: Parse configuration with global → domain → server hierarchy
# Changes: v2.0.1 - Added hierarchical configuration resolution

VERSION="2.0.1"

# Get the base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${CONFIG_FILE:-$BASE_DIR/etc/servers.conf}"

# Function to get configuration value with hierarchy
# Usage: get_config_value "key" "server_name" "domain_name"
# Returns value from server-specific → domain-specific → global (in that priority order)
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
            echo "$value"
            return 0
        fi
    fi
    
    # Second, try to get domain-specific value (medium priority)
    if [[ -n "$domain_name" ]]; then
        value=$(get_section_value "$config_file" "$domain_name" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    # Finally, get global value (default/fallback)
    value=$(get_section_value "$config_file" "global" "$key")
    echo "$value"
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

# Function to get all effective configuration for a server
get_server_config() {
    local server_name="$1"
    local domain_name="$2"
    
    # Define all possible configuration keys
    local config_keys=(
        "log_format"
        "skip_hosts" 
        "skip_files"
        "awstats_bin"
        "log_directory"
        "log_file_pattern"
        "enabled"
        "server_type"
        "retention_days"
        "max_concurrent_processes"
        "archive_processed_logs"
        "compress_archived_logs"
    )
    
    echo "# Effective Configuration for Server: $server_name (Domain: $domain_name)"
    echo "# Resolved using hierarchy: server → domain → global"
    echo ""
    
    for key in "${config_keys[@]}"; do
        local value
        value=$(get_config_value "$key" "$server_name" "$domain_name")
        if [[ -n "$value" ]]; then
            printf "%-25s = %s\n" "$key" "$value"
        fi