from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class Message(BaseModel):
    role: str  # 'user' | 'ai'
    content: str


class SessionState(BaseModel):
    session_id: str
    user_id: str
    document_name: str
    summary: str
    key_points: List[str]
    topics: List[str]
    mode: str
    current_topic_index: int = 0
    interaction_count: int = 0
    history: List[Dict[str, str]] = []
    questions_asked: int = 0
    questions_correct: int = 0
    last_question: Optional[str] = None
    last_correct_answer: Optional[str] = None
    awaiting_answer: bool = False
    score_sum: float = 0.0
    created_at: str = ''
    document_language: str = 'en'
    response_language: str = 'en'
    language_display_name: str = 'English'