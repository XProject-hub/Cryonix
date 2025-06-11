<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Cryonix Panel')</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="{{ asset('css/cryonix.css') }}" rel="stylesheet">
    <meta name="csrf-token" content="{{ csrf_token() }}">
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <!-- Sidebar -->
            <nav class="col-md-3 col-lg-2 d-md-block bg-dark sidebar collapse">
                <div class="position-sticky pt-3">
                    <div class="text-center mb-4">
                        <h4 class="text-primary">Cryonix</h4>
                        <small class="text-muted">v1.0.0</small>
                    </div>
                    
                    <ul class="nav flex-column">
                        <li class="nav-item">
                            <a class="nav-link active" href="{{ route('dashboard') }}">
                                <i class="bi bi-speedometer2"></i> Dashboard
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link" data-bs-toggle="collapse" href="#serversMenu">
                                <i class="bi bi-server"></i> Servers
                            </a>
                            <div class="collapse" id="serversMenu">
                                <ul class="nav flex-column ms-3">
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('servers.index') }}">Manage Servers</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('servers.monitor') }}">Process Monitor</a>
                                    </li>
                                </ul>
                            </div>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link" data-bs-toggle="collapse" href="#usersMenu">
                                <i class="bi bi-people"></i> Users
                            </a>
                            <div class="collapse" id="usersMenu">
                                <ul class="nav flex-column ms-3">
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('users.create') }}">Add User</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('users.index') }}">Manage Users</a>
                                    </li>
                                </ul>
                            </div>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link" data-bs-toggle="collapse" href="#contentMenu">
                                <i class="bi bi-play-circle"></i> Content
                            </a>
                            <div class="collapse" id="contentMenu">
                                <ul class="nav flex-column ms-3">
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('streams.create') }}">Add Stream</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('streams.index') }}">Manage Streams</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('streams.import') }}">Import Multiple</a>
                                    </li>
                                </ul>
                            </div>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link" data-bs-toggle="collapse" href="#managementMenu">
                                <i class="bi bi-gear"></i> Management
                            </a>
                            <div class="collapse" id="managementMenu">
                                <ul class="nav flex-column ms-3">
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('categories.index') }}">Categories</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('packages.index') }}">Packages</a>
                                    </li>
                                    <li class="nav-item">
                                        <a class="nav-link" href="{{ route('epg.index') }}">EPG Sources</a>
                                    </li>
                                </ul>
                            </div>
                        </li>
                    </ul>
                    
                    <div class="mt-4">
                        <div class="d-flex justify-content-between align-items-center">
                            <small class="text-muted">Theme</small>
                            <button class="btn btn-sm btn-outline-secondary" id="themeToggle">
                                <i class="bi bi-sun"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </nav>
            
            <!-- Main content -->
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">@yield('page-title', 'Dashboard')</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <div class="btn-group me-2">
                            <button type="button" class="btn btn-sm btn-outline-secondary" id="refreshBtn">
                                <i class="bi bi-arrow-clockwise"></i> Refresh
                            </button>
                        </div>
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown">
                                <i class="bi bi-person-circle"></i> {{ auth()->user()->username }}
                            </button>
                            <ul class="dropdown-menu">
                                <li><a class="dropdown-item" href="{{ route('profile') }}">Profile</a></li>
                                <li><a class="dropdown-item" href="{{ route('settings') }}">Settings</a></li>
                                <li><hr class="dropdown-divider"></li>
                                <li><a class="dropdown-item" href="{{ route('logout') }}">Logout</a></li>
                            </ul>
                        </div>
                    </div>
                </div>
                
                @yield('content')
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="{{ asset('js/cryonix.js') }}"></script>
    @stack('scripts')
</body>
</html>
