import os
import sys

root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
backend_dir = os.path.join(root_dir, "backend")

for p in [backend_dir, root_dir]:
    if os.path.exists(p) and p not in sys.path:
        sys.path.insert(0, p)

try:
    from main import app
except Exception as e1:
    try:
        from backend.main import app
    except Exception as e2:
        from fastapi import FastAPI
        app = FastAPI()
        @app.get("/")
        @app.get("/{full_path:path}")
        def fallback(full_path: str = ""):
            return {
                "error": "Failed to load backend",
                "detail1": str(e1),
                "detail2": str(e2),
            }
