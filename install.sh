# File: install.sh

#!/bin/bash

# Cryonix Panel - Fully Automated Installation Script
# Compatible with Ubuntu 20.04, 22.04, 24.04 LTS
# Usage: curl -sSL https://raw.githubusercontent.com/XProject-hub/Cryonix/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/cryonix"
WEB_USER="www-data"
CRYONIX_USER="cryonix"
DB_NAME="cryonix_prod"
DB_USER="cryonix_admin"
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
DB_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
LOGIN_PATH="admin_$(openssl rand -hex 6)"
JWT_SECRET=$(openssl rand -base64 32)
APP_KEY="base64:$(openssl rand -base64 32)"

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
HTTP_PORT=80
HTTPS_PORT=443

# Banner
clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ██████╗██████╗ ██╗   ██╗ ██████╗ ███╗   ██╗██╗██╗  ██╗     ║
║  ██╔════╝██╔══██╗╚██╗ ██╔╝██╔═══██╗████╗  ██║██║╚██╗██╔╝     ║
║  ██║     ██████╔╝ ╚████╔╝ ██║   ██║██╔██╗ ██║██║ ╚███╔╝      ║
║  ██║     ██╔══██╗  ╚██╔╝  ██║   ██║██║╚██╗██║██║ ██╔██╗      ║
║  ╚██████╗██║  ██║   ██║   ╚██████╔╝██║ ╚████║██║██╔╝ ██╗     ║
║   ╚═════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝     ║
║                                                              ║
║                  Cryonix Panel - v1.0.0                      ║
║                   Developed by X Project                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${WHITE}🚀 Starting Automated Installation...${NC}"
echo -e "${CYAN}📍 Server IP: ${SERVER_IP}${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   echo -e "${YELLOW}💡 Run: sudo bash install.sh${NC}"
   exit 1
fi

# Detect OS version
echo -e "${YELLOW}🔍 Detecting operating system...${NC}"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}❌ Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected: $OS $VER${NC}"

# Check if supported Ubuntu version
if [[ "$ID" != "ubuntu" ]] || [[ ! "$VER" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
    echo -e "${RED}❌ Unsupported OS. This installer supports Ubuntu 20.04, 22.04, and 24.04 LTS only.${NC}"
    exit 1
fi

# Stop existing services if they exist
echo -e "${YELLOW}🛑 Stopping existing services...${NC}"
systemctl stop nginx mysql redis-server 2>/dev/null || true
systemctl stop cryonix-stream-manager cryonix-epg-sync 2>/dev/null || true

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt upgrade -y -qq

# Install required packages
echo -e "${YELLOW}📦 Installing required packages...${NC}"
apt install -y -qq software-properties-common curl wget git unzip nginx mysql-server redis-server \
    php8.1 php8.1-fpm php8.1-mysql php8.1-redis php8.1-xml php8.1-curl php8.1-mbstring \
    php8.1-zip php8.1-gd php8.1-json php8.1-bcmath php8.1-tokenizer php8.1-intl \
    python3 python3-pip python3-venv ffmpeg htop nano certbot python3-certbot-nginx \
    ufw fail2ban logrotate

# Install Composer
echo -e "${YELLOW}🎼 Installing Composer...${NC}"
if [ ! -f /usr/local/bin/composer ]; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Install Node.js and npm
echo -e "${YELLOW}📦 Installing Node.js...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
apt install -y -qq nodejs

# Secure MySQL installation
echo -e "${YELLOW}🔒 Securing MySQL installation...${NC}"
MYSQL_ROOT_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASS} -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASS} -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# Create cryonix user
echo -e "${YELLOW}👤 Creating system user...${NC}"
if ! id "$CRYONIX_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d $INSTALL_DIR -m $CRYONIX_USER
fi

# Remove existing installation if exists
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}🗑️  Removing existing installation...${NC}"
    rm -rf $INSTALL_DIR
fi

# Create installation directory
echo -e "${YELLOW}📁 Creating installation directory...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone Cryonix repository (assuming it's already created)
echo -e "${YELLOW}📥 Downloading Cryonix files...${NC}"
# For now, we'll create the structure since the repo doesn't exist yet
mkdir -p {web,services/stream_manager,services/epg_sync,config,logs,updater}

# Create Laravel application structure
echo -e "${YELLOW}🏗️  Setting up Laravel application...${NC}"
cd $INSTALL_DIR/web

# Initialize Laravel project
composer create-project laravel/laravel . --no-interaction --quiet
composer require tymon/jwt-auth --quiet

# Create all the files we defined earlier
# (In real scenario, these would come from git clone)

# Create .env file
cat > .env << EOF
APP_NAME=Cryonix
APP_ENV=production
APP_KEY=${APP_KEY}
APP_DEBUG=false
APP_URL=http://${SERVER_IP}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error

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

JWT_SECRET=${JWT_SECRET}
JWT_TTL=60

CRYONIX_LOGIN_PATH=${LOGIN_PATH}
STREAM_MANAGER_URL=http://127.0.0.1:8000
EPG_SYNC_URL=http://127.0.0.1:8001
EOF

# Set up database
echo -e "${YELLOW}🗄️  Setting up database...${NC}"
mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null
mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
mysql -u root -p${MYSQL_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
mysql -u root -p${MYSQL_ROOT_PASS} -e "FLUSH PRIVILEGES;" 2>/dev/null

# Generate application key and JWT secret
php artisan key:generate --force
php artisan jwt:secret --force

# Create basic routes for the login path
cat > routes/web.php << 'EOF'
<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/dashboard');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->name('dashboard');

Route::get('/' . env('CRYONIX_LOGIN_PATH', 'admin'), function () {
    return view('auth.login');
})->name('login');

Route::post('/logout', function () {
    return redirect('/' . env('CRYONIX_LOGIN_PATH', 'admin'));
})->name('logout');
EOF

# Create basic migration for users
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
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('users');
    }
};
EOF

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
        'password', 'remember_token',
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

# Create basic views directory structure
mkdir -p resources/views/{layouts,auth}

# Create login view
cat > resources/views/auth/login.blade.php << 'EOF'
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
            max-width: 400px;
            width: 100%;
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
    </style>
</head>
<body>
    <div class="login-card">
        <div class="logo">Cryonix</div>
        <p class="text-center text-white-50 mb-4">Modern IPTV Management Panel</p>
        
        <div class="alert alert-info">
            <strong>Default Login:</strong><br>
            Username: admin<br>
            Password: admin123<br>
            <small>Please change after first login</small>
        </div>
        
        <form method="POST" action="/api/v1/login">
            @csrf
            <div class="mb-3">
                <input type="text" class="form-control" name="username" placeholder="Username" required>
            </div>
            <div class="mb-4">
                <input type="password" class="form-control" name="password" placeholder="Password" required>
            </div>
            <div class="d-grid">
                <button type="submit" class="btn btn-primary">Login</button>
            </div>
        </form>
        
        <div class="text-center mt-4">
            <small class="text-white-50">Powered by Cryonix v1.0.0</small>
        </div>
    </div>
</body>
</html>
EOF

# Create dashboard view
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
            <div class="col-12">
                <nav class="navbar navbar-dark bg-dark">
                    <div class="container-fluid">
                        <span class="navbar-brand mb-0 h1">
                            <i class="bi bi-speedometer2"></i> Cryonix Panel
                        </span>
                        <div class="d-flex">
                            <span class="navbar-text me-3">Welcome, Admin!</span>
                            <a href="/logout" class="btn btn-outline-light btn-sm">Logout</a>
                        </div>
                    </div>
                </nav>
            </div>
        </div>
        
        <div class="container mt-4">
            <div class="row">
                <div class="col-12">
                    <div class="alert alert-success">
                        <h4><i class="bi bi-check-circle"></i> Installation Complete!</h4>
                        <p>Your Cryonix panel has been successfully installed and is ready to use.</p>
                        <hr>
                        <p class="mb-0">
                            <strong>Next Steps:</strong>
                            <br>• Change your admin password
                            <br>• Configure your streams and users
                            <br>• Set up EPG sources
                        </p>
                    </div>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <i class="bi bi-people-fill display-4 text-primary"></i>
                            <h5 class="card-title mt-2">User Management</h5>
                            <p class="card-text">Manage users, resellers, and permissions</p>
                            <a href="#" class="btn btn-primary">Manage Users</a>
                        </div>
                    </div>
                </div>
                
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <i class="bi bi-play-circle-fill display-4 text-success"></i>
                            <h5 class="card-title mt-2">Stream Management</h5>
                            <p class="card-text">Add and manage your IPTV streams</p>
                            <a href="#" class="btn btn-success">Manage Streams</a>
                        </div>
                    </div>
                </div>
                
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <i class="bi bi-tv-fill display-4 text-info"></i>
                            <h5 class="card-title mt-2">EPG Management</h5>
                            <p class="card-text">Configure Electronic Program Guide</p>
                            <a href="#" class="btn btn-info">Manage EPG</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Run migrations
echo -e "${YELLOW}🔄 Running database migrations...${NC}"
php artisan migrate --force

# Create admin user
echo -e "${YELLOW}👤 Creating admin user...${NC}"
php artisan tinker --execute="
\$user = new App\Models\User();
\$user->username = '${ADMIN_USER}';
\$user->email = 'admin@cryonix.local';
\$user->password = Hash::make('admin123');
\$user->role = 'admin';
\$user->is_active = true;
\$user->save();
echo 'Admin user created successfully';
"

# Set up Python services
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

cat > main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
import logging

app = FastAPI(title="Cryonix Stream Manager")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StreamStatus(BaseModel):
    status: str
    message: str

@app.get("/")
async def root():
    return {"message": "Cryonix Stream Manager is running"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "stream_manager"}

@app.get("/streams/list")
async def list_streams():
    return {"streams": [], "count": 0}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
EOF

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt --quiet
deactivate

# EPG Sync Service
cd $INSTALL_DIR/services/epg_sync
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
aiohttp==3.9.1
mysql-connector-python==8.2.0
EOF

cat > main.py << 'EOF'
from fastapi import FastAPI
import logging

app = FastAPI(title="Cryonix EPG Sync Service")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.get("/")
async def root():
    return {"message": "Cryonix EPG Sync Service is running"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "epg_sync"}

@app.get("/epg/sources")
async def get_sources():
    return {"sources": [], "count": 0}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8001)
EOF

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt --quiet
deactivate

# Set permissions
echo -e "${YELLOW}🔐 Setting permissions...${NC}"
chown -R $CRYONIX_USER:$CRYONIX_USER $INSTALL_DIR
chown -R $WEB_USER:$WEB_USER $INSTALL_DIR/web/storage $INSTALL_DIR/web/bootstrap/cache
chmod -R 755 $INSTALL_DIR
chmod -R 775 $INSTALL_DIR/web/storage $INSTALL_DIR/web/bootstrap/cache

# Configure Nginx
echo -e "${YELLOW}🌐 Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/cryonix << EOF
server {
    listen 80;
    server_name _;
    root $INSTALL_DIR/web/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.ht {
        deny all;
    }

    # Custom login path
    location /${LOGIN_PATH} {
        try_files \$uri /index.php?\$query_string;
    }

    # API endpoints
    location /api/ {
        try_files \$uri /index.php?\$query_string;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site and remove default
ln -sf /etc/nginx/sites-available/cryonix /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Create systemd services
echo -e "${YELLOW}⚙️  Creating system services...${NC}"

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
StandardOutput=journal
StandardError=journal

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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create update script
echo -e "${YELLOW}🔄 Creating update script...${NC}"
cat > $INSTALL_DIR/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating Cryonix Panel..."
cd /opt/cryonix
git pull origin main
cd web
composer install --no-dev --optimize-autoloader --quiet
php artisan migrate --force
php artisan config:cache
php artisan route:cache
systemctl restart cryonix-stream-manager cryonix-epg-sync
systemctl reload nginx
echo "✅ Cryonix updated successfully!"
EOF

chmod +x $INSTALL_DIR/update.sh

# Create backup script
cat > $INSTALL_DIR/backup.sh << EOF
#!/bin/bash
BACKUP_DIR="/opt/cryonix/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > \$BACKUP_DIR/database_\$DATE.sql
tar -czf \$BACKUP_DIR/cryonix_\$DATE.tar.gz -C /opt cryonix --exclude=cryonix/backups
echo "💾 Backup created: \$BACKUP_DIR/cryonix_\$DATE.tar.gz"
EOF

chmod +x $INSTALL_DIR/backup.sh

# Configure firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https

# Set up log rotation
cat > /etc/logrotate.d/cryonix << 'EOF'
/opt/cryonix/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 cryonix cryonix
}
EOF

# Configure fail2ban
cat > /etc/fail2ban/jail.d/cryonix.conf << 'EOF'
[cryonix]
enabled = true
port = http,https
filter = cryonix
logpath = /opt/cryonix/logs/*.log
maxretry = 5
bantime = 3600
EOF

# Set up cron jobs
echo -e "${YELLOW}⏰ Setting up scheduled tasks...${NC}"
(crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup.sh") | crontab -

# Reload systemd and start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl daemon-reload
systemctl enable nginx php8.1-fpm mysql redis-server
systemctl enable cryonix-stream-manager cryonix-epg-sync
systemctl restart nginx php8.1-fpm mysql redis-server
systemctl start cryonix-stream-manager cryonix-epg-sync

# Final Laravel setup
echo -e "${YELLOW}🏁 Finalizing Laravel setup...${NC}"
cd $INSTALL_DIR/web
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Wait for services to start
sleep 3

# Check service status
check_service() {
    if systemctl is-active --quiet $1; then
        echo -e "   $1: ${GREEN}✅ Running${NC}"
    else
        echo -e "   $1: ${RED}❌ Stopped${NC}"
    fi
}

# Save installation info
cat > $INSTALL_DIR/installation_info.txt << EOF
Cryonix Panel Installation Information
=====================================

Installation Date: $(date)
Server IP: $SERVER_IP
Login URL: http://$SERVER_IP/$LOGIN_PATH

Default Credentials:
- Username: $ADMIN_USER
- Password: admin123

Database Information:
- Database: $DB_NAME
- Username: $DB_USER
- Password: $DB_PASS
- MySQL Root Password: $MYSQL_ROOT_PASS

Installation Directory: $INSTALL_DIR
Update Command: $INSTALL_DIR/update.sh
Backup Comman
