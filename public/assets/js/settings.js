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

// Initialize update manager when document is ready
document.addEventListener('DOMContentLoaded', () => {
    new UpdateManager();
});
