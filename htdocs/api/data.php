<?php
/*
    AWStats API Data Endpoint
    File: htdocs/api/data.php
    Version: 2.0.1
    Purpose: JSON API for dashboard data and system status
    Changes: v2.0.1 - Enhanced error handling and configuration hierarchy support
*/

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Configuration
$config_file = __DIR__ . '/../../etc/servers.conf';
$db_file = __DIR__ . '/../../database/awstats.db';

// Function to parse configuration file with hierarchy support
function parse_config($config_file) {
    $config = ['global' => []];
    $current_section = 'global';
    
    if (!file_exists($config_file)) {
        return $config;
    }
    
    $lines = file($config_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    
    foreach ($lines as $line) {
        $line = trim($line);
        
        // Skip comments
        if (empty($line) || $line[0] === '#') {
            continue;
        }
        
        // Section headers
        if (preg_match('/^\[(.+)\]$/', $line, $matches)) {
            $current_section = $matches[1];
            $config[$current_section] = [];
            continue;
        }
        
        // Key-value pairs
        if (strpos($line, '=') !== false) {
            list($key, $value) = explode('=', $line, 2);
            $config[$current_section][trim($key)] = trim($value);
        }
    }
    
    return $config;
}

// Function to get database connection
function get_db_connection($db_file) {
    try {
        $pdo = new PDO("sqlite:$db_file");
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        return $pdo;
    } catch (PDOException $e) {
        error_log("Database connection failed: " . $e->getMessage());
        return null;
    }
}

// Function to send JSON response
function send_json_response($data, $status = 200) {
    http_response_code($status);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

// Function to send error response
function send_error($message, $status = 500, $details = null) {
    $response = [
        'error' => true,
        'message' => $message,
        'timestamp' => date('c')
    ];
    
    if ($details) {
        $response['details'] = $details;
    }
    
    send_json_response($response, $status);
}

// Function to validate and sanitize parameters
function get_param($key, $default = null, $type = 'string') {
    $value = $_GET[$key] ?? $default;
    
    switch ($type) {
        case 'int':
            return (int)$value;
        case 'bool':
            return filter_var($value, FILTER_VALIDATE_BOOLEAN);
        case 'email':
            return filter_var($value, FILTER_VALIDATE_EMAIL);
        default:
            return is_string($value) ? trim($value) : $value;
    }
}

// Get request parameters
$action = get_param('action', 'status');
$domain = get_param('domain');
$limit = get_param('limit', 10, 'int');

// Load configuration and connect to database
$config = parse_config($config_file);

// Expand $HOME in database file path
if (isset($config['global']['database_file'])) {
    $db_file = str_replace('$HOME', $_SERVER['HOME'] ?? '/home/user', $config['global']['database_file']);
}

$pdo = get_db_connection($db_file);

if (!$pdo) {
    send_error('Database connection failed', 503);
}

// Route to appropriate handler
try {
    switch ($action) {
        case 'system_status':
            handle_system_status($pdo, $config, $db_file);
            break;
            
        case 'dashboard_stats':
            handle_dashboard_stats($pdo);
            break;
            
        case 'domain_stats':
            handle_domain_stats($pdo, $domain);
            break;
            
        case 'processing_log':
            handle_processing_log($pdo, $limit);
            break;
            
        case 'recent_activity':
            handle_recent_activity($pdo, $limit);
            break;
            
        case 'top_apis':
            handle_top_apis($pdo, $domain, $limit);
            break;
            
        case 'server_stats':
            handle_server_stats($pdo, $domain);
            break;
            
        default:
            send_error('Unknown action: ' . $action, 400);
    }
} catch (Exception $e) {
    error_log("API Error [$action]: " . $e->getMessage());
    send_error('Internal server error', 500, $e->getMessage());
}

function handle_system_status($pdo, $config, $db_file) {
    $status = [
        'system' => 'AWStats Analytics Dashboard',
        'version' => '2.0.1',
        'timestamp' => date('c'),
        'database' => [
            'connected' => true,
            'file' => $db_file,
            'size' => 'N/A'
        ],
        'configuration' => [
            'file_exists' => file_exists($config['_file'] ?? ''),
            'domains_configured' => 0,
            'servers_configured' => 0,
            'hierarchy_enabled' => true
        ],
        'data' => [
            'total_records' => 0,
            'date_range' => null
        ]
    ];
    
    try {
        // Get database info
        if (file_exists($db_file)) {
            $status['database']['size'] = format_bytes(filesize($db_file));
        }
        
        // Get configuration counts
        $stmt = $pdo->query("SELECT COUNT(*) FROM domains WHERE enabled = 1");
        $status['configuration']['domains_configured'] = (int)$stmt->fetchColumn();
        
        $stmt = $pdo->query("SELECT COUNT(*) FROM servers WHERE enabled = 1");
        $status['configuration']['servers_configured'] = (int)$stmt->fetchColumn();
        
        // Get data statistics
        $stmt = $pdo->query("SELECT COUNT(*) FROM api_usage");
        $status['data']['total_records'] = (int)$stmt->fetchColumn();
        
        $stmt = $pdo->query("SELECT MIN(date_day) as min_date, MAX(date_day) as max_date FROM api_usage");
        $date_range = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($date_range['min_date']) {
            $status['data']['date_range'] = [
                'start' => $date_range['min_date'],
                'end' => $date_range['max_date']
            ];
        }
        
        // Check recent processing activity
        $stmt = $pdo->query("SELECT COUNT(*) FROM processing_log WHERE started_at >= datetime('now', '-24 hours')");
        $status['processing'] = [
            'recent_jobs' => (int)$stmt->fetchColumn()
        ];
        
        // Configuration validation
        $status['configuration']['valid_sections'] = count($config);
        $status['configuration']['global_settings'] = count($config['global'] ?? []);
        
    } catch (PDOException $e) {
        $status['database']['connected'] = false;
        $status['error'] = $e->getMessage();
    }
    
    send_json_response($status);
}

function handle_dashboard_stats($pdo) {
    try {
        // Get domain statistics
        $stmt = $pdo->query("SELECT * FROM v_domain_stats ORDER BY total_hits DESC");
        $domains = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get recent activity
        $stmt = $pdo->query("SELECT * FROM v_recent_activity ORDER BY processed_at DESC LIMIT 10");
        $recent_activity = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get today's top APIs
        $stmt = $pdo->query("SELECT * FROM v_top_apis_today LIMIT 5");
        $top_apis_today = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get processing statistics
        $stmt = $pdo->query("
            SELECT 
                processing_status,
                COUNT(*) as count
            FROM processing_log 
            WHERE started_at >= datetime('now', '-7 days')
            GROUP BY processing_status
        ");
        $processing_stats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response([
            'domains' => $domains,
            'recent_activity' => $recent_activity,
            'top_apis_today' => $top_apis_today,
            'processing_stats' => $processing_stats,
            'timestamp' => date('c')
        ]);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch dashboard stats: ' . $e->getMessage());
    }
}

function handle_domain_stats($pdo, $domain) {
    if (!$domain) {
        send_error('Domain parameter required', 400);
    }
    
    try {
        // Get domain info
        $stmt = $pdo->prepare("SELECT * FROM v_domain_stats WHERE domain_name = ?");
        $stmt->execute([$domain]);
        $domain_info = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$domain_info) {
            send_error('Domain not found', 404);
        }
        
        // Get monthly statistics for the domain
        $stmt = $pdo->prepare("
            SELECT 
                strftime('%Y-%m', date_day) as month,
                COUNT(DISTINCT api_endpoint) as unique_apis,
                SUM(hits) as total_hits,
                COUNT(DISTINCT server_id) as active_servers,
                AVG(hits) as avg_hits
            FROM api_usage au
            JOIN domains d ON au.domain_id = d.id
            WHERE d.domain_name = ?
            GROUP BY month
            ORDER BY month DESC
            LIMIT 12
        ");
        $stmt->execute([$domain]);
        $monthly_stats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get top APIs for the domain
        $stmt = $pdo->prepare("
            SELECT 
                api_endpoint,
                SUM(hits) as total_hits,
                COUNT(DISTINCT server_id) as server_count,
                AVG(hits) as avg_hits_per_server,
                MAX(date_day) as last_seen
            FROM api_usage au
            JOIN domains d ON au.domain_id = d.id
            WHERE d.domain_name = ?
            GROUP BY api_endpoint
            ORDER BY total_hits DESC
            LIMIT 20
        ");
        $stmt->execute([$domain]);
        $top_apis = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get server breakdown
        $stmt = $pdo->prepare("
            SELECT 
                s.server_name,
                s.server_display_name,
                COUNT(DISTINCT au.api_endpoint) as unique_apis,
                SUM(au.hits) as total_hits,
                MAX(au.date_day) as last_activity
            FROM servers s
            JOIN domains d ON s.domain_id = d.id
            LEFT JOIN api_usage au ON s.id = au.server_id
            WHERE d.domain_name = ? AND s.enabled = 1
            GROUP BY s.id, s.server_name, s.server_display_name
            ORDER BY total_hits DESC
        ");
        $stmt->execute([$domain]);
        $server_breakdown = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response([
            'domain_info' => $domain_info,
            'monthly_stats' => $monthly_stats,
            'top_apis' => $top_apis,
            'server_breakdown' => $server_breakdown,
            'timestamp' => date('c')
        ]);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch domain stats: ' . $e->getMessage());
    }
}

function handle_processing_log($pdo, $limit) {
    try {
        $stmt = $pdo->prepare("
            SELECT 
                pl.*,
                d.domain_name,
                s.server_name,
                s.server_display_name
            FROM processing_log pl
            JOIN domains d ON pl.domain_id = d.id
            JOIN servers s ON pl.server_id = s.id
            ORDER BY pl.started_at DESC
            LIMIT ?
        ");
        $stmt->execute([$limit]);
        $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response($logs);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch processing log: ' . $e->getMessage());
    }
}

function handle_recent_activity($pdo, $limit) {
    try {
        $stmt = $pdo->prepare("SELECT * FROM v_recent_activity ORDER BY processed_at DESC LIMIT ?");
        $stmt->execute([$limit]);
        $activities = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response($activities);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch recent activity: ' . $e->getMessage());
    }
}

function handle_top_apis($pdo, $domain, $limit) {
    try {
        if ($domain) {
            $stmt = $pdo->prepare("
                SELECT 
                    api_endpoint,
                    SUM(hits) as total_hits,
                    COUNT(DISTINCT server_id) as server_count,
                    ROUND(AVG(hits), 2) as avg_hits_per_server
                FROM api_usage au
                JOIN domains d ON au.domain_id = d.id
                WHERE d.domain_name = ?
                GROUP BY api_endpoint
                ORDER BY total_hits DESC
                LIMIT ?
            ");
            $stmt->execute([$domain, $limit]);
        } else {
            $stmt = $pdo->prepare("
                SELECT 
                    d.domain_name,
                    au.api_endpoint,
                    SUM(au.hits) as total_hits,
                    COUNT(DISTINCT au.server_id) as server_count
                FROM api_usage au
                JOIN domains d ON au.domain_id = d.id
                GROUP BY d.domain_name, au.api_endpoint
                ORDER BY total_hits DESC
                LIMIT ?
            ");
            $stmt->execute([$limit]);
        }
        
        $apis = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response($apis);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch top APIs: ' . $e->getMessage());
    }
}

function handle_server_stats($pdo, $domain) {
    try {
        $query = "
            SELECT 
                s.server_name,
                s.server_display_name,
                COUNT(DISTINCT au.api_endpoint) as unique_apis,
                SUM(au.hits) as total_hits,
                COUNT(DISTINCT au.date_day) as active_days,
                MIN(au.date_day) as first_activity,
                MAX(au.date_day) as last_activity
            FROM servers s
            LEFT JOIN api_usage au ON s.id = au.server_id
        ";
        
        if ($domain) {
            $query .= " JOIN domains d ON s.domain_id = d.id WHERE d.domain_name = ? AND s.enabled = 1";
            $stmt = $pdo->prepare($query . " GROUP BY s.id ORDER BY total_hits DESC");
            $stmt->execute([$domain]);
        } else {
            $query .= " WHERE s.enabled = 1";
            $stmt = $pdo->prepare($query . " GROUP BY s.id ORDER BY total_hits DESC");
            $stmt->execute();
        }
        
        $servers = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        send_json_response($servers);
        
    } catch (PDOException $e) {
        send_error('Failed to fetch server stats: ' . $e->getMessage());
    }
}

function format_bytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}
?>