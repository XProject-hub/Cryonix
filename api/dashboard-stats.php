<?php
header('Content-Type: application/json');
require_once '../config/database.php';
require_once '../includes/auth.php';

requireAuth();

$db = new Database();
$conn = $db->getConnection();

// Get active streams count
$query = "SELECT COUNT(*) as count FROM channels WHERE status = 1";
$stmt = $conn->prepare($query);
$stmt->execute();
$activeStreams = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

// Get total users
$query = "SELECT COUNT(*) as count FROM users WHERE status = 'active'";
$stmt = $conn->prepare($query);
$stmt->execute();
$totalUsers = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

// Get bandwidth usage (mock data for now)
$bandwidth = rand(50, 500);

// Get server load
$serverLoad = sys_getloadavg()[0] * 100;

// Get stream details
$query = "SELECT id, name, status, viewers, quality FROM channels ORDER BY name";
$stmt = $conn->prepare($query);
$stmt->execute();
$streams = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo json_encode([
    'active_streams' => $activeStreams,
    'total_users' => $totalUsers,
    'bandwidth' => $bandwidth,
    'server_load' => round($serverLoad, 1),
    'streams' => $streams
]);
?>
