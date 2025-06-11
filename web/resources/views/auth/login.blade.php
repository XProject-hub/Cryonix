<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Cryonix Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .login-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 20px;
            padding: 2rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }
        
        .logo {
            font-size: 2.5rem;
            font-weight: bold;
            background: linear-gradient(45deg, #00d4ff, #090979);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-align: center;
            margin-bottom: 1rem;
        }
        
        .form-control {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.3);
            color: white;
        }
        
        .form-control:focus {
            background: rgba(255, 255, 255, 0.2);
            border-color: #00d4ff;
            box-shadow: 0 0 0 0.2rem rgba(0, 212, 255, 0.25);
            color: white;
        }
        
        .form-control::placeholder {
            color: rgba(255, 255, 255, 0.7);
        }
        
        .btn-login {
            background: linear-gradient(45deg, #00d4ff, #090979);
            border: none;
            padding: 0.75rem 2rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .btn-login:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 212, 255, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-6 col-lg-4">
                <div class="login-card">
                    <div class="logo">Cryonix</div>
                    <p class="text-center text-white-50 mb-4">Modern IPTV Management Panel</p>
                    
                    <form id="loginForm">
                        <div class="mb-3">
                            <div class="input-group">
                                <span class="input-group-text bg-transparent border-end-0 text-white-50">
                                    <i class="bi bi-person"></i>
                                </span>
                                <input type="text" class="form-control border-start-0" id="username" 
                                       placeholder="Username" required>
                            </div>
                        </div>
                        
                        <div class="mb-4">
                            <div class="input-group">
                                <span class="input-group-text bg-transparent border-end-0 text-white-50">
                                    <i class="bi bi-lock"></i>
                                </span>
                                <input type="password" class="form-control border-start-0" id="password" 
                                       placeholder="Password" required>
                                <button class="btn btn-outline-secondary border-start-0" type="button" id="togglePassword">
                                    <i class="bi bi-eye"></i>
                                </button>
                            </div>
                        </div>
                        
                        <div class="d-grid">
                            <button type="submit" class="btn btn-login text-white">
                                <span class="spinner-border spinner-border-sm d-none me-2" id="loginSpinner"></span>
                                Login
                            </button>
                        </div>
                    </form>
                    
                    <div class="text-center mt-4">
                        <small class="text-white-50">
                            Powered by Cryonix v1.0.0
                        </small>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const loginForm = document.getElementById('loginForm');
            const togglePassword = document.getElementById('togglePassword');
            const passwordInput = document.getElementById('password');
            const loginSpinner = document.getElementById('loginSpinner');
            
            // Toggle password visibility
            togglePassword.addEventListener('click', function() {
                const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
                passwordInput.setAttribute('type', type);
                
                const icon = this.querySelector('i');
                icon.className = type === 'password' ? 'bi bi-eye' : 'bi bi-eye-slash';
            });
            
            // Handle login form submission
            loginForm.addEventListener('submit', async function(e) {
                e.preventDefault();
                
                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;
                
                // Show loading spinner
                loginSpinner.classList.remove('d-none');
                
                try {
                    const response = await fetch('/api/v1/login', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Accept': 'application/json'
                        },
                        body: JSON.stringify({ username, password })
                    });
                    
                    const data = await response.json();
                    
                    if (response.ok) {
                        // Store auth token
                        localStorage.setItem('auth_token', data.access_token);
                        
                        // Redirect to dashboard
                        window.location.href = '/dashboard';
                    } else {
                        showError(data.error || 'Login failed');
                    }
                } catch (error) {
                    showError('Network error. Please try again.');
                } finally {
                    loginSpinner.classList.add('d-none');
                }
            });
            
            function showError(message) {
                // Remove existing alerts
                const existingAlert = document.querySelector('.alert');
                if (existingAlert) {
                    existingAlert.remove();
                }
                
                const alert = document.createElement('div');
                alert.className = 'alert alert-danger alert-dismissible fade show mt-3';
                alert.innerHTML = `
                    ${message}
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                `;
                
                loginForm.appendChild(alert);
                
                setTimeout(() => {
                    if (alert.parentNode) {
                        alert.remove();
                    }
                }, 5000);
            }
        });
    </script>
</body>
</html>
