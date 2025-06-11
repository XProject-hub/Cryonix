<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

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
            throw new Exception("Database connection failed: " . $exception->getMessage());
        }
        return $this->conn;
    }
}

// Database Schema Creation
function createTables() {
    try {
        $database = new Database();
        $db = $database->getConnection();
        
        if (!$db) {
            throw new Exception("Failed to get database connection");
        }
        
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
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
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
        
        // Resellers table
        $db->exec("CREATE TABLE IF NOT EXISTS resellers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            max_users INT DEFAULT 10,
            max_channels INT DEFAULT 100,
            commission_rate DECIMAL(5,2) DEFAULT 0.00,
            status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // User subscriptions table
        $db->exec("CREATE TABLE IF NOT EXISTS user_subscriptions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            channel_id INT,
            expires_at TIMESTAMP NULL,
            status ENUM('active', 'expired', 'suspended') DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        
        // Logs table
        $db->exec("CREATE TABLE IF NOT EXISTS logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NULL,
            action VARCHAR(255) NOT NULL,
            description TEXT,
            ip_address VARCHAR(45),
            user_agent TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_user_id (user_id),
            INDEX idx_action (action),
            INDEX idx_created_at (created_at),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
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
            ['session_timeout', '3600'],
            ['enable_registration', '0'],
            ['enable_2fa', '0'],
            ['default_user_role', 'user'],
            ['max_upload_size', '100M'],
            ['stream_timeout', '300'],
            ['enable_logs', '1']
        ];
        
        $stmt = $db->prepare("INSERT IGNORE INTO settings (setting_key, setting_value) VALUES (?, ?)");
        foreach ($defaultSettings as $setting) {
            $stmt->execute($setting);
        }
        
        // Create sample channel for testing
        $stmt = $db->prepare("INSERT IGNORE INTO channels (name, stream_url, category, status, created_by) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute(['Test Channel', 'http://example.com/stream.m3u8', 'Entertainment', 'active', 1]);
        
        echo "Database tables created successfully\n";
        return true;
        
    } catch (Exception $e) {
        error_log("Database setup error: " . $e->getMessage());
        echo "Error creating database tables: " . $e->getMessage() . "\n";
        return false;
    }
}

// Test database connection first
try {
    $database = new Database();
    $db = $database->getConnection();
    
    if ($db) {
        echo "Database connection successful\n";
        
        // Run table creation
        if (createTables()) {
            echo "Database setup completed successfully\n";
            exit(0);
        } else {
            echo "Database setup failed\n";
            exit(1);
        }
    } else {
        echo "Failed to connect to database\n";
        exit(1);
    }
    
} catch (Exception $e) {
    echo "Database error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
