<?php
session_start();
require_once '../config/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

// Route handling
$request = $_SERVER['REQUEST_URI'];
$path = parse_url($request, PHP_URL_PATH);
$path = str_replace('/public', '', $path);

switch ($path) {
    case '/':
    case '/login':
        if (isLoggedIn()) {
            header('Location: /dashboard');
            exit;
        }
        include '../views/login.php';
        break;
    
    case '/dashboard':
        requireAuth();
        include '../views/dashboard.php';
        break;
    
    case '/channels':
        requireAuth();
        include '../views/channels.php';
        break;
    
    case '/users':
        requireAuth();
        include '../views/users.php';
        break;
    
    case '/logout':
        logout();
        header('Location: /login');
        break;
    
    default:
        http_response_code(404);
        echo "404 - Page Not Found";
        break;
}
?>
