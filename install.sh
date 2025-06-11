#!/bin/bash

# Cryonix Installation Script
# This script installs Cryonix streaming management panel
# Supports Ubuntu 20.04, 22.04, and 24.04 LTS

set -e

echo "🚀 Starting Cryonix Installation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (use sudo)"
fi

# Detect Ubuntu version
if [ ! -f /etc/os-release ]; then
    error "Cannot detect OS version. This script requires Ubuntu 20.04, 22.04, or 24.04 LTS"
fi

. /etc/os-release
UBUNTU_VERSION=$VERSION_ID

if [[ ! "$UBUNTU_VERSION" =~ ^(20.04|22.04|24.04)$ ]]; then
    error "This script requires Ubuntu 20.04, 22.04 or 24.04 LTS. Detected: Ubuntu $UBUNTU_VERSION"
fi

success "Detected Ubuntu $UBUNTU_VERSION"

# Set versions based on Ubuntu version
case $UBUNTU_VERSION in
    "20.04")
        PHP_VERSION="8.1"
        PYTHON_VERSION="3.9"
        ;;
    "22.04")
        PHP_VERSION="8.1"
        PYTHON_VERSION="3.10"
        ;;
    "24.04")
        PHP_VERSION="8.3"
        PYTHON_VERSION="3.12"
        ;;
esac

log "Using PHP $PHP_VERSION and Python $PYTHON_VERSION for Ubuntu $UBUNTU_VERSION"

# Update system
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install basic dependencies
log "Installing basic dependencies..."
apt-get install -y -qq \
    curl \
    wget \
    unzip \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    openssl \
    zip \
    unzip

# Add repositories
log "Adding required repositories..."

# Add Ondrej PHP repository
if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    curl -sSL https://packages.sury.org/php/README.txt | bash -x
    add-apt-repository ppa:ondrej/php -y
fi

# For Ubuntu 20.04, add deadsnakes for Python
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    if ! grep -q "deadsnakes/ppa" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        add-apt-repository ppa:deadsnakes/ppa -y
    fi
fi

# Update after adding repositories
apt-get update -qq

# Install Nginx
log "Installing Nginx..."
apt-get install -y nginx

# Install PHP and extensions
log "Installing PHP $PHP_VERSION and extensions..."
apt-get install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-cli

# Install MariaDB
log "Installing MariaDB..."
apt-get install -y mariadb-server mariadb-client

# Install Python and pip
log "Installing Python $PYTHON_VERSION..."
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-distutils
    # Install pip for Python on Ubuntu 20.04
    curl -sSL https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}
else
    apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv python3-pip
fi

# Install FFmpeg
log "Installing FFmpeg..."
apt-get install -y ffmpeg

# Install Redis
log "Installing Redis..."
apt-get install -y redis-server

# Install Node.js
log "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

success "All dependencies installed successfully"

# Configure MariaDB
log "Configuring MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Generate secure passwords
DB_ROOT_PASSWORD=$(openssl rand -base64 32)
DB_USER_PASSWORD=$(openssl rand -base64 32)
ADMIN_PATH=$(openssl rand -hex 8)
JWT_SECRET=$(openssl rand -base64 64)

# Secure MariaDB installation
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';" 2>/dev/null || \
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$DB_ROOT_PASSWORD') WHERE User = 'root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Create Cryonix database and user
mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS cryonix_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER IF NOT EXISTS 'cryonix_admin'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';"
mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON cryonix_db.* TO 'cryonix_admin'@'localhost';"
mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

success "MariaDB configured successfully"

# Install Python dependencies
log "Installing Python packages..."
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    python${PYTHON_VERSION} -m pip install --upgrade pip
    python${PYTHON_VERSION} -m pip install fastapi uvicorn redis psutil python-multipart
else
    python3 -m pip install --upgrade pip
    python3 -m pip install fastapi uvicorn redis psutil python-multipart
fi

# Create installation directory
INSTALL_DIR="/opt/cryonix"
log "Creating installation directory: $INSTALL_DIR"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Create directory structure
mkdir -p {public,config,api,views,includes,services,streams,logs,backups}
mkdir -p {public/assets/css,public/assets/js,views/includes}

# Clone Cryonix from GitHub
log "Cloning Cryonix from GitHub..."
if [ -d ".git" ]; then
    git pull https://github.com/XProject-hub/Cryonix.git main || warning "Failed to pull updates from GitHub"
else
    git init
    git remote add origin https://github.com/XProject-hub/Cryonix.git
    git fetch origin main || warning "Failed to fetch from GitHub - continuing with local setup"
fi

# Set permissions
chown -R www-data:www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR
chmod -R 777 $INSTALL_DIR/streams
chmod -R 777 $INSTALL_DIR/logs
chmod -R 755 $INSTALL_DIR/backups

# Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/cryonix << EOF
server {
    listen 80;
    server_name _;
    root /opt/cryonix/public;
    index index.php index.html;
    
    client_max_body_size 100M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location /streams {
        alias /opt/cryonix/streams;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization";
    }

    location /api {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ /\. {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location /robots.txt {
        log_not_found off;
        access_log off;
    }
}
EOF

# Enable site and disable default
ln -sf /etc/nginx/sites-available/cryonix /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t && systemctl restart nginx
systemctl enable nginx

success "Nginx configured successfully"

# Configure PHP
log "Configuring PHP..."
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_POOL="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

# Update PHP settings
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' $PHP_INI
sed -i 's/post_max_size = 8M/post_max_size = 100M/' $PHP_INI
sed -i 's/memory_limit = 128M/memory_limit = 512M/' $PHP_INI
sed -i 's/max_execution_time = 30/max_execution_time = 300/' $PHP_INI
sed -i 's/max_input_time = 60/max_input_time = 300/' $PHP_INI
sed -i 's/;max_input_vars = 1000/max_input_vars = 3000/' $PHP_INI

# Update PHP-FPM pool settings
sed -i 's/pm.max_children = 5/pm.max_children = 20/' $PHP_POOL
sed -i 's/pm.start_servers = 2/pm.start_servers = 5/' $PHP_POOL
sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 3/' $PHP_POOL
sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 10/' $PHP_POOL

# Restart PHP-FPM
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

success "PHP configured successfully"

# Configure Redis
log "Configuring Redis..."
systemctl start redis-server
systemctl enable redis-server

# Create systemd service for transcoder
log "Creating transcoder service..."
PYTHON_EXEC="/usr/bin/python${PYTHON_VERSION}"
if [ "$UBUNTU_VERSION" != "20.04" ]; then
    PYTHON_EXEC="/usr/bin/python3"
fi

cat > /etc/systemd/system/cryonix-transcoder.service << EOF
[Unit]
Description=Cryonix Transcoder Service
After=network.target redis.service mariadb.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/cryonix/services
ExecStart=$PYTHON_EXEC transcoder.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/cryonix

[Install]
WantedBy=multi-user.target
EOF

# Create config file with generated passwords
log "Creating configuration files..."
cat > /opt/cryonix/config/config.php << EOF
<?php
// Cryonix Configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'cryonix_db');
define('DB_USER', 'cryonix_admin');
define('DB_PASS', '$DB_USER_PASSWORD');

define('SITE_NAME', 'Cryonix Panel');
define('SITE_URL', 'http://localhost');
define('ADMIN_EMAIL', 'admin@cryonix.local');
define('ADMIN_PATH', '$ADMIN_PATH');

// Security
define('JWT_SECRET', '$JWT_SECRET');
define('SESSION_TIMEOUT', 3600); // 1 hour

// Streaming
define('FFMPEG_PATH', '/usr/bin/ffmpeg');
define('STREAM_BASE_URL', 'http://localhost:8080');
define('HLS_OUTPUT_DIR', '/opt/cryonix/streams/');

// Python Service
define('TRANSCODER_API', 'http://localhost:8000');

// System Info
define('PHP_VERSION', '$PHP_VERSION');
define('PYTHON_VERSION', '$PYTHON_VERSION');
define('UBUNTU_VERSION', '$UBUNTU_VERSION');

// GitHub Repository
define('GITHUB_REPO', 'https://github.com/XProject-hub/Cryonix.git');

// Error Reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', '/opt/cryonix/logs/php_errors.log');
?>
EOF

# Create version file
echo "1.0.0" > /opt/cryonix/version.txt

# Create database schema file
cat > /opt/cryonix/config/database.php << 'EOF'
<?php
require_once 'config.php';

class Database {
    private $host = DB_HOST;
    private $db_name = DB_NAME;
    private $username = DB_USER;
    private $password = DB_PASS;
    private $conn;

    public function getConnection() {
        $this->conn = null;
        try {
            $this->conn = new PDO(
                "mysql:host=" . $this->host . ";dbname=" . $this->db_name,
                $this->username,
                $this->password,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
                ]
            );
        } catch(PDOException $exception) {
            error_log("Database connection error: " . $exception->getMessage());
            throw $exception;
        }
        return $this->conn;
    }
}

// Create tables
function createTables() {
    try {
        $database = new Database();
        $db = $database->getConnection();
        
        // Users table
        $db->exec("CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            role ENUM('admin', 'reseller', 'user') DEFAULT 'user',
            status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
            last_login TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_username (username),
            INDEX idx_email (email),
            INDEX idx_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // Channels table
        $db->exec("CREATE TABLE IF NOT EXISTS channels (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            stream_url VARCHAR(1000) NOT NULL,
            category VARCHAR(100),
            logo_url VARCHAR(500),
            epg_id VARCHAR(100),
            status ENUM('active', 'inactive') DEFAULT 'active',
            created_by INT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_name (name),
            INDEX idx_category (category),
            INDEX idx_status (status),
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // Streams table
        $db->exec("CREATE TABLE IF NOT EXISTS streams (
            id INT AUTO_INCREMENT PRIMARY KEY,
            channel_id INT,
            user_id INT,
            stream_key VARCHAR(255),
            status ENUM('running', 'stopped', 'error') DEFAULT 'stopped',
            viewers INT DEFAULT 0,
            started_at TIMESTAMP NULL,
            stopped_at TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_status (status),
            INDEX idx_started (started_at),
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // Settings table
        $db->exec("CREATE TABLE IF NOT EXISTS settings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            setting_key VARCHAR(100) UNIQUE NOT NULL,
            setting_value TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_key (setting_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // Insert default admin user
        $stmt = $db->prepare("INSERT IGNORE INTO users (username, password, email, role) VALUES (?, ?, ?, ?)");
        $stmt->execute(['cryonix', password_hash('cryonix123', PASSWORD_DEFAULT), 'admin@cryonix.local', 'admin']);
        
        // Insert default settings
        $defaultSettings = [
            ['site_name', 'Cryonix Panel'],
            ['site_url', 'http://localhost'],
            ['admin_email', 'admin@cryonix.local'],
            ['max_concurrent_streams', '100'],
            ['auto_restart_streams', '1'],
            ['session_timeout', '3600']
        ];
        
        $stmt = $db->prepare("INSERT IGNORE INTO settings (setting_key, setting_value) VALUES (?, ?)");
        foreach ($defaultSettings as $setting) {
            $stmt->execute($setting);
        }
        
        return true;
    } catch (Exception $e) {
        error_log("Database setup error: " . $e->getMessage());
        return false;
    }
}

// Run table creation
if (createTables()) {
    echo "Database tables created successfully\n";
} else {
    echo "Error creating database tables\n";
}
?>
EOF

# Create a comprehensive index.php for testing
cat > /opt/cryonix/public/index.php << 'EOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Cryonix Installation Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .info { color: #17a2b8; }
        .test-item { margin: 15px 0; padding: 10px; border-left: 4px solid #ddd; }
        .test-item.success { border-left-color: #28a745; }
        .test-item.error { border-left-color: #dc3545; }
        h1 { color: #333; text-align: center; }
        h2 { color: #666; border-bottom: 2px solid #eee; padding-bottom: 10px; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>🚀 Cryonix Installation Test</h1>";

echo "<div class='test-item success'>";
echo "<h3>✓ Basic Information</h3>";
echo "<p><strong>PHP Version:</strong> " . phpversion() . "</p>";
echo "<p><strong>Server:</strong> " . ($_SERVER['SERVER_SOFTWARE'] ?? 'Unknown') . "</p>";
echo "<p><strong>Document Root:</strong> " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
echo "<p><strong>Current Time:</strong> " . date('Y-m-d H:i:s') . "</p>";
echo "</div>";

// Test database connection
echo "<div class='test-item ";
try {
    require_once '../config/config.php';
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME, DB_USER, DB_PASS);
    echo "success'>";
    echo "<h3>✓ Database Connection</h3>";
    echo "<p>Successfully connected to database: " . DB_NAME . "</p>";
    
    // Test table creation
    require_once '../config/database.php';
    echo "<p>Database tables initialized successfully</p>";
} catch (Exception $e) {
    echo "error'>";
    echo "<h3>✗ Database Connection</h3>";
    echo "<p>Database connection failed: " . $e->getMessage() . "</p>";
}
echo "</div>";

// Test Redis connection
echo "<div class='test-item ";
try {
    if (extension_loaded('redis')) {
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
        $redis->ping();
        echo "success'>";
        echo "<h3>✓ Redis Connection</h3>";
        echo "<p>Redis is running and accessible</p>";
    } else {
        echo "error'>";
        echo "<h3>✗ Redis Extension</h3>";
        echo "<p>Redis PHP extension is not installed</p>";
    }
} catch (Exception $e) {
    echo "error'>";
    echo "<h3>✗ Redis Connection</h3>";
    echo "<p>Redis connection failed: " . $e->getMessage() . "</p>";
}
echo "</div>";

// Test file permissions
echo "<div class='test-item ";
$writableDirectories = ['/opt/cryonix/streams', '/opt/cryonix/logs'];
$allWritable = true;
foreach ($writableDirectories as $dir) {
    if (!is_writable($dir)) {
        $allWritable = false;
        break;
    }
}

if ($allWritable) {
    echo "success'>";
    echo "<h3>✓ File Permissions</h3>";
    echo "<p>All required directories are writable</p>";
} else {
    echo "error'>";
    echo "<h3>✗ File Permissions</h3>";
    echo "<p>Some directories are not writable. Please check permissions.</p>";
}
echo "</div>";

// Test FFmpeg
echo "<div class='test-item ";
$ffmpegPath = '/usr/bin/ffmpeg';
if (file_exists($ffmpegPath) && is_executable($ffmpegPath)) {
    echo "success'>";
    echo "<h3>✓ FFmpeg</h3>";
    echo "<p>FFmpeg is installed and executable</p>";
} else {
    echo "error'>";
    echo "<h3>✗ FFmpeg</h3>";
    echo "<p>FFmpeg not found or not executable</p>";
}
echo "</div>";

echo "<div class='test-item info'>";
echo "<h3>📋 Next Steps</h3>";
echo "<p>1. Access the admin panel at: <strong>http://your-server-ip/" . (defined('ADMIN_PATH') ? ADMIN_PATH : 'admin') . "</strong></p>";
echo "<p>2. Default login: <strong>cryonix</strong> / <strong>cryonix123</strong></p>";
echo "<p>3. Change the default password immediately</p>";
echo "<p>4. Configure your streaming sources</p>";
echo "</div>";

echo "</div></body></html>";
?>
EOF

# Run database setup
log "Setting up database..."
php /opt/cryonix/config/database.php

# Create service management scripts
cat > /opt/cryonix/start-services.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Cryonix services..."
systemctl start nginx
systemctl start php*-fpm
systemctl start mariadb
systemctl start redis-server
systemctl start cryonix-transcoder
echo "✅ All services started!"
systemctl status nginx php*-fpm mariadb redis-server cryonix-transcoder --no-pager -l
EOF

cat > /opt/cryonix/stop-services.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Cryonix services..."
systemctl stop cryonix-transcoder
systemctl stop nginx
systemctl stop php*-fpm
systemctl stop redis-server
echo "✅ Services stopped!"
EOF

cat > /opt/cryonix/restart-services.sh << 'EOF'
#!/bin/bash
echo "🔄 Restarting Cryonix services..."
systemctl restart nginx
systemctl restart php*-fpm
systemctl restart mariadb
systemctl restart redis-server
systemctl restart cryonix-transcoder
echo "✅ Services restarted!"
EOF

chmod +x /opt/cryonix/*.sh

# Enable and start services
systemctl daemon-reload
systemctl enable cryonix-transcoder
systemctl enable nginx
systemctl enable php${PHP_VERSION}-fpm
systemctl enable mariadb
systemctl enable redis-server

# Start all services
/opt/cryonix/start-services.sh

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

# Create credentials file
cat > /opt/cryonix/CREDENTIALS.txt << EOF
CRYONIX INSTALLATION CREDENTIALS
================================

🌐 Access URLs:
   Main Site: http://$SERVER_IP/
   Admin Panel: http://$SERVER_IP/$ADMIN_PATH

👤 Default Login:
   Username: cryonix
   Password: cryonix123

🗄️ Database:
   Host: localhost
   Database: cryonix_db
   Username: cryonix_admin
   Password: $DB_USER_PASSWORD
   Root Password: $DB_ROOT_PASSWORD

🔐 Security:
   JWT Secret: $JWT_SECRET
   Admin Path: $ADMIN_PATH

📁 Important Paths:
   Installation: /opt/cryonix
   Streams: /opt/cryonix/streams
   Logs: /opt/cryonix/logs
   Config: /opt/cryonix/config

🔧 System Info:
   Ubuntu: $UBUNTU_VERSION
   PHP: $PHP_VERSION
   Python: $PYTHON_VERSION

⚠️  IMPORTANT SECURITY NOTES:
   1. Change the default password immediately
   2. Keep these credentials secure
   3. Consider setting up SSL/TLS
   4. Regularly update the system

📚 Management Commands:
   Start Services: /opt/cryonix/start-services.sh
   Stop Services: /opt/cryonix/stop-services.sh
   Restart Services: /opt/cryonix/restart-services.sh

Generated on: $(date)
EOF

chmod 600 /opt/cryonix/CREDENTIALS.txt

# Final permissions
chown -R www-data:www-data /opt/cryonix
chmod -R 755 /opt/cryonix
chmod -R 777 /opt/cryonix/streams
chmod -R 777 /opt/cryonix/logs

# Installation complete
clear
echo ""
echo -e "${GREEN}✅ CRYONIX INSTALLATION COMPLETED SUCCESSFULLY! ✅${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
