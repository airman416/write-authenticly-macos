from fastapi import APIRouter, HTTPException
import sys
import os

# Add shared schemas to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from shared.schemas.journal_entry import JournalAnalysisRequest, JournalAnalysisResponse
from app.services.gemini_service import gemini_service

router = APIRouter()


@router.post("/analyze", response_model=JournalAnalysisResponse)
async def analyze_journal(request: JournalAnalysisRequest):
    """Analyze a journal entry using AI"""
    try:
        analysis = await gemini_service.analyze_journal(request)
        if not analysis:
            raise HTTPException(status_code=500, detail="Failed to generate analysis")
        return analysis
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.get("/prompt")
async def get_writing_prompt():
    """Get an AI-generated writing prompt"""
    try:
        prompt = await gemini_service.get_writing_prompt()
        return {"prompt": prompt}
    except Exception as e:
        print(f"Error generating prompt: {e}")
        return {"prompt": "What's on your mind today? Let your thoughts flow freely."}