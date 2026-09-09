import json
import os
import firebase_admin
from firebase_admin import credentials, firestore

# ── FIREBASE INIT ─────────────────────────────────────────────────────────────

db = None

def _init_firebase():
    global db
    if firebase_admin._apps:
        try:
            db = firestore.client()
        except Exception:
            db = None
        return

    key_json = os.getenv('FIREBASE_ADMIN_KEY_JSON')
    if key_json:
        try:
            cred_dict = json.loads(key_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print('[FIRESTORE] Initialised from environment variable')
            return
        except Exception as e:
            print(f'[FIRESTORE] Warning: FIREBASE_ADMIN_KEY_JSON invalid: {e}')
            db = None
            return

    # Local dev — key from file
    key_path = 'firebase-admin-key.json'
    if not os.path.exists(key_path) and os.path.exists('../firebase-admin-key.json'):
        key_path = '../firebase-admin-key.json'
    if os.path.exists(key_path):
        try:
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print('[FIRESTORE] Initialised from local key file')
            return
        except Exception as e:
            print(f'[FIRESTORE] Warning: Could not read local key file: {e}')
            db = None
            return

    print('[FIRESTORE] Warning: No Firebase credentials found. Running in offline/in-memory mode.')
    db = None

_init_firebase()


# ── COLLECTION REFERENCES ─────────────────────────────────────────────────────

def users_col():
    return db.collection('users') if db else None

def user_doc(uid: str):
    return db.collection('users').document(uid) if db else None

def sessions_col(uid: str):
    return db.collection('users').document(uid).collection('sessions') if db else None

def session_doc(uid: str, session_id: str):
    return db.collection('users').document(uid).collection('sessions').document(session_id) if db else None

def daily_stats_col(uid: str):
    return db.collection('users').document(uid).collection('dailyStats') if db else None

def daily_stats_doc(uid: str, date_str: str):
    return db.collection('users').document(uid).collection('dailyStats').document(date_str) if db else None


# ── USER PROFILE ──────────────────────────────────────────────────────────────

def get_user_profile(uid: str) -> dict:
    if not db:
        return {'uid': uid, 'name': 'User', 'username': 'user', 'streak': 0}
    try:
        doc = user_doc(uid).get()
        if doc.exists:
            return doc.to_dict()
    except Exception as e:
        print(f'[FIRESTORE] get_user_profile error: {e}')
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

    if not db:
        return {
            'uid': uid,
            'name': name,
            'username': username or '',
            'avatarId': avatar_id if avatar_id is not None else 0,
            'email': email,
            'deviceId': device_id,
            'streak': 1,
            'longestStreak': 1,
            'totalSessions': 1,
            'totalStudyTimeSec': 0,
            'avgScore': 0.0,
            'totalQuestionsAttempted': 0,
            'totalQuestionsCorrect': 0,
        }

    existing = get_user_profile(uid)

    if not existing:
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
        try:
            user_doc(uid).set(profile)
            print(f'[FIRESTORE] Created user profile: {uid}')
        except Exception as e:
            print(f'[FIRESTORE] Error creating profile: {e}')
        return profile
    else:
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
        try:
            user_doc(uid).update(updates)
            print(f'[FIRESTORE] Updated user profile: {uid}')
        except Exception as e:
            print(f'[FIRESTORE] Error updating profile: {e}')
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

    if db:
        try:
            session_doc(uid, session_id).set(session_data)
            print(f'[FIRESTORE] Session logged: {session_id[:8]} for user {uid[:8]}')
        except Exception as e:
            print(f'[FIRESTORE] Failed to log session: {e}')

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
    if not db:
        return {'date': date_str, 'sessions': 1, 'score': score}

    try:
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
    except Exception as e:
        print(f'[FIRESTORE] update_daily_stats error: {e}')
        return {'date': date_str, 'sessions': 1, 'score': score}


# ── STREAK CALCULATION ────────────────────────────────────────────────────────

def calculate_and_update_streak(uid: str) -> int:
    if not db:
        return 1

    from datetime import datetime, timezone, timedelta

    today = datetime.now(timezone.utc).date()

    try:
        docs = (
            daily_stats_col(uid)
            .order_by('date', direction=firestore.Query.DESCENDING)
            .limit(60)
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
            user_doc(uid).update({'streak': 0})
            return 0

        streak = 0
        check_date = today
        if today not in study_dates:
            check_date = today - timedelta(days=1)

        while check_date in study_dates:
            streak += 1
            check_date -= timedelta(days=1)

        existing = get_user_profile(uid)
        longest = max(existing.get('longestStreak', 0), streak)

        user_doc(uid).update({
            'streak': streak,
            'longestStreak': longest,
        })
        return streak
    except Exception as e:
        print(f'[FIRESTORE] calculate_and_update_streak error: {e}')
        return 1


# ── USER AGGREGATED STATS UPDATE ─────────────────────────────────────────────

def update_user_aggregate_stats(
    uid: str,
    score: float,
    duration_sec: int,
    questions_attempted: int,
    questions_correct: int,
) -> dict:
    if not db:
        return {}

    existing = get_user_profile(uid)
    if not existing:
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

    try:
        user_doc(uid).update(updates)
    except Exception as e:
        print(f'[FIRESTORE] update_user_aggregate_stats error: {e}')

    return updates


# ── READ: USER STATS FOR DASHBOARD ───────────────────────────────────────────

def get_user_stats(uid: str) -> dict:
    from datetime import datetime, timezone, timedelta

    profile = get_user_profile(uid)
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    today_data = {}

    if db:
        try:
            today_doc = daily_stats_doc(uid, today_str).get()
            today_data = today_doc.to_dict() if today_doc.exists else {}
        except Exception:
            pass

    weekly_data = []
    for i in range(6, -1, -1):
        day = datetime.now(timezone.utc).date() - timedelta(days=i)
        day_str = day.strftime('%Y-%m-%d')
        day_data = {}
        if db:
            try:
                day_doc = daily_stats_doc(uid, day_str).get()
                day_data = day_doc.to_dict() if day_doc.exists else {}
            except Exception:
                pass
        weekly_data.append({
            'date': day_str,
            'dayLabel': day.strftime('%a')[0],
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
    if not db:
        return []
    try:
        docs = (
            sessions_col(uid)
            .order_by('createdAt', direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [doc.to_dict() for doc in docs]
    except Exception as e:
        print(f'[FIRESTORE] get_recent_sessions error: {e}')
        return []


# ── READ: SESSION HISTORY BY DOCUMENT ────────────────────────────────────────

def get_sessions_for_document(uid: str, document_name: str, limit: int = 5) -> list:
    if not db:
        return []
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
        try:
            docs = (
                sessions_col(uid)
                .where('documentName', '==', document_name)
                .stream()
            )
            items = [doc.to_dict() for doc in docs]
            items.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
            return items[:limit]
        except Exception:
            return []


# ── ACCOUNT DELETION ──────────────────────────────────────────────────────────

def delete_user_account_data(uid: str) -> None:
    if not db:
        return
    try:
        sessions = sessions_col(uid).stream()
        for doc in sessions:
            doc.reference.delete()

        daily_stats = daily_stats_col(uid).stream()
        for doc in daily_stats:
            doc.reference.delete()

        user_doc(uid).delete()
        print(f'[FIRESTORE] Successfully deleted all data for user {uid}')
    except Exception as e:
        print(f'[FIRESTORE] Failed to delete user data for {uid}: {e}')