import time
import math
from threading import Lock
from typing import Dict, List
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

# Rate limit configs
GENERAL_LIMIT = 100
GENERAL_WINDOW_SECONDS = 60

LOGIN_LIMIT = 5
LOGIN_WINDOW_SECONDS = 300


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self._lock = Lock()
        self._ip_records: Dict[str, List[float]] = {}
        self._login_records: Dict[str, List[float]] = {}

    def _get_client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client and request.client.host:
            return request.client.host
        return "127.0.0.1"

    async def dispatch(self, request: Request, call_next) -> Response:
        now = time.time()
        client_ip = self._get_client_ip(request)
        path = request.url.path

        with self._lock:
            # Clean and check login rate limit
            if path == "/auth/login" and request.method == "POST":
                history = self._login_records.get(client_ip, [])
                history = [t for t in history if now - t < LOGIN_WINDOW_SECONDS]
                if len(history) >= LOGIN_LIMIT:
                    oldest = history[0]
                    retry_after = max(1, math.ceil(oldest + LOGIN_WINDOW_SECONDS - now))
                    return JSONResponse(
                        status_code=429,
                        content={
                            "detail": {
                                "error": "Too many login attempts",
                                "message": f"Too many login attempts. Please wait {retry_after} seconds.",
                                "retry_after": retry_after,
                            }
                        },
                        headers={
                            "X-RateLimit-Limit": str(LOGIN_LIMIT),
                            "X-RateLimit-Remaining": "0",
                            "X-RateLimit-Window": str(LOGIN_WINDOW_SECONDS),
                            "Retry-After": str(retry_after),
                        },
                    )
                history.append(now)
                self._login_records[client_ip] = history

            # General rate limit
            ip_history = self._ip_records.get(client_ip, [])
            ip_history = [t for t in ip_history if now - t < GENERAL_WINDOW_SECONDS]

            limit = GENERAL_LIMIT
            window = GENERAL_WINDOW_SECONDS

            if len(ip_history) >= limit:
                retry_after = max(1, math.ceil(ip_history[0] + window - now))
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": {
                            "error": "Rate limit exceeded",
                            "message": f"Too many requests. Please wait {retry_after} seconds.",
                            "retry_after": retry_after,
                        }
                    },
                    headers={
                        "X-RateLimit-Limit": str(limit),
                        "X-RateLimit-Remaining": "0",
                        "X-RateLimit-Window": str(window),
                        "Retry-After": str(retry_after),
                    },
                )

            ip_history.append(now)
            self._ip_records[client_ip] = ip_history
            remaining = max(0, limit - len(ip_history))

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Window"] = str(window)
        return response
