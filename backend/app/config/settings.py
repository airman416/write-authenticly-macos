import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    """Application settings"""
    
    # API Configuration
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Firebase Configuration
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")
    
    # Google Gemini Configuration
    GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")
    
    # Collections
    JOURNALS_COLLECTION: str = "journals"
    ANALYSES_COLLECTION: str = "journal_analyses"
    
    @property
    def firebase_configured(self) -> bool:
        """Check if Firebase is properly configured"""
        return bool(self.FIREBASE_PROJECT_ID)
    
    @property
    def gemini_configured(self) -> bool:
        """Check if Gemini is properly configured"""
        return bool(self.GOOGLE_API_KEY)


settings = Settings()