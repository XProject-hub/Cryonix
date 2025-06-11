class CryonixPanel {
    constructor() {
        this.apiBaseUrl = '/api/v1';
        this.authToken = localStorage.getItem('auth_token');
        this.init();
    }

    init() {
        this.setupThemeToggle();
        this.setupRefreshButton();
        this.setupAjaxDefaults();
        this.checkAuthStatus();
        this.setupNotifications();
        this.setupWebSocket();
    }

    setupThemeToggle() {
        const themeToggle = document.getElementById('themeToggle');
        const currentTheme = localStorage.getItem('theme') || 'dark';
        
        document.documentElement.setAttribute('data-bs-theme', currentTheme);
        this.updateThemeIcon(currentTheme);
        
        if (themeToggle) {
            themeToggle.addEventListener('click', () => {
                const newTheme = document.documentElement.getAttribute('data-bs-theme') === 'dark' ? 'light' : 'dark';
                document.documentElement.setAttribute('data-bs-theme', newTheme);
                localStorage.setItem('theme', newTheme);
                this.updateThemeIcon(newTheme);
            });
        }
    }

    updateThemeIcon(theme) {
        const themeToggle = document.getElementById('themeToggle');
        if (themeToggle) {
            const icon = themeToggle.querySelector('i');
            icon.className = theme === 'dark' ? 'bi bi-sun' : 'bi bi-moon';
        }
    }

    setupRefreshButton() {
        const refreshBtn = document.getElementById('refreshBtn');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => {
                this.refreshCurrentPage();
            });
        }
    }

    setupAjaxDefaults() {
        // Set default headers for all fetch requests
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
            if (args[1] && args[1].headers) {
                args[1].headers['X-Requested-With'] = 'XMLHttpRequest';
                if (localStorage.getItem('auth_token')) {
                    args[1].headers['Authorization'] = 'Bearer ' + localStorage.getItem('auth_token');
                }
            }
            return originalFetch.apply(this, args);
        };
    }

    async checkAuthStatus() {
        if (!this.authToken) {
            this.redirectToLogin();
            return;
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/me`, {
                headers: {
                    'Authorization': `Bearer ${this.authToken}`,
                    'Accept': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error('Authentication failed');
            }

            const user = await response.json();
            this.currentUser = user;
            this.updateUserInfo(user);
        } catch (error) {
            console.error('Auth check failed:', error);
            this.redirectToLogin();
        }
    }

    updateUserInfo(user) {
        const userElements = document.querySelectorAll('[data-user-info]');
        userElements.forEach(element => {
            const info = element.dataset.userInfo;
            if (user[info]) {
                element.textContent = user[info];
            }
        });
    }

    setupNotifications() {
        this.notifications = [];
        this.createNotificationContainer();
    }

    createNotificationContainer() {
        if (!document.getElementById('notificationContainer')) {
            const container = document.createElement('div');
            container.id = 'notificationContainer';
            container.className = 'position-fixed top-0 end-0 p-3';
            container.style.zIndex = '9999';
            document.body.appendChild(container);
        }
    }

    showNotification(message, type = 'info', duration = 5000) {
        const notification = document.createElement('div');
        notification.className = `toast align-items-center text-bg-${type} border-0 fade show`;
        notification.setAttribute('role', 'alert');
        notification.innerHTML = `
            <div class="d-flex">
                <div class="toast-body">
                    ${message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
            </div>
        `;

        document.getElementById('notificationContainer').appendChild(notification);

        // Auto remove after duration
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, duration);

        return notification;
    }

    setupWebSocket() {
        if (typeof WebSocket !== 'undefined') {
            this.connectWebSocket();
        }
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        try {
            this.ws = new WebSocket(wsUrl);
            
            this.ws.onopen = () => {
                console.log('WebSocket connected');
                this.wsConnected = true;
            };
            
            this.ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                this.handleWebSocketMessage(data);
            };
            
            this.ws.onclose = () => {
                console.log('WebSocket disconnected');
                this.wsConnected = false;
                // Reconnect after 5 seconds
                setTimeout(() => this.connectWebSocket(), 5000);
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        } catch (error) {
            console.error('WebSocket connection failed:', error);
        }
    }

    handleWebSocketMessage(data) {
        switch (data.type) {
            case 'notification':
                this.showNotification(data.message, data.level || 'info');
                break;
            case 'stream_status':
                this.updateStreamStatus(data.stream_id, data.status);
                break;
            case 'system_stats':
                this.updateSystemStats(data.stats);
                break;
            default:
                console.log('Unknown WebSocket message:', data);
        }
    }

    updateStreamStatus(streamId, status) {
        const statusElements = document.querySelectorAll(`[data-stream-id="${streamId}"] .stream-status`);
        statusElements.forEach(element => {
            element.className = `badge bg-${status === 'running' ? 'success' : 'danger'}`;
            element.textContent = status === 'running' ? 'Active' : 'Inactive';
        });
    }

    updateSystemStats(stats) {
        Object.entries(stats).forEach(([key, value]) => {
            const element = document.getElementById(key);
            if (element) {
                element.textContent = value;
            }
        });
    }

    async apiRequest(endpoint, options = {}) {
        const url = endpoint.startsWith('http') ? endpoint : `${this.apiBaseUrl}${endpoint}`;
        
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            }
        };

        if (this.authToken) {
            defaultOptions.headers['Authorization'] = `Bearer ${this.authToken}`;
        }

        const mergedOptions = {
            ...defaultOptions,
            ...options,
            headers: {
                ...defaultOptions.headers,
                ...options.headers
            }
        };

        try {
            const response = await fetch(url, mergedOptions);
            
            if (response.status === 401) {
                this.redirectToLogin();
                throw new Error('Unauthorized');
            }

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const contentType = response.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                return await response.json();
            }
            
            return await response.text();
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    redirectToLogin() {
        localStorage.removeItem('auth_token');
        window.location.href = '/login';
    }

    refreshCurrentPage() {
        const refreshBtn = document.getElementById('refreshBtn');
        if (refreshBtn) {
            const icon = refreshBtn.querySelector('i');
            icon.classList.add('fa-spin');
            
            setTimeout(() => {
                icon.classList.remove('fa-spin');
            }, 1000);
        }

        // Trigger page-specific refresh
        if (typeof window.refreshPageData === 'function') {
            window.refreshPageData();
        } else {
            window.location.reload();
        }
    }

    formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }

    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}h ${minutes}m ${secs}s`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleString();
    }

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    async confirmAction(message, title = 'Confirm Action') {
        return new Promise((resolve) => {
            const modal = document.createElement('div');
            modal.className = 'modal fade';
            modal.innerHTML = `
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">${title}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <p>${message}</p>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="button" class="btn btn-danger" id="confirmBtn">Confirm</button>
                        </div>
                    </div>
                </div>
            `;

            document.body.appendChild(modal);
            const bsModal = new bootstrap.Modal(modal);
            
            modal.querySelector('#confirmBtn').addEventListener('click', () => {
                resolve(true);
                bsModal.hide();
            });

            modal.addEventListener('hidden.bs.modal', () => {
                resolve(false);
                modal.remove();
            });

            bsModal.show();
        });
    }
}

// Stream Management Functions
class StreamManager {
    constructor(cryonixPanel) {
        this.panel = cryonixPanel;
    }

    async startStream(streamId, profile = 'medium') {
        try {
            const stream = await this.panel.apiRequest(`/streams/${streamId}`);
            
            const response = await fetch('http://localhost:8000/stream/start', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    stream_id: streamId.toString(),
                    input_url: stream.stream_url,
                    output_url: `rtmp://localhost/live/${stream.stream_key}`,
                    profile: this.getTranscodingProfile(profile)
                })
            });

            if (response.ok) {
                this.panel.showNotification(`Stream ${stream.name} started successfully`, 'success');
                return await response.json();
            } else {
                throw new Error('Failed to start stream');
            }
        } catch (error) {
            this.panel.showNotification(`Failed to start stream: ${error.message}`, 'danger');
            throw error;
        }
    }

    async stopStream(streamId) {
        try {
            const response = await fetch(`http://localhost:8000/stream/stop/${streamId}`, {
                method: 'POST'
            });

            if (response.ok) {
                this.panel.showNotification('Stream stopped successfully', 'success');
                return await response.json();
            } else {
                throw new Error('Failed to stop stream');
            }
        } catch (error) {
            this.panel.showNotification(`Failed to stop stream: ${error.message}`, 'danger');
            throw error;
        }
    }

    async getStreamStatus(streamId) {
        try {
            const response = await fetch(`http://localhost:8000/stream/status/${streamId}`);
            return await response.json();
        } catch (error) {
            console.error('Failed to get stream status:', error);
            return { status: 'unknown' };
        }
    }

    getTranscodingProfile(profileName) {
        const profiles = {
            'low': {
                'video_codec': 'libx264',
                'audio_codec': 'aac',
                'video_bitrate': '1000k',
                'audio_bitrate': '96k',
                'resolution': '854x480'
            },
            'medium': {
                'video_codec': 'libx264',
                'audio_codec': 'aac',
                'video_bitrate': '2000k',
                'audio_bitrate': '128k',
                'resolution': '1280x720'
            },
            'high': {
                'video_codec': 'libx264',
                'audio_codec': 'aac',
                'video_bitrate': '4000k',
                'audio_bitrate': '192k',
                'resolution': '1920x1080'
            }
        };

        return profiles[profileName] || profiles['medium'];
    }
}

// Initialize Cryonix Panel
document.addEventListener('DOMContentLoaded', function() {
    window.cryonixPanel = new CryonixPanel();
    window.streamManager = new StreamManager(window.cryonixPanel);
    
    // Global utility functions
    window.showAlert = function(message, type = 'info') {
        window.cryonixPanel.showNotification(message, type);
    };
    
    window.confirmDelete = async function(message = 'Are you sure you want to delete this item?') {
        return await window.cryonixPanel.confirmAction(message, 'Confirm Delete');
    };
    
    window.formatBytes = window.cryonixPanel.formatBytes;
    window.formatDuration = window.cryonixPanel.formatDuration;
    window.formatDate = window.cryonixPanel.formatDate;
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { CryonixPanel, StreamManager };
}
