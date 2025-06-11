<?php

namespace App\Http\Controllers;

use App\Models\Package;
use Illuminate\Http\Request;

class PackageController extends Controller
{
    public function index()
    {
        return Package::paginate(15);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string',
            'description' => 'nullable|string',
            'price' => 'required|numeric|min:0',
            'duration_days' => 'required|integer|min:1',
            'max_connections' => 'required|integer|min:1',
            'allowed_categories' => 'nullable|array'
        ]);

        return Package::create($validated);
    }

    public function show(Package $package)
    {
        return $package->load('userLines');
    }

    public function update(Request $request, Package $package)
    {
        $validated = $request->validate([
            'name' => 'string',
            'description' => 'nullable|string',
            'price' => 'numeric|min:0',
            'duration_days' => 'integer|min:1',
            'max_connections' => 'integer|min:1',
            'allowed_categories' => 'nullable|array',
            'is_active' => 'boolean'
        ]);

        $package->update($validated);
        return $package;
    }

    public function destroy(Package $package)
    {
        $package->delete();
        return response()->json(['message' => 'Package deleted']);
    }
}
