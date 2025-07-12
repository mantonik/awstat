/*
    AWStats Dashboard JavaScript
    File: htdocs/js/dashboard.js
    Version: 2.0.1
    Purpose: Interactive functionality for dashboard
    Changes: v2.0.1 - Enhanced error handling and performance improvements
*/

class AWStatsDashboard {
    constructor() {
        this.apiEndpoint = 'api/data.php';
        this.refreshInterval = 5 * 60 * 1000; // 5 minutes
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.startAutoRefresh();
        this.addLoadingStates();
        this.enhanceAnimations();
        this.initializeTooltips();
    }

    setupEventListeners() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupCardHovers();
            this.setupActionButtons();
            this.setupKeyboardShortcuts();
        });
    }

    setupCardHovers() {
        const cards = document.querySelectorAll('.card');
        cards.forEach(card => {
            card.addEventListener('mouseenter', (e) => {
                this.animateCard(e.target, 'enter');
            });
            
            card.addEventListener('mouseleave', (e) => {
                this.animateCard(e.target, 'leave');
            });
        });
    }

    setupActionButtons() {
        const actionBtns = document.querySelectorAll('.action-btn');
        actionBtns.forEach(btn => {
            const originalIcon = btn.querySelector('i').className;
            btn.setAttribute('data-original-icon', originalIcon);
            
            btn.addEventListener('click', (e) => {
                this.handleActionClick(e);
            });
        });
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl+R or F5 for refresh
            if ((e.ctrlKey && e.key === 'r') || e.key === 'F5') {
                e.preventDefault();
                this.refreshDashboardData();
            }
            
            // Escape to close notifications
            if (e.key === 'Escape') {
                this.closeAllNotifications();
            }
        });
    }

    initializeTooltips() {
        const statusIndicators = document.querySelectorAll('.status-indicator');
        statusIndicators.forEach(indicator => {
            const isOnline = indicator.classList.contains('online');
            const tooltip = isOnline ? 'Service is running normally' : 'Service needs attention';
            indicator.setAttribute('title', tooltip);
            indicator.setAttribute('aria-label', tooltip);
        });
    }

    animateCard(card, action) {
        if (action === 'enter') {
            card.style.transform = 'translateY(-4px) scale(1.01)';
            card.style.boxShadow = '0 25px 50px -12px rgba(0, 0, 0, 0.25)';
        } else {
            card.style.transform = 'translateY(0) scale(1)';
            card.style.boxShadow = '0 10px 15px -3px rgba(0, 0, 0, 0.1)';
        }
    }

    handleActionClick(e) {
        const button = e.currentTarget;
        const icon = button.querySelector('i');
        const originalIcon = button.getAttribute('data-original-icon');
        
        // Don't process if already loading
        if (button.classList.contains('loading')) {
            return;
        }
        
        // Add loading state
        button.classList.add('loading');
        if (icon) {
            icon.className = 'fas fa-spinner fa-spin';
            button.style.pointerEvents = 'none';
            
            // Reset after animation
            setTimeout(() => {
                icon.className = 'fas fa-check';
                button.classList.remove('loading');
                button.style.pointerEvents = 'auto';
                
                // Reset to original icon after success indication
                setTimeout(() => {
                    if (originalIcon) {
                        icon.className = originalIcon;
                    }
                }, 1000);
            }, 1500);
        }
    }

    startAutoRefresh() {
        // Auto-refresh data every 5 minutes
        setInterval(() => {
            this.refreshDashboardData();
        }, this.refreshInterval);
        
        // Show auto-refresh indicator
        this.showAutoRefreshIndicator();
    }

    showAutoRefreshIndicator() {
        const footer = document.querySelector('.footer p');
        if (footer) {
            const refreshText = document.createElement('span');
            refreshText.className = 'auto-refresh-indicator';
            refreshText.innerHTML = ' | Auto-refresh: <span class="refresh-countdown">5:00</span>';
            footer.appendChild(refreshText);
            
            this.startRefreshCountdown();
        }
    }

    startRefreshCountdown() {
        let timeLeft = this.refreshInterval / 1000; // Convert to seconds
        
        const countdownElement = document.querySelector('.refresh-countdown');
        if (!countdownElement) return;
        
        const updateCountdown = () => {
            const minutes = Math.floor(timeLeft / 60);
            const seconds = timeLeft % 60;
            countdownElement.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
            
            if (timeLeft > 0) {
                timeLeft--;
                setTimeout(updateCountdown, 1000);
            } else {
                timeLeft = this.refreshInterval / 1000; // Reset
                setTimeout(updateCountdown, 1000);
            }
        };
        
        updateCountdown();
    }

    async refreshDashboardData() {
        try {
            this.showNotification('Refreshing dashboard data...', 'info');
            
            const data = await this.fetchData('dashboard_stats');
            this.updateDashboardStats(data);
            this.showNotification('Dashboard updated successfully', 'success');
            
        } catch (error) {
            console.error('Failed to refresh data:', error);
            this.showNotification('Failed to refresh data', 'error');
        }
    }

    async fetchData(action, params = {}) {
        const url = new URL(this.apiEndpoint, window.location.origin);
        url.searchParams.append('action', action);
        
        Object.keys(params).forEach(key => {
            url.searchParams.append(key, params[key]);
        });

        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        return await response.json();
    }

    updateDashboardStats(data) {
        // Update domain statistics
        if (data.domains) {
            data.domains.forEach(domain => {
                this.updateDomainCard(domain);
            });
        }

        // Update recent activity
        if (data.recent_activity) {
            this.updateRecentActivity(data.recent_activity);
        }

        // Update last updated timestamp
        const timestamp = document.querySelector('.footer p');
        if (timestamp) {
            const now = new Date().toLocaleString();
            timestamp.innerHTML = timestamp.innerHTML.replace(/Last updated: [^|]+/, `Last updated: ${now}`);
        }
    }

    updateDomainCard(domainData) {
        const domainCards = document.querySelectorAll('.domain-item');
        domainCards.forEach(card => {
            const domainNameElement = card.querySelector('.domain-name');
            if (domainNameElement && domainNameElement.textContent === domainData.domain_name) {
                // Update statistics with animation
                const stats = card.querySelectorAll('.stat-value');
                if (stats.length >= 3) {
                    this.animateNumberChange(stats[0], domainData.total_hits);
                    this.animateNumberChange(stats[1], domainData.server_count);
                    this.animateNumberChange(stats[2], domainData.days_with_data);
                }
                
                // Add update animation
                card.style.background = 'rgba(37, 99, 235, 0.1)';
                setTimeout(() => {
                    card.style.background = '';
                }, 1000);
            }
        });
    }

    animateNumberChange(element, newValue) {
        const currentValue = parseInt(element.textContent.replace(/,/g, '')) || 0;
        const formattedNewValue = this.formatNumber(newValue);
        
        if (currentValue !== newValue) {
            element.style.transform = 'scale(1.1)';
            element.style.color = 'var(--success-color)';
            
            setTimeout(() => {
                element.textContent = formattedNewValue;
                element.style.transform = 'scale(1)';
                element.style.color = '';
            }, 200);
        }
    }

    updateRecentActivity(activities) {
        const activityList = document.querySelector('.activity-list');
        if (activityList && activities.length > 0) {
            // Fade out current activities
            activityList.style.opacity = '0.5';
            
            setTimeout(() => {
                // Clear current activities
                activityList.innerHTML = '';
                
                // Add new activities
                activities.slice(0, 5).forEach((activity, index) => {
                    const activityItem = this.createActivityItem(activity);
                    activityItem.style.animationDelay = `${index * 100}ms`;
                    activityList.appendChild(activityItem);
                });
                
                // Fade in
                activityList.style.opacity = '1';
            }, 300);
        }
    }

    createActivityItem(activity) {
        const item = document.createElement('div');
        item.className = 'activity-item animate-in';
        
        item.innerHTML = `
            <div class="activity-icon">
                <i class="fas fa-api"></i>
            </div>
            <div class="activity-info">
                <span class="activity-endpoint">${this.escapeHtml(activity.api_endpoint)}</span>
                <span class="activity-details">
                    ${this.escapeHtml(activity.server_name)} • 
                    ${this.formatNumber(activity.hits)} hits • 
                    ${this.formatDateTime(activity.processed_at)}
                </span>
            </div>
        `;
        
        return item;
    }

    addLoadingStates() {
        const cards = document.querySelectorAll('.card-content');
        cards.forEach(card => {
            if (card.children.length === 0) {
                this.showLoadingState(card);
            }
        });
    }

    showLoadingState(container) {
        const loader = document.createElement('div');
        loader.className = 'loading-state';
        loader.innerHTML = `
            <div class="spinner">
                <i class="fas fa-spinner fa-spin"></i>
            </div>
            <p>Loading data...</p>
        `;
        container.appendChild(loader);
    }

    enhanceAnimations() {
        // Add intersection observer for scroll animations
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.animationDelay = `${entry.target.dataset.delay || 0}ms`;
                    entry.target.classList.add('animate-in');
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '50px'
        });

        document.querySelectorAll('.card').forEach((card, index) => {
            card.dataset.delay = index * 100;
            observer.observe(card);
        });
    }

    showNotification(message, type = 'info') {
        // Remove existing notifications of the same type
        document.querySelectorAll(`.notification-${type}`).forEach(notification => {
            notification.remove();
        });
        
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <i class="fas fa-${this.getNotificationIcon(type)}"></i>
                <span>${this.escapeHtml(message)}</span>
            </div>
            <button class="notification-close" onclick="this.parentElement.remove()">
                <i class="fas fa-times"></i>
            </button>
        `;

        // Add to page
        document.body.appendChild(notification);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 5000);

        // Animate in
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);
    }

    closeAllNotifications() {
        document.querySelectorAll('.notification').forEach(notification => {
            notification.remove();
        });
    }

    getNotificationIcon(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || icons.info;
    }

    formatNumber(num) {
        return new Intl.NumberFormat().format(num);
    }

    formatDateTime(dateString) {
        const date = new Date(dateString);
        return date.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// API Helper Functions
class APIHelper {
    static async fetchData(endpoint, params = {}) {
        const url = new URL(endpoint, window.location.origin);
        Object.keys(params).forEach(key => {
            url.searchParams.append(key, params[key]);
        });

        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    static async getSystemStatus() {
        return this.fetchData('api/data.php', { action: 'system_status' });
    }

    static async getDomainStats(domain) {
        return this.fetchData('api/data.php', { action: 'domain_stats', domain });
    }

    static async getProcessingLog(limit = 50) {
        return this.fetchData('api/data.php', { action: 'processing_log', limit });
    }
}

// Global functions for inline event handlers
window.refreshData = function() {
    if (window.dashboard) {
        window.dashboard.refreshDashboardData();
    } else {
        location.reload();
    }
};

window.showProcessingLog = function() {
    APIHelper.getProcessingLog().then(data => {
        const popup = window.open('', '_blank', 'width=800,height=600,scrollbars=yes');
        popup.document.write(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Processing Log</title>
                <link rel="stylesheet" href="css/style.css">
                <style>
                    body { padding: 20px; }
                    .log-entry { margin: 10px 0; padding: 15px; background: var(--surface-color); border-radius: 8px; border-left: 4px solid var(--primary-color); }
                    .log-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
                    .log-status { font-weight: bold; padding: 4px 8px; border-radius: 4px; font-size: 0.875rem; }
                    .log-status.completed { background: var(--success-color); color: white; }
                    .log-status.failed { background: var(--error-color); color: white; }
                    .log-status.pending { background: var(--warning-color); color: white; }
                    .log-status.processing { background: var(--primary-color); color: white; }
                    .log-details { font-size: 0.875rem; color: var(--text-muted); }
                </style>
            </head>
            <body>
                <h1><i class="fas fa-list-alt"></i> Processing Log</h1>
                <p>Recent log processing activity</p>
                <div id="log-entries">
                    ${data.length > 0 ? data.map(entry => `
                        <div class="log-entry">
                            <div class="log-header">
                                <div>
                                    <strong>${entry.domain_name || 'Unknown Domain'}</strong> • 
                                    <span>${entry.server_name || 'Unknown Server'}</span>
                                </div>
                                <div class="log-status ${entry.processing_status}">${entry.processing_status.toUpperCase()}</div>
                            </div>
                            <div class="log-details">
                                <div><strong>File:</strong> ${entry.log_file_path}</div>
                                <div><strong>Records:</strong> ${new Intl.NumberFormat().format(entry.records_## File: htdocs/css/style.css
```css
/*
    AWStats Dashboard Styles
    File: htdocs/css/style.css
    Version: 2.0.1
    Purpose: Modern, responsive styling for AWStats dashboard
    Changes: v2.0.1 - Enhanced notifications and responsive improvements
*/

/* CSS Custom Properties for theming */
:root {
    --primary-color: #2563eb;
    --primary-dark: #1d4ed8;
    --secondary-color: #64748b;
    --success-color: #10b981;
    --warning-color: #f59e0b;
    --error-color: #ef4444;
    --background-color: #0f172a;
    --surface-color: #1e293b;
    --surface-light: #334155;
    --text-primary: #f8fafc;
    --text-secondary: #cbd5e1;
    --text-muted: #94a3b8;
    --border-color: #334155;
    --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
    --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    --border-radius: 8px;
    --border-radius-lg: 12px;
    --transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

/* Reset and base styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {