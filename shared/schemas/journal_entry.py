from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class JournalEntryBase(BaseModel):
    """Base model for journal entries"""
    content: str = ""
    preview_text: Optional[str] = None
    
    def update_preview_text(self):
        """Update preview text based on content"""
        trimmed = self.content.replace("\n", " ").strip()
        
        if not trimmed:
            self.preview_text = "Empty entry"
        elif len(trimmed) > 50:
            self.preview_text = trimmed[:50] + "..."
        else:
            self.preview_text = trimmed


class JournalEntryCreate(JournalEntryBase):
    """Model for creating journal entries"""
    pass


class JournalEntryUpdate(JournalEntryBase):
    """Model for updating journal entries"""
    content: Optional[str] = None


class JournalEntry(JournalEntryBase):
    """Complete journal entry model"""
    id: UUID = Field(default_factory=uuid4)
    date: str
    filename: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }


class JournalAnalysisRequest(BaseModel):
    """Request model for journal analysis"""
    entry_id: UUID
    analysis_type: str = "general"  # general, mood, insights, etc.


class JournalAnalysisResponse(BaseModel):
    """Response model for journal analysis"""
    entry_id: UUID
    analysis_type: str
    analysis: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }