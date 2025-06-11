// Cryonix Application JavaScript
class CryonixApp {
    constructor() {
        this.init();
        this.bindEvents();
        this.loadDashboardData();
    }

    init() {
        // Initialize theme
        const savedTheme = localStorage.getItem('cryonix-theme') || 'dark';
        document.documentElement.setAttribute('data-theme', savedTheme);
        
        // Initialize tooltips
        const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
        tooltipTriggerList.map(function (tooltipTriggerEl) {
            return new bootstrap.Tooltip(tooltipTriggerEl);
        });
    }

    bindEvents() {
        // Theme toggle
        const themeToggle = document.getElementById('themeToggle');
        if (themeToggle) {
            themeToggle.addEventListener('click', () => this.toggleTheme());
        }

        // Search functionality
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => this.handleSearch(e.target.value));
        }

        // Channel management
        this.bindChannelEvents();
        
        // User management
        this.bindUserEvents();
    }

    toggleTheme() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
                document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('cryonix-theme', newTheme);
        
        // Update theme toggle icon
        const themeToggle = document.getElementById('themeToggle');
        const icon = themeToggle.querySelector('i');
        icon.className = newTheme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    }

    handleSearch(query) {
        // Implement search functionality
        console.log('Searching for:', query);
        // Add your search logic here
    }

    bindChannelEvents() {
        // Add channel button
        const addChannelBtn = document.getElementById('addChannelBtn');
        if (addChannelBtn) {
            addChannelBtn.addEventListener('click', () => this.showAddChannelModal());
        }

        // Edit channel buttons
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('edit-channel-btn')) {
                const channelId = e.target.dataset.channelId;
                this.editChannel(channelId);
            }
            
            if (e.target.classList.contains('delete-channel-btn')) {
                const channelId = e.target.dataset.channelId;
                this.deleteChannel(channelId);
            }
        });
    }

    bindUserEvents() {
        // Add user button
        const addUserBtn = document.getElementById('addUserBtn');
        if (addUserBtn) {
            addUserBtn.addEventListener('click', () => this.showAddUserModal());
        }

        // Edit user buttons
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('edit-user-btn')) {
                const userId = e.target.dataset.userId;
                this.editUser(userId);
            }
            
            if (e.target.classList.contains('delete-user-btn')) {
                const userId = e.target.dataset.userId;
                this.deleteUser(userId);
            }
        });
    }

    async loadDashboardData() {
        try {
            // Load dashboard statistics
            const response = await fetch('/api/dashboard.php');
            const data = await response.json();
            
            if (data.success) {
                this.updateDashboardStats(data.stats);
            }
        } catch (error) {
            console.error('Error loading dashboard data:', error);
        }
    }

    updateDashboardStats(stats) {
        document.getElementById('activeChannels').textContent = stats.channels || 0;
        document.getElementById('activeUsers').textContent = stats.users || 0;
        document.getElementById('liveStreams').textContent = stats.streams || 0;
        document.getElementById('systemLoad').textContent = (stats.load || 0) + '%';
    }

    async showAddChannelModal() {
        const modal = new bootstrap.Modal(document.getElementById('addChannelModal'));
        modal.show();
    }

    async addChannel(formData) {
        try {
            const response = await fetch('/api/channels.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(formData)
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showNotification('Channel added successfully', 'success');
                this.loadChannels();
            } else {
                this.showNotification(result.message, 'error');
            }
        } catch (error) {
            this.showNotification('Error adding channel', 'error');
        }
    }

    async editChannel(channelId) {
        // Implementation for editing channel
        console.log('Editing channel:', channelId);
    }

    async deleteChannel(channelId) {
        if (confirm('Are you sure you want to delete this channel?')) {
            try {
                const response = await fetch('/api/channels.php', {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ id: channelId })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    this.showNotification('Channel deleted successfully', 'success');
                    this.loadChannels();
                } else {
                    this.showNotification(result.message, 'error');
                }
            } catch (error) {
                this.showNotification('Error deleting channel', 'error');
            }
        }
    }

    async loadChannels() {
        try {
            const response = await fetch('/api/channels.php');
            const data = await response.json();
            
            if (data.success) {
                this.renderChannels(data.data);
            }
        } catch (error) {
            console.error('Error loading channels:', error);
        }
    }

    renderChannels(channels) {
        const channelsContainer = document.getElementById('channelsContainer');
        if (!channelsContainer) return;
        
        channelsContainer.innerHTML = channels.map(channel => `
            <div class="col-md-6 col-lg-4 mb-4">
                <div class="card h-100">
                    <div class="card-body">
                        <h5 class="card-title">${channel.name}</h5>
                        <p class="card-text">${channel.category || 'No category'}</p>
                        <div class="d-flex justify-content-between">
                            <button class="btn btn-sm btn-outline-primary edit-channel-btn" data-channel-id="${channel.id}">
                                <i class="fas fa-edit"></i> Edit
                            </button>
                            <button class="btn btn-sm btn-outline-danger delete-channel-btn" data-channel-id="${channel.id}">
                                <i class="fas fa-trash"></i> Delete
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `alert alert-${type === 'error' ? 'danger' : type} alert-dismissible fade show position-fixed`;
        notification.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
        notification.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 5000);
    }

    // Stream management methods
    async startStream(channelId) {
        try {
            const response = await fetch('/api/streams.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ action: 'start', channel_id: channelId })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showNotification('Stream started successfully', 'success');
            } else {
                this.showNotification(result.message, 'error');
            }
        } catch (error) {
            this.showNotification('Error starting stream', 'error');
        }
    }

    async stopStream(streamId) {
        try {
            const response = await fetch('/api/streams.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ action: 'stop', stream_id: streamId })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showNotification('Stream stopped successfully', 'success');
            } else {
                this.showNotification(result.message, 'error');
            }
        } catch (error) {
            this.showNotification('Error stopping stream', 'error');
        }
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new CryonixApp();
});

// Utility functions
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function formatDuration(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

