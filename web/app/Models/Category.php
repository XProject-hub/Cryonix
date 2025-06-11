<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    protected $fillable = [
        'name',
        'slug',
        'type',
        'sort_order',
        'is_active'
    ];

    protected $casts = [
        'is_active' => 'boolean'
    ];

    public function streams()
    {
        return $this->hasMany(Stream::class, 'category', 'slug');
    }
}
