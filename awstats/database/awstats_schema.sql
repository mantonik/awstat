-- AWStats Database Schema
-- File: database/awstats_schema.sql
-- Version: 2.0.0
-- Purpose: Optimized schema for PHP-based reporting with fast queries
-- Changes: Complete redesign for PHP integration, added indexes for performance

-- Domains configuration table
CREATE TABLE IF NOT EXISTS domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Servers configuration table
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

-- Main API usage data table - optimized for fast reporting
CREATE TABLE IF NOT EXISTS api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    api_endpoint TEXT NOT NULL,
    date_day DATE NOT NULL,
    hour INTEGER NOT NULL DEFAULT 0,
    hits INTEGER NOT NULL DEFAULT 0,
    bytes_transferred INTEGER DEFAULT 0,
    response_time_avg INTEGER DEFAULT 0, -- in microseconds
    status_2xx INTEGER DEFAULT 0,
    status_3xx INTEGER DEFAULT 0,
    status_4xx INTEGER DEFAULT 0,
    status_5xx INTEGER DEFAULT 0,
    unique_ips INTEGER DEFAULT 0,
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    UNIQUE(domain_id, server_id, api_endpoint, date_day, hour)
);

-- Daily summaries for faster dashboard queries
CREATE TABLE IF NOT EXISTS daily_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    date_day DATE NOT NULL,
    total_hits INTEGER NOT NULL DEFAULT 0,
    total_bytes INTEGER DEFAULT 0,
    unique_apis INTEGER DEFAULT 0,
    unique_ips INTEGER DEFAULT 0,
    avg_response_time INTEGER DEFAULT 0,
    error_rate REAL DEFAULT 0.0, -- percentage
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    UNIQUE(domain_id, server_id, date_day)
);

-- Monthly summaries for yearly reports
CREATE TABLE IF NOT EXISTS monthly_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_hits INTEGER NOT NULL DEFAULT 0,
    total_bytes INTEGER DEFAULT 0,
    unique_apis INTEGER DEFAULT 0,
    unique_ips INTEGER DEFAULT 0,
    avg_response_time INTEGER DEFAULT 0,
    error_rate REAL DEFAULT 0.0,
    top_api_endpoint TEXT,
    top_api_hits INTEGER DEFAULT 0,
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    UNIQUE(domain_id, server_id, year, month)
);

-- Processing log for tracking data extraction
CREATE TABLE IF NOT EXISTS processing_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    log_file_path TEXT NOT NULL,
    log_file_date DATE NOT NULL,
    processing_status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (domain_id) REFERENCES domains (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_api_usage_domain_date ON api_usage(domain_id, date_day);
CREATE INDEX IF NOT EXISTS idx_api_usage_server_date ON api_usage(server_id, date_day);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON api_usage(api_endpoint);
CREATE INDEX IF NOT EXISTS idx_api_usage_hits ON api_usage(hits DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_date_hour ON api_usage(date_day, hour);

CREATE INDEX IF NOT EXISTS idx_daily_summaries_domain_date ON daily_summaries(domain_id, date_day);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_server_date ON daily_summaries(server_id, date_day);

CREATE INDEX IF NOT EXISTS idx_monthly_summaries_domain_year ON monthly_summaries(domain_id, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_summaries_server_year ON monthly_summaries(server_id, year, month);

CREATE INDEX IF NOT EXISTS idx_processing_log_status ON processing_log(processing_status);
CREATE INDEX IF NOT EXISTS idx_processing_log_date ON processing_log(log_file_date);

-- Views for common PHP queries
CREATE VIEW IF NOT EXISTS v_domain_stats AS
SELECT 
    d.domain_name,
    d.display_name,
    COUNT(DISTINCT s.id) as server_count,
    COUNT(DISTINCT ds.date_day) as days_with_data,
    COALESCE(SUM(ds.total_hits), 0) as total_hits,
    COALESCE(SUM(ds.total_bytes), 0) as total_bytes,
    MAX(ds.date_day) as last_data_date
FROM domains d
LEFT JOIN servers s ON d.id = s.domain_id AND s.enabled = 1
LEFT JOIN daily_summaries ds ON s.id = ds.server_id
WHERE d.enabled = 1
GROUP BY d.id, d.domain_name, d.display_name;

CREATE VIEW IF NOT EXISTS v_recent_activity AS
SELECT 
    d.domain_name,
    s.server_name,
    au.api_endpoint,
    au.date_day,
    au.hour,
    au.hits,
    au.processed_at
FROM api_usage au
JOIN servers s ON au.server_id = s.id
JOIN domains d ON au.domain_id = d.id
WHERE au.date_day >= date('now', '-7 days')
ORDER BY au.processed_at DESC
LIMIT 100;

CREATE VIEW IF NOT EXISTS v_top_apis_today AS
SELECT 
    d.domain_name,
    au.api_endpoint,
    SUM(au.hits) as total_hits,
    COUNT(DISTINCT au.server_id) as server_count
FROM api_usage au
JOIN domains d ON au.domain_id = d.id
WHERE au.date_day = date('now')
GROUP BY d.domain_name, au.api_endpoint
ORDER BY total_hits DESC;

-- Sample data for development (remove in production)
INSERT OR IGNORE INTO domains (domain_name, display_name) VALUES 
('sbil-api.bos.njtransit.com', 'SBIL API - Boston NJ Transit');

INSERT OR IGNORE INTO servers (domain_id, server_name, server_display_name, log_path_pattern) VALUES 
(1, 'pnjt1sweb1', 'Production Web Server 1', '/home/awstats/logs/pnjt1sweb1/access-*.log'),
(1, 'pnjt1sweb2', 'Production Web Server 2', '/home/awstats/logs/pnjt1sweb2/access-*.log');