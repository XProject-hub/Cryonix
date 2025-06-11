#!/bin/bash

# Cryonix Installation Script
# This script installs Cryonix streaming management panel

set -e

echo "🚀 Starting Cryonix Installation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check Ubuntu version
. /etc/os-release
if [[ ! "$VERSION_ID" =~ ^(20.04|22.04|24.04)$ ]]; then
    echo -e "${RED}This script requires Ubuntu 20.04, 22.04 or 24.04 LTS${NC}"
    exit 1
fi

echo -e "${GREEN}✓ System requirements checked${NC}"

# Install dependencies
echo "📦 Installing dependencies..."
apt-get update
apt-get install -y \
    nginx \
    php8.1-fpm \
    php8.1-mysql \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-zip \
    mariadb-server \
    python3.11 \
    python3-pip \
    ffmpeg \
    redis-server

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Configure MySQL
echo "🗄️ Configuring MySQL..."
mysql_secure_installation

# Create database and user
echo "Creating database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS cryonix_db;"
mysql -e "CREATE USER IF NOT EXISTS 'cryonix_admin'@'localhost' IDENTIFIED BY 'your_secure_password';"
mysql -e "GRANT ALL PRIVILEGES ON cryonix_db.* TO 'cryonix_admin'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}✓ MySQL configured${NC}"

# Install Python dependencies
echo "🐍 Installing Python packages..."
pip3 install fastapi uvicorn redis psutil

# Create installation directory
INSTALL_DIR="/opt/cryonix"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone repository (placeholder - replace with actual repo)
# git clone https://github.com/xproject-hub/Cryonix.git .

# Set permissions
chown -R www-data:www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR

# Configure Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/cryonix << 'EOF'
server {
    listen 80;
    server_name _;
    root /opt/cryonix/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    location /streams {
        alias /opt/cryonix/streams;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
    }

    location ~ /\. {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/cryonix /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo -e "${GREEN}✓ Nginx configured${NC}"

# Configure PHP
echo "🔧 Configuring PHP..."
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/8.1/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 100M/' /etc/php/8.1/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini
systemctl restart php8.1-fpm

# Create systemd service for transcoder
echo "📺 Creating transcoder service..."
cat > /etc/systemd/system/cryonix-transcoder.service << 'EOF'
[Unit]
Description=Cryonix Transcoder Service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/cryonix/services
ExecStart=/usr/bin/python3 transcoder.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cryonix-transcoder
systemctl start cryonix-transcoder

# Create required directories
mkdir -p /opt/cryonix/streams
mkdir -p /opt/cryonix/logs
chown -R www-data:www-data /opt/cryonix/streams /opt/cryonix/logs

# Generate random admin URL path
ADMIN_PATH=$(openssl rand -hex 8)
sed -i "s/admin_path = .*/admin_path = $ADMIN_PATH/" /opt/cryonix/config/config.php

# Final setup
echo "🔐 Performing final setup..."
php /opt/cryonix/config/database.php

# Installation complete
echo -e "${GREEN}✅ Cryonix installation complete!${NC}"
echo -e "${YELLOW}Admin URL: http://YOUR_SERVER_IP/$ADMIN_PATH${NC}"
echo -e "${YELLOW}Default login: cryonix / cryonix123${NC}"
echo -e "${RED}⚠️  IMPORTANT: Change the default password immediately!${NC}"

# Print MySQL credentials
echo -e "${YELLOW}MySQL Database: cryonix_db${NC}"
echo -e "${YELLOW}MySQL User: cryonix_admin${NC}"
echo -e "${YELLOW}MySQL Password: your_secure_password${NC}"

echo -e "\n${GREEN}Thank you for installing Cryonix!${NC}"

