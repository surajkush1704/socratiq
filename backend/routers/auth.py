import os
from typing import Optional
from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel

try:
    from db.firestore import delete_user_account_data, create_or_update_user_profile
except Exception as e:
    print(f"[AUTH ROUTER] Firestore import warning: {e}")
    delete_user_account_data = None
    create_or_update_user_profile = None

try:
    from firebase_admin import auth as fb_auth
except Exception:
    fb_auth = None

router = APIRouter()
is_production = os.getenv("ENV", "development") == "production"


class LoginRequest(BaseModel):
    uid: str
    email: Optional[str] = ""
    name: Optional[str] = ""
    provider: Optional[str] = ""


def _verify_caller_uid(uid: str, authorization: Optional[str] = None) -> None:
    """
    Verifies that the request's Firebase ID token matches the target uid.
    Enforced strictly in production; allowed in dev/test when header omitted.
    """
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ")[1].strip()
        if fb_auth:
            try:
                decoded = fb_auth.verify_id_token(token)
                if decoded.get("uid") != uid:
                    raise HTTPException(
                        status_code=403,
                        detail="Not authorized to modify this user account",
                    )
            except HTTPException:
                raise
            except Exception as e:
                raise HTTPException(
                    status_code=401,
                    detail="Invalid or expired authentication token",
                )
    elif is_production:
        raise HTTPException(
            status_code=401,
            detail="Authentication token required in production",
        )


@router.post("/login")
async def login(req: LoginRequest):
    """
    Called by mobile app on login and pre-checks.
    Rate limited by RateLimitMiddleware (5 attempts / 5 mins).
    """
    try:
        # Pre-check is used by mobile to verify rate limit before Firebase attempt
        if req.uid and req.uid != "pre_check":
            print(f"[AUTH] User login: uid={req.uid[:8]}, provider={req.provider}")
            if create_or_update_user_profile:
                try:
                    create_or_update_user_profile(
                        uid=req.uid,
                        name=req.name or "",
                        email=req.email or "",
                    )
                except Exception as db_err:
                    print(f"[AUTH] Profile update warning: {db_err}")

        return {"status": "ok", "uid": req.uid}
    except Exception as e:
        print(f"[AUTH] Login error: {e}")
        raise HTTPException(status_code=500, detail="Authentication processing failed")


@router.post("/logout")
async def logout(uid: str = Query(default="")):
    """Called on user sign out."""
    if uid:
        print(f"[AUTH] User logged out: {uid[:8]}")
    return {"status": "logged_out", "uid": uid}


@router.delete("/account/{uid}")
async def delete_account(
    uid: str,
    authorization: Optional[str] = Header(default=None),
):
    """Permanently deletes user data from backend and Firestore."""
    if not uid:
        raise HTTPException(status_code=400, detail="User ID is required")

    # Verify authorization
    _verify_caller_uid(uid, authorization)

    try:
        print(f"[AUTH] Deleting all data for user {uid[:8]}...")
        if delete_user_account_data:
            delete_user_account_data(uid)
        return {"status": "deleted", "uid": uid}
    except Exception as e:
        print(f"[AUTH] Failed to delete account data for {uid}: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete account data")
