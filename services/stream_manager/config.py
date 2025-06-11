# File: cryonix/services/stream_manager/config.py

import os

class Config:
    FFMPEG_PATH = os.getenv('FFMPEG_PATH', 'ffmpeg')
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    MAX_STREAMS = int(os.getenv('MAX_STREAMS', '100'))
    HEALTH_CHECK_INTERVAL = int(os.getenv('HEALTH_CHECK_INTERVAL', '30'))
    
    # Default transcoding profiles
    TRANSCODING_PROFILES = {
        'high': {
            'video_codec': 'libx264',
            'audio_codec': 'aac',
            'video_bitrate': '4000k',
            'audio_bitrate': '192k',
            'resolution': '1920x1080'
        },
        'medium': {
            'video_codec': 'libx264',
            'audio_codec': 'aac',
            'video_bitrate': '2000k',
            'audio_bitrate': '128k',
            'resolution': '1280x720'
        },
        'low': {
            'video_codec': 'libx264',
            'audio_codec': 'aac',
            'video_bitrate': '1000k',
            'audio_bitrate': '96k',
            'resolution': '854x480'
        }
    }
