from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from routers import content

load_dotenv()

app = FastAPI(title="Socratiq Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(content.router, prefix="/content", tags=["content"])


@app.get("/")
def root():
    return {"status": "Socratiq backend running"}