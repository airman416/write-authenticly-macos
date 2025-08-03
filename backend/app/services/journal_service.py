from typing import List, Optional
from uuid import UUID
from datetime import datetime
import sys
import os

# Add shared schemas to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from shared.schemas.journal_entry import JournalEntry, JournalEntryCreate, JournalEntryUpdate
from app.config.firebase import firebase_config
from app.config.settings import settings


class JournalService:
    """Service for managing journal entries"""
    
    def __init__(self):
        self.db = firebase_config.get_db()
        self.collection_name = settings.JOURNALS_COLLECTION
    
    async def create_journal(self, journal_data: JournalEntryCreate) -> JournalEntry:
        """Create a new journal entry"""
        if not self.db:
            raise Exception("Firebase not configured")
        
        # Create journal entry
        journal = JournalEntry(
            content=journal_data.content,
            date=datetime.now().strftime("%b %d"),
            filename=f"[{datetime.now().strftime('%Y-%m-%d-%H-%M-%S')}].md"
        )
        
        # Update preview text
        journal.update_preview_text()
        
        # Save to Firestore
        doc_ref = self.db.collection(self.collection_name).document(str(journal.id))
        doc_ref.set(journal.model_dump(mode='json'))
        
        return journal
    
    async def get_journal(self, journal_id: UUID) -> Optional[JournalEntry]:
        """Get a journal entry by ID"""
        if not self.db:
            raise Exception("Firebase not configured")
        
        doc_ref = self.db.collection(self.collection_name).document(str(journal_id))
        doc = doc_ref.get()
        
        if not doc.exists:
            return None
        
        data = doc.to_dict()
        return JournalEntry(**data)
    
    async def get_journals(self, limit: int = 100, offset: int = 0) -> List[JournalEntry]:
        """Get all journal entries with pagination"""
        if not self.db:
            return []  # Return empty list if Firebase not configured
        
        try:
            query = (self.db.collection(self.collection_name)
                    .order_by('timestamp', direction='DESCENDING')
                    .limit(limit)
                    .offset(offset))
            
            docs = query.stream()
            journals = []
            
            for doc in docs:
                try:
                    data = doc.to_dict()
                    journals.append(JournalEntry(**data))
                except Exception as e:
                    print(f"Error parsing journal {doc.id}: {e}")
                    continue
            
            return journals
        except Exception as e:
            print(f"Error fetching journals: {e}")
            return []
    
    async def update_journal(self, journal_id: UUID, journal_data: JournalEntryUpdate) -> Optional[JournalEntry]:
        """Update a journal entry"""
        if not self.db:
            raise Exception("Firebase not configured")
        
        doc_ref = self.db.collection(self.collection_name).document(str(journal_id))
        doc = doc_ref.get()
        
        if not doc.exists:
            return None
        
        # Get existing data
        existing_data = doc.to_dict()
        existing_journal = JournalEntry(**existing_data)
        
        # Update only provided fields
        update_data = journal_data.model_dump(exclude_unset=True)
        
        for field, value in update_data.items():
            setattr(existing_journal, field, value)
        
        # Update preview text if content changed
        if 'content' in update_data:
            existing_journal.update_preview_text()
        
        # Save to Firestore
        doc_ref.update(existing_journal.model_dump(mode='json'))
        
        return existing_journal
    
    async def delete_journal(self, journal_id: UUID) -> bool:
        """Delete a journal entry"""
        if not self.db:
            raise Exception("Firebase not configured")
        
        doc_ref = self.db.collection(self.collection_name).document(str(journal_id))
        doc = doc_ref.get()
        
        if not doc.exists:
            return False
        
        doc_ref.delete()
        return True


# Global service instance
journal_service = JournalService()