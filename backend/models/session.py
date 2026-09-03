from pydantic import BaseModel
from typing import Optional, List


class ContentProcessRequest(BaseModel):
    extracted_text: str
    document_name: str


class SessionStartRequest(BaseModel):
    user_id: str
    document_name: str
    summary: str
    key_points: List[str]
    topics: List[str]
    mode: str  # 'learn' | 'revise' | 'test'


class SessionStartResponse(BaseModel):
    session_id: str
    mode: str
    first_message: str
    document_name: str


class SessionEndRequest(BaseModel):
    session_id: str
    user_id: str


class InteractRequest(BaseModel):
    session_id: str
    user_input: str
    interaction_type: str  # 'answer' | 'question' | 'request_mcq' | 'contextual'
    # contextual types: 'explain_differently' | 'give_example' | 'go_deeper'


class MCQOption(BaseModel):
    index: int
    text: str


class MCQData(BaseModel):
    question: str
    options: List[str]
    correct_index: int
    explanation: str


class InteractResponse(BaseModel):
    session_id: str
    ai_message: str
    mcq: Optional[MCQData] = None
    score: Optional[float] = None
    feedback: Optional[str] = None
    correction: Optional[str] = None
    trigger_reasoning: bool = False
    session_complete: bool = False
    next_action: str  # 'wait_answer' | 'wait_voice' | 'show_mcq' | 'continue'