<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Stream;
use App\Models\UserLine;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function stats()
    {
        $stats = [
            'total_users' => User::count(),
            'active_users' => User::where('is_active', true)->count(),
            'total_streams' => Stream::count(),
            'active_streams' => Stream::where('is_active', true)->count(),
            'total_lines' => UserLine::count(),
            'active_lines' => UserLine::where('is_active', true)
                ->where('expires_at', '>', now())
                ->count(),
            'expired_lines' => UserLine::where('expires_at', '<', now())->count(),
        ];

        return response()->json($stats);
    }

    public function recentActivity()
    {
        $recentUsers = User::latest()->take(5)->get();
        $recentStreams = Stream::latest()->take(5)->get();
        
        return response()->json([
            'recent_users' => $recentUsers,
            'recent_streams' => $recentStreams
        ]);
    }

    public function systemHealth()
    {
        $health = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'disk_space' => $this->checkDiskSpace(),
            'memory_usage' => $this->getMemoryUsage()
        ];

        return response()->json($health);
    }

    private function checkDatabase()
    {
        try {
            DB::connection()->getPdo();
            return ['status' => 'healthy', 'message' => 'Database connection OK'];
        } catch (\Exception $e) {
            return ['status' => 'error', 'message' => 'Database connection failed'];
        }
    }

    private function checkRedis()
    {
        try {
            \Illuminate\Support\Facades\Redis::ping();
            return ['status' => 'healthy', 'message' => 'Redis connection OK'];
        } catch (\Exception $e) {
            return ['status' => 'error', 'message' => 'Redis connection failed'];
        }
    }

    private function checkDiskSpace()
    {
        $freeBytes = disk_free_space('/');
        $totalBytes = disk_total_space('/');
        $usedPercent = (($totalBytes - $freeBytes) / $totalBytes) * 100;

        return [
            'status' => $usedPercent > 90 ? 'warning' : 'healthy',
            'used_percent' => round($usedPercent, 2),
            'free_space' => $this->formatBytes($freeBytes)
        ];
    }

    private function getMemoryUsage()
    {
        $memoryUsage = memory_get_usage(true);
        $memoryLimit = ini_get('memory_limit');
        
        return [
            'current' => $this->formatBytes($memoryUsage),
            'limit' => $memoryLimit
        ];
    }

    private function formatBytes($bytes, $precision = 2)
    {
        $units = array('B', 'KB', 'MB', 'GB', 'TB');
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
}
