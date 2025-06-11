<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    public function index()
    {
        return User::paginate(15);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'username' => 'required|unique:users',
            'email' => 'required|email|unique:users',
            'password' => 'required|min:6',
            'role' => 'required|in:admin,reseller,user'
        ]);

        $validated['password'] = Hash::make($validated['password']);
        
        return User::create($validated);
    }

    public function show(User $user)
    {
        return $user->load('userLines');
    }

    public function update(Request $request, User $user)
    {
        $validated = $request->validate([
            'username' => 'unique:users,username,' . $user->id,
            'email' => 'email|unique:users,email,' . $user->id,
            'password' => 'min:6',
            'role' => 'in:admin,reseller,user',
            'is_active' => 'boolean'
        ]);

        if (isset($validated['password'])) {
            $validated['password'] = Hash::make($validated['password']);
        }

        $user->update($validated);
        return $user;
    }

    public function destroy(User $user)
    {
        $user->delete();
        return response()->json(['message' => 'User deleted']);
    }
}
