<!DOCTYPE html>
<!--
    AWStats Dashboard
    File: htdocs/index.php
    Version: 2.0.0
    Purpose: Main dashboard for AWStats reporting system
    Changes: New PHP-based interface with responsive design
-->
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWStats Analytics Dashboard</title>
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1><i class="fas fa-chart-line"></i> AWStats Analytics Dashboard</h1>
            <p class="subtitle">Real-time API Traffic Analysis & Reporting</p>
        </header>

        <?php
        // Configuration
        $config_file = __DIR__ . '/../etc/servers.conf';
        $db_file = __DIR__ . '/../database/awstats.db';
        
        // Function to parse configuration file with hierarchy support
        function parse_config($config_file) {
            $config = [];
            $current_section = '';
            
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
                if (strpos($line, '=') !== false && $current_section) {
                    list($key, $value) = explode('=', $line, 2);
                    $config[$current_section][trim($key)] = trim($value);
                }
            }
            
            return $config;
        }
        
        // Function to get configuration value with hierarchy
        // Priority: server-specific → domain-specific → global
        function get_config_value($config, $key, $server_name = null, $domain_name = null) {
            // Try server-specific first (highest priority)
            if ($server_name && isset($config[$server_name][$key])) {
                return $config[$server_name][$key];
            }
            
            // Try domain-specific (medium priority)  
            if ($domain_name && isset($config[$domain_name][$key])) {
                return $config[$domain_name][$key];
            }
            
            // Fall back to global (default)
            return $config['global'][$key] ?? null;
        }
        
        // Function to get database connection
        function get_db_connection($db_file) {
            try {
                $pdo = new PDO("sqlite:$db_file");
                $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                return $pdo;
            } catch (PDOException $e) {
                return null;
            }
        }
        
        // Function to get domain statistics
        function get_domain_stats($pdo) {
            try {
                $stmt = $pdo->query("SELECT * FROM v_domain_stats ORDER BY total_hits DESC");
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            } catch (PDOException $e) {
                return [];
            }
        }
        
        // Function to get recent activity
        function get_recent_activity($pdo, $limit = 10) {
            try {
                $stmt = $pdo->prepare("SELECT * FROM v_recent_activity ORDER BY processed_at DESC LIMIT ?");
                $stmt->execute([$limit]);
                return $stmt->fetchAll(PDO::FETCH_ASSOC);
            } catch (PDOException $e) {
                return [];
            }
        }
        
        // Load configuration and connect to database
        $config = parse_config($config_file);
        $pdo = get_db_connection($db_file);
        
        if ($pdo) {
            $domain_stats = get_domain_stats($pdo);
            $recent_activity = get_recent_activity($pdo);
        } else {
            $domain_stats = [];
            $recent_activity = [];
        }
        ?>

        <div class="dashboard-grid">
            <!-- System Status Card -->
            <div class="card status-card">
                <div class="card-header">
                    <h3><i class="fas fa-server"></i> System Status</h3>
                </div>
                <div class="card-content">
                    <?php if ($pdo): ?>
                        <div class="status-item">
                            <span class="status-indicator online"></span>
                            <span>Database Connected</span>
                        </div>
                        <div class="status-item">
                            <span class="status-indicator online"></span>
                            <span>Configuration Loaded</span>
                        </div>
                        <div class="status-item">
                            <span class="status-indicator <?php echo count($domain_stats) > 0 ? 'online' : 'offline'; ?>"></span>
                            <span><?php echo count($domain_stats); ?> Domain(s) Configured</span>
                        </div>
                    <?php else: ?>
                        <div class="status-item">
                            <span class="status-indicator offline"></span>
                            <span>Database Connection Failed</span>
                        </div>
                        <div class="alert alert-warning">
                            <i class="fas fa-exclamation-triangle"></i>
                            Please run initialization script: <code>bin/awstats_init.sh</code>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Domains Overview -->
            <div class="card domains-card">
                <div class="card-header">
                    <h3><i class="fas fa-globe"></i> Domains Overview</h3>
                </div>
                <div class="card-content">
                    <?php if (!empty($domain_stats)): ?>
                        <?php foreach ($domain_stats as $domain): ?>
                            <div class="domain-item">
                                <div class="domain-info">
                                    <h4><?php echo htmlspecialchars($domain['display_name']); ?></h4>
                                    <p class="domain-name"><?php echo htmlspecialchars($domain['domain_name']); ?></p>
                                </div>
                                <div class="domain-stats">
                                    <div class="stat">
                                        <span class="stat-value"><?php echo number_format($domain['total_hits']); ?></span>
                                        <span class="stat-label">Total Hits</span>
                                    </div>
                                    <div class="stat">
                                        <span class="stat-value"><?php echo $domain['server_count']; ?></span>
                                        <span class="stat-label">Servers</span>
                                    </div>
                                    <div class="stat">
                                        <span class="stat-value"><?php echo $domain['days_with_data']; ?></span>
                                        <span class="stat-label">Days</span>
                                    </div>
                                </div>
                                <div class="domain-actions">
                                    <a href="reports.php?domain=<?php echo urlencode($domain['domain_name']); ?>" class="btn btn-primary">
                                        <i class="fas fa-chart-bar"></i> View Reports
                                    </a>
                                </div>
                            </div>
                        <?php endforeach; ?>
                    <?php else: ?>
                        <div class="empty-state">
                            <i class="fas fa-database"></i>
                            <h4>No Data Available</h4>
                            <p>Run the data processor to populate the dashboard</p>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Recent Activity -->
            <div class="card activity-card">
                <div class="card-header">
                    <h3><i class="fas fa-clock"></i> Recent Activity</h3>
                </div>
                <div class="card-content">
                    <?php if (!empty($recent_activity)): ?>
                        <div class="activity-list">
                            <?php foreach (array_slice($recent_activity, 0, 5) as $activity): ?>
                                <div class="activity-item">
                                    <div class="activity-icon">
                                        <i class="fas fa-api"></i>
                                    </div>
                                    <div class="activity-info">
                                        <span class="activity-endpoint"><?php echo htmlspecialchars($activity['api_endpoint']); ?></span>
                                        <span class="activity-details">
                                            <?php echo htmlspecialchars($activity['server_name']); ?> • 
                                            <?php echo number_format($activity['hits']); ?> hits • 
                                            <?php echo date('M j, H:i', strtotime($activity['processed_at'])); ?>
                                        </span>
                                    </div>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    <?php else: ?>
                        <div class="empty-state">
                            <i class="fas fa-history"></i>
                            <h4>No Recent Activity</h4>
                            <p>Process some log files to see activity</p>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card actions-card">
                <div class="card-header">
                    <h3><i class="fas fa-tools"></i> Quick Actions</h3>
                </div>
                <div class="card-content">
                    <div class="action-grid">
                        <a href="api/data.php?action=system_status" class="action-btn" target="_blank">
                            <i class="fas fa-heartbeat"></i>
                            <span>System Status</span>
                        </a>
                        <a href="#" class="action-btn" onclick="refreshData()">
                            <i class="fas fa-sync-alt"></i>
                            <span>Refresh Data</span>
                        </a>
                        <a href="reports/" class="action-btn">
                            <i class="fas fa-folder-open"></i>
                            <span>Browse Reports</span>
                        </a>
                        <a href="#" class="action-btn" onclick="showProcessingLog()">
                            <i class="fas fa-list-alt"></i>
                            <span>Processing Log</span>
                        </a>
                    </div>
                </div>
            </div>
        </div>

        <footer class="footer">
            <p>&copy; 2025 AWStats Analytics Dashboard v2.0.0 | 
               Last updated: <?php echo date('Y-m-d H:i:s'); ?> | 
               Database: <?php echo file_exists($db_file) ? 'Connected' : 'Not Found'; ?>
            </p>
        </footer>
    </div>

    <script src="js/dashboard.js"></script>
    <script>
        function refreshData() {
            location.reload();
        }
        
        function showProcessingLog() {
            window.open('api/data.php?action=processing_log', '_blank');
        }
    </script>
</body>
</html>