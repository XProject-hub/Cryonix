@extends('layouts.app')

@section('title', 'Dashboard - Cryonix Panel')
@section('page-title', 'Dashboard')

@section('content')
<div class="row">
    <!-- Stats Cards -->
    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-primary shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">Total Users</div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalUsers">0</div>
                    </div>
                    <div class="col-auto">
                        <i class="bi bi-people fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-success shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-success text-uppercase mb-1">Active Streams</div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="activeStreams">0</div>
                    </div>
                    <div class="col-auto">
                        <i class="bi bi-play-circle fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-info shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-info text-uppercase mb-1">Active Lines</div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="activeLines">0</div>
                    </div>
                    <div class="col-auto">
                        <i class="bi bi-broadcast fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-warning shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">System Load</div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="systemLoad">0%</div>
                    </div>
                    <div class="col-auto">
                        <i class="bi bi-cpu fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row">
    <!-- Recent Activity -->
    <div class="col-lg-6 mb-4">
        <div class="card shadow">
            <div class="card-header py-3">
                <h6 class="m-0 font-weight-bold text-primary">Recent Activity</h6>
            </div>
            <div class="card-body">
                <div id="recentActivity">
                    <div class="text-center">
                        <div class="spinner-border" role="status">
                            <span class="visually-hidden">Loading...</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- System Health -->
    <div class="col-lg-6 mb-4">
        <div class="card shadow">
            <div class="card-header py-3">
                <h6 class="m-0 font-weight-bold text-primary">System Health</h6>
            </div>
            <div class="card-body">
                <div id="systemHealth">
                    <div class="text-center">
                        <div class="spinner-border" role="status">
                            <span class="visually-hidden">Loading...</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Live Connections Chart -->
<div class="row">
    <div class="col-lg-12 mb-4">
        <div class="card shadow">
            <div class="card-header py-3">
                <h6 class="m-0 font-weight-bold text-primary">Live Connections</h6>
            </div>
            <div class="card-body">
                <canvas id="connectionsChart" width="400" height="100"></canvas>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
document.addEventListener('DOMContentLoaded', function() {
    loadDashboardData();
    setInterval(loadDashboardData, 30000); // Refresh every 30 seconds
});

async function loadDashboardData() {
    try {
        // Load stats
        const statsResponse = await fetch('/api/v1/dashboard/stats', {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (statsResponse.ok) {
            const stats = await statsResponse.json();
            document.getElementById('totalUsers').textContent = stats.total_users;
            document.getElementById('activeStreams').textContent = stats.active_streams;
            document.getElementById('activeLines').textContent = stats.active_lines;
        }
        
        // Load recent activity
        const activityResponse = await fetch('/api/v1/dashboard/activity', {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (activityResponse.ok) {
            const activity = await activityResponse.json();
            renderRecentActivity(activity);
        }
        
        // Load system health
        const healthResponse = await fetch('/api/v1/dashboard/health', {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (healthResponse.ok) {
            const health = await healthResponse.json();
            renderSystemHealth(health);
        }
        
    } catch (error) {
        console.error('Error loading dashboard data:', error);
    }
}

function renderRecentActivity(activity) {
    const container = document.getElementById('recentActivity');
    let html = '<div class="list-group list-group-flush">';
    
    activity.recent_users.forEach(user => {
        html += `
            <div class="list-group-item">
                <div class="d-flex w-100 justify-content-between">
                    <h6 class="mb-1">New user: ${user.username}</h6>
                    <small>${formatDate(user.created_at)}</small>
                </div>
                <small>Role: ${user.role}</small>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

function renderSystemHealth(health) {
    const container = document.getElementById('systemHealth');
    let html = '';
    
    Object.entries(health).forEach(([key, value]) => {
        const statusClass = value.status === 'healthy' ? 'success' : 
                           value.status === 'warning' ? 'warning' : 'danger';
        
        html += `
            <div class="d-flex justify-content-between align-items-center mb-2">
                <span class="text-capitalize">${key.replace('_', ' ')}</span>
                <span class="badge bg-${statusClass}">${value.status}</span>
            </div>
        `;
    });
    
    container.innerHTML = html;
}

function formatDate(dateString) {
    return new Date(dateString).toLocaleString();
}
</script>
@endpush
