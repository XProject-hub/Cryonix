<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cryonix - Settings</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/style.css">
    <style>
        .update-log {
            max-height: 400px;
            overflow-y: auto;
            padding: 15px;
            background: rgba(0, 0, 0, 0.05);
            border-radius: 5px;
            margin-top: 15px;
        }

        .update-step {
            margin-bottom: 10px;
            padding: 10px;
            border-radius: 5px;
            background: rgba(255, 255, 255, 0.5);
        }

        .update-step pre {
            margin-top: 5px;
            padding: 10px;
            background: rgba(0, 0, 0, 0.05);
            border-radius: 3px;
            font-size: 12px;
            white-space: pre-wrap;
        }
    </style>
</head>
<body>
    <?php include 'includes/navbar.php'; ?>
    
    <div class="container-fluid">
        <div class="row">
            <?php include 'includes/sidebar.php'; ?>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">System Settings</h1>
                </div>
                
                <div class="row">
                    <div class="col-lg-8">
                        <!-- System Update Card -->
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">System Update</h5>
                            </div>
                            <div class="card-body">
                                <div class="d-grid gap-2">
                                    <button class="btn btn-primary" id="updateCryonixBtn">
                                        <i class="fas fa-sync-alt"></i> Update Cryonix
                                    </button>
                                    <div id="updateStatus"></div>
                                </div>
                            </div>
                        </div>

                        <!-- General Settings Card -->
                        <div class="card mb-4">
                            <!-- ... rest of your general settings card content ... -->
                        </div>
                        
                        <!-- Streaming Settings Card -->
                        <div class="card mb-4">
                            <!-- ... rest of your streaming settings card content ... -->
                        </div>
                        
                        <!-- Security Settings Card -->
                        <div class="card mb-4">
                            <!-- ... rest of your security settings card content ... -->
                        </div>
                    </div>
                    
                    <div class="col-lg-4">
                        <!-- System Information Card -->
                        <div class="card mb-4">
                            <!-- ... rest of your system information card content ... -->
                        </div>
                        
                        <!-- Quick Actions Card -->
                        <div class="card mb-4">
                            <!-- ... rest of your quick actions card content ... -->
                        </div>
                        
                        <!-- System Health Card -->
                        <div class="card">
                            <!-- ... rest of your system health card content ... -->
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/assets/js/app.js"></script>
    <script>
        // Update Manager Class
        class UpdateManager {
            constructor() {
                this.updateBtn = document.getElementById('updateCryonixBtn');
                this.updateStatus = document.getElementById('updateStatus');
                this.bindEvents();
            }

            bindEvents() {
                if (this.updateBtn) {
                    this.updateBtn.addEventListener('click', () => this.performUpdate());
                }
            }

            async performUpdate() {
                try {
                    this.updateBtn.disabled = true;
                    this.updateStatus.innerHTML = '<div class="alert alert-info">Starting update process...</div>';

                    const response = await fetch('/api/update.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        }
                    });

                    const result = await response.json();
                    
                    let statusHtml = '<div class="update-log">';
                    
                    result.steps.forEach(step => {
                        const icon = step.status === 'success' ? '✅' : '❌';
                        const className = step.status === 'success' ? 'text-success' : 'text-danger';
                        
                        statusHtml += `
                            <div class="update-step ${className}">
                                <strong>${icon} ${step.step}:</strong> 
                                ${step.message ? `<br><pre>${step.message}</pre>` : ''}
                            </div>
                        `;
                    });
                    
                    statusHtml += '</div>';
                    
                    if (result.success) {
                        statusHtml = `
                            <div class="alert alert-success">
                                <h4 class="alert-heading">Update Completed Successfully!</h4>
                                <p>Current version: ${result.version}</p>
                                ${statusHtml}
                            </div>
                        `;
                    } else {
                        statusHtml = `
                            <div class="alert alert-danger">
                                <h4 class="alert-heading">Update Failed</h4>
                                <p>Please check the logs below for details:</p>
                                ${statusHtml}
                            </div>
                        `;
                    }
                    
                    this.updateStatus.innerHTML = statusHtml;
                } catch (error) {
                    this.updateStatus.innerHTML = `
                        <div class="alert alert-danger">
                            <h4 class="alert-heading">Error</h4>
                            <p>${error.message}</p>
                        </div>
                    `;
                } finally {
                    this.updateBtn.disabled = false;
                }
            }
        }

        // Initialize Update Manager
        document.addEventListener('DOMContentLoaded', () => {
            new UpdateManager();
        });

        // System Health Monitoring
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
