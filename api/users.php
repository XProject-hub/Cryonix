<?php
header('Content-Type: application/json');
require_once '../config/config.php';
require_once '../includes/database.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

session_start();
requireAuth();

$method = $_SERVER['REQUEST_METHOD'];
$database = new Database();
$db = $database->getConnection();

switch ($method) {
    case 'GET':
        $stmt = $db->query("SELECT id, username, email, role, status, created_at FROM users ORDER BY created_at DESC");
        $users = $stmt->fetchAll();
        echo json_encode(['success' => true, 'data' => $users]);
        break;
    
    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        $username = sanitizeInput($input['username']);
        $email = sanitizeInput($input['email']);
        $password = password_hash($input['password'], PASSWORD_DEFAULT);
        $role = sanitizeInput($input['role']);
        $status = sanitizeInput($input['status']);
        
        // Check if username or email already exists
        $stmt = $db->prepare("SELECT COUNT(*) as count FROM users WHERE username = ? OR email = ?");
        $stmt->execute([$username, $email]);
        if ($stmt->fetch()['count'] > 0) {
            echo json_encode(['success' => false, 'message' => 'Username or email already exists']);
            break;
        }
        
        $stmt = $db->prepare("INSERT INTO users (username, email, password, role, status) VALUES (?, ?, ?, ?, ?)");
        if ($stmt->execute([$username, $email, $password, $role, $status])) {
            echo json_encode(['success' => true, 'message' => 'User added successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to add user']);
        }
        break;
    
    case 'PUT':
        $input = json_decode(file_get_contents('php://input'), true);
        $id = (int)$input['id'];
        $username = sanitizeInput($input['username']);
        $email = sanitizeInput($input['email']);
        $role = sanitizeInput($input['role']);
        $status = sanitizeInput($input['status']);
        
        $updateFields = "username=?, email=?, role=?, status=?";
        $params = [$username, $email, $role, $status];
        
        // Update password if provided
        if (!empty($input['password'])) {
            $updateFields .= ", password=?";
            $params[] = password_hash($input['password'], PASSWORD_DEFAULT);
        }
        
        $params[] = $id;
        
        $stmt = $db->prepare("UPDATE users SET $updateFields WHERE id=?");
        if ($stmt->execute($params)) {
            echo json_encode(['success' => true, 'message' => 'User updated successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to update user']);
        }
        break;
    
    case 'DELETE':
        $input = json_decode(file_get_contents('php://input'), true);
        $id = (int)$input['id'];
        
        // Don't allow deleting the current user
        if ($id == $_SESSION['user_id']) {
            echo json_encode(['success' => false, 'message' => 'Cannot delete your own account']);
            break;
        }
        
        $stmt = $db->prepare("DELETE FROM users WHERE id=?");
        if ($stmt->execute([$id])) {
            echo json_encode(['success' => true, 'message' => 'User deleted successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to delete user']);
        }
        break;
}
?>
