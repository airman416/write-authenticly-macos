#!/usr/bin/env python3
"""
Startup script for Freewrite API backend
"""

import uvicorn
import os
import sys

# Add the app directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.config.settings import settings

if __name__ == "__main__":
    print("🚀 Starting Freewrite API Backend...")
    print(f"📍 Host: {settings.API_HOST}")
    print(f"🔌 Port: {settings.API_PORT}")
    print(f"🔧 Debug: {settings.DEBUG}")
    print()
    print("To test the API:")
    print(f"  • Health check: http://{settings.API_HOST}:{settings.API_PORT}/health")
    print(f"  • API docs: http://{settings.API_HOST}:{settings.API_PORT}/docs")
    print()
    
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.DEBUG,
        access_log=settings.DEBUG
    )