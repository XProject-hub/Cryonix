<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserLine extends Model
{
    protected $fillable = [
        'user_id',
        'package_id',
        'username',
        'password',
        'expires_at',
        'max_connections',
        'is_active',
        'allowed_ips'
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'allowed_ips' => 'array',
        'is_active' => 'boolean'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function package()
    {
        return $this->belongsTo(Package::class);
    }

    public function isExpired()
    {
        return $this->expires_at->isPast();
    }
}
