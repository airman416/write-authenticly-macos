from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import sys
import os

# Add shared schemas to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))

from app.config.firebase import firebase_config
from app.config.settings import settings
from app.routers import journals, analysis


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    print("🚀 Starting Freewrite API...")
    
    # Initialize Firebase
    firebase_config.initialize()
    
    print(f"📊 Firebase configured: {settings.firebase_configured}")
    print(f"🤖 Gemini configured: {settings.gemini_configured}")
    print(f"🌐 API running on {settings.API_HOST}:{settings.API_PORT}")
    
    yield
    
    # Shutdown
    print("👋 Shutting down Freewrite API...")


# Create FastAPI app
app = FastAPI(
    title="Freewrite API",
    description="Backend API for Freewrite journal application",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(journals.router, prefix="/api/journals", tags=["journals"])
app.include_router(analysis.router, prefix="/api/analysis", tags=["analysis"])


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to Freewrite API",
        "version": "1.0.0",
        "status": "running",
        "firebase_configured": settings.firebase_configured,
        "gemini_configured": settings.gemini_configured
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "firebase": "connected" if firebase_config.db else "disconnected",
        "gemini": "configured" if settings.gemini_configured else "not configured"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.DEBUG
    )