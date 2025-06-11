<?php

namespace App\Http\Controllers;

use App\Models\Stream;
use Illuminate\Http\Request;

class StreamController extends Controller
{
    public function index()
    {
        return Stream::paginate(15);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string',
            'stream_url' => 'required|url',
            'type' => 'required|in:live,movie,series',
            'category' => 'required|string'
        ]);

        $validated['stream_key'] = uniqid('stream_');
        
        return Stream::create($validated);
    }

    public function show(Stream $stream)
    {
        return $stream;
    }

    public function update(Request $request, Stream $stream)
    {
        $validated = $request->validate([
            'name' => 'string',
            'stream_url' => 'url',
            'type' => 'in:live,movie,series',
            'category' => 'string',
            'is_active' => 'boolean'
        ]);

        $stream->update($validated);
        return $stream;
    }

    public function destroy(Stream $stream)
    {
        $stream->delete();
        return response()->json(['message' => 'Stream deleted']);
    }
}
