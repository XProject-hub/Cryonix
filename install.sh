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
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Detect Ubuntu version
. /etc/os-release
UBUNTU_VERSION=$VERSION_ID

if [[ ! "$UBUNTU_VERSION" =~ ^(20.04|22.04|24.04)$ ]]; then
    echo -e "${RED}This script requires Ubuntu 20.04, 22.04 or 24.04 LTS${NC}"
    echo -e "${RED}Detected: Ubuntu $UBUNTU_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected Ubuntu $UBUNTU_VERSION${NC}"

# Set PHP and Python versions based on Ubuntu version
case $UBUNTU_VERSION in
    "20.04")
        PHP_VERSION="8.0"
        PYTHON_VERSION="3.8"
        echo -e "${BLUE}Using PHP $PHP_VERSION and Python $PYTHON_VERSION for Ubuntu 20.04${NC}"
        ;;
    "22.04")
        PHP_VERSION="8.1"
        PYTHON_VERSION="3.10"
        echo -e "${BLUE}Using PHP $PHP_VERSION and Python $PYTHON_VERSION for Ubuntu 22.04${NC}"
        ;;
    "24.04")
        PHP_VERSION="8.3"
        PYTHON_VERSION="3.12"
        echo -e "${BLUE}Using PHP $PHP_VERSION and Python $PYTHON_VERSION for Ubuntu 24.04${NC}"
        ;;
esac

# Update system
echo "🔄 Updating system packages..."
apt-get update
apt-get upgrade -y

# Add necessary repositories for older Ubuntu versions
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    echo "📦 Adding repositories for Ubuntu 20.04..."
    
    # Add Ondrej PHP repository for newer PHP versions
    apt-get install -y software-properties-common
    add-apt-repository ppa:ondrej/php -y
    
    # Add deadsnakes repository for newer Python versions
    add-apt-repository ppa:deadsnakes/ppa -y
    
    # Update after adding repositories
    apt-get update
    
    # For Ubuntu 20.04, we'll use PHP 8.1 and Python 3.9
    PHP_VERSION="8.1"
    PYTHON_VERSION="3.9"
    echo -e "${BLUE}Updated: Using PHP $PHP_VERSION and Python $PYTHON_VERSION${NC}"
fi

# Install dependencies
echo "📦 Installing dependencies..."
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Nginx
echo "🌐 Installing Nginx..."
apt-get install -y nginx

# Install PHP and extensions
echo "🐘 Installing PHP $PHP_VERSION..."
apt-get install -y \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-common

# Install MariaDB
echo "🗄️ Installing MariaDB..."
apt-get install -y mariadb-server mariadb-client

# Install Python and pip
echo "🐍 Installing Python $PYTHON_VERSION..."
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv
    # Install pip for Python 3.9 on Ubuntu 20.04
    curl https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}
else
    apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv python3-pip
fi

# Install FFmpeg
echo "📺 Installing FFmpeg..."
apt-get install -y ffmpeg

# Install Redis
echo "🔴 Installing Redis..."
apt-get install -y redis-server

# Install Node.js (for future use)
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo -e "${GREEN}✓ All dependencies installed${NC}"

# Configure MariaDB
echo "🔐 Configuring MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Generate secure passwords
DB_ROOT_PASSWORD=$(openssl rand -base64 32)
DB_USER_PASSWORD=$(openssl rand -base64 32)
ADMIN_PATH=$(openssl rand -hex 8)

# Secure MariaDB installation
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$DB_ROOT_PASSWORD') WHERE User = 'root'"
mysql -e "DELETE FROM mysql.user WHERE User=''"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -e "DROP DATABASE IF EXISTS test"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
mysql -e "FLUSH PRIVILEGES"

# Create Cryonix database and user
mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS cryonix_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER IF NOT EXISTS 'cryonix_admin'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';"
mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON cryonix_db.* TO 'cryonix_admin'@'localhost';"
mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}✓ MariaDB configured${NC}"

# Install Python dependencies
echo "🐍 Installing Python packages..."
if [ "$UBUNTU_VERSION" = "20.04" ]; then
    python${PYTHON_VERSION} -m pip install --upgrade pip
    python${PYTHON_VERSION} -m pip install fastapi uvicorn redis psutil python-multipart
else
    python3 -m pip install --upgrade pip
    python3 -m pip install fastapi uvicorn redis psutil python-multipart
fi

# Create installation directory
INSTALL_DIR="/opt/cryonix"
echo "📁 Creating installation directory: $INSTALL_DIR"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Create directory structure
mkdir -p {public,config,api,views,includes,services,streams,logs}
mkdir -p {public/assets/css,public/assets/js,views/includes}

# Set permissions
chown -R www-data:www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR

# Configure Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/cryonix << EOF
server {
    listen 80;
    server_name _;
    root /opt/cryonix/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
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

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site and disable default
ln -sf /etc/nginx/sites-available/cryonix /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t && systemctl restart nginx
systemctl enable nginx

echo -e "${GREEN}✓ Nginx configured${NC}"

# Configure PHP
echo "🔧 Configuring PHP..."
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' $PHP_INI
sed -i 's/post_max_size = 8M/post_max_size = 100M/' $PHP_INI
sed -i 's/memory_limit = 128M/memory_limit = 512M/' $PHP_INI
sed -i 's/max_execution_time = 30/max_execution_time = 300/' $PHP_INI
sed -i 's/max_input_time = 60/max_input_time = 300/' $PHP_INI

# Restart PHP-FPM
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

echo -e "${GREEN}✓ PHP configured${NC}"

# Configure Redis
echo "🔴 Configuring Redis..."
systemctl start redis-server
systemctl enable redis-server

# Create systemd service for transcoder
echo "📺 Creating transcoder service..."
cat > /etc/systemd/system/cryonix-transcoder.service << EOF
[Unit]
Description=Cryonix Transcoder Service
After=network.target redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/cryonix/services
ExecStart=/usr/bin/python${PYTHON_VERSION} transcoder.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create config file with generated passwords
echo "⚙️ Creating configuration..."
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
define('JWT_SECRET', '$(openssl rand -base64 64)');
define('SESSION_TIMEOUT', 3600); // 1 hour

// Streaming
define('FFMPEG_PATH', '/usr/bin/ffmpeg');
define('STREAM_BASE_URL', 'http://localhost:8080');
define('HLS_OUTPUT_DIR', '/opt/cryonix/streams/');

// Python Service
define('TRANSCODER_API', 'http://localhost:8000');

// PHP Version
define('PHP_VERSION', '$PHP_VERSION');
define('PYTHON_VERSION', '$PYTHON_VERSION');

// Error Reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
?>
EOF

# Create a simple index.php for testing
cat > /opt/cryonix/public/index.php << 'EOF'
<?php
echo "<h1>🚀 Cryonix Installation Successful!</h1>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Server: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
echo "<p>Current Time: " . date('Y-m-d H:i:s') . "</p>";

// Test database connection
try {
    require_once '../config/config.php';
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME, DB_USER, DB_PASS);
    echo "<p style='color: green;'>✓ Database connection successful</p>";
} catch (Exception $e) {
    echo "<p style='color: red;'>✗ Database connection failed: " . $e->getMessage() . "</p>";
}

// Test Redis connection
try {
    $redis = new Redis();
    $redis->connect('127.0.0.1', 6379);
    echo "<p style='color: green;'>✓ Redis connection successful</p>";
} catch (Exception $e) {
    echo "<p style='color: red;'>✗ Redis connection failed: " . $e->getMessage() . "</p>";
}

phpinfo();
?>
EOF

# Set final permissions
chown -R www-data:www-data /opt/cryonix
chmod -R 755 /opt/cryonix
chmod -R 777 /opt/cryonix/streams
chmod -R 777 /opt/cryonix/logs

# Enable and start services
systemctl daemon-reload
systemctl enable cryonix-transcoder

# Create startup script
cat > /opt/cryonix/start-services.sh << 'EOF'
#!/bin/bash
echo "Starting Cryonix services..."
systemctl start nginx
systemctl start php*-fpm
systemctl start mariadb
systemctl start redis-server
systemctl start cryonix-transcoder
echo "All services started!"
EOF

chmod +x /opt/cryonix/start-services.sh

# Create stop script
cat > /opt/cryonix/stop-services.sh << 'EOF'
#!/bin/bash
echo "Stopping Cryonix services..."
systemctl stop cryonix-transcoder
systemctl stop nginx
systemctl stop php*-fpm
systemctl stop redis-server
echo "Services stopped!"
EOF

chmod +x /opt/cryonix/stop-services.sh

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

# Installation complete
echo ""
echo -e "${GREEN}✅ Cryonix installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
