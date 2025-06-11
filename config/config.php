<?php
// Cryonix Configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'cryonix_db');
define('DB_USER', 'cryonix_admin');
define('DB_PASS', 'your_secure_password');

define('SITE_NAME', 'Cryonix Panel');
define('SITE_URL', 'http://localhost');
define('ADMIN_EMAIL', 'admin@cryonix.local');
define('ADMIN_PATH', 'admin');

// Security
define('JWT_SECRET', 'your_jwt_secret_key_here');
define('SESSION_TIMEOUT', 3600); // 1 hour

// Streaming
define('FFMPEG_PATH', '/usr/bin/ffmpeg');
define('STREAM_BASE_URL', 'http://localhost:8080');
define('HLS_OUTPUT_DIR', '/opt/cryonix/streams/');

// Python Service
define('TRANSCODER_API', 'http://localhost:8000');

// System Info (renamed to avoid conflicts)
define('CRYONIX_PHP_VERSION', '7.4');
define('CRYONIX_PYTHON_VERSION', '3.10');
define('CRYONIX_UBUNTU_VERSION', '20.04');

// GitHub Repository
define('GITHUB_REPO', 'https://github.com/XProject-hub/Cryonix.git');

// File Paths
define('INSTALL_DIR', '/opt/cryonix');
define('LOGS_DIR', '/opt/cryonix/logs');
define('STREAMS_DIR', '/opt/cryonix/streams');
define('BACKUPS_DIR', '/opt/cryonix/backups');

// Application Settings
define('MAX_UPLOAD_SIZE', '100M');
define('MAX_CONCURRENT_STREAMS', 100);
define('AUTO_RESTART_STREAMS', true);
define('ENABLE_DEBUG', true);

// Redis Configuration
define('REDIS_HOST', '127.0.0.1');
define('REDIS_PORT', 6379);
define('REDIS_PASSWORD', '');
define('REDIS_DATABASE', 0);

// Email Configuration (for notifications)
define('SMTP_HOST', 'localhost');
define('SMTP_PORT', 587);
define('SMTP_USERNAME', '');
define('SMTP_PASSWORD', '');
define('SMTP_ENCRYPTION', 'tls');

// API Configuration
define('API_VERSION', 'v1');
define('API_RATE_LIMIT', 1000); // requests per hour
define('API_TIMEOUT', 30); // seconds

// Transcoding Settings
define('DEFAULT_VIDEO_CODEC', 'libx264');
define('DEFAULT_AUDIO_CODEC', 'aac');
define('DEFAULT_PRESET', 'fast');
define('DEFAULT_CRF', 23);

// HLS Settings
define('HLS_TIME', 10); // segment duration in seconds
define('HLS_LIST_SIZE', 6); // number of segments in playlist
define('HLS_FLAGS', 'delete_segments');

// Security Settings
define('ENABLE_2FA', false);
define('PASSWORD_MIN_LENGTH', 8);
define('SESSION_SECURE', false); // Set to true when using HTTPS
define('SESSION_HTTPONLY', true);
define('CSRF_PROTECTION', true);

// Logging Settings
define('LOG_LEVEL', 'INFO'); // DEBUG, INFO, WARNING, ERROR
define('LOG_MAX_SIZE', '10M');
define('LOG_ROTATION', true);

// Version Information
define('CRYONIX_VERSION', '1.0.0');
define('CRYONIX_BUILD', date('Y-m-d H:i:s'));

// Error Reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', '/opt/cryonix/logs/php_errors.log');

// Timezone
date_default_timezone_set('UTC');

// Helper Functions
function getConfigValue($key, $default = null)
{
    return defined($key) ? constant($key) : $default;
}

function isDebugMode()
{
    return defined('ENABLE_DEBUG') && ENABLE_DEBUG === true;
}

function getLogPath($filename = 'app.log')
{
    return LOGS_DIR . '/' . $filename;
}

function getStreamPath($filename = '')
{
    return STREAMS_DIR . '/' . $filename;
}

// Database Connection Helper
function getDatabaseConnection()
{
    static $pdo = null;

    if ($pdo === null) {
        try {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
            ];

            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            error_log("Database connection failed: " . $e->getMessage());
            throw new Exception("Database connection failed");
        }
    }

    return $pdo;
}

// Redis Connection Helper
function getRedisConnection()
{
    static $redis = null;

    if ($redis === null && class_exists('Redis')) {
        try {
            $redis = new Redis();
            $redis->connect(REDIS_HOST, REDIS_PORT);

            if (REDIS_PASSWORD) {
                $redis->auth(REDIS_PASSWORD);
            }

            $redis->select(REDIS_DATABASE);
        } catch (Exception $e) {
            error_log("Redis connection failed: " . $e->getMessage());
            $redis = null;
        }
    }

    return $redis;
}

// Ensure required directories exist
$requiredDirs = [LOGS_DIR, STREAMS_DIR, BACKUPS_DIR];
foreach ($requiredDirs as $dir) {
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Set proper permissions for log files
if (!file_exists(getLogPath('php_errors.log'))) {
    touch(getLogPath('php_errors.log'));
    chmod(getLogPath('php_errors.log'), 0644);
}
?>