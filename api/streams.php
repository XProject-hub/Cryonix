<?php
header('Content-Type: application/json');
require_once '../config/config.php';
require_once '../includes/database.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

session_start();
requireAuth();

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

$database = new Database();
$db = $database->getConnection();

switch ($method) {
    case 'GET':
        // Get all streams
        $stmt = $db->query("
            SELECT s.*, c.name as channel_name 
            FROM streams s 
            LEFT JOIN channels c ON s.channel_id = c.id 
            ORDER BY s.started_at DESC
        ");
        $streams = $stmt->fetchAll();
        echo json_encode(['success' => true, 'data' => $streams]);
        break;
        
    case 'POST':
        $action = $input['action'] ?? '';
        
        if ($action === 'start') {
            $channelId = (int)$input['channel_id'];
            
            // Get channel info
            $stmt = $db->prepare("SELECT * FROM channels WHERE id = ?");
            $stmt->execute([$channelId]);
            $channel = $stmt->fetch();
            
            if (!$channel) {
                echo json_encode(['success' => false, 'message' => 'Channel not found']);
                break;
            }
            
            // Call Python transcoder service
            $transcoderData = [
                'channel_id' => $channelId,
                'stream_url' => $channel['stream_url'],
                'resolution' => '720p',
                'bitrate' => '2000k'
            ];
            
            $result = callPythonService('/stream/start', $transcoderData);
            
            if ($result && $result['success']) {
                // Save stream to database
                $stmt = $db->prepare("
                    INSERT INTO streams (channel_id, user_id, stream_key, status, started_at) 
                    VALUES (?, ?, ?, 'running', NOW())
                ");
                $stmt->execute([$channelId, $_SESSION['user_id'], $result['stream_id']]);
                
                echo json_encode([
                    'success' => true, 
                    'message' => 'Stream started successfully',
                    'stream_id' => $result['stream_id'],
                    'output_url' => $result['output_url']
                ]);
            } else {
                echo json_encode(['success' => false, 'message' => 'Failed to start stream']);
            }
            
        } elseif ($action === 'stop') {
            $streamId = $input['stream_id'] ?? '';
            
            // Call Python transcoder service
            $result = callPythonService('/stream/stop', ['stream_id' => $streamId]);
            
            if ($result && $result['success']) {
                // Update stream status in database
                $stmt = $db->prepare("UPDATE streams SET status = 'stopped' WHERE stream_key = ?");
                $stmt->execute([$streamId]);
                
                echo json_encode(['success' => true, 'message' => 'Stream stopped successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Failed to stop stream']);
            }
        }
        break;
        
    case 'DELETE':
        $streamId = (int)$input['id'];
        
        $stmt = $db->prepare("DELETE FROM streams WHERE id = ?");
        if ($stmt->execute([$streamId])) {
            echo json_encode(['success' => true, 'message' => 'Stream deleted successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to delete stream']);
        }
        break;
}
?>
