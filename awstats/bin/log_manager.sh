#!/bin/bash

# AWStats Log Manager
# File: bin/log_manager.sh
# Version: 2.1.0
# Purpose: Manage log files - rotation, archiving, compression, cleanup
# Changes: v2.1.0 - Initial log management implementation

VERSION="2.1.0"
SCRIPT_NAME="log_manager.sh"

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

# Configuration
CONFIG_FILE="$BASE_DIR/etc/servers.conf"
ARCHIVE_BASE_DIR="$BASE_DIR/logs/archive"

# Load configuration parser
source "$SCRIPT_DIR/config_parser.sh" 2>/dev/null || {
    print_color "$RED" "❌ Error: config_parser.sh not found"
    exit 1
}

# Default settings
DEFAULT_RETENTION_DAYS=365
DEFAULT_COMPRESS_AFTER_DAYS=7
ALLOWED_EXTENSIONS=("log" "txt" "access" "error" "combined")

# Function to create archive structure
create_archive_structure() {
    local domain="$1"
    local server="$2"
    
    local archive_dir="$ARCHIVE_BASE_DIR/$domain/$server"
    local yearly_dirs=()
    
    # Create base archive directory
    mkdir -p "$archive_dir"
    
    # Create yearly directories for the last 3 years
    for i in {0..2}; do
        local year=$(date -d "$current_date -$i year" +%Y 2>/dev/null || date -d "$(date +%Y-01-01) -$i year" +%Y)
        yearly_dirs+=("$archive_dir/$year")
        mkdir -p "$archive_dir/$year"
        
        # Create monthly directories
        for month in {01..12}; do
            mkdir -p "$archive_dir/$year/$month"
        done
    done
    
    print_color "$GREEN" "✅ Created archive structure for $domain-$server"
    return 0
}

# Function to compress old log files
compress_log_files() {
    local log_directory="$1"
    local compress_after_days="$2"
    local dry_run="$3"
    
    print_color "$CYAN" "🗜️  Compressing log files older than $compress_after_days days in: $log_directory"
    
    if [[ ! -d "$log_directory" ]]; then
        print_color "$RED" "❌ Log directory not found: $log_directory"
        return 1
    fi
    
    local compressed_count=0
    local total_saved=0
    
    # Find uncompressed log files older than specified days
    local old_files=$(find "$log_directory" -type f -name "*.log" -o -name "*.txt" -o -name "*access*" -o -name "*error*" | \
                     grep -v "\.gz$" | grep -v "\.bz2$" | \
                     xargs -I {} stat -c "%Y %n" {} 2>/dev/null | \
                     awk -v cutoff="$(($(date +%s) - compress_after_days * 86400))" '$1 < cutoff {print $2}')
    
    if [[ -z "$old_files" ]]; then
        print_color "$YELLOW" "  ℹ️  No files found to compress"
        return 0
    fi
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local original_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            local file_age_days=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || echo 0)) / 86400 ))
            
            print_color "$CYAN" "    📦 Compressing: $(basename "$file") (${file_age_days}d old, $(( original_size / 1024 ))KB)"
            
            if [[ "$dry_run" == "true" ]]; then
                print_color "$YELLOW" "    [DRY RUN] Would compress: $file"
            else
                # Compress with gzip (preserving original timestamps)
                if gzip -9 "$file" 2>/dev/null; then
                    local compressed_size=$(stat -c%s "${file}.gz" 2>/dev/null || echo 0)
                    local saved_space=$((original_size - compressed_size))
                    
                    print_color "$GREEN" "    ✅ Compressed: $(basename "$file").gz (saved $(( saved_space / 1024 ))KB)"
                    ((compressed_count++))
                    total_saved=$((total_saved + saved_space))
                else
                    print_color "$RED" "    ❌ Failed to compress: $file"
                fi
            fi
        fi
    done <<< "$old_files"
    
    if [[ "$dry_run" != "true" && $compressed_count -gt 0 ]]; then
        print_color "$GREEN" "✅ Compressed $compressed_count files, saved $(( total_saved / 1024 / 1024 ))MB"
    fi
    
    return 0
}

# Function to archive processed log files
archive_processed_logs() {
    local domain="$1"
    local server="$2"
    local log_directory="$3"
    local dry_run="$4"
    
    print_color "$CYAN" "📦 Archiving processed logs for $domain-$server"
    
    local processed_dir="$log_directory/processed"
    
    if [[ ! -d "$processed_dir" ]]; then
        print_color "$YELLOW" "  ℹ️  No processed directory found: $processed_dir"
        return 0
    fi
    
    local archive_base="$ARCHIVE_BASE_DIR/$domain/$server"
    create_archive_structure "$domain" "$server"
    
    local archived_count=0
    local total_size=0
    
    # Find all processed log files
    local processed_files=$(find "$processed_dir" -type f \( -name "*.log*" -o -name "*.txt*" -o -name "*access*" -o -name "*error*" \))
    
    if [[ -z "$processed_files" ]]; then
        print_color "$YELLOW" "  ℹ️  No processed files found to archive"
        return 0
    fi
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            
            # Try to extract date from filename
            local year=""
            local month=""
            
            # Common date patterns in log filenames
            if [[ "$filename" =~ ([0-9]{4})-([0-9]{2}) ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
            elif [[ "$filename" =~ ([0-9]{4})([0-9]{2})[0-9]{2} ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
            elif [[ "$filename" =~ access\.log\.([0-9]{4})([0-9]{2}) ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
            else
                # Use file modification time
                year=$(date -r "$file" +%Y 2>/dev/null || date +%Y)
                month=$(date -r "$file" +%m 2>/dev/null || date +%m)
            fi
            
            local archive_dir="$archive_base/$year/$month"
            local archive_file="$archive_dir/$filename"
            
            print_color "$CYAN" "    📁 Archiving: $filename → $year/$month/"
            
            if [[ "$dry_run" == "true" ]]; then
                print_color "$YELLOW" "    [DRY RUN] Would archive to: $archive_file"
            else
                # Ensure archive directory exists
                mkdir -p "$archive_dir"
                
                # Move file to archive
                if mv "$file" "$archive_file" 2>/dev/null; then
                    print_color "$GREEN" "    ✅ Archived: $filename ($(( file_size / 1024 ))KB)"
                    ((archived_count++))
                    total_size=$((total_size + file_size))
                else
                    print_color "$RED" "    ❌ Failed to archive: $file"
                fi
            fi
        fi
    done <<< "$processed_files"
    
    if [[ "$dry_run" != "true" && $archived_count -gt 0 ]]; then
        print_color "$GREEN" "✅ Archived $archived_count files ($(( total_size / 1024 / 1024 ))MB)"
    fi
    
    return 0
}

# Function to cleanup old archived files
cleanup_old_archives() {
    local domain="$1"
    local server="$2"
    local retention_days="$3"
    local dry_run="$4"
    
    print_color "$CYAN" "🧹 Cleaning up archives older than $retention_days days for $domain-$server"
    
    local archive_dir="$ARCHIVE_BASE_DIR/$domain/$server"
    
    if [[ ! -d "$archive_dir" ]]; then
        print_color "$YELLOW" "  ℹ️  No archive directory found: $archive_dir"
        return 0
    fi
    
    local deleted_count=0
    local total_freed=0
    
    # Find files older than retention period
    local old_files=$(find "$archive_dir" -type f -mtime +$retention_days 2>/dev/null)
    
    if [[ -z "$old_files" ]]; then
        print_color "$YELLOW" "  ℹ️  No files older than $retention_days days found"
        return 0
    fi
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            local file_age_days=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || echo 0)) / 86400 ))
            local relative_path=${file#$archive_dir/}
            
            print_color "$CYAN" "    🗑️  Removing: $relative_path (${file_age_days}d old)"
            
            if [[ "$dry_run" == "true" ]]; then
                print_color "$YELLOW" "    [DRY RUN] Would delete: $file"
            else
                if rm -f "$file" 2>/dev/null; then
                    print_color "$GREEN" "    ✅ Deleted: $relative_path (freed $(( file_size / 1024 ))KB)"
                    ((deleted_count++))
                    total_freed=$((total_freed + file_size))
                else
                    print_color "$RED" "    ❌ Failed to delete: $file"
                fi
            fi
        fi
    done <<< "$old_files"
    
    if [[ "$dry_run" != "true" && $deleted_count -gt 0 ]]; then
        print_color "$GREEN" "✅ Deleted $deleted_count old files, freed $(( total_freed / 1024 / 1024 ))MB"
        
        # Remove empty directories
        find "$archive_dir" -type d -empty -delete 2>/dev/null
    fi
    
    return 0
}

# Function to show disk usage statistics
show_disk_usage() {
    local domain="$1"
    local server="$2"
    
    print_color "$BLUE" "💾 Disk Usage Statistics"
    
    if [[ -n "$domain" && -n "$server" ]]; then
        print_color "$CYAN" "For $domain-$server:"
        
        # Server-specific directories
        local log_directory=$(get_config_value "log_directory" "$server" "$domain")
        local archive_dir="$ARCHIVE_BASE_DIR/$domain/$server"
        
        if [[ -n "$log_directory" ]]; then
            log_directory="${log_directory/\$HOME/$HOME}"
            log_directory="${log_directory/\$BASE_DIR/$BASE_DIR}"
            
            if [[ -d "$log_directory" ]]; then
                local log_usage=$(du -sh "$log_directory" 2>/dev/null | cut -f1)
                print_color "$GREEN" "  📂 Active logs: $log_usage ($log_directory)"
                
                # Count files by type
                local log_files=$(find "$log_directory" -name "*.log" -type f 2>/dev/null | wc -l)
                local gz_files=$(find "$log_directory" -name "*.gz" -type f 2>/dev/null | wc -l)
                local processed_files=$(find "$log_directory/processed" -type f 2>/dev/null | wc -l)
                
                print_color "$CYAN" "    📊 Files: $log_files uncompressed, $gz_files compressed, $processed_files processed"
            fi
        fi
        
        if [[ -d "$archive_dir" ]]; then
            local archive_usage=$(du -sh "$archive_dir" 2>/dev/null | cut -f1)
            print_color "$GREEN" "  📦 Archives: $archive_usage ($archive_dir)"
            
            # Show breakdown by year
            for year_dir in "$archive_dir"/*; do
                if [[ -d "$year_dir" ]]; then
                    local year=$(basename "$year_dir")
                    local year_usage=$(du -sh "$year_dir" 2>/dev/null | cut -f1)
                    local year_files=$(find "$year_dir" -type f 2>/dev/null | wc -l)
                    print_color "$CYAN" "    📅 $year: $year_usage ($year_files files)"
                fi
            done
        fi
    else
        # Overall statistics
        print_color "$CYAN" "Overall:"
        
        if [[ -d "$BASE_DIR/logs" ]]; then
            local total_logs=$(du -sh "$BASE_DIR/logs" 2>/dev/null | cut -f1)
            print_color "$GREEN" "  📂 Total logs: $total_logs"
        fi
        
        if [[ -d "$ARCHIVE_BASE_DIR" ]]; then
            local total_archives=$(du -sh "$ARCHIVE_BASE_DIR" 2>/dev/null | cut -f1)
            print_color "$GREEN" "  📦 Total archives: $total_archives"
        fi
        
        # Show top consumers
        print_color "$CYAN" "  🔝 Top space consumers:"
        if [[ -d "$ARCHIVE_BASE_DIR" ]]; then
            du -sh "$ARCHIVE_BASE_DIR"/*/* 2>/dev/null | sort -hr | head -5 | while read -r size path; do
                local relative_path=${path#$ARCHIVE_BASE_DIR/}
                print_color "$GREEN" "    $size - $relative_path"
            done
        fi
    fi
}

# Function to rotate current log files
rotate_current_logs() {
    local domain="$1"
    local server="$2"
    local dry_run="$3"
    
    print_color "$CYAN" "🔄 Rotating current log files for $domain-$server"
    
    local log_directory=$(get_config_value "log_directory" "$server" "$domain")
    log_directory="${log_directory/\$HOME/$HOME}"
    log_directory="${log_directory/\$BASE_DIR/$BASE_DIR}"
    
    if [[ ! -d "$log_directory" ]]; then
        print_color "$RED" "❌ Log directory not found: $log_directory"
        return 1
    fi
    
    local rotated_count=0
    local current_date=$(date +%Y%m%d)
    
    # Find current log files (typically named access.log, error.log, etc.)
    local current_logs=$(find "$log_directory" -maxdepth 1 -name "*.log" -type f ! -name "*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*")
    
    if [[ -z "$current_logs" ]]; then
        print_color "$YELLOW" "  ℹ️  No current log files found to rotate"
        return 0
    fi
    
    while IFS= read -r log_file; do
        if [[ -f "$log_file" ]]; then
            local basename=$(basename "$log_file" .log)
            local rotated_name="${basename}-${current_date}.log"
            local rotated_path="$log_directory/$rotated_name"
            local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            
            # Only rotate if file has content
            if [[ $file_size -gt 0 ]]; then
                print_color "$CYAN" "    🔄 Rotating: $(basename "$log_file") → $rotated_name"
                
                if [[ "$dry_run" == "true" ]]; then
                    print_color "$YELLOW" "    [DRY RUN] Would rotate to: $rotated_path"
                else
                    # Copy and truncate (safer for active logs)
                    if cp "$log_file" "$rotated_path" 2>/dev/null && truncate -s 0 "$log_file" 2>/dev/null; then
                        print_color "$GREEN" "    ✅ Rotated: $rotated_name ($(( file_size / 1024 ))KB)"
                        ((rotated_count++))
                    else
                        print_color "$RED" "    ❌ Failed to rotate: $log_file"
                    fi
                fi
            else
                print_color "$YELLOW" "    ⚠️  Skipping empty file: $(basename "$log_file")"
            fi
        fi
    done <<< "$current_logs"
    
    if [[ "$dry_run" != "true" && $rotated_count -gt 0 ]]; then
        print_color "$GREEN" "✅ Rotated $rotated_count log files"
    fi
    
    return 0
}

# Function to process domain/server combination
process_domain_server() {
    local domain="$1"
    local server="$2"
    local action="$3"
    local dry_run="$4"
    
    print_color "$PURPLE" "🚀 Processing $domain - $server ($action)"
    
    # Get configuration
    local log_directory=$(get_config_value "log_directory" "$server" "$domain")
    local retention_days=$(get_config_value "retention_days" "$server" "$domain")
    local compress_after_days=$(get_config_value "compress_after_days" "$server" "$domain")
    local archive_enabled=$(get_config_value "archive_processed_logs" "$server" "$domain")
    local compress_enabled=$(get_config_value "compress_archived_logs" "$server" "$domain")
    
    # Expand variables and set defaults
    log_directory="${log_directory/\$HOME/$HOME}"
    log_directory="${log_directory/\$BASE_DIR/$BASE_DIR}"
    retention_days="${retention_days:-$DEFAULT_RETENTION_DAYS}"
    compress_after_days="${compress_after_days:-$DEFAULT_COMPRESS_AFTER_DAYS}"
    archive_enabled="${archive_enabled:-yes}"
    compress_enabled="${compress_enabled:-yes}"
    
    case "$action" in
        "all"|"full")
            if [[ "$compress_enabled" == "yes" ]]; then
                compress_log_files "$log_directory" "$compress_after_days" "$dry_run"
            fi
            
            if [[ "$archive_enabled" == "yes" ]]; then
                archive_processed_logs "$domain" "$server" "$log_directory" "$dry_run"
            fi
            
            cleanup_old_archives "$domain" "$server" "$retention_days" "$dry_run"
            ;;
        "compress")
            compress_log_files "$log_directory" "$compress_after_days" "$dry_run"
            ;;
        "archive")
            archive_processed_logs "$domain" "$server" "$log_directory" "$dry_run"
            ;;
        "cleanup")
            cleanup_old_archives "$domain" "$server" "$retention_days" "$dry_run"
            ;;
        "rotate")
            rotate_current_logs "$domain" "$server" "$dry_run"
            ;;
        "usage")
            show_disk_usage "$domain" "$server"
            ;;
        *)
            print_color "$RED" "❌ Unknown action: $action"
            return 1
            ;;
    esac
}

# Function to show usage
usage() {
    echo "AWStats Log Manager v$VERSION"
    echo ""
    echo "Usage: $0 ACTION [OPTIONS] [DOMAIN] [SERVER]"
    echo ""
    echo "ACTIONS:"
    echo "  all                 Perform all log management tasks"
    echo "  compress            Compress old log files"
    echo "  archive             Archive processed log files"
    echo "  cleanup             Remove old archived files"
    echo "  rotate              Rotate current active log files"
    echo "  usage               Show disk usage statistics"
    echo ""
    echo "OPTIONS:"
    echo "  --all               Process all configured domains/servers"
    echo "  --dry-run           Show what would be done without making changes"
    echo "  --retention-days N  Override retention period (default: $DEFAULT_RETENTION_DAYS)"
    echo "  --compress-after N  Compress files after N days (default: $DEFAULT_COMPRESS_AFTER_DAYS)"
    echo "  --help              Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 all --all                                    # Full cleanup for all servers"
    echo "  $0 compress sbil-api.bos.njtransit.com pnjt1sweb1  # Compress specific server logs"
    echo "  $0 usage --all                                  # Show usage statistics"
    echo "  $0 all --dry-run --all                          # Preview what would be done"
    echo "  $0 rotate sbil-api.bos.njtransit.com pnjt1sweb1    # Rotate current logs"
    echo ""
}

# Parse command line arguments
ACTION=""
PROCESS_ALL=false
DRY_RUN=false
TARGET_DOMAIN=""
TARGET_SERVER=""
CUSTOM_RETENTION=""
CUSTOM_COMPRESS_AFTER=""

# First argument should be action
if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    ACTION="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            PROCESS_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --retention-days)
            CUSTOM_RETENTION="$2"
            shift 2
            ;;
        --compress-after)
            CUSTOM_COMPRESS_AFTER="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$TARGET_DOMAIN" ]]; then
                TARGET_DOMAIN="$1"
            elif [[ -z "$TARGET_SERVER" ]]; then
                TARGET_SERVER="$1"
            else
                print_color "$RED" "❌ Unknown argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate action
if [[ -z "$ACTION" ]]; then
    print_color "$RED" "❌ Action required"
    usage
    exit 1
fi

# Override defaults if custom values provided
if [[ -n "$CUSTOM_RETENTION" ]]; then
    DEFAULT_RETENTION_DAYS="$CUSTOM_RETENTION"
fi

if [[ -n "$CUSTOM_COMPRESS_AFTER" ]]; then
    DEFAULT_COMPRESS_AFTER_DAYS="$CUSTOM_COMPRESS_AFTER"
fi

# Main execution
main() {
    print_color "$PURPLE" "🔥 AWStats Log Manager v$VERSION"
    print_color "$BLUE" "=================================================="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$YELLOW" "🔍 DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Create base archive directory
    mkdir -p "$ARCHIVE_BASE_DIR"
    
    # Special case for usage action without specific domain/server
    if [[ "$ACTION" == "usage" && "$PROCESS_ALL" == "true" ]]; then
        show_disk_usage
        exit 0
    fi
    
    # Determine what to process
    local domains_servers=()
    
    if [[ "$PROCESS_ALL" == "true" ]]; then
        # Get all enabled domain/server combinations from config
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            if [[ "$line" =~ ^\[(.+)\]$ ]]; then
                local section="${BASH_REMATCH[1]}"
                if [[ "$section" != "global" ]]; then
                    local enabled=$(get_config_value "enabled" "" "$section")
                    local servers=$(get_config_value "servers" "" "$section")
                    
                    if [[ "$enabled" == "yes" && -n "$servers" ]]; then
                        # This is a domain with servers
                        IFS=',' read -ra server_list <<< "$servers"
                        for server in "${server_list[@]}"; do
                            server=$(echo "$server" | xargs)  # trim whitespace
                            local server_enabled=$(get_config_value "enabled" "$server" "$section")
                            if [[ "$server_enabled" == "yes" ]]; then
                                domains_servers+=("$section:$server")
                            fi
                        done
                    fi
                fi
            fi
        done < "$CONFIG_FILE"
    else
        # Process specific domain/server
        if [[ -n "$TARGET_DOMAIN" && -n "$TARGET_SERVER" ]]; then
            domains_servers+=("$TARGET_DOMAIN:$TARGET_SERVER")
        else
            print_color "$RED" "❌ Please specify domain and server, or use --all"
            usage
            exit 1
        fi
    fi
    
    if [[ ${#domains_servers[@]} -eq 0 ]]; then
        print_color "$RED" "❌ No enabled domain/server combinations found"
        exit 1
    fi
    
    print_color "$GREEN" "🎯 Found ${#domains_servers[@]} domain/server combinations to process"
    echo ""
    
    # Process each combination
    local total_processed=0
    local total_failed=0
    
    for domain_server in "${domains_servers[@]}"; do
        local domain=$(echo "$domain_server" | cut -d':' -f1)
        local server=$(echo "$domain_server" | cut -d':' -f2)
        
        print_color "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if process_domain_server "$domain" "$server" "$ACTION" "$DRY_RUN"; then
            ((total_processed++))
        else
            ((total_failed++))
        fi
        echo ""
    done
    
    # Final summary
    print_color "$BLUE" "=================================================="
    print_color "$GREEN" "🎉 Log Management Complete!"
    print_color "$GREEN" "✅ Successfully processed: $total_processed"
    
    if [[ $total_failed -gt 0 ]]; then
        print_color "$RED" "❌ Failed: $total_failed"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$YELLOW" "💡 This was a dry run. Run without --dry-run to apply changes."
    fi
}

# Execute main function
main

log_message "Log management completed"