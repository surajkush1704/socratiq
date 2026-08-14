from pathlib import Path
from uuid import uuid4

import fitz
from fastapi import APIRouter, File, HTTPException, UploadFile

from agents.content_agent import process_content
from models.session import ContentProcessRequest

router = APIRouter()
TEMP_DIR = Path("temp")
TEMP_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/upload")
async def upload_pdf(file: UploadFile = File(...)):
    filename = file.filename or "document.pdf"
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    unique_name = f"{uuid4()}_{filename}"
    saved_path = TEMP_DIR / unique_name

    content = await file.read()
    saved_path.write_bytes(content)

    try:
        with fitz.open(saved_path) as document:
            extracted_chunks = [page.get_text("text") for page in document]
            page_count = len(document)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to extract PDF text: {exc}") from exc

    extracted_text = "\n".join(extracted_chunks).strip()

    return {
        "document_name": filename,
        "page_count": page_count,
        "extracted_text": extracted_text,
        "temp_file": str(saved_path),
    }


@router.post("/process")
async def process_document(body: ContentProcessRequest):
    result = await process_content(body.extracted_text)
    return {
        "document_name": body.document_name,
        "summary": result.get("summary", ""),
        "key_points": result.get("key_points", []),
        "topics": result.get("topics", []),
    }