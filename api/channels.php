<?php
header('Content-Type: application/json');
require_once '../config/config.php';
require_once '../includes/database.php';
require_once '../includes/auth.php';

session_start();
requireAuth();

$method = $_SERVER['REQUEST_METHOD'];
$database = new Database();
$db = $database->getConnection();

switch ($method) {
    case 'GET':
        $stmt = $db->query("SELECT * FROM channels ORDER BY name");
        $channels = $stmt->fetchAll();
        echo json_encode(['success' => true, 'data' => $channels]);
        break;
    
    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        $name = sanitizeInput($input['name']);
        $stream_url = sanitizeInput($input['stream_url']);
        $category = sanitizeInput($input['category'] ?? '');
        $logo_url = sanitizeInput($input['logo_url'] ?? '');
        
        $stmt = $db->prepare("INSERT INTO channels (name, stream_url, category, logo_url) VALUES (?, ?, ?, ?)");
        if ($stmt->execute([$name, $stream_url, $category, $logo_url])) {
            echo json_encode(['success' => true, 'message' => 'Channel added successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to add channel']);
        }
        break;
    
    case 'PUT':
        $input = json_decode(file_get_contents('php://input'), true);
        $id = (int)$input['id'];
        $name = sanitizeInput($input['name']);
        $stream_url = sanitizeInput($input['stream_url']);
        $category = sanitizeInput($input['category'] ?? '');
        $logo_url = sanitizeInput($input['logo_url'] ?? '');
        
        $stmt = $db->prepare("UPDATE channels SET name=?, stream_url=?, category=?, logo_url=? WHERE id=?");
        if ($stmt->execute([$name, $stream_url, $category, $logo_url, $id])) {
            echo json_encode(['success' => true, 'message' => 'Channel updated successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to update channel']);
        }
        break;
    
    case 'DELETE':
        $input = json_decode(file_get_contents('php://input'), true);
        $id = (int)$input['id'];
        
        $stmt = $db->prepare("DELETE FROM channels WHERE id=?");
        if ($stmt->execute([$id])) {
            echo json_encode(['success' => true, 'message' => 'Channel deleted successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to delete channel']);
        }
        break;
}
?>
