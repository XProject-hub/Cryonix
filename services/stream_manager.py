#!/usr/bin/env python3
"""
Stream Manager Service - Companion to transcoder.py
Handles stream monitoring and auto-restart functionality
"""

import asyncio
import logging
import mysql.connector
import redis
import json
from datetime import datetime
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StreamManager:
    def __init__(self):
        self.redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
        self.db_config = {
            'host': 'localhost',
            'database': 'cryonix',
            'user': 'cryonix_admin',
            'password': 'CryonixSecure2024!'
        }

    def get_db_connection(self):
        return mysql.connector.connect(**self.db_config)

    async def monitor_streams(self):
        """Monitor all streams and restart failed ones"""
        while True:
            try:
                # Get all active streams from database
                conn = self.get_db_connection()
                cursor = conn.cursor(dictionary=True)
                cursor.execute("SELECT * FROM channels WHERE status = 1 AND auto_restart = 1")
                active_channels = cursor.fetchall()
                conn.close()

                for channel in active_channels:
                    await self.check_stream_health(channel)

                await asyncio.sleep(30)  # Check every 30 seconds

            except Exception as e:
                logger.error(f"Error in monitor loop: {str(e)}")
                await asyncio.sleep(60)

    async def check_stream_health(self, channel):
        """Check if a stream is healthy and restart if needed"""
        try:
            # Check transcoder status
            response = requests.get(f"http://localhost:8000/stream/status/{channel['id']}", timeout=5)
            
            if response.status_code == 404 or response.json().get('status') != 'running':
                logger.warning(f"Stream {channel['id']} is down, attempting restart")
                await self.restart_stream(channel)

        except Exception as e:
            logger.error(f"Health check failed for stream {channel['id']}: {str(e)}")

    async def restart_stream(self, channel):
        """Restart a failed stream"""
        try:
            # Call transcoder to start stream
            stream_data = {
                'channel_id': channel['id'],
                'stream_url': channel['stream_url'],
                'resolution': channel['quality'] or '720p',
                'bitrate': '2000k'
            }

            response = requests.post('http://localhost:8000/stream/start', json=stream_data, timeout=10)
            
            if response.status_code == 200:
                logger.info(f"Successfully restarted stream {channel['id']}")
                
                # Log restart
                conn = self.get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO logs (type, message, created_at) VALUES (%s, %s, %s)",
                    ('stream_restart', f"Auto-restarted stream {channel['name']}", datetime.now())
                )
                conn.commit()
                conn.close()
            else:
                logger.error(f"Failed to restart stream {channel['id']}")

        except Exception as e:
            logger.error(f"Error restarting stream {channel['id']}: {str(e)}")

if __name__ == "__main__":
    manager = StreamManager()
    asyncio.run(manager.monitor_streams())
