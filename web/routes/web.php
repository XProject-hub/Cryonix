# File: web/routes/web.php (UPDATE - Add to existing routes)

<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\UserController;
use App\Http\Controllers\StreamController;
use App\Http\Controllers\PackageController;

Route::get('/', function () {
    return redirect('/login_' . env('LOGIN_PATH', 'admin'));
});

Route::get('/login_{login_path}', function () {
    return view('auth.login');
})->name('login');

Route::middleware(['auth:api'])->group(function () {
    Route::get('/dashboard', function () {
        return view('dashboard');
    })->name('dashboard');
    
    // User Management
    Route::resource('users', UserController::class);
    
    // Stream Management
    Route::resource('streams', StreamController::class);
    
    // Package Management
    Route::resource('packages', PackageController::class);
});
