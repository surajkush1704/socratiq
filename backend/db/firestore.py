import json
import os
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import AsyncClient

# ── FIREBASE INIT ─────────────────────────────────────────────────────────────

def _init_firebase():
    if firebase_admin._apps:
        return

    key_json = os.getenv('FIREBASE_ADMIN_KEY_JSON')
    if key_json:
        # Railway / production — key from environment variable
        try:
            cred_dict = json.loads(key_json)
            cred = credentials.Certificate(cred_dict)
            print('[FIRESTORE] Initialising from environment variable')
        except json.JSONDecodeError as e:
            raise ValueError(f'FIREBASE_ADMIN_KEY_JSON is not valid JSON: {e}')
    else:
        # Local dev — key from file
        key_path = 'firebase-admin-key.json'
        if not os.path.exists(key_path) and os.path.exists('../firebase-admin-key.json'):
            key_path = '../firebase-admin-key.json'
        if not os.path.exists(key_path):
            raise FileNotFoundError(
                f'Firebase key not found. '
                f'Set FIREBASE_ADMIN_KEY_JSON env var or '
                f'place firebase-admin-key.json in backend root.'
            )
        cred = credentials.Certificate(key_path)
        print('[FIRESTORE] Initialising from local key file')

    firebase_admin.initialize_app(cred)
    print('[FIRESTORE] Firebase Admin initialised successfully')


_init_firebase()
db = firestore.client()


# ── COLLECTION REFERENCES ─────────────────────────────────────────────────────

def users_col():
    return db.collection('users')

def user_doc(uid: str):
    return db.collection('users').document(uid)

def sessions_col(uid: str):
    return db.collection('users').document(uid).collection('sessions')

def session_doc(uid: str, session_id: str):
    return db.collection('users').document(uid).collection('sessions').document(session_id)

def daily_stats_col(uid: str):
    return db.collection('users').document(uid).collection('dailyStats')

def daily_stats_doc(uid: str, date_str: str):
    return db.collection('users').document(uid).collection('dailyStats').document(date_str)


# ── USER PROFILE ──────────────────────────────────────────────────────────────

def get_user_profile(uid: str) -> dict:
    doc = user_doc(uid).get()
    if doc.exists:
        return doc.to_dict()
    return {}


def create_or_update_user_profile(
    uid: str,
    name: str = '',
    email: str = '',
    device_id: str = '',
    username: str = None,
    avatar_id: int = None,
) -> dict:
    from datetime import datetime, timezone

    existing = get_user_profile(uid)

    if not existing:
        # First time — create full profile
        profile = {
            'uid': uid,
            'name': name,
            'username': username or '',
            'avatarId': avatar_id if avatar_id is not None else 0,
            'email': email,
            'deviceId': device_id,
            'createdAt': datetime.now(timezone.utc).isoformat(),
            'lastActive': datetime.now(timezone.utc).isoformat(),
            'streak': 0,
            'longestStreak': 0,
            'totalSessions': 0,
            'totalStudyTimeSec': 0,
            'avgScore': 0.0,
            'totalQuestionsAttempted': 0,
            'totalQuestionsCorrect': 0,
        }
        user_doc(uid).set(profile)
        print(f'[FIRESTORE] Created user profile: {uid}')
        return profile
    else:
        # Update last active + name/email/username if changed
        updates = {
            'lastActive': datetime.now(timezone.utc).isoformat(),
        }
        if name and name != existing.get('name'):
            updates['name'] = name
        if email and email != existing.get('email'):
            updates['email'] = email
        if username is not None:
            updates['username'] = username
        if avatar_id is not None:
            updates['avatarId'] = avatar_id
        user_doc(uid).update(updates)
        print(f'[FIRESTORE] Updated user profile: {uid}')
        return {**existing, **updates}


# ── SESSION WRITE ─────────────────────────────────────────────────────────────

def write_session_log(
    uid: str,
    session_id: str,
    document_name: str,
    mode: str,
    duration_sec: int,
    score: float,
    questions_attempted: int,
    questions_correct: int,
    topics: list,
) -> dict:
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    date_str = now.strftime('%Y-%m-%d')

    session_data = {
        'sessionId': session_id,
        'documentName': document_name,
        'mode': mode,
        'durationSec': duration_sec,
        'score': round(score, 2),
        'questionsAttempted': questions_attempted,
        'questionsCorrect': questions_correct,
        'topics': topics,
        'createdAt': now.isoformat(),
        'dateStr': date_str,
    }

    # Write session log
    session_doc(uid, session_id).set(session_data)
    print(f'[FIRESTORE] Session logged: {session_id[:8]} for user {uid[:8]}')

    return session_data


# ── DAILY STATS UPDATE ────────────────────────────────────────────────────────

def update_daily_stats(
    uid: str,
    date_str: str,
    duration_sec: int,
    score: float,
    questions_attempted: int,
    questions_correct: int,
) -> dict:
    doc_ref = daily_stats_doc(uid, date_str)
    existing = doc_ref.get()

    if existing.exists:
        data = existing.to_dict()
        new_sessions = data.get('sessions', 0) + 1
        new_total_time = data.get('totalTimeSec', 0) + duration_sec
        new_total_score = data.get('totalScore', 0.0) + score
        new_avg_score = new_total_score / new_sessions
        new_questions = data.get('questionsAttempted', 0) + questions_attempted
        new_correct = data.get('questionsCorrect', 0) + questions_correct

        updated = {
            'sessions': new_sessions,
            'totalTimeSec': new_total_time,
            'totalScore': new_total_score,
            'avgScore': round(new_avg_score, 2),
            'questionsAttempted': new_questions,
            'questionsCorrect': new_correct,
            'date': date_str,
            'updatedAt': __import__('datetime').datetime.utcnow().isoformat(),
        }
        doc_ref.update(updated)
        print(f'[FIRESTORE] Daily stats updated: {date_str}')
        return updated
    else:
        created = {
            'date': date_str,
            'sessions': 1,
            'totalTimeSec': duration_sec,
            'totalScore': score,
            'avgScore': round(score, 2),
            'questionsAttempted': questions_attempted,
            'questionsCorrect': questions_correct,
            'createdAt': __import__('datetime').datetime.utcnow().isoformat(),
            'updatedAt': __import__('datetime').datetime.utcnow().isoformat(),
        }
        doc_ref.set(created)
        print(f'[FIRESTORE] Daily stats created: {date_str}')
        return created


# ── STREAK CALCULATION ────────────────────────────────────────────────────────

def calculate_and_update_streak(uid: str) -> int:
    """
    Recalculates the user's study streak based on dailyStats documents.
    A streak is consecutive calendar days with at least one session.
    Updates the user profile with new streak value.
    Returns the new streak count.
    """
    from datetime import datetime, timezone, timedelta

    today = datetime.now(timezone.utc).date()

    # Get all daily stats docs ordered by date descending
    docs = (
        daily_stats_col(uid)
        .order_by('date', direction=firestore.Query.DESCENDING)
        .limit(60)  # check last 60 days max
        .stream()
    )

    study_dates = set()
    for doc in docs:
        data = doc.to_dict()
        date_str = data.get('date', '')
        if date_str:
            try:
                study_dates.add(
                    datetime.strptime(date_str, '%Y-%m-%d').date()
                )
            except ValueError:
                continue

    if not study_dates:
        print(f'[FIRESTORE] Streak: no study dates found for {uid[:8]}')
        user_doc(uid).update({'streak': 0})
        return 0

    # Count consecutive days ending today or yesterday
    streak = 0
    check_date = today

    # If today not studied yet, check from yesterday
    if today not in study_dates:
        check_date = today - timedelta(days=1)

    while check_date in study_dates:
        streak += 1
        check_date -= timedelta(days=1)

    # Update user profile
    existing = get_user_profile(uid)
    longest = max(existing.get('longestStreak', 0), streak)

    user_doc(uid).update({
        'streak': streak,
        'longestStreak': longest,
    })

    print(f'[FIRESTORE] Streak calculated: {streak} days for {uid[:8]}')
    return streak


# ── USER AGGREGATED STATS UPDATE ─────────────────────────────────────────────

def update_user_aggregate_stats(
    uid: str,
    score: float,
    duration_sec: int,
    questions_attempted: int,
    questions_correct: int,
) -> dict:
    """
    Updates the running aggregated stats on the user profile doc.
    Called after every session completes.
    """
    existing = get_user_profile(uid)
    if not existing:
        print(f'[FIRESTORE] No user profile to update for {uid[:8]}')
        return {}

    old_total = existing.get('totalSessions', 0)
    old_time = existing.get('totalStudyTimeSec', 0)
    old_avg = existing.get('avgScore', 0.0)
    old_questions = existing.get('totalQuestionsAttempted', 0)
    old_correct = existing.get('totalQuestionsCorrect', 0)

    new_total = old_total + 1
    new_time = old_time + duration_sec
    new_avg = ((old_avg * old_total) + score) / new_total if new_total > 0 else score
    new_questions = old_questions + questions_attempted
    new_correct = old_correct + questions_correct

    updates = {
        'totalSessions': new_total,
        'totalStudyTimeSec': new_time,
        'avgScore': round(new_avg, 2),
        'totalQuestionsAttempted': new_questions,
        'totalQuestionsCorrect': new_correct,
        'lastActive': __import__('datetime').datetime.utcnow().isoformat(),
    }

    user_doc(uid).update(updates)
    print(f'[FIRESTORE] User aggregate stats updated for {uid[:8]}')
    return updates


# ── READ: USER STATS FOR DASHBOARD ───────────────────────────────────────────

def get_user_stats(uid: str) -> dict:
    """Returns all stats needed for the Flutter dashboard"""
    from datetime import datetime, timezone, timedelta

    profile = get_user_profile(uid)
    if not profile:
        return {
            'streak': 0,
            'longestStreak': 0,
            'totalSessions': 0,
            'totalStudyTimeSec': 0,
            'avgScore': 0.0,
            'totalQuestionsAttempted': 0,
            'totalQuestionsCorrect': 0,
            'todayTimeSec': 0,
            'todaySessions': 0,
            'weeklyData': [],
        }

    # Today's stats
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    today_doc = daily_stats_doc(uid, today_str).get()
    today_data = today_doc.to_dict() if today_doc.exists else {}

    # Weekly data — last 7 days
    weekly_data = []
    for i in range(6, -1, -1):
        day = datetime.now(timezone.utc).date() - timedelta(days=i)
        day_str = day.strftime('%Y-%m-%d')
        day_doc = daily_stats_doc(uid, day_str).get()
        day_data = day_doc.to_dict() if day_doc.exists else {}
        weekly_data.append({
            'date': day_str,
            'dayLabel': day.strftime('%a')[0],  # M, T, W, T, F, S, S
            'totalTimeSec': day_data.get('totalTimeSec', 0),
            'sessions': day_data.get('sessions', 0),
            'avgScore': day_data.get('avgScore', 0.0),
        })

    return {
        'streak': profile.get('streak', 0),
        'longestStreak': profile.get('longestStreak', 0),
        'totalSessions': profile.get('totalSessions', 0),
        'totalStudyTimeSec': profile.get('totalStudyTimeSec', 0),
        'avgScore': profile.get('avgScore', 0.0),
        'totalQuestionsAttempted': profile.get('totalQuestionsAttempted', 0),
        'totalQuestionsCorrect': profile.get('totalQuestionsCorrect', 0),
        'todayTimeSec': today_data.get('totalTimeSec', 0),
        'todaySessions': today_data.get('sessions', 0),
        'weeklyData': weekly_data,
    }


# ── READ: RECENT SESSIONS ─────────────────────────────────────────────────────

def get_recent_sessions(uid: str, limit: int = 10) -> list:
    """Returns recent session logs for activity feed"""
    docs = (
        sessions_col(uid)
        .order_by('createdAt', direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )
    return [doc.to_dict() for doc in docs]


# ── READ: SESSION HISTORY BY DOCUMENT ────────────────────────────────────────

def get_sessions_for_document(uid: str, document_name: str, limit: int = 5) -> list:
    """Returns sessions for a specific document"""
    try:
        docs = (
            sessions_col(uid)
            .where('documentName', '==', document_name)
            .order_by('createdAt', direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [doc.to_dict() for doc in docs]
    except Exception as e:
        print(f'[FIRESTORE] Query with order_by failed ({e}), falling back to memory sort')
        docs = (
            sessions_col(uid)
            .where('documentName', '==', document_name)
            .stream()
        )
        items = [doc.to_dict() for doc in docs]
        items.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
        return items[:limit]


# ── ACCOUNT DELETION ──────────────────────────────────────────────────────────

def delete_user_account_data(uid: str) -> None:
    """Deletes all Firestore data associated with a user."""
    try:
        # 1. Delete sessions subcollection
        sessions = sessions_col(uid).stream()
        for doc in sessions:
            doc.reference.delete()

        # 2. Delete dailyStats subcollection
        daily_stats = daily_stats_col(uid).stream()
        for doc in daily_stats:
            doc.reference.delete()

        # 3. Delete user document
        user_doc(uid).delete()
        print(f'[FIRESTORE] Successfully deleted all data for user {uid}')
    except Exception as e:
        print(f'[FIRESTORE] Failed to delete user data for {uid}: {e}')
        raise