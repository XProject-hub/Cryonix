<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('epg_channels', function (Blueprint $table) {
            $table->id();
            $table->foreignId('source_id')->constrained('epg_sources')->onDelete('cascade');
            $table->string('channel_id');
            $table->string('name');
            $table->string('icon')->nullable();
            $table->timestamps();
            
            $table->index(['source_id', 'channel_id']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('epg_channels');
    }
};
