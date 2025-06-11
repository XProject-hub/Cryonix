# File: web/routes/api.php (UPDATE - Replace existing content)

<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\StreamController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\PackageController;
use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('login', [AuthController::class, 'login']);
    
    Route::middleware('auth:api')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        
        // Dashboard
        Route::get('dashboard/stats', [DashboardController::class, 'stats']);
        Route::get('dashboard/activity', [DashboardController::class, 'recentActivity']);
        Route::get('dashboard/health', [DashboardController::class, 'systemHealth']);
        
        // API Resources
        Route::apiResource('users', UserController::class);
        Route::apiResource('streams', StreamController::class);
        Route::apiResource('packages', PackageController::class);
        
        // M3U Generation
        Route::get('playlist/{username}/{password}', [StreamController::class, 'generateM3U']);
        Route::get('epg/{username}/{password}', [StreamController::class, 'generateEPG']);
    });
});
