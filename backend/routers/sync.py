import traceback
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from db.firestore import (
    create_or_update_user_profile,
    write_session_log,
    update_daily_stats,
    calculate_and_update_streak,
    update_user_aggregate_stats,
    get_user_stats,
    get_recent_sessions,
    get_sessions_for_document,
    get_user_profile,
)

router = APIRouter()


# ── REQUEST/RESPONSE MODELS ───────────────────────────────────────────────────

class UserProfileRequest(BaseModel):
    uid: str
    name: str = ''
    email: str = ''
    device_id: str = ''


class SyncSessionRequest(BaseModel):
    uid: str
    session_id: str
    document_name: str
    mode: str  # learn | revise | test
    duration_sec: int
    score: float  # 0.0 to 10.0
    questions_attempted: int
    questions_correct: int
    topics: List[str] = []


class SyncSessionResponse(BaseModel):
    success: bool
    new_streak: int
    total_sessions: int
    avg_score: float
    message: str


# ── ENDPOINTS ─────────────────────────────────────────────────────────────────

@router.post('/profile')
async def sync_profile(request: UserProfileRequest):
    """
    Called on app launch after Firebase Auth.
    Creates user profile if first time, updates lastActive otherwise.
    """
    try:
        print(f'[SYNC] Profile sync for uid: {request.uid[:8]}...')
        profile = create_or_update_user_profile(
            uid=request.uid,
            name=request.name,
            email=request.email,
            device_id=request.device_id,
        )
        return {'success': True, 'profile': profile}
    except Exception as e:
        print(f'[SYNC] Profile sync error: {e}')
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@router.post('/session', response_model=SyncSessionResponse)
async def sync_session(request: SyncSessionRequest):
    """
    Called after every completed study session.
    Writes session log, updates daily stats, recalculates streak,
    and updates user aggregate stats — all in one call.
    """
    try:
        print(f'[SYNC] Session sync: uid={request.uid[:8]}, '
              f'doc={request.document_name}, mode={request.mode}, '
              f'score={request.score}, duration={request.duration_sec}s')

        now = datetime.now(timezone.utc)
        date_str = now.strftime('%Y-%m-%d')

        # 1. Write session log
        write_session_log(
            uid=request.uid,
            session_id=request.session_id,
            document_name=request.document_name,
            mode=request.mode,
            duration_sec=request.duration_sec,
            score=request.score,
            questions_attempted=request.questions_attempted,
            questions_correct=request.questions_correct,
            topics=request.topics,
        )

        # 2. Update daily stats
        update_daily_stats(
            uid=request.uid,
            date_str=date_str,
            duration_sec=request.duration_sec,
            score=request.score,
            questions_attempted=request.questions_attempted,
            questions_correct=request.questions_correct,
        )

        # 3. Update user aggregate stats
        updated = update_user_aggregate_stats(
            uid=request.uid,
            score=request.score,
            duration_sec=request.duration_sec,
            questions_attempted=request.questions_attempted,
            questions_correct=request.questions_correct,
        )

        # 4. Recalculate streak
        new_streak = calculate_and_update_streak(request.uid)

        print(f'[SYNC] Session sync complete: streak={new_streak}, '
              f'total_sessions={updated.get("totalSessions", 0)}')

        return SyncSessionResponse(
            success=True,
            new_streak=new_streak,
            total_sessions=updated.get('totalSessions', 0),
            avg_score=round(updated.get('avgScore', 0.0), 2),
            message='Session synced successfully',
        )

    except Exception as e:
        print(f'[SYNC] Session sync error: {e}')
        print(traceback.format_exc())
        # Return partial success so Flutter doesn't crash
        return SyncSessionResponse(
            success=False,
            new_streak=0,
            total_sessions=0,
            avg_score=0.0,
            message=f'Sync failed: {str(e)}',
        )


@router.get('/stats/{uid}')
async def get_stats(uid: str):
    """
    Returns all dashboard data for a user.
    Called on dashboard screen open and pull-to-refresh.
    """
    try:
        print(f'[SYNC] Stats fetch for uid: {uid[:8]}...')
        stats = get_user_stats(uid)
        return {'success': True, 'stats': stats}
    except Exception as e:
        print(f'[SYNC] Stats fetch error: {e}')
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/activity/{uid}')
async def get_activity(uid: str, limit: int = 10):
    """
    Returns recent session activity for home screen feed.
    """
    try:
        print(f'[SYNC] Activity fetch for uid: {uid[:8]}, limit={limit}')
        sessions = get_recent_sessions(uid=uid, limit=limit)
        return {'success': True, 'sessions': sessions}
    except Exception as e:
        print(f'[SYNC] Activity fetch error: {e}')
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/document-history/{uid}')
async def get_document_history(uid: str, document_name: str, limit: int = 5):
    """
    Returns session history for a specific document.
    Used in Library screen to show last studied + score per doc.
    """
    try:
        sessions = get_sessions_for_document(
            uid=uid,
            document_name=document_name,
            limit=limit,
        )
        return {'success': True, 'sessions': sessions}
    except Exception as e:
        print(f'[SYNC] Document history error: {e}')
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/profile/{uid}')
async def get_profile(uid: str):
    """Returns user profile — used for settings screen"""
    try:
        profile = get_user_profile(uid)
        if not profile:
            raise HTTPException(status_code=404, detail='User not found')
        return {'success': True, 'profile': profile}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))