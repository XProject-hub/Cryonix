<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cryonix - Settings</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <?php include 'includes/navbar.php'; ?>
    
    <div class="container-fluid">
        <div class="row">
            <?php include 'includes/sidebar.php'; ?>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">System Settings</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button class="btn btn-success" id="updateCryonixBtn">
                            <i class="fas fa-sync-alt"></i> Update Cryonix
                        </button>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-lg-8">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">General Settings</h5>
                            </div>
                            <div class="card-body">
                                <form id="generalSettingsForm">
                                    <div class="mb-3">
                                        <label for="siteName" class="form-label">Site Name</label>
                                        <input type="text" class="form-control" id="siteName" value="Cryonix Panel">
                                    </div>
                                    <div class="mb-3">
                                        <label for="siteUrl" class="form-label">Site URL</label>
                                        <input type="url" class="form-control" id="siteUrl" value="http://localhost">
                                    </div>
                                    <div class="mb-3">
                                        <label for="adminEmail" class="form-label">Admin Email</label>
                                        <input type="email" class="form-control" id="adminEmail" value="admin@cryonix.local">
                                    </div>
                                    <div class="mb-3">
                                        <label for="timezone" class="form-label">Timezone</label>
                                        <select class="form-select" id="timezone">
                                            <option value="UTC">UTC</option>
                                            <option value="America/New_York">Eastern Time</option>
                                            <option value="America/Chicago">Central Time</option>
                                            <option value="America/Denver">Mountain Time</option>
                                            <option value="America/Los_Angeles">Pacific Time</option>
                                        </select>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Save General Settings</button>
                                </form>
                            </div>
                        </div>
                        
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">Streaming Settings</h5>
                            </div>
                            <div class="card-body">
                                <form id="streamingSettingsForm">
                                    <div class="mb-3">
                                        <label for="ffmpegPath" class="form-label">FFmpeg Path</label>
                                        <input type="text" class="form-control" id="ffmpegPath" value="/usr/bin/ffmpeg">
                                    </div>
                                    <div class="mb-3">
                                        <label for="streamBaseUrl" class="form-label">Stream Base URL</label>
                                        <input type="url" class="form-control" id="streamBaseUrl" value="http://localhost:8080">
                                    </div>
                                    <div class="mb-3">
                                        <label for="hlsOutputDir" class="form-label">HLS Output Directory</label>
                                        <input type="text" class="form-control" id="hlsOutputDir" value="/opt/cryonix/streams/">
                                    </div>
                                    <div class="mb-3">
                                        <label for="maxConcurrentStreams" class="form-label">Max Concurrent Streams</label>
                                        <input type="number" class="form-control" id="maxConcurrentStreams" value="100">
                                    </div>
                                    <div class="mb-3">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" id="autoRestart" checked>
                                            <label class="form-check-label" for="autoRestart">
                                                Auto-restart failed streams
                                            </label>
                                        </div>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Save Streaming Settings</button>
                                </form>
                            </div>
                        </div>
                        
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">Security Settings</h5>
                            </div>
                            <div class="card-body">
                                <form id="securitySettingsForm">
                                    <div class="mb-3">
                                        <label for="sessionTimeout" class="form-label">Session Timeout (seconds)</label>
                                        <input type="number" class="form-control" id="sessionTimeout" value="3600">
                                    </div>
                                    <div class="mb-3">
                                        <label for="maxLoginAttempts" class="form-label">Max Login Attempts</label>
                                        <input type="number" class="form-control" id="maxLoginAttempts" value="5">
                                    </div>
                                    <div class="mb-3">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" id="enableTwoFactor">
                                            <label class="form-check-label" for="enableTwoFactor">
                                                Enable Two-Factor Authentication
                                            </label>
                                        </div>
                                    </div>
                                    <div class="mb-3">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" id="forceHttps" checked>
                                            <label class="form-check-label" for="forceHttps">
                                                Force HTTPS
                                            </label>
                                        </div>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Save Security Settings</button>
                                </form>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-lg-4">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">System Information</h5>
                            </div>
                            <div class="card-body">
                                <div class="mb-3">
                                    <strong>Cryonix Version:</strong><br>
                                    <span class="text-muted">v1.0.0</span>
                                </div>
                                <div class="mb-3">
                                    <strong>PHP Version:</strong><br>
                                    <span class="text-muted"><?= phpversion() ?></span>
                                </div>
                                <div class="mb-3">
                                    <strong>Server OS:</strong><br>
                                    <span class="text-muted"><?= php_uname('s') . ' ' . php_uname('r') ?></span>
                                </div>
                                <div class="mb-3">
                                    <strong>Database:</strong><br>
                                    <span class="text-muted">MySQL <?= $db->query('SELECT VERSION()')->fetchColumn() ?></span>
                                </div>
                                <div class="mb-3">
                                    <strong>Uptime:</strong><br>
                                    <span class="text-muted" id="systemUptime">Loading...</span>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">Quick Actions</h5>
                            </div>
                            <div class="card-body">
                                <div class="d-grid gap-2">
                                    <button class="btn btn-outline-primary" id="clearCacheBtn">
                                        <i class="fas fa-broom"></i> Clear Cache
                                    </button>
                                    <button class="btn btn-outline-warning" id="restartServicesBtn">
                                        <i class="fas fa-redo"></i> Restart Services
                                    </button>
                                    <button class="btn btn-outline-info" id="backupDatabaseBtn">
                                        <i class="fas fa-database"></i> Backup Database
                                    </button>
                                    <button class="btn btn-outline-success" id="testStreamBtn">
                                        <i class="fas fa-play-circle"></i> Test Stream
                                    </button>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0">System Health</h5>
                            </div>
                            <div class="card-body">
                                <div class="mb-3">
                                    <div class="d-flex justify-content-between">
                                        <span>CPU Usage</span>
                                        <span id="cpuUsage">0%</span>
                                    </div>
                                    <div class="progress">
                                        <div class="progress-bar" id="cpuProgressBar" style="width: 0%"></div>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <div class="d-flex justify-content-between">
                                        <span>Memory Usage</span>
                                        <span id="memoryUsage">0%</span>
                                    </div>
                                    <div class="progress">
                                        <div class="progress-bar" id="memoryProgressBar" style="width: 0%"></div>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <div class="d-flex justify-content-between">
                                        <span>Disk Usage</span>
                                        <span id="diskUsage">0%</span>
                                    </div>
                                    <div class="progress">
                                        <div class="progress-bar" id="diskProgressBar" style="width: 0%"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/assets/js/app.js"></script>
    <script>
        // Load system health data
        async function loadSystemHealth() {
            try {
                const response = await fetch('/api/system-health.php');
                const data = await response.json();
                
                if (data.success) {
                    document.getElementById('cpuUsage').textContent = data.cpu + '%';
                    document.getElementById('cpuProgressBar').style.width = data.cpu + '%';
                    
                    document.getElementById('memoryUsage').textContent = data.memory + '%';
                    document.getElementById('memoryProgressBar').style.width = data.memory + '%';
                    
                    document.getElementById('diskUsage').textContent = data.disk + '%';
                    document.getElementById('diskProgressBar').style.width = data.disk + '%';
                }
            } catch (error) {
                console.error('Error loading system health:', error);
            }
        }
        
        // Load system health on page load and refresh every 30 seconds
        loadSystemHealth();
        setInterval(loadSystemHealth, 30000);
    </script>
</body>
</html>
