import os
import json
from typing import Optional
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()

class FirebaseConfig:
    """Firebase configuration and initialization"""
    
    def __init__(self):
        self.db: Optional[firestore.Client] = None
        self._initialized = False
    
    def initialize(self):
        """Initialize Firebase with credentials"""
        if self._initialized:
            return
        
        try:
            # Check if running in production with service account file
            if os.path.exists('firebase-service-account.json'):
                cred = credentials.Certificate('firebase-service-account.json')
            else:
                # Use environment variables for development
                firebase_config = {
                    "type": "service_account",
                    "project_id": os.getenv("FIREBASE_PROJECT_ID"),
                    "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
                    "private_key": os.getenv("FIREBASE_PRIVATE_KEY", "").replace('\\n', '\n'),
                    "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
                    "client_id": os.getenv("FIREBASE_CLIENT_ID"),
                    "auth_uri": os.getenv("FIREBASE_AUTH_URI", "https://accounts.google.com/o/oauth2/auth"),
                    "token_uri": os.getenv("FIREBASE_TOKEN_URI", "https://oauth2.googleapis.com/token"),
                }
                
                # Validate required fields
                required_fields = ["project_id", "private_key", "client_email"]
                missing_fields = [field for field in required_fields if not firebase_config.get(field)]
                
                if missing_fields:
                    raise ValueError(f"Missing required Firebase config: {missing_fields}")
                
                cred = credentials.Certificate(firebase_config)
            
            # Initialize Firebase app
            firebase_admin.initialize_app(cred)
            self.db = firestore.client()
            self._initialized = True
            print("✅ Firebase initialized successfully")
            
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
            # For development, we can create a mock client
            if os.getenv("DEBUG", "false").lower() == "true":
                print("🔧 Running in debug mode without Firebase")
                self.db = None
            else:
                raise
    
    def get_db(self) -> firestore.Client:
        """Get Firestore database client"""
        if not self._initialized:
            self.initialize()
        return self.db


# Global Firebase instance
firebase_config = FirebaseConfig()