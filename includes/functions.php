<?php
function sanitizeInput($data) {
    return htmlspecialchars(strip_tags(trim($data)));
}

function generateApiKey() {
    return bin2hex(random_bytes(32));
}

function callPythonService($endpoint, $data = []) {
    $url = TRANSCODER_API . $endpoint;
    $options = [
        'http' => [
            'header' => "Content-type: application/json\r\n",
            'method' => 'POST',
            'content' => json_encode($data)
        ]
    ];
    $context = stream_context_create($options);
    $result = file_get_contents($url, false, $context);
    return json_decode($result, true);
}

function getChannels() {
    $database = new Database();
    $db = $database->getConnection();
    $stmt = $db->query("SELECT * FROM channels ORDER BY name");
    return $stmt->fetchAll();
}

function getUsers() {
    $database = new Database();
    $db = $database->getConnection();
    $stmt = $db->query("SELECT id, username, email, role, status, created_at FROM users ORDER BY created_at DESC");
    return $stmt->fetchAll();
}

function addChannel($name, $stream_url, $category = '', $logo_url = '') {
    $database = new Database();
    $db = $database->getConnection();
    $stmt = $db->prepare("INSERT INTO channels (name, stream_url, category, logo_url) VALUES (?, ?, ?, ?)");
    return $stmt->execute([$name, $stream_url, $category, $logo_url]);
}
?>
