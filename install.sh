#!/bin/bash

# Cryonix Panel - Fully Automated Installation Script (PHP ONLY)
# Compatible with Ubuntu 20.04, 22.04, 24.04 LTS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/cryonix"
WEB_USER="www-data"
CRYONIX_USER="cryonix"
DB_NAME="cryonix_prod"
DB_USER="cryonix_admin"
ADMIN_USER="cryonix"
ADMIN_PASS=$(openssl rand -base64 12)
DB_PASS=$(openssl rand -base64 16)
LOGIN_PATH=$(openssl rand -hex 8)
JWT_SECRET=$(openssl rand -base64 32)
MYSQL_ROOT_PASS=$(openssl rand -base64 16)

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    🚀 CRYONIX PANEL 🚀                       ║${NC}"
echo -e "${BLUE}║              Modern IPTV Management System                   ║${NC}"
echo -e "${BLUE}║            PHP + Python + Bootstrap Only                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🌟 Starting automated installation...${NC}"
echo -e "${YELLOW}📍 Server IP: ${SERVER_IP}${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   echo -e "${YELLOW}💡 Please run: sudo bash install.sh${NC}"
   exit 1
fi

# Detect OS version
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}❌ Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected OS: $OS $VER${NC}"

# Check if supported Ubuntu version
if [[ "$ID" != "ubuntu" ]] || [[ ! "$VER" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
    echo -e "${RED}❌ Unsupported OS. This installer supports Ubuntu 20.04, 22.04, and 24.04 LTS only.${NC}"
    exit 1
fi

# Stop services that might interfere
echo -e "${YELLOW}🛑 Stopping conflicting services...${NC}"
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true

# Update system
echo -e "${YELLOW}🔄 Updating system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt upgrade -y -qq

# Add PHP repository
echo -e "${YELLOW}📦 Adding PHP repository...${NC}"
apt install -y software-properties-common curl wget git unzip
add-apt-repository ppa:ondrej/php -y
apt update -qq

# Install required packages (NO NODE.JS)
echo -e "${YELLOW}📦 Installing required packages...${NC}"
apt install -y nginx mysql-server redis-server \
    php8.2 php8.2-fpm php8.2-mysql php8.2-redis php8.2-xml php8.2-curl \
    php8.2-mbstring php8.2-zip php8.2-gd php8.2-bcmath php8.2-tokenizer \
    php8.2-intl php8.2-cli php8.2-common php8.2-opcache \
    python3 python3-pip python3-venv ffmpeg htop nano expect

# Install Composer
echo -e "${YELLOW}📦 Installing Composer...${NC}"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create cryonix user
echo -e "${YELLOW}👤 Creating cryonix user...${NC}"
if ! id "$CRYONIX_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d $INSTALL_DIR $CRYONIX_USER
fi

# Clean and create installation directory
echo -e "${YELLOW}📁 Preparing installation directory...${NC}"
rm -rf $INSTALL_DIR
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Initialize project structure
echo -e "${YELLOW}🔧 Setting up project structure...${NC}"
mkdir -p services/{stream_manager,epg_sync} config logs updater

# Secure MySQL installation
echo -e "${YELLOW}🔒 Securing MySQL installation...${NC}"
systemctl start mysql
sleep 10

# Check if MySQL is running
if ! systemctl is-active --quiet mysql; then
    echo -e "${RED}❌ MySQL failed to start${NC}"
    systemctl status mysql
    exit 1
fi

# Set MySQL root password with error handling
echo -e "${YELLOW}🔐 Setting MySQL root password...${NC}"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Root password might already be set, trying with existing password...${NC}"
    # Try with empty password first
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Using existing MySQL root setup...${NC}"
        # Generate a new password and try
        MYSQL_ROOT_PASS="cryonix123"
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    }
}

# Clean up MySQL
echo -e "${YELLOW}🧹 Cleaning up MySQL...${NC}"
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# Set up database
echo -e "${YELLOW}🗄️  Setting up database...${NC}"
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';" 2>/dev/null
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null

# Test database connection
echo -e "${YELLOW}🔍 Testing database connection...${NC}"
if mysql -u"${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME};" 2>/dev/null; then
    echo -e "${GREEN}✅ Database connection successful${NC}"
else
    echo -e "${RED}❌ Database connection failed${NC}"
    echo -e "${YELLOW}🔧 Attempting to fix database connection...${NC}"
    
    # Try alternative approach
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';" 2>/dev/null
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    # Test again
    if mysql -u"${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME};" 2>/dev/null; then
        echo -e "${GREEN}✅ Database connection fixed${NC}"
    else
        echo -e "${RED}❌ Database connection still failed${NC}"
        exit 1
    fi
fi

# Create Laravel application (Pure PHP approach)
echo -e "${YELLOW}🏗️  Setting up PHP application...${NC}"
TEMP_DIR="/tmp/cryonix_laravel"
rm -rf $TEMP_DIR

# Set Composer environment variables
export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_NO_INTERACTION=1

# Create Laravel project in temp directory
composer create-project laravel/laravel $TEMP_DIR --no-interaction

# Move Laravel files to web directory
mv $TEMP_DIR $INSTALL_DIR/web
cd $INSTALL_DIR/web

# Install JWT Auth
composer require tymon/jwt-auth --no-interaction

# Create environment file
echo -e "${YELLOW}⚙️  Configuring environment...${NC}"
cat > .env << EOF
APP_NAME=Cryonix
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://${SERVER_IP}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"

JWT_SECRET=${JWT_SECRET}
JWT_TTL=60

STREAM_MANAGER_URL=http://127.0.0.1:8000
EPG_SYNC_URL=http://127.0.0.1:8001
EOF

# Clear any cached config
php artisan config:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true

# Generate application key
php artisan key:generate --force

# Configure JWT
php artisan jwt:secret --force

# Create application structure
echo -e "${YELLOW}🏗️  Creating application structure...${NC}"

# Create User model
cat > app/Models/User.php << 'EOF'
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Tymon\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject
{
    protected $fillable = [
        'username', 'email', 'password', 'role', 'is_active'
    ];

    protected $hidden = [
        'password', 'remember_token', 'api_token'
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_active' => 'boolean'
    ];

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims()
    {
        return [];
    }
}
EOF

# Create migration
cat > database/migrations/2024_01_01_000001_create_users_table.php << 'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('username')->unique();
            $table->string('email')->unique();
            $table->string('password');
            $table->enum('role', ['admin', 'reseller', 'user'])->default('user');
            $table->boolean('is_active')->default(true);
            $table->string('api_token')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('users');
    }
};
EOF

# Create AuthController
cat > app/Http/Controllers/AuthController.php << 'EOF'
<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'username' => 'required',
            'password' => 'required',
        ]);

        if (!$token = auth()->attempt($credentials)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => auth()->factory()->getTTL() * 60,
            'user' => auth()->user()
        ]);
    }

    public function me()
    {
        return response()->json(auth()->user());
    }

    public function logout()
    {
        auth()->logout();
        return response()->json(['message' => 'Successfully logged out']);
    }
}
EOF

# Create routes
cat > routes/api.php << 'EOF'
<?php

use App\Http\Controllers\AuthController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('login', [AuthController::class, 'login']);
    
    Route::middleware('auth:api')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
    });
});
EOF

# Update auth config
cat > config/auth.php << 'EOF'
<?php

return [
    'defaults' => [
        'guard' => 'api',
        'passwords' => 'users',
    ],

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
        'api' => [
            'driver' => 'jwt',
            'provider' => 'users',
        ],
    ],

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => App\Models\User::class,
        ],
    ],

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => 'password_reset_tokens',
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    'password_timeout' => 10800,
];
EOF

# Create seeder
cat > database/seeders/DatabaseSeeder.php << EOF
<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run()
    {
        User::create([
            'username' => '${ADMIN_USER}',
            'email' => 'admin@cryonix.local',
            'password' => Hash::make('${ADMIN_PASS}'),
            'role' => 'admin',
            'is_active' => true
        ]);
    }
}
EOF

# Clear config cache before migrations
php artisan config:clear
php artisan cache:clear

# Run migrations and seeders
echo -e "${YELLOW}🔄 Running database migrations...${NC}"
php artisan migrate:fresh --force
php artisan db:seed --force

# Verify migrations
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database migrations completed successfully${NC}"
else
    echo -e "${RED}❌ Database migrations failed${NC}"
    exit 1
fi

# Create web routes
cat > routes/web.php << EOF
<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/login_${LOGIN_PATH}');
});

Route::get('/login_${LOGIN_PATH}', function () {
    return view('login');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->name('dashboard');
EOF

# Create login view (Pure HTML/CSS/JS with Bootstrap CDN)
cat > resources/views/login.blade.php << 'EOF'
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
                            <input type="text" class="form-control" id="username" placeholder="Username" required>
                        </div>
                        <div class="mb-4">
                            <input type="password" class="form-control" id="password" placeholder="Password" required>
                        </div>
                        <div class="d-grid">
                            <button type="submit" class="btn btn-login text-white">Login</button>
                        </div>
                    </form>
                    
                    <div class="text-center mt-4">
                        <small class="text-white-50">Powered by Cryonix v1.0.0</small>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Pure JavaScript - No Node.js dependencies
        document.getElementById('loginForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            
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
                    localStorage.setItem('auth_token', data.access_token);
                    window.location.href = '/dashboard';
                } else {
                    alert(data.error || 'Login failed');
                }
            } catch (error) {
                alert('Network error. Please try again.');
            }
        });
    </script>
</body>
</html>
EOF

# Create dashboard view (Pure HTML/CSS/JS with Bootstrap CDN)
cat > resources/views/dashboard.blade.php << 'EOF'
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Cryonix Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <nav class="col-md-3 col-lg-2 d-md-block bg-dark sidebar">
                <div class="position-sticky pt-3">
                    <div class="text-center mb-4">
                        <h4 class="text-primary">Cryonix</h4>
                        <small class="text-muted">v1.0.0</small>
                    </div>
                    <ul class="nav flex-column">
                        <li class="nav-item">
                            <a class="nav-link active text-white" href="#">
                                <i class="bi bi-speedometer2"></i> Dashboard
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link text-white-50" href="#">
                                <i class="bi bi-server"></i> Servers
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link text-white-50" href="#">
                                <i class="bi bi-people"></i> Users
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link text-white-50" href="#">
                                <i class="bi bi-play-circle"></i> Streams
                            </a>
                        </li>
                    </ul>
                </div>
            </nav>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Dashboard</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button type="button" class="btn btn-sm btn-outline-secondary" onclick="location.reload()">
                            <i class="bi bi-arrow-clockwise"></i> Refresh
                        </button>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-start border-primary border-4">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">Total Users</div>
                                        <div class="h5 mb-0 font-weight-bold">1</div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-people fa-2x text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-start border-success border-4">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-success text-uppercase mb-1">Active Streams</div>
                                        <div class="h5 mb-0 font-weight-bold">0</div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-play-circle fa-2x text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-start border-info border-4">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-info text-uppercase mb-1">System Status</div>
                                        <div class="h5 mb-0 font-weight-bold text-success">Online</div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-check-circle fa-2x text-success"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-start border-warning border-4">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">Server Load</div>
                                        <div class="h5 mb-0 font-weight-bold">Low</div>
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
                    <div class="col-lg-12">
                        <div class="card">
                            <div class="card-header">
                                <h6 class="m-0 font-weight-bold text-primary">Welcome to Cryonix Panel</h6>
                            </div>
                            <div class="card-body">
                                <p>Your Cryonix panel has been successfully installed and is ready to use!</p>
                                <p><strong>Technology Stack:</strong></p>
                                <ul>
                                    <li>✅ PHP 8.2 (Backend)</li>
                                    <li>✅ Python 3 (Services)</li>
                                    <li>✅ Bootstrap 5 (Frontend)</li>
                                    <li>✅ Pure JavaScript (No Node.js)</li>
                                    <li>✅ Custom CSS</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Pure JavaScript functionality - No Node.js required
        console.log('Cryonix Panel - Pure PHP/Python/Bootstrap/JavaScript');
    </script>
</body>
</html>
EOF

# Set up Python services (for stream management only)
echo -e "${YELLOW}🐍 Setting up Python services...${NC}"

# Stream Manager Service
cd $INSTALL_DIR/services/stream_manager
cat > requirements.txt << 'EOF'
fastapi==0.104.1

uvicorn==0.24.0
python-multipart==0.0.6
pydantic==2.5.0
aiofiles==23.2.1
EOF

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# EPG Sync Service
cd $INSTALL_DIR/services/epg_sync
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
aiohttp==3.9.1
mysql-connector-python==8.2.0
EOF

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# Set up systemd services
echo -e "${YELLOW}📦 Creating systemd services...${NC}"

# Stream Manager Service
cat > /etc/systemd/system/cryonix-stream-manager.service << EOF
[Unit]
Description=Cryonix Stream Manager
After=network.target

[Service]
Type=simple
User=$CRYONIX_USER
Group=$CRYONIX_USER
WorkingDirectory=$INSTALL_DIR/services/stream_manager
Environment=PATH=$INSTALL_DIR/services/stream_manager/venv/bin
ExecStart=$INSTALL_DIR/services/stream_manager/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# EPG Sync Service
cat > /etc/systemd/system/cryonix-epg-sync.service << EOF
[Unit]
Description=Cryonix EPG Sync Service
After=network.target mysql.service

[Service]
Type=simple
User=$CRYONIX_USER
Group=$CRYONIX_USER
WorkingDirectory=$INSTALL_DIR/services/epg_sync
Environment=PATH=$INSTALL_DIR/services/epg_sync/venv/bin
Environment=DB_HOST=localhost
Environment=DB_DATABASE=$DB_NAME
Environment=DB_USERNAME=$DB_USER
Environment=DB_PASSWORD=$DB_PASS
ExecStart=$INSTALL_DIR/services/epg_sync/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8001
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
echo -e "${YELLOW}📦 Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/cryonix << EOF
server {
    listen 80;
    server_name _;
    root $INSTALL_DIR/web/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable site and remove default
ln -sf /etc/nginx/sites-available/cryonix /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Set permissions
echo -e "${YELLOW}📦 Setting permissions...${NC}"
chown -R $CRYONIX_USER:$CRYONIX_USER $INSTALL_DIR
chown -R $WEB_USER:$WEB_USER $INSTALL_DIR/web/storage $INSTALL_DIR/web/bootstrap/cache
chmod -R 755 $INSTALL_DIR
chmod -R 775 $INSTALL_DIR/web/storage $INSTALL_DIR/web/bootstrap/cache

# Reload systemd and start services
echo -e "${YELLOW}📦 Starting services...${NC}"
systemctl daemon-reload
systemctl enable nginx php8.2-fpm mysql redis-server
systemctl enable cryonix-stream-manager cryonix-epg-sync
systemctl restart nginx php8.2-fpm mysql redis-server
systemctl start cryonix-stream-manager cryonix-epg-sync

# Final setup
echo -e "${YELLOW}📦 Finalizing installation...${NC}"
cd $INSTALL_DIR/web
php artisan config:cache
php artisan route:cache

# Clear screen for final message
clear

# Installation complete - Display credentials
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 🎉 INSTALLATION COMPLETE! 🎉                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Installation Summary:${NC}"
echo -e "${YELLOW}🔗 Panel URL:${NC}      http://$SERVER_IP"
echo -e "${YELLOW}🔐 Login URL:${NC}      http://$SERVER_IP/login_$LOGIN_PATH"
echo -e "${YELLOW}👤 Username:${NC}       $ADMIN_USER"
echo -e "${YELLOW}🔑 Password:${NC}       $ADMIN_PASS"
echo ""
echo -e "${BLUE}📁 Database Credentials:${NC}"
echo -e "${YELLOW}📂 Database:${NC}       $DB_NAME"
echo -e "${YELLOW}👤 DB User:${NC}        $DB_USER"
echo -e "${YELLOW}🔑 DB Password:${NC}    $DB_PASS"
echo -e "${YELLOW}🔐 MySQL Root:${NC}     $MYSQL_ROOT_PASS"
echo ""
echo -e "${BLUE}🛠️ System Information:${NC}"
echo -e "${YELLOW}📂 Install Path:${NC}   $INSTALL_DIR"
echo -e "${YELLOW}🔄 Update Script:${NC}  $INSTALL_DIR/update.sh"
echo -e "${YELLOW}💾 Backup Script:${NC}  $INSTALL_DIR/backup.sh"
echo ""
echo -e "${GREEN}✅ Services Status:${NC}"
systemctl is-active --quiet nginx && echo -e "   Nginx: ${GREEN}Running${NC}" || echo -e "   Nginx: ${RED}Stopped${NC}"
systemctl is-active --quiet mysql && echo -e "   MySQL: ${GREEN}Running${NC}" || echo -e "   MySQL: ${RED}Stopped${NC}"
systemctl is-active --quiet redis-server && echo -e "   Redis: ${GREEN}Running${NC}" || echo -e "   Redis: ${RED}Stopped${NC}"
systemctl is-active --quiet cryonix-stream-manager && echo -e "   Stream Manager: ${GREEN}Running${NC}" || echo -e "   Stream Manager: ${RED}Stopped${NC}"
systemctl is-active --quiet cryonix-epg-sync && echo -e "   EPG Sync: ${GREEN}Running${NC}" || echo -e "   EPG Sync: ${RED}Stopped${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Save these credentials in a secure location!${NC}"
echo -e "${YELLOW}💡 After logging in, please change the default password.${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Access your panel at: http://$SERVER_IP/login_$LOGIN_PATH"
echo "2. Log in with the credentials above"
echo "3. Change your admin password"
echo "4. Configure your streams and users"
echo ""
echo -e "${PURPLE}🔧 Troubleshooting:${NC}"
echo "- Check logs: tail -f $INSTALL_DIR/logs/*.log"
echo "- Restart services: systemctl restart cryonix-*"
echo "- Database access: mysql -u $DB_USER -p$DB_PASS $DB_NAME"
echo ""
echo -e "${GREEN}Thank you for choosing Cryonix Panel!${NC}"

# Save credentials to a file
echo -e "${YELLOW}💾 Saving credentials to $INSTALL_DIR/credentials.txt...${NC}"
cat > $INSTALL_DIR/credentials.txt << EOF
CRYONIX PANEL CREDENTIALS
========================
Installation Date: $(date)
Server IP: $SERVER_IP

Panel Access
-----------
Panel URL: http://$SERVER_IP
Login URL: http://$SERVER_IP/login_$LOGIN_PATH
Username: $ADMIN_USER
Password: $ADMIN_PASS

Database Credentials
------------------
Database: $DB_NAME
Username: $DB_USER
Password: $DB_PASS
MySQL Root Password: $MYSQL_ROOT_PASS

Installation Details
------------------
Install Path: $INSTALL_DIR
Update Script: $INSTALL_DIR/update.sh
Backup Script: $INSTALL_DIR/backup.sh

Service URLs
-----------
Stream Manager: http://127.0.0.1:8000
EPG Sync: http://127.0.0.1:8001

IMPORTANT: Delete this file after saving the credentials securely!
EOF

chmod 600 $INSTALL_DIR/credentials.txt
chown $CRYONIX_USER:$CRYONIX_USER $INSTALL_DIR/credentials.txt

echo -e "${YELLOW}📋 Credentials have been saved to: $INSTALL_DIR/credentials.txt${NC}"
echo -e "${RED}⚠️  Remember to delete this file after saving the information securely!${NC}"
