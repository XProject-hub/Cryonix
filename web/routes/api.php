<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\StreamController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\PackageController;
use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Auth routes
    Route::post('login', [AuthController::class, 'login']);
    
    // Protected routes
    Route::middleware('auth:api')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        
        // Dashboard
        Route::get('dashboard/stats', [DashboardController::class, 'stats']);
        Route::get('dashboard/activity', [DashboardController::class, 'recentActivity']);
        Route::get('dashboard/health', [DashboardController::class, 'systemHealth']);
        
        // Admin only routes
        Route::middleware('admin')->group(function () {
            Route::apiResource('users', UserController::class);
            Route::apiResource('packages', PackageController::class);
        });
        
        // Stream management
        Route::apiResource('streams', StreamController::class);
    });
});
