import google.generativeai as genai
from typing import Optional
import sys
import os

# Add shared schemas to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from shared.schemas.journal_entry import JournalAnalysisRequest, JournalAnalysisResponse
from app.config.settings import settings
from app.services.journal_service import journal_service


class GeminiService:
    """Service for Google Gemini LLM integration"""
    
    def __init__(self):
        self.configured = False
        if settings.GOOGLE_API_KEY:
            try:
                genai.configure(api_key=settings.GOOGLE_API_KEY)
                self.model = genai.GenerativeModel('gemini-pro')
                self.configured = True
                print("✅ Gemini AI configured successfully")
            except Exception as e:
                print(f"❌ Failed to configure Gemini: {e}")
    
    def get_analysis_prompt(self, content: str, analysis_type: str) -> str:
        """Get the appropriate prompt for analysis type"""
        prompts = {
            "general": f"""
            Below is my journal entry. Respond like an old friend - conversational, warm, and insightful. 
            Don't therapize me or give me a breakdown with headings. Just talk through it with me naturally.
            Share thoughts, relate to what I'm saying, ask questions if relevant, and be genuinely supportive.
            
            Journal entry:
            {content}
            """,
            
            "mood": f"""
            Analyze the mood and emotional tone of this journal entry. 
            Provide insights about the writer's emotional state in a friendly, supportive way.
            Don't be clinical - be like a caring friend who notices how you're feeling.
            
            Journal entry:
            {content}
            """,
            
            "insights": f"""
            Look for patterns, themes, or interesting insights in this journal entry.
            What stands out? What might the writer learn about themselves?
            Share your observations in a friendly, non-judgmental way.
            
            Journal entry:
            {content}
            """,
            
            "reflection": f"""
            Help me reflect on this journal entry. What questions might be worth exploring?
            What aspects deserve more thought? Guide me through reflection like a thoughtful friend.
            
            Journal entry:
            {content}
            """
        }
        
        return prompts.get(analysis_type, prompts["general"])
    
    async def analyze_journal(self, request: JournalAnalysisRequest) -> Optional[JournalAnalysisResponse]:
        """Analyze a journal entry using Gemini"""
        if not self.configured:
            raise Exception("Gemini AI not configured")
        
        # Get the journal entry
        journal = await journal_service.get_journal(request.entry_id)
        if not journal:
            raise Exception("Journal entry not found")
        
        # Generate analysis prompt
        prompt = self.get_analysis_prompt(journal.content, request.analysis_type)
        
        try:
            # Generate response
            response = self.model.generate_content(prompt)
            
            if not response.text:
                raise Exception("No response from Gemini")
            
            return JournalAnalysisResponse(
                entry_id=request.entry_id,
                analysis_type=request.analysis_type,
                analysis=response.text
            )
            
        except Exception as e:
            raise Exception(f"Failed to analyze journal: {str(e)}")
    
    async def get_writing_prompt(self) -> str:
        """Generate a creative writing prompt"""
        if not self.configured:
            return "What's on your mind today? Start writing about anything that comes to you."
        
        prompt = """
        Generate a thoughtful, creative writing prompt for someone doing freewriting/journaling.
        Make it open-ended, inspiring, and suitable for stream-of-consciousness writing.
        Keep it to 1-2 sentences. Don't make it too specific or constraining.
        Examples of good prompts:
        - "Write about a moment today when you felt completely present"
        - "If your thoughts had a color right now, what would it be and why?"
        - "Describe the feeling of something ending and something beginning"
        
        Generate a new, unique prompt:
        """
        
        try:
            response = self.model.generate_content(prompt)
            return response.text.strip() if response.text else "What's flowing through your mind right now?"
        except Exception as e:
            print(f"Error generating prompt: {e}")
            return "What's flowing through your mind right now?"


# Global service instance
gemini_service = GeminiService()