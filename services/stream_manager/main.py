# File: cryonix/services/stream_manager/main.py

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, List
import asyncio
import json
import logging
import os
import signal
import subprocess
from datetime import datetime

app = FastAPI(title="Cryonix Stream Manager")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='stream_manager.log'
)
logger = logging.getLogger(__name__)

# Store active streams
active_streams: Dict[str, subprocess.Popen] = {}

class StreamInput(BaseModel):
    stream_id: str
    input_url: str
    output_url: str
    profile: dict
    options: Optional[dict] = None

class StreamStatus(BaseModel):
    stream_id: str
    status: str
    uptime: Optional[float] = None
    error: Optional[str] = None

@app.post("/stream/start")
async def start_stream(stream: StreamInput):
    if stream.stream_id in active_streams:
        raise HTTPException(status_code=400, detail="Stream already running")
    
    try:
        command = build_ffmpeg_command(stream)
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid
        )
        
        active_streams[stream.stream_id] = {
            'process': process,
            'start_time': datetime.now(),
            'command': command
        }
        
        logger.info(f"Started stream {stream.stream_id}")
        return {"status": "started", "stream_id": stream.stream_id}
        
    except Exception as e:
        logger.error(f"Failed to start stream {stream.stream_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/stream/stop/{stream_id}")
async def stop_stream(stream_id: str):
    if stream_id not in active_streams:
        raise HTTPException(status_code=404, detail="Stream not found")
    
    try:
        os.killpg(os.getpgid(active_streams[stream_id]['process'].pid), signal.SIGTERM)
        del active_streams[stream_id]
        logger.info(f"Stopped stream {stream_id}")
        return {"status": "stopped", "stream_id": stream_id}
        
    except Exception as e:
        logger.error(f"Failed to stop stream {stream_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stream/status/{stream_id}")
async def get_stream_status(stream_id: str):
    if stream_id not in active_streams:
        return StreamStatus(
            stream_id=stream_id,
            status="stopped"
        )
    
    stream_data = active_streams[stream_id]
    process = stream_data['process']
    
    if process.poll() is None:
        uptime = (datetime.now() - stream_data['start_time']).total_seconds()
        return StreamStatus(
            stream_id=stream_id,
            status="running",
            uptime=uptime
        )
    else:
        error_output = process.stderr.read().decode()
        del active_streams[stream_id]
        return StreamStatus(
            stream_id=stream_id,
            status="failed",
            error=error_output
        )

@app.get("/streams/list")
async def list_streams():
    return [
        {
            "stream_id": stream_id,
            "uptime": (datetime.now() - data['start_time']).total_seconds(),
            "command": data['command']
        }
        for stream_id, data in active_streams.items()
    ]

def build_ffmpeg_command(stream: StreamInput) -> List[str]:
    command = ['ffmpeg', '-y']
    
    # Input options
    if stream.options and stream.options.get('input_options'):
        command.extend(stream.options['input_options'])
    
    # Input URL
    command.extend(['-i', stream.input_url])
    
    # Transcoding profile
    if stream.profile:
        if 'video_codec' in stream.profile:
            command.extend(['-c:v', stream.profile['video_codec']])
        if 'audio_codec' in stream.profile:
            command.extend(['-c:a', stream.profile['audio_codec']])
        if 'video_bitrate' in stream.profile:
            command.extend(['-b:v', stream.profile['video_bitrate']])
        if 'audio_bitrate' in stream.profile:
            command.extend(['-b:a', stream.profile['audio_bitrate']])
        if 'resolution' in stream.profile:
            command.extend(['-s', stream.profile['resolution']])
    
    # Output options
    if stream.options and stream.options.get('output_options'):
        command.extend(stream.options['output_options'])
    
    # Output URL
    command.extend([stream.output_url])
    
    return command

@app.on_event("startup")
async def startup_event():
    logger.info("Stream Manager service started")

@app.on_event("shutdown")
async def shutdown_event():
    for stream_id in list(active_streams.keys()):
        try:
            await stop_stream(stream_id)
        except Exception as e:
            logger.error(f"Error stopping stream {stream_id} during shutdown: {str(e)}")
    logger.info("Stream Manager service stopped")
