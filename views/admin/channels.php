<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cryonix - Channel Management</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background: #0d1117; color: #c9d1d9; }
        .card { background: #161b22; border: 1px solid #30363d; }
        .navbar { background: #161b22 !important; border-bottom: 1px solid #30363d; }
        .table-dark { --bs-table-bg: #161b22; }
        .neon-accent { color: #00d4ff; text-shadow: 0 0 10px #00d4ff; }
        .modal-content { background: #161b22; border: 1px solid #30363d; }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark">
        <div class="container-fluid">
            <a class="navbar-brand neon-accent" href="#">🚀 Cryonix</a>
            <div class="navbar-nav ms-auto">
                <a class="nav-link" href="/dashboard">Dashboard</a>
                <a class="nav-link active" href="/channels">Channels</a>
                <a class="nav-link" href="/users">Users</a>
                <a class="nav-link" href="/settings">Settings</a>
            </div>
        </div>
    </nav>

    <div class="container-fluid mt-4">
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <h5 class="mb-0">Channel Management</h5>
                        <div>
                            <button class="btn btn-success btn-sm" data-bs-toggle="modal" data-bs-target="#addChannelModal">
                                ➕ Add Channel
                            </button>
                            <button class="btn btn-info btn-sm" onclick="importM3U()">
                                📥 Import M3U
                            </button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <input type="text" class="form-control" id="searchChannels" placeholder="🔍 Search channels...">
                            </div>
                            <div class="col-md-3">
                                <select class="form-select" id="filterCategory">
                                    <option value="">All Categories</option>
                                    <option value="sports">Sports</option>
                                    <option value="movies">Movies</option>
                                    <option value="news">News</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <select class="form-select" id="filterStatus">
                                    <option value="">All Status</option>
                                    <option value="1">Active</option>
                                    <option value="0">Inactive</option>
                                </select>
                            </div>
                        </div>
                        
                        <table class="table table-dark table-hover">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>URL</th>
                                    <th>Category</th>
                                    <th>Status</th>
                                    <th>Viewers</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody id="channelsTable">
                                <!-- Dynamic content -->
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Add Channel Modal -->
    <div class="modal fade" id="addChannelModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Add New Channel</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <form id="addChannelForm">
                        <div class="mb-3">
                            <label class="form-label">Channel Name</label>
                            <input type="text" class="form-control" name="name" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Stream URL</label>
                            <input type="url" class="form-control" name="stream_url" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Type</label>
                            <select class="form-select" name="type" required>
                                <option value="live">Live TV</option>
                                <option value="vod">Video on Demand</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Category</label>
                            <select class="form-select" name="category_id" required>
                                <option value="1">Sports</option>
                                <option value="2">Movies</option>
                                <option value="3">News</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Quality</label>
                            <select class="form-select" name="quality">
                                <option value="480p">480p</option>
                                <option value="720p" selected>720p</option>
                                <option value="1080p">1080p</option>
                            </select>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" onclick="saveChannel()">Save Channel</button>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        async function loadChannels() {
            try {
                const response = await fetch('/api/channels');
                const data = await response.json();
                
                const tbody = document.getElementById('channelsTable');
                tbody.innerHTML = '';
                
                data.data.forEach(channel => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${channel.name}</td>
                        <td><small>${channel.stream_url.substring(0, 50)}...</small></td>
                        <td><span class="badge bg-info">${channel.category || 'Uncategorized'}</span></td>
                        <td><span class="badge bg-${channel.status ? 'success' : 'danger'}">
                            ${channel.status ? 'Active' : 'Inactive'}
                        </span></td>
                        <td>${channel.viewers || 0}</td>
                        <td>
                            <button class="btn btn-sm btn-warning" onclick="editChannel(${channel.id})">✏️</button>
                            <button class="btn btn-sm btn-danger" onclick="deleteChannel(${channel.id})">🗑️</button>
                            <button class="btn btn-sm btn-info" onclick="testStream(${channel.id})">🔍</button>
                        </td>
                    `;
                    tbody.appendChild(row);
                });
            } catch (error) {
                console.error('Failed to load channels:', error);
            }
        }

        async function saveChannel() {
            const form = document.getElementById('addChannelForm');
            const formData = new FormData(form);
            const data = Object.fromEntries(formData);
            data.status = 1;

            try {
                const response = await fetch('/api/channels', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    bootstrap.Modal.getInstance(document.getElementById('addChannelModal')).hide();
                    form.reset();
                    loadChannels();
                }
            } catch (error) {
                console.error('Failed to save channel:', error);
            }
        }

        async function deleteChannel(id) {
            if (confirm('Are you sure you want to delete this channel?')) {
                try {
                    const response = await fetch(`/api/channels/${id}`, {
                        method: 'DELETE'
                    });
                    
                    if (response.ok) {
                        loadChannels();
                    }
                } catch (error) {
                    console.error('Failed to delete channel:', error);
                }
            }
        }

        function importM3U() {
            // M3U import functionality
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = '.m3u,.m3u8';
            input.onchange = handleM3UFile;
            input.click();
        }

        function handleM3UFile(event) {
            const file = event.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    parseM3U(e.target.result);
                };
                reader.readAsText(file);
            }
        }

        function parseM3U(content) {
            const lines = content.split('\n');
            const channels = [];
            
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith('#EXTINF:')) {
                    const name = lines[i].split(',')[1];
                    const url = lines[i + 1];
                    if (name && url) {
                        channels.push({ name: name.trim(), stream_url: url.trim() });
                    }
                }
            }
            
            // Bulk import channels
            channels.forEach(channel => {
                fetch('/api/channels', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        ...channel,
                        type: 'live',
                        category_id: 1,
                        status: 1
                    })
                });
            });
            
            setTimeout(loadChannels, 2000);
        }

        // Search and filter functionality
        document.getElementById('searchChannels').addEventListener('input', filterChannels);
        document.getElementById('filterCategory').addEventListener('change', filterChannels);
        document.getElementById('filterStatus').addEventListener('change', filterChannels);

        function filterChannels() {
            // Filter implementation
            loadChannels();
        }

        document.addEventListener('DOMContentLoaded', loadChannels);
    </script>
</body>
</html>
