<?php
header('Content-Type: application/json');
require_once '../config/config.php';
require_once '../includes/database.php';
require_once '../includes/auth.php';

session_start();
requireAuth();

$database = new Database();
$db = $database->getConnection();

try {
    // Get channel count
    $stmt = $db->query("SELECT COUNT(*) as count FROM channels WHERE status = 'active'");
    $channelCount = $stmt->fetch()['count'];
    
    // Get user count
    $stmt = $db->query("SELECT COUNT(*) as count FROM users WHERE status = 'active'");
    $userCount = $stmt->fetch()['count'];
    
    // Get active streams count
    $stmt = $db->query("SELECT COUNT(*) as count FROM streams WHERE status = 'running'");
    $streamCount = $stmt->fetch()['count'];
    
    // Get system load (simplified)
    $load = sys_getloadavg();
    $systemLoad = round($load[0] * 100 / 4, 2); // Assuming 4 cores
    
    echo json_encode([
        'success' => true,
        'stats' => [
            'channels' => $channelCount,
            'users' => $userCount,
            'streams' => $streamCount,
            'load' => $systemLoad
        ]
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error fetching dashboard data: ' . $e->getMessage()
    ]);
}
?>
