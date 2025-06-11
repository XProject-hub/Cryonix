<?php
// Cryonix Configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'cryonix_db');
define('DB_USER', 'cryonix_admin');
define('DB_PASS', 'your_secure_password');

define('SITE_NAME', 'Cryonix Panel');
define('SITE_URL', 'http://localhost');
define('ADMIN_EMAIL', 'admin@cryonix.local');

// Security
define('JWT_SECRET', 'your_jwt_secret_key_here');
define('SESSION_TIMEOUT', 3600); // 1 hour

// Streaming
define('FFMPEG_PATH', '/usr/bin/ffmpeg');
define('STREAM_BASE_URL', 'http://localhost:8080');
define('HLS_OUTPUT_DIR', '/opt/cryonix/streams/');

// Python Service
define('TRANSCODER_API', 'http://localhost:8000');

// Error Reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
?>
