<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('servers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('hostname');
            $table->string('ip_address');
            $table->integer('port')->default(80);
            $table->enum('type', ['main', 'load_balancer', 'transcoding']);
            $table->boolean('is_active')->default(true);
            $table->json('stats')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('servers');
    }
};
