<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Server extends Model
{
    protected $fillable = [
        'name',
        'hostname',
        'ip_address',
        'port',
        'type',
        'is_active',
        'stats'
    ];

    protected $casts = [
        'stats' => 'array',
        'is_active' => 'boolean'
    ];
}
