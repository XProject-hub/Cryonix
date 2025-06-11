#!/usr/bin/env python3
"""
Cryonix Transcoder Service
FastAPI-based microservice for FFmpeg stream management
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
import subprocess
import psutil
import asyncio
import json
import os
import logging
from typing import Dict, List, Optional
import redis
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Cryonix Transcoder", version="1.0.0")

# Redis connection for stream state management
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

# Configuration
FFMPEG_PATH = "/usr/bin/ffmpeg"
HLS_OUTPUT_DIR = "/opt/cryonix/streams/"
STREAM_BASE_URL = "http://localhost:8080/streams/"

# Ensure output directory exists
os.makedirs(HLS_OUTPUT_DIR, exist_ok=True)

class StreamRequest(BaseModel):
    channel_id: int
    stream_url: str
    output_format: str = "hls"
    resolution: str = "720p"
    bitrate: str = "2000k"

class StreamResponse(BaseModel):
    success: bool
    message: str
    stream_id: Optional[str] = None
    output_url: Optional[str] = None

class StreamStatus(BaseModel):
    stream_id: str
    status: str
    viewers: int = 0
    uptime: int = 0
    bitrate: str = "0k"

# Active streams storage
active_streams: Dict[str, subprocess.Popen] = {}

@app.get("/")
async def root():
    return {"message": "Cryonix Transcoder Service", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "active_streams": len(active_streams),
        "system_load": psutil.cpu_percent(),
        "memory_usage": psutil.virtual_memory().percent
    }

@app.post("/stream/start", response_model=StreamResponse)
async def start_stream(request: StreamRequest, background_tasks: BackgroundTasks):
    """Start a new stream transcoding process"""
    try:
        stream_id = f"stream_{request.channel_id}_{int(datetime.now().timestamp())}"
        output_dir = os.path.join(HLS_OUTPUT_DIR, stream_id)
        os.makedirs(output_dir, exist_ok=True)
        
        # Build FFmpeg command
        ffmpeg_cmd = build_ffmpeg_command(
            request.stream_url,
            output_dir,
            request.resolution,
            request.bitrate
        )
        
        # Start FFmpeg process
        process = subprocess.Popen(
            ffmpeg_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        # Store active stream
        active_streams[stream_id] = process
        
        # Store stream info in Redis
        stream_info = {
            "channel_id": request.channel_id,
            "stream_url": request.stream_url,
            "status": "running",
            "started_at": datetime.now().isoformat(),
            "output_dir": output_dir
        }
        redis_client.hset(f"stream:{stream_id}", mapping=stream_info)
        
        # Monitor stream in background
        background_tasks.add_task(monitor_stream, stream_id, process)
        
        output_url = f"{STREAM_BASE_URL}{stream_id}/playlist.m3u8"
        
        logger.info(f"Started stream {stream_id} for channel {request.channel_id}")
        
        return StreamResponse(
            success=True,
            message="Stream started successfully",
            stream_id=stream_id,
            output_url=output_url
        )
        
    except Exception as e:
        logger.error(f"Error starting stream: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/stream/stop")
async def stop_stream(stream_id: str):
    """Stop a running stream"""
    try:
        if stream_id not in active_streams:
            raise HTTPException(status_code=404, detail="Stream not found")
        
        process = active_streams[stream_id]
        process.terminate()
        
        # Wait for process to terminate
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        
        # Clean up
        del active_streams[stream_id]
        redis_client.hset(f"stream:{stream_id}", "status", "stopped")
        
        logger.info(f"Stopped stream {stream_id}")
        
        return {"success": True, "message": "Stream stopped successfully"}
        
    except Exception as e:
        logger.error(f"Error stopping stream: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stream/status/{stream_id}", response_model=StreamStatus)
async def get_stream_status(stream_id: str):
    """Get status of a specific stream"""
    try:
        stream_info = redis_client.hgetall(f"stream:{stream_id}")
        
        if not stream_info:
            raise HTTPException(status_code=404, detail="Stream not found")
        
        # Calculate uptime
        started_at = datetime.fromisoformat(stream_info.get("started_at", datetime.now().isoformat()))
        uptime = int((datetime.now() - started_at).total_seconds())
        
        # Check if process is still running
        status = "stopped"
        if stream_id in active_streams:
            process = active_streams[stream_id]
            if process.poll() is None:
                status = "running"
            else:
                status = "error"
                del active_streams[stream_id]
        
        return StreamStatus(
            stream_id=stream_id,
            status=status,
            uptime=uptime,
            viewers=int(stream_info.get("viewers", 0)),
            bitrate=stream_info.get("bitrate", "0k")
        )
        
    except Exception as e:
        logger.error(f"Error getting stream status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/streams", response_model=List[StreamStatus])
async def list_streams():
    """List all active streams"""
    try:
        streams = []
        stream_keys = redis_client.keys("stream:*")
        
        for key in stream_keys:
            stream_id = key.split(":")[1]
            try:
                status = await get_stream_status(stream_id)
                streams.append(status)
            except:
                continue
        
        return streams
        
    except Exception as e:
        logger.error(f"Error listing streams: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

def build_ffmpeg_command(input_url: str, output_dir: str, resolution: str, bitrate: str) -> List[str]:
    """Build FFmpeg command for transcoding"""
    
    # Resolution mapping
    resolution_map = {
        "240p": "426x240",
        "360p": "640x360",
        "480p": "854x480",
        "720p": "1280x720",
        "1080p": "1920x1080"
    }
    
    size = resolution_map.get(resolution, "1280x720")
    playlist_path = os.path.join(output_dir, "playlist.m3u8")
    segment_path = os.path.join(output_dir, "segment_%03d.ts")
    
    cmd = [
        FFMPEG_PATH,
        "-i", input_url,
        "-c:v", "libx264",
        "-c:a", "aac",
        "-b:v", bitrate,
        "-b:a", "128k",
        "-s", size,
        "-f", "hls",
        "-hls_time", "10",
        "-hls_list_size", "6",
        "-hls_flags", "delete_segments",
        "-hls_segment_filename", segment_path,
        playlist_path
    ]
    
    return cmd

async def monitor_stream(stream_id: str, process: subprocess.Popen):
    """Monitor stream process and update status"""
    try:
        while process.poll() is None:
            await asyncio.sleep(5)
            
            # Update stream stats
            redis_client.hset(f"stream:{stream_id}", "last_check", datetime.now().isoformat())
            
        # Process ended
        return_code = process.returncode
        status = "stopped" if return_code == 0 else "error"
        
        redis_client.hset(f"stream:{stream_id}", "status", status)
        
        if stream_id in active_streams:
            del active_streams[stream_id]
            
        logger.info(f"Stream {stream_id} ended with return code {return_code}")
        
    except Exception as e:
        logger.error(f"Error monitoring stream {stream_id}: {str(e)}")

@app.get("/system/stats")
async def get_system_stats():
    """Get system statistics"""
    try:
        return {
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
                "percent": psutil.virtual_memory().percent
            },
            "disk": {
                "total": psutil.disk_usage('/').total,
                "used": psutil.disk_usage('/').used,
                "free": psutil.disk_usage('/').free,
                "percent": psutil.disk_usage('/').percent
            },
            "active_streams": len(active_streams),
            "uptime": int(psutil.boot_time())
        }
    except Exception as e:
        logger.error(f"Error getting system stats: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
