# File: cryonix/services/stream_manager/stream_monitor.py

import asyncio
import logging
from datetime import datetime
from typing import Dict

logger = logging.getLogger(__name__)

class StreamMonitor:
    def __init__(self, active_streams: Dict, check_interval: int = 30):
        self.active_streams = active_streams
        self.check_interval = check_interval
        self.running = False
    
    async def start(self):
        self.running = True
        while self.running:
            await self.check_streams()
            await asyncio.sleep(self.check_interval)
    
    async def stop(self):
        self.running = False
    
    async def check_streams(self):
        for stream_id, stream_data in list(self.active_streams.items()):
            process = stream_data['process']
            
            # Check if process is still running
            if process.poll() is not None:
                logger.warning(f"Stream {stream_id} has stopped unexpectedly")
                
                # Get error output
                error_output = process.stderr.read().decode()
                logger.error(f"Stream {stream_id} error: {error_output}")
                
                # Remove from active streams
                del self.active_streams[stream_id]
                
                # Here you could implement auto-restart logic
                # await self.restart_stream(stream_id, stream_data)
    
    async def restart_stream(self, stream_id: str, stream_data: dict):
        try:
            command = stream_data['command']
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            self.active_streams[stream_id] = {
                'process': process,
                'start_time': datetime.now(),
                'command': command,
                'restarts': stream_data.get('restarts', 0) + 1
            }
            
            logger.info(f"Restarted stream {stream_id}")
            
        except Exception as e:
            logger.error(f"Failed to restart stream {stream_id}: {str(e)}")
