import uuid
from datetime import datetime
from typing import Dict, Optional
from models.interaction import SessionState
from models.session import (
    SessionStartRequest, SessionStartResponse,
    InteractRequest, InteractResponse, MCQData
)
from agents.tutor_agent import get_tutor_response, get_opening_message
from agents.mcq_agent import generate_mcq, generate_test_set
from agents.evaluation_agent import evaluate_answer
from agents.reasoning_agent import (
    ReasoningTracker,
    get_socratic_followup,
    get_deepening_question,
    get_encouragement,
)

# In-memory stores
# Phase 6 will move this to Firestore
_sessions: Dict[str, SessionState] = {}
_reasoning_trackers: Dict[str, ReasoningTracker] = {}


async def start_session(request: SessionStartRequest) -> SessionStartResponse:
    session_id = str(uuid.uuid4())

    # Get opening message from Tutor Agent
    opening = await get_opening_message(
        mode=request.mode,
        document_name=request.document_name,
        summary=request.summary,
        topics=request.topics,
    )

    state = SessionState(
        session_id=session_id,
        user_id=request.user_id,
        document_name=request.document_name,
        summary=request.summary,
        key_points=request.key_points,
        topics=request.topics,
        mode=request.mode,
        current_topic_index=0,
        interaction_count=0,
        history=[{'role': 'ai', 'content': opening}],
        questions_asked=0,
        questions_correct=0,
        awaiting_answer=False,
        score_sum=0.0,
        created_at=datetime.utcnow().isoformat(),
    )

    _sessions[session_id] = state
    _reasoning_trackers[session_id] = ReasoningTracker()
    print(f'[ORCHESTRATOR] Session started: {session_id}, mode: {request.mode}')

    return SessionStartResponse(
        session_id=session_id,
        mode=request.mode,
        first_message=opening,
        document_name=request.document_name,
    )


async def handle_interaction(request: InteractRequest) -> InteractResponse:
    state = _sessions.get(request.session_id)
    if not state:
        return InteractResponse(
            session_id=request.session_id,
            ai_message='Session not found. Please start a new session.',
            next_action='session_error',
            session_complete=True,
        )

    # Add user message to history
    state.history.append({
        'role': 'user',
        'content': request.user_input
    })
    state.interaction_count += 1

    current_topic = (
        state.topics[state.current_topic_index]
        if state.topics
        else state.document_name
    )

    print(f'[ORCHESTRATOR] Session {request.session_id[:8]}, '
          f'mode={state.mode}, type={request.interaction_type}, '
          f'topic={current_topic}')

    # ── MCQ REQUEST ────────────────────────────────────────────────────────────
    if request.interaction_type == 'request_mcq':
        asked = [
            h['content'] for h in state.history
            if h['role'] == 'ai' and '?' in h['content']
        ]
        mcq_data = await generate_mcq(
            summary=state.summary,
            key_points=state.key_points,
            current_topic=current_topic,
            previously_asked=asked
        )

        if not mcq_data:
            ai_msg = 'Let me think of a good question for you. What part of this topic would you like to test?'
            state.history.append({'role': 'ai', 'content': ai_msg})
            return InteractResponse(
                session_id=request.session_id,
                ai_message=ai_msg,
                next_action='wait_answer',
            )

        state.last_question = mcq_data['question']
        state.last_correct_answer = mcq_data['options'][mcq_data['correct_index']]
        state.awaiting_answer = True
        state.questions_asked += 1

        return InteractResponse(
            session_id=request.session_id,
            ai_message='Here is a question to check your understanding:',
            mcq=MCQData(
                question=mcq_data['question'],
                options=mcq_data['options'],
                correct_index=mcq_data['correct_index'],
                explanation=mcq_data.get('explanation', ''),
            ),
            next_action='show_mcq',
        )

    # ── MCQ ANSWER ──────────────────────────────────────────────────────────────
    if request.interaction_type == 'answer' and state.awaiting_answer:
        eval_result = await evaluate_answer(
            question=state.last_question or '',
            correct_answer=state.last_correct_answer or '',
            user_answer=request.user_input,
            context_summary=state.summary,
            is_mcq=False,
        )

        score = eval_result['score']
        state.score_sum += score
        state.awaiting_answer = False

        if score >= 7:
            state.questions_correct += 1

        tracker = _reasoning_trackers.get(request.session_id)

        # ── LOW SCORE → REASONING AGENT ────────────────────────────────────────
        if eval_result.get('trigger_reasoning') and state.last_question:
            attempt_num = 1
            if tracker:
                attempt_num = tracker.record_struggle(state.last_question)

            print(f'[ORCHESTRATOR] Triggering reasoning, attempt #{attempt_num}')

            reasoning_response = await get_socratic_followup(
                question=state.last_question,
                user_wrong_answer=request.user_input,
                correct_answer=state.last_correct_answer or '',
                context_summary=state.summary,
                attempt_number=attempt_num,
            )

            # Build full AI message
            feedback = eval_result.get('feedback', '')
            ai_message = f"{feedback}\n\n{reasoning_response}"

            # If this was a reveal (attempt 3+), reset tracker
            # and advance topic so we don't get stuck forever
            if attempt_num >= 3:
                if tracker:
                    tracker.reset_question(state.last_question)
                # Advance topic
                if state.current_topic_index < len(state.topics) - 1:
                    state.current_topic_index += 1
                ai_message += (
                    "\n\nLet's move forward and revisit this later. "
                    "You'll find it makes more sense after studying the next topic."
                )

            state.history.append({'role': 'ai', 'content': ai_message})

            return InteractResponse(
                session_id=request.session_id,
                ai_message=ai_message,
                score=score,
                feedback=eval_result.get('feedback', ''),
                correction=eval_result.get('correction', ''),
                trigger_reasoning=True,
                next_action='continue',
            )

        # ── HIGH SCORE → CORRECT ANSWER ──────────────────────────────────────────
        else:
            # Reset struggle tracker for this question
            if tracker and state.last_question:
                tracker.reset_question(state.last_question)

            # Advance topic if doing consistently well
            if score >= 7 and state.interaction_count % 3 == 0:
                if state.current_topic_index < len(state.topics) - 1:
                    state.current_topic_index += 1

            current_topic = (
                state.topics[state.current_topic_index]
                if state.topics else state.document_name
            )

            # Occasionally add a deepening question for excellent answers
            deepening = None
            if score >= 9 and state.interaction_count % 4 == 0:
                deepening = await get_deepening_question(
                    question=state.last_question or '',
                    correct_answer=state.last_correct_answer or '',
                    user_correct_answer=request.user_input,
                    context_summary=state.summary,
                )

            # Get tutor to continue teaching
            tutor_response = await get_tutor_response(
                mode=state.mode,
                summary=state.summary,
                key_points=state.key_points,
                topics=state.topics,
                current_topic=current_topic,
                history=state.history,
                user_input=request.user_input,
            )

            feedback = eval_result.get('feedback', 'Well done!')

            if deepening:
                ai_message = f"{feedback}\n\n{deepening}"
            else:
                ai_message = f"{feedback} {tutor_response}"

            # Add milestone encouragement every 5 questions
            if state.questions_asked > 0 and state.questions_asked % 5 == 0:
                avg = state.score_sum / state.questions_asked
                encouragement = await get_encouragement(
                    score=avg,
                    questions_attempted=state.questions_asked,
                    document_name=state.document_name,
                )
                ai_message += f"\n\n✨ {encouragement}"

            state.history.append({'role': 'ai', 'content': ai_message})

            return InteractResponse(
                session_id=request.session_id,
                ai_message=ai_message,
                score=score,
                feedback=eval_result.get('feedback', ''),
                correction=eval_result.get('correction', ''),
                trigger_reasoning=False,
                next_action='continue',
            )

    # ── CONTEXTUAL REQUEST ─────────────────────────────────────────────────────
    if request.interaction_type == 'contextual':
        contextual_type = request.user_input.lower().replace(' ', '_')
        tutor_response = await get_tutor_response(
            mode=state.mode,
            summary=state.summary,
            key_points=state.key_points,
            topics=state.topics,
            current_topic=current_topic,
            history=state.history,
            user_input=request.user_input,
            contextual_type=contextual_type,
        )
        state.history.append({'role': 'ai', 'content': tutor_response})

        return InteractResponse(
            session_id=request.session_id,
            ai_message=tutor_response,
            next_action='continue',
        )

    # ── GENERAL QUESTION / LEARN ───────────────────────────────────────────────
    tutor_response = await get_tutor_response(
        mode=state.mode,
        summary=state.summary,
        key_points=state.key_points,
        topics=state.topics,
        current_topic=current_topic,
        history=state.history,
        user_input=request.user_input,
    )
    state.history.append({'role': 'ai', 'content': tutor_response})

    # Auto-generate MCQ every 3 tutor interactions in revise/test mode
    mcq = None
    if state.mode in ['revise', 'test'] and state.interaction_count % 3 == 0:
        asked = [h['content'] for h in state.history if h['role'] == 'ai']
        mcq_data = await generate_mcq(
            summary=state.summary,
            key_points=state.key_points,
            current_topic=current_topic,
            previously_asked=asked
        )
        if mcq_data:
            state.last_question = mcq_data['question']
            state.last_correct_answer = mcq_data['options'][mcq_data['correct_index']]
            state.awaiting_answer = True
            state.questions_asked += 1
            mcq = MCQData(
                question=mcq_data['question'],
                options=mcq_data['options'],
                correct_index=mcq_data['correct_index'],
                explanation=mcq_data.get('explanation', ''),
            )

    return InteractResponse(
        session_id=request.session_id,
        ai_message=tutor_response,
        mcq=mcq,
        next_action='show_mcq' if mcq else 'continue',
    )


async def end_session(session_id: str, user_id: str) -> dict:
    from datetime import datetime, timezone

    state = _sessions.pop(session_id, None)
    _reasoning_trackers.pop(session_id, None)

    if not state:
        return {'error': 'Session not found'}

    avg_score = (
        state.score_sum / state.questions_asked
        if state.questions_asked > 0
        else 0.0
    )

    # Calculate duration from created_at
    try:
        created = datetime.fromisoformat(state.created_at)
        duration_sec = int(
            (datetime.now(timezone.utc) - created.replace(tzinfo=timezone.utc))
            .total_seconds()
        )
    except Exception:
        duration_sec = 0

    result = {
        'session_id': session_id,
        'document_name': state.document_name,
        'mode': state.mode,
        'questions_asked': state.questions_asked,
        'questions_correct': state.questions_correct,
        'avg_score': round(avg_score, 2),
        'interaction_count': state.interaction_count,
        'duration_sec': duration_sec,
        'topics': state.topics,
    }

    print(f'[ORCHESTRATOR] Session ended: {session_id[:8]}, '
          f'questions: {state.questions_asked}, '
          f'avg: {avg_score:.1f}, duration: {duration_sec}s')

    # Auto-sync to Firestore if user_id provided
    if user_id and user_id != 'anonymous':
        try:
            from db.firestore import (
                write_session_log,
                update_daily_stats,
                calculate_and_update_streak,
                update_user_aggregate_stats,
            )
            from datetime import datetime, timezone

            date_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')

            write_session_log(
                uid=user_id,
                session_id=session_id,
                document_name=state.document_name,
                mode=state.mode,
                duration_sec=duration_sec,
                score=avg_score,
                questions_attempted=state.questions_asked,
                questions_correct=state.questions_correct,
                topics=state.topics,
            )

            update_daily_stats(
                uid=user_id,
                date_str=date_str,
                duration_sec=duration_sec,
                score=avg_score,
                questions_attempted=state.questions_asked,
                questions_correct=state.questions_correct,
            )

            update_user_aggregate_stats(
                uid=user_id,
                score=avg_score,
                duration_sec=duration_sec,
                questions_attempted=state.questions_asked,
                questions_correct=state.questions_correct,
            )

            new_streak = calculate_and_update_streak(user_id)
            result['new_streak'] = new_streak
            result['synced_to_firestore'] = True

            print(f'[ORCHESTRATOR] Auto-synced to Firestore, streak={new_streak}')

        except Exception as e:
            print(f'[ORCHESTRATOR] Auto-sync failed (non-fatal): {e}')
            result['synced_to_firestore'] = False
    else:
        result['synced_to_firestore'] = False

    # Evict ended session from memory to prevent memory leaks
    _sessions.pop(session_id, None)
    _reasoning_trackers.pop(session_id, None)

    return result


def get_session(session_id: str) -> Optional[SessionState]:
    return _sessions.get(session_id)


async def add_document_to_session(
    session_id: str,
    document_name: str,
    summary: str,
    key_points: List[str],
    topics: List[str],
) -> dict:
    """
    Appends a new document or chapter's context to an active session.
    Combines summaries and topics so the tutor can seamlessly teach across documents.
    """
    state = _sessions.get(session_id)
    if not state:
        raise ValueError('Session not found')

    if state.document_name and state.document_name not in ('General Topic', 'Any Topic'):
        state.document_name = f"{state.document_name} & {document_name}"
        state.summary = f"{state.summary}\n\n[Chapter: {document_name}]\n{summary}"
    else:
        state.document_name = document_name
        state.summary = summary

    for kp in key_points:
        if kp not in state.key_points:
            state.key_points.append(kp)
    for t in topics:
        if t not in state.topics:
            state.topics.append(t)

    ack_msg = (
        f"I've analyzed and loaded '{document_name}' into our session! "
        f"I'm ready to walk you through its concepts or answer any questions."
    )
    state.history.append({'role': 'ai', 'content': ack_msg})

    return {
        'session_id': session_id,
        'document_name': state.document_name,
        'ack_message': ack_msg,
        'topics': state.topics,
    }