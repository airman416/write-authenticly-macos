# Freewrite Backend

FastAPI backend for the Freewrite journal application with Firebase Firestore and Google Gemini integration.

## Quick Start with Docker

1. **Set up environment variables:**
   ```bash
   cp env.example .env
   # Edit .env with your Firebase and Gemini credentials
   ```

2. **Start the backend:**
   ```bash
   docker-compose up --build
   ```

3. **Access the API:**
   - API: http://localhost:8000
   - Documentation: http://localhost:8000/docs
   - Health check: http://localhost:8000/health

## Configuration

### Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing
3. Enable Firestore Database
4. Go to Project Settings > Service Accounts
5. Generate a new private key (JSON file)
6. Copy the values to your `.env` file

### Google Gemini Setup
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create a new API key
3. Add it to your `.env` file as `GOOGLE_API_KEY`

## API Endpoints

### Journals
- `POST /api/journals/` - Create journal entry
- `GET /api/journals/` - List journal entries
- `GET /api/journals/{id}` - Get specific journal entry
- `PUT /api/journals/{id}` - Update journal entry
- `DELETE /api/journals/{id}` - Delete journal entry

### Analysis
- `POST /api/analysis/analyze` - Analyze journal entry with AI
- `GET /api/analysis/prompt` - Get AI-generated writing prompt

## Development

### Running without Docker
```bash
cd backend
pip install -r requirements.txt
python run.py
```

### Testing the API
```bash
# Health check
curl http://localhost:8000/health

# Create a journal entry
curl -X POST http://localhost:8000/api/journals/ \
  -H "Content-Type: application/json" \
  -d '{"content": "Today was a good day..."}'

# Get writing prompt
curl http://localhost:8000/api/analysis/prompt
```

## Architecture

```
backend/
├── app/
│   ├── config/          # Configuration (Firebase, settings)
│   ├── models/          # Data models
│   ├── routers/         # API endpoints
│   ├── services/        # Business logic
│   └── main.py          # FastAPI app
├── tests/               # Unit tests
├── Dockerfile           # Docker configuration
├── requirements.txt     # Python dependencies
└── run.py              # Startup script
```

## Features

- ✅ Firebase Firestore integration
- ✅ Google Gemini AI analysis
- ✅ RESTful API with FastAPI
- ✅ Docker containerization
- ✅ Health checks and monitoring
- ✅ Automatic API documentation
- 🔄 Offline-first sync (coming next)
- 🔄 Authentication (coming later)