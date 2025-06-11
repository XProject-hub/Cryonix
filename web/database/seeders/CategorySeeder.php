<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run()
    {
        $categories = [
            ['name' => 'Sports', 'slug' => 'sports', 'type' => 'live'],
            ['name' => 'News', 'slug' => 'news', 'type' => 'live'],
            ['name' => 'Entertainment', 'slug' => 'entertainment', 'type' => 'live'],
            ['name' => 'Movies', 'slug' => 'movies', 'type' => 'movie'],
            ['name' => 'Series', 'slug' => 'series', 'type' => 'series'],
        ];

        foreach ($categories as $category) {
            Category::create($category);
        }
    }
}
