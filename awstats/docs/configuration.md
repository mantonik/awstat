# Configuration Reference

## Overview

The AWStats Analytics system uses a hierarchical configuration system that allows you to set global defaults and override them at the domain or server level.

## Configuration Hierarchy

Settings are resolved in this order (highest to lowest priority):

1. **Server-specific settings** (highest priority)
2. **Domain-specific settings** (medium priority)
3. **Global settings** (default/fallback)

## Configuration File: `etc/servers.conf`

### Global Section

The `[global]` section contains system-wide defaults:

```ini
[global]
# Database settings
database_file=$HOME/awstats-analytics/database/awstats.db
database_type=sqlite3

# Directory settings
base_dir=$HOME/awstats-analytics
htdocs_dir=$HOME/awstats-analytics/htdocs
logs_dir=$HOME/awstats-analytics/logs

# AWStats settings
awstats_bin=/usr/local/awstats/wwwroot/cgi-bin/awstats.pl
log_format=4
skip_hosts="127.0.0.1 localhost"
skip_files="REGEX[/\.css$|/\.js$|/\.png$]"

# Processing settings
max_concurrent_processes=2
archive_processed_logs=yes
compress_archived_logs=yes
retention_days=365