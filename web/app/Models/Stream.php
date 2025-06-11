<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Stream extends Model
{
    protected $fillable = [
        'name',
        'stream_url',
        'stream_key',
        'type',
        'category',
        'is_active',
        'transcoding_profile'
    ];

    protected $casts = [
        'transcoding_profile' => 'array',
        'is_active' => 'boolean'
    ];
}
