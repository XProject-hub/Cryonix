<?php
// File: /opt/cryonix/api/update.php

header('Content-Type: application/json');
require_once '../config/config.php';
require_once '../includes/auth.php';

session_start();
requireAuth();

// Only admin can perform updates
if (!isAdmin()) {
    echo json_encode([
        'success' => false,
        'message' => 'Only administrators can perform updates'
    ]);
    exit;
}

function execCommand($command) {
    $output = [];
    $returnCode = 0;
    exec($command . " 2>&1", $output, $returnCode);
    return [
        'output' => $output,
        'code' => $returnCode
    ];
}

function checkGitInstalled() {
    $result = execCommand("which git");
    return $result['code'] === 0;
}

function getCurrentVersion() {
    if (file_exists('../version.txt')) {
        return trim(file_get_contents('../version.txt'));
    }
    return 'unknown';
}

function backupFiles() {
    $backupDir = "/opt/cryonix/backups";
    $timestamp = date('Y-m-d_H-i-s');
    $backupFile = "{$backupDir}/backup_{$timestamp}.tar.gz";
    
    if (!is_dir($backupDir)) {
        mkdir($backupDir, 0755, true);
    }
    
    $result = execCommand("tar -czf {$backupFile} -C /opt/cryonix .");
    return $result['code'] === 0 ? $backupFile : false;
}

function performUpdate() {
    $updates = [
        'success' => false,
        'steps' => [],
        'version' => 'unknown'
    ];

    // Step 1: Check Git installation
    if (!checkGitInstalled()) {
        $updates['steps'][] = [
            'step' => 'Git check',
            'status' => 'failed',
            'message' => 'Git is not installed'
        ];
        return $updates;
    }
    $updates['steps'][] = [
        'step' => 'Git check',
        'status' => 'success'
    ];

    // Step 2: Create backup
    $backupFile = backupFiles();
    if (!$backupFile) {
        $updates['steps'][] = [
            'step' => 'Backup',
            'status' => 'failed',
            'message' => 'Failed to create backup'
        ];
        return $updates;
    }
    $updates['steps'][] = [
        'step' => 'Backup',
        'status' => 'success',
        'message' => "Backup created: " . basename($backupFile)
    ];

    // Step 3: Pull updates from GitHub
    $result = execCommand("cd /opt/cryonix && git pull https://github.com/XProject-hub/Cryonix.git main");
    if ($result['code'] !== 0) {
        $updates['steps'][] = [
            'step' => 'Update',
            'status' => 'failed',
            'message' => implode("\n", $result['output'])
        ];
        return $updates;
    }
    $updates['steps'][] = [
        'step' => 'Update',
        'status' => 'success',
        'message' => implode("\n", $result['output'])
    ];

    // Step 4: Update permissions
    $result = execCommand("chown -R www-data:www-data /opt/cryonix && chmod -R 755 /opt/cryonix");
    if ($result['code'] !== 0) {
        $updates['steps'][] = [
            'step' => 'Permissions',
            'status' => 'failed',
            'message' => 'Failed to update permissions'
        ];
        return $updates;
    }
    $updates['steps'][] = [
        'step' => 'Permissions',
        'status' => 'success'
    ];

    // Step 5: Restart services
    $result = execCommand("/opt/cryonix/start-services.sh");
    if ($result['code'] !== 0) {
        $updates['steps'][] = [
            'step' => 'Services',
            'status' => 'failed',
            'message' => 'Failed to restart services'
        ];
        return $updates;
    }
    $updates['steps'][] = [
        'step' => 'Services',
        'status' => 'success'
    ];

    $updates['success'] = true;
    $updates['version'] = getCurrentVersion();
    return $updates;
}

// Handle update request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $result = performUpdate();
    echo json_encode($result);
    exit;
}

// Handle version check request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    echo json_encode([
        'success' => true,
        'current_version' => getCurrentVersion()
    ]);
    exit;
}
