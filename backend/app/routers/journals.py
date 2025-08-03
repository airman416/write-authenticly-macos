from typing import List
from uuid import UUID
from fastapi import APIRouter, HTTPException, Query
import sys
import os

# Add shared schemas to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from shared.schemas.journal_entry import JournalEntry, JournalEntryCreate, JournalEntryUpdate
from app.services.journal_service import journal_service

router = APIRouter()


@router.post("/", response_model=JournalEntry)
async def create_journal(journal_data: JournalEntryCreate):
    """Create a new journal entry"""
    try:
        return await journal_service.create_journal(journal_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create journal: {str(e)}")


@router.get("/", response_model=List[JournalEntry])
async def get_journals(
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0)
):
    """Get all journal entries with pagination"""
    try:
        return await journal_service.get_journals(limit=limit, offset=offset)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch journals: {str(e)}")


@router.get("/{journal_id}", response_model=JournalEntry)
async def get_journal(journal_id: UUID):
    """Get a specific journal entry"""
    try:
        journal = await journal_service.get_journal(journal_id)
        if not journal:
            raise HTTPException(status_code=404, detail="Journal not found")
        return journal
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch journal: {str(e)}")


@router.put("/{journal_id}", response_model=JournalEntry)
async def update_journal(journal_id: UUID, journal_data: JournalEntryUpdate):
    """Update a journal entry"""
    try:
        journal = await journal_service.update_journal(journal_id, journal_data)
        if not journal:
            raise HTTPException(status_code=404, detail="Journal not found")
        return journal
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update journal: {str(e)}")


@router.delete("/{journal_id}")
async def delete_journal(journal_id: UUID):
    """Delete a journal entry"""
    try:
        success = await journal_service.delete_journal(journal_id)
        if not success:
            raise HTTPException(status_code=404, detail="Journal not found")
        return {"message": "Journal deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete journal: {str(e)}")