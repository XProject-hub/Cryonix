<?php
header('Content-Type: application/json');
require_once '../config/database.php';
require_once '../includes/auth.php';

requireAuth();

$data = json_decode(file_get_contents('php://input'), true);
$streamId = $data['stream_id'];

$db = new Database();
$conn = $db->getConnection();

// Get current stream status
$query = "SELECT * FROM channels WHERE id = :id";
$stmt = $conn->prepare($query);
$stmt->bindParam(':id', $streamId);
$stmt->execute();
$stream = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$stream) {
    echo json_encode(['status' => 'error', 'message' => 'Stream not found']);
    exit;
}

$newStatus = $stream['status'] ? 0 : 1;

// Update database
$query = "UPDATE channels SET status = :status WHERE id = :id";
$stmt = $conn->prepare($query);
$stmt->bindParam(':status', $newStatus);
$stmt->bindParam(':id', $streamId);

if ($stmt->execute()) {
    // Call Python service to start/stop stream
    $pythonUrl = 'http://localhost:8000/stream/' . ($newStatus ? 'start' : 'stop');
    
    $postData = json_encode([
        'stream_id' => $streamId,
        'input_url' => $stream['stream_url'],
        'output_url' => 'rtmp://localhost/live/' . $streamId,
        'quality' => $stream['quality'] ?? '720p'
    ]);
    
    $ch = curl_init($pythonUrl);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $result = curl_exec($ch);
    curl_close($ch);
    
    echo json_encode(['status' => 'success', 'new_status' => $newStatus]);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Database update failed']);
}
?>
