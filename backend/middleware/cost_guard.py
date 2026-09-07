from datetime import datetime, timezone
from threading import Lock
from typing import Dict
from fastapi import HTTPException

MAX_OUTPUT_TOKENS = 1000
MAX_AUDIO_SIZE_MB = 25
MAX_PDF_SIZE_MB = 10

# Thread-safe in-memory quota tracking: { "YYYY-MM-DD:uid:resource": count }
_quota_lock = Lock()
_daily_quota_counts: Dict[str, int] = {}
_last_cleared_date: str = ""


def validate_text_input(text: str, max_chars: int = 2000) -> None:
    """Validates that text input does not exceed character limit."""
    if text and len(text) > max_chars:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "Input too large",
                "message": f"Text input exceeds maximum allowed length of {max_chars} characters (received {len(text)}).",
            },
        )


def validate_file_size(size_bytes: int, max_mb: int, file_type: str = "File") -> None:
    """Validates that uploaded file size does not exceed max_mb (returns 413 if exceeded)."""
    max_bytes = max_mb * 1024 * 1024
    if size_bytes > max_bytes:
        raise HTTPException(
            status_code=413,
            detail={
                "error": "File too large",
                "message": f"{file_type} size ({size_bytes / (1024 * 1024):.2f}MB) exceeds maximum allowed limit of {max_mb}MB.",
            },
        )


def enforce_daily_quota(uid: str, resource: str, limit: int) -> None:
    """Enforces daily usage limits per user for high-cost operations (returns 429 if exceeded)."""
    if not uid:
        return

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = f"{today}:{uid}:{resource}"

    global _last_cleared_date
    with _quota_lock:
        # Prune old keys when day rolls over
        if _last_cleared_date != today:
            keys_to_remove = [k for k in _daily_quota_counts if not k.startswith(today)]
            for k in keys_to_remove:
                del _daily_quota_counts[k]
            _last_cleared_date = today

        current_count = _daily_quota_counts.get(key, 0)
        if current_count >= limit:
            raise HTTPException(
                status_code=429,
                detail={
                    "error": "Daily quota exceeded",
                    "message": f"Daily limit of {limit} {resource} requests reached. Resets at midnight UTC.",
                    "resource": resource,
                    "limit": limit,
                },
            )

        _daily_quota_counts[key] = current_count + 1
