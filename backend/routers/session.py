from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict
from models.session import SessionStartRequest, SessionStartResponse
from orchestrator import start_session, end_session, get_session, add_document_to_session
from agents.mcq_agent import generate_test_set
from agents.evaluation_agent import evaluate_answer

router = APIRouter()


# ── EXISTING ROUTES (keep unchanged) ─────────────────────────────────────────

@router.post('/start', response_model=SessionStartResponse)
async def start(request: SessionStartRequest):
    try:
        print(f'[SESSION ROUTER] Starting session: {request.mode}')
        return await start_session(request)
    except Exception as e:
        print(f'[SESSION ROUTER] Start error: {e}')
        raise HTTPException(status_code=500, detail=str(e))


@router.post('/end')
async def end(session_id: str, user_id: str):
    try:
        return await end_session(session_id, user_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/state/{session_id}')
async def get_state(session_id: str):
    state = get_session(session_id)
    if not state:
        raise HTTPException(status_code=404, detail='Session not found')
    return state


# ── NEW: TEST GENERATION ──────────────────────────────────────────────────────

class GenerateTestRequest(BaseModel):
    document_name: str
    summary: str
    key_points: List[str]
    topics: List[str]
    question_count: int = 15  # default 15 (5E+5M+5H)


class GenerateTestResponse(BaseModel):
    questions: List[dict]
    document_name: str
    total_questions: int


@router.post('/generate-test', response_model=GenerateTestResponse)
async def generate_test(request: GenerateTestRequest):
    """
    Generates a full set of MCQ questions for a test session.
    Flutter TestScreen calls this once on load, receives all
    questions, then conducts the test locally without further
    backend calls until submission.
    """
    try:
        count = min(request.question_count, 30)  # cap at 30
        print(f'[SESSION ROUTER] Generating test: '
              f'{count} questions for "{request.document_name}"')

        questions = await generate_test_set(
            summary=request.summary,
            key_points=request.key_points,
            topics=request.topics,
            count=count,
        )

        if not questions:
            raise HTTPException(
                status_code=500,
                detail='Failed to generate questions — try again'
            )

        print(f'[SESSION ROUTER] Generated {len(questions)} questions')

        return GenerateTestResponse(
            questions=questions,
            document_name=request.document_name,
            total_questions=len(questions),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f'[SESSION ROUTER] Generate test error: {e}')
        raise HTTPException(status_code=500, detail=str(e))


# ── NEW: TEST SUBMISSION ──────────────────────────────────────────────────────

class QuestionAnswer(BaseModel):
    question: str
    correct_answer: str
    user_answer: str
    selected_index: int
    correct_index: int


class SubmitTestRequest(BaseModel):
    document_name: str
    summary: str
    answers: List[QuestionAnswer]


class QuestionResult(BaseModel):
    question: str
    user_answer: str
    correct_answer: str
    score: float
    feedback: str
    correction: str
    is_correct: bool


class SubmitTestResponse(BaseModel):
    total_score: float
    avg_score: float
    correct_count: int
    total_questions: int
    results: List[QuestionResult]
    weak_topics: List[str]
    performance_label: str


@router.post('/submit-test', response_model=SubmitTestResponse)
async def submit_test(request: SubmitTestRequest):
    """
    Receives all test answers, evaluates each one using
    the Evaluation Agent, returns full breakdown.
    Flutter ResultScreen shows this breakdown.
    """
    try:
        print(f'[SESSION ROUTER] Submitting test: '
              f'{len(request.answers)} answers for "{request.document_name}"')

        results = []
        total_score = 0.0
        correct_count = 0
        wrong_indices = []

        for i, qa in enumerate(request.answers):
            # For MCQ — deterministic evaluation based on selected index
            is_correct = qa.selected_index == qa.correct_index
            score = 10.0 if is_correct else 0.0
            total_score += score

            if is_correct:
                correct_count += 1
            else:
                wrong_indices.append(i)

            feedback = (
                'Correct! Well done.' if is_correct
                else f'The correct answer was: {qa.correct_answer}'
            )
            correction = (
                '' if is_correct
                else f'You selected: {qa.user_answer}. '
                     f'Correct: {qa.correct_answer}'
            )

            results.append(QuestionResult(
                question=qa.question,
                user_answer=qa.user_answer,
                correct_answer=qa.correct_answer,
                score=score,
                feedback=feedback,
                correction=correction,
                is_correct=is_correct,
            ))

            print(f'[SESSION ROUTER] Q{i+1}: '
                  f'{"✓" if is_correct else "✗"} score={score}')

        avg_score = (
            total_score / len(request.answers)
            if request.answers else 0.0
        )

        # Performance label
        if avg_score >= 90:
            performance_label = 'Excellent'
        elif avg_score >= 70:
            performance_label = 'Good'
        elif avg_score >= 50:
            performance_label = 'Fair'
        else:
            performance_label = 'Needs Revision'

        # Weak topics — topics corresponding to wrong answers
        # Simple heuristic: flag first N topics where N = wrong count
        weak_count = min(len(wrong_indices), 3)
        weak_topics = []
        if weak_count > 0 and request.summary:
            # Extract topic hints from wrong questions
            for idx in wrong_indices[:3]:
                q_text = request.answers[idx].question
                # First 4 words of question as topic hint
                words = q_text.split()[:4]
                if words:
                    weak_topics.append(' '.join(words) + '...')

        print(f'[SESSION ROUTER] Test result: '
              f'avg={avg_score:.1f}%, correct={correct_count}/{len(request.answers)}, '
              f'label={performance_label}')

        return SubmitTestResponse(
            total_score=total_score,
            avg_score=avg_score,
            correct_count=correct_count,
            total_questions=len(request.answers),
            results=results,
            weak_topics=weak_topics,
            performance_label=performance_label,
        )

    except Exception as e:
        print(f'[SESSION ROUTER] Submit test error: {e}')
        raise HTTPException(status_code=500, detail=str(e))


# ── ADD DOCUMENT TO ACTIVE SESSION ───────────────────────────────────────────

class AddDocumentRequest(BaseModel):
    session_id: str
    document_name: str
    summary: str
    key_points: List[str]
    topics: List[str]


@router.post('/add-document')
async def add_document(request: AddDocumentRequest):
    """
    Appends a newly processed PDF's content to an active session,
    enabling combined multi-document voice tutoring (project/chapters).
    """
    try:
        result = await add_document_to_session(
            session_id=request.session_id,
            document_name=request.document_name,
            summary=request.summary,
            key_points=request.key_points,
            topics=request.topics,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f'[SESSION ROUTER] Add document error: {e}')
        raise HTTPException(status_code=500, detail=str(e))