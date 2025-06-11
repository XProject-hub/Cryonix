<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('streams', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('stream_url');
            $table->string('stream_key')->unique();
            $table->enum('type', ['live', 'movie', 'series']);
            $table->string('category');
            $table->boolean('is_active')->default(true);
            $table->json('transcoding_profile')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('streams');
    }
};
