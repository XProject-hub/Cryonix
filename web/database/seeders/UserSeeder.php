<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run()
    {
        User::create([
            'username' => 'cryonix',
            'email' => 'admin@cryonix.com',
            'password' => Hash::make('cryonix123'),
            'role' => 'admin',
            'is_active' => true
        ]);
    }
}
