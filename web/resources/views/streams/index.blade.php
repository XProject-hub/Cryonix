@extends('layouts.app')

@section('title', 'Manage Streams - Cryonix Panel')
@section('page-title', 'Manage Streams')

@section('content')
<div class="row mb-3">
    <div class="col-md-6">
        <div class="input-group">
            <input type="text" class="form-control" placeholder="Search streams..." id="searchInput">
            <button class="btn btn-outline-secondary" type="button" id="searchBtn">
                <i class="bi bi-search"></i>
            </button>
        </div>
    </div>
    <div class="col-md-6 text-end">
        <div class="btn-group">
            <a href="{{ route('streams.create') }}" class="btn btn-primary">
                <i class="bi bi-plus"></i> Add Stream
            </a>
            <a href="{{ route('streams.import') }}" class="btn btn-success">
                <i class="bi bi-upload"></i> Import M3U
            </a>
            <button class="btn btn-warning" id="bulkEditBtn">
                <i class="bi bi-pencil-square"></i> Bulk Edit
            </button>
        </div>
    </div>
</div>

<div class="card shadow">
    <div class="card-header">
        <div class="row align-items-center">
            <div class="col">
                <h6 class="m-0 font-weight-bold text-primary">Streams List</h6>
            </div>
            <div class="col-auto">
                <div class="dropdown">
                    <button class="btn btn-sm btn-outline-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown">
                        Filter by Category
                    </button>
                    <ul class="dropdown-menu" id="categoryFilter">
                        <li><a class="dropdown-item" href="#" data-category="">All Categories</a></li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
    <div class="card-body">
        <div class="table-responsive">
            <table class="table table-hover" id="streamsTable">
                <thead>
                    <tr>
                        <th><input type="checkbox" id="selectAll"></th>
                        <th>Name</th>
                        <th>Category</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody id="streamsTableBody">
                    <tr>
                        <td colspan="6" class="text-center">
                            <div class="spinner-border" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
        
        <nav aria-label="Streams pagination">
            <ul class="pagination justify-content-center" id="pagination">
            </ul>
        </nav>
    </div>
</div>

<!-- Stream Test Modal -->
<div class="modal fade" id="testStreamModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Test Stream</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div id="streamTestResult"></div>
                <video id="testVideo" controls style="width: 100%; display: none;">
                    Your browser does not support the video tag.
                </video>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script>
let currentPage = 1;
let currentCategory = '';
let selectedStreams = [];

document.addEventListener('DOMContentLoaded', function() {
    loadStreams();
    loadCategories();
    
    // Search functionality
    document.getElementById('searchInput').addEventListener('keyup', function(e) {
        if (e.key === 'Enter') {
            loadStreams();
        }
    });
    
    document.getElementById('searchBtn').addEventListener('click', loadStreams);
    
    // Select all checkbox
    document.getElementById('selectAll').addEventListener('change', function() {
        const checkboxes = document.querySelectorAll('input[name="streamSelect"]');
        checkboxes.forEach(cb => cb.checked = this.checked);
        updateSelectedStreams();
    });
});

async function loadStreams(page = 1) {
    const searchTerm = document.getElementById('searchInput').value;
    const params = new URLSearchParams({
        page: page,
        search: searchTerm,
        category: currentCategory
    });
    
    try {
        const response = await fetch(`/api/v1/streams?${params}`, {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            renderStreamsTable(data.data);
            renderPagination(data);
        }
    } catch (error) {
        console.error('Error loading streams:', error);
        showAlert('Error loading streams', 'danger');
    }
}

function renderStreamsTable(streams) {
    const tbody = document.getElementById('streamsTableBody');
    let html = '';
    
    if (streams.length === 0) {
        html = '<tr><td colspan="6" class="text-center">No streams found</td></tr>';
    } else {
        streams.forEach(stream => {
            const statusBadge = stream.is_active ? 
                '<span class="badge bg-success">Active</span>' : 
                '<span class="badge bg-danger">Inactive</span>';
            
            html += `
                <tr>
                    <td><input type="checkbox" name="streamSelect" value="${stream.id}"></td>
                    <td>
                        <div class="d-flex align-items-center">
                            <div>
                                <div class="fw-bold">${stream.name}</div>
                                <small class="text-muted">${stream.stream_key}</small>
                            </div>
                        </div>
                    </td>
                    <td><span class="badge bg-secondary">${stream.category}</span></td>
                    <td><span class="badge bg-info">${stream.type}</span></td>
                    <td>${statusBadge}</td>
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-primary" onclick="testStream(${stream.id})">
                                <i class="bi bi-play"></i>
                            </button>
                            <button class="btn btn-outline-warning" onclick="editStream(${stream.id})">
                                <i class="bi bi-pencil"></i>
                            </button>
                            <button class="btn btn-outline-danger" onclick="deleteStream(${stream.id})">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `;
        });
    }
    
    tbody.innerHTML = html;
    
    // Add event listeners to checkboxes
    document.querySelectorAll('input[name="streamSelect"]').forEach(cb => {
        cb.addEventListener('change', updateSelectedStreams);
    });
}

async function loadCategories() {
    try {
        const response = await fetch('/api/v1/categories', {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            const categories = await response.json();
            const filterMenu = document.getElementById('categoryFilter');
            
            categories.forEach(category => {
                const li = document.createElement('li');
                li.innerHTML = `<a class="dropdown-item" href="#" data-category="${category.slug}">${category.name}</a>`;
                filterMenu.appendChild(li);
            });
            
            // Add click handlers
            filterMenu.addEventListener('click', function(e) {
                if (e.target.classList.contains('dropdown-item')) {
                    e.preventDefault();
                    currentCategory = e.target.dataset.category;
                    loadStreams();
                }
            });
        }
    } catch (error) {
        console.error('Error loading categories:', error);
    }
}

async function testStream(streamId) {
    try {
        const response = await fetch(`/api/v1/streams/${streamId}`, {
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            const stream = await response.json();
            const modal = new bootstrap.Modal(document.getElementById('testStreamModal'));
            const video = document.getElementById('testVideo');
            const result = document.getElementById('streamTestResult');
            
            result.innerHTML = `
                <div class="alert alert-info">
                    <strong>Testing stream:</strong> ${stream.name}<br>
                    <strong>URL:</strong> ${stream.stream_url}
                </div>
            `;
            
            video.src = stream.stream_url;
            video.style.display = 'block';
            modal.show();
        }
    } catch (error) {
        console.error('Error testing stream:', error);
        showAlert('Error testing stream', 'danger');
    }
}

async function deleteStream(streamId) {
    if (!confirm('Are you sure you want to delete this stream?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/v1/streams/${streamId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('auth_token'),
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            showAlert('Stream deleted successfully', 'success');
            loadStreams();
        }
    } catch (error) {
        console.error('Error deleting stream:', error);
        showAlert('Error deleting stream', 'danger');
    }
}

function updateSelectedStreams() {
    selectedStreams = Array.from(document.querySelectorAll('input[name="streamSelect"]:checked'))
        .map(cb => cb.value);
    
    document.getElementById('bulkEditBtn').disabled = selectedStreams.length === 0;
}

function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.querySelector('main').insertBefore(alertDiv, document.querySelector('main').firstChild);
    
    setTimeout(() => {
        alertDiv.remove();
    }, 5000);
}
</script>
@endpush
