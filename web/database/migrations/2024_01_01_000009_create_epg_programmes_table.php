<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('epg_programmes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('source_id')->constrained('epg_sources')->onDelete('cascade');
            $table->string('channel_id');
            $table->datetime('start_time');
            $table->datetime('stop_time');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('category')->nullable();
            $table->timestamps();
            
            $table->index(['channel_id', 'start_time']);
            $table->index(['source_id', 'start_time']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('epg_programmes');
    }
};
