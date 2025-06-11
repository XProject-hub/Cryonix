<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Package extends Model
{
    protected $fillable = [
        'name',
        'description',
        'price',
        'duration_days',
        'max_connections',
        'allowed_categories',
        'is_active'
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'allowed_categories' => 'array',
        'is_active' => 'boolean'
    ];

    public function userLines()
    {
        return $this->hasMany(UserLine::class);
    }
}
