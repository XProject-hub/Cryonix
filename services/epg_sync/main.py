# File: cryonix/services/epg_sync/main.py

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict
import asyncio
import aiohttp
import xml.etree.ElementTree as ET
import json
import logging
from datetime import datetime, timedelta
import mysql.connector
from mysql.connector import Error
import os

app = FastAPI(title="Cryonix EPG Sync Service")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='epg_sync.log'
)
logger = logging.getLogger(__name__)

class EPGSource(BaseModel):
    id: int
    name: str
    url: str
    type: str  # xmltv or xtream
    is_active: bool

class SyncRequest(BaseModel):
    source_id: int
    force: Optional[bool] = False

class EPGSyncService:
    def __init__(self):
        self.db_config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'database': os.getenv('DB_DATABASE', 'cryonix_prod'),
            'user': os.getenv('DB_USERNAME', 'cryonix_admin'),
            'password': os.getenv('DB_PASSWORD', ''),
            'port': int(os.getenv('DB_PORT', '3306'))
        }
    
    async def get_db_connection(self):
        try:
            connection = mysql.connector.connect(**self.db_config)
            return connection
        except Error as e:
            logger.error(f"Database connection error: {e}")
            raise HTTPException(status_code=500, detail="Database connection failed")
    
    async def sync_xmltv_epg(self, source: EPGSource):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(source.url) as response:
                    if response.status != 200:
                        raise HTTPException(status_code=400, detail=f"Failed to fetch EPG: {response.status}")
                    
                    xml_content = await response.text()
                    root = ET.fromstring(xml_content)
                    
                    # Parse channels
                    channels = []
                    for channel in root.findall('channel'):
                        channel_id = channel.get('id')
                        display_name = channel.find('display-name')
                        if display_name is not None:
                            channels.append({
                                'id': channel_id,
                                'name': display_name.text,
                                'icon': channel.find('icon').get('src') if channel.find('icon') is not None else None
                            })
                    
                    # Parse programmes
                    programmes = []
                    for programme in root.findall('programme'):
                        channel_id = programme.get('channel')
                        start_time = self.parse_xmltv_time(programme.get('start'))
                        stop_time = self.parse_xmltv_time(programme.get('stop'))
                        
                        title_elem = programme.find('title')
                        desc_elem = programme.find('desc')
                        category_elem = programme.find('category')
                        
                        programmes.append({
                            'channel_id': channel_id,
                            'start_time': start_time,
                            'stop_time': stop_time,
                            'title': title_elem.text if title_elem is not None else '',
                            'description': desc_elem.text if desc_elem is not None else '',
                            'category': category_elem.text if category_elem is not None else ''
                        })
                    
                    # Save to database
                    await self.save_epg_data(source.id, channels, programmes)
                    
                    return {
                        'channels_count': len(channels),
                        'programmes_count': len(programmes),
                        'sync_time': datetime.now().isoformat()
                    }
                    
        except Exception as e:
            logger.error(f"XMLTV sync error for source {source.id}: {str(e)}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def sync_xtream_epg(self, source: EPGSource):
        try:
            # Parse Xtream API URL
            base_url = source.url.rstrip('/')
            
            async with aiohttp.ClientSession() as session:
                # Get EPG data
                epg_url = f"{base_url}/xmltv.php"
                async with session.get(epg_url) as response:
                    if response.status != 200:
                        raise HTTPException(status_code=400, detail=f"Failed to fetch Xtream EPG: {response.status}")
                    
                    xml_content = await response.text()
                    root = ET.fromstring(xml_content)
                    
                    # Process similar to XMLTV
                    channels = []
                    programmes = []
                    
                    for channel in root.findall('channel'):
                        channel_id = channel.get('id')
                        display_name = channel.find('display-name')
                        if display_name is not None:
                            channels.append({
                                'id': channel_id,
                                'name': display_name.text,
                                'icon': None
                            })
                    
                    for programme in root.findall('programme'):
                        channel_id = programme.get('channel')
                        start_time = self.parse_xmltv_time(programme.get('start'))
                        stop_time = self.parse_xmltv_time(programme.get('stop'))
                        
                        title_elem = programme.find('title')
                        desc_elem = programme.find('desc')
                        
                        programmes.append({
                            'channel_id': channel_id,
                            'start_time': start_time,
                            'stop_time': stop_time,
                            'title': title_elem.text if title_elem is not None else '',
                            'description': desc_elem.text if desc_elem is not None else '',
                            'category': ''
                        })
                    
                    await self.save_epg_data(source.id, channels, programmes)
                    
                    return {
                        'channels_count': len(channels),
                        'programmes_count': len(programmes),
                        'sync_time': datetime.now().isoformat()
                    }
                    
        except Exception as e:
            logger.error(f"Xtream sync error for source {source.id}: {str(e)}")
            raise HTTPException(status_code=500, detail=str(e))
    
    def parse_xmltv_time(self, time_str: str) -> datetime:
        # Parse XMLTV time format: 20231201120000 +0000
        if not time_str:
            return datetime.now()
        
        try:
            # Remove timezone info for simplicity
            time_part = time_str.split(' ')[0]
            return datetime.strptime(time_part, '%Y%m%d%H%M%S')
        except:
            return datetime.now()
    
    async def save_epg_data(self, source_id: int, channels: List[Dict], programmes: List[Dict]):
        connection = await self.get_db_connection()
        cursor = connection.cursor()
        
        try:
            # Clear old EPG data for this source
            cursor.execute("DELETE FROM epg_channels WHERE source_id = %s", (source_id,))
            cursor.execute("DELETE FROM epg_programmes WHERE source_id = %s", (source_id,))
            
            # Insert channels
            for channel in channels:
                cursor.execute("""
                    INSERT INTO epg_channels (source_id, channel_id, name, icon, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, NOW(), NOW())
                """, (source_id, channel['id'], channel['name'], channel.get('icon')))
            
            # Insert programmes
            for programme in programmes:
                cursor.execute("""
                    INSERT INTO epg_programmes (source_id, channel_id, start_time, stop_time, title, description, category, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
                """, (
                    source_id,
                    programme['channel_id'],
                    programme['start_time'],
                    programme['stop_time'],
                    programme['title'],
                    programme['description'],
                    programme['category']
                ))
            
            # Update last sync time
            cursor.execute("""
                UPDATE epg_sources SET last_sync = NOW(), updated_at = NOW() WHERE id = %s
            """, (source_id,))
            
            connection.commit()
            logger.info(f"EPG data saved for source {source_id}: {len(channels)} channels, {len(programmes)} programmes")
            
        except Error as e:
            connection.rollback()
            logger.error(f"Database error saving EPG data: {e}")
            raise HTTPException(status_code=500, detail="Failed to save EPG data")
        finally:
            cursor.close()
            connection.close()

epg_service = EPGSyncService()

@app.post("/epg/sync")
async def sync_epg(sync_request: SyncRequest, background_tasks: BackgroundTasks):
    connection = await epg_service.get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT * FROM epg_sources WHERE id = %s AND is_active = 1", (sync_request.source_id,))
        source_data = cursor.fetchone()
        
        if not source_data:
            raise HTTPException(status_code=404, detail="EPG source not found or inactive")
        
        source = EPGSource(**source_data)
        
        # Check if sync is needed (unless forced)
        if not sync_request.force and source_data['last_sync']:
            last_sync = source_data['last_sync']
            if isinstance(last_sync, str):
                last_sync = datetime.fromisoformat(last_sync)
            
            if datetime.now() - last_sync < timedelta(hours=6):
                return {"message": "EPG was synced recently, use force=true to override"}
        
        # Start sync in background
        if source.type == 'xmltv':
            background_tasks.add_task(epg_service.sync_xmltv_epg, source)
        elif source.type == 'xtream':
            background_tasks.add_task(epg_service.sync_xtream_epg, source)
        else:
            raise HTTPException(status_code=400, detail="Unsupported EPG source type")
        
        return {"message": "EPG sync started", "source_id": sync_request.source_id}
        
    finally:
        cursor.close()
        connection.close()

@app.get("/epg/sources")
async def get_epg_sources():
    connection = await epg_service.get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT * FROM epg_sources ORDER BY name")
        sources = cursor.fetchall()
        return sources
    finally:
        cursor.close()
        connection.close()

@app.get("/epg/channels/{source_id}")
async def get_epg_channels(source_id: int):
    connection = await epg_service.get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT * FROM epg_channels WHERE source_id = %s ORDER BY name", (source_id,))
        channels = cursor.fetchall()
        return channels
    finally:
        cursor.close()
        connection.close()

@app.get("/epg/programmes/{channel_id}")
async def get_epg_programmes(channel_id: str, hours: int = 24):
    connection = await epg_service.get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    try:
        end_time = datetime.now() + timedelta(hours=hours)
        cursor.execute("""
            SELECT * FROM epg_programmes 
            WHERE channel_id = %s AND start_time >= NOW() AND start_time <= %s
            ORDER BY start_time
        """, (channel_id, end_time))
        programmes = cursor.fetchall()
        return programmes
    finally:
        cursor.close()
        connection.close()
