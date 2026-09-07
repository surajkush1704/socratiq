from pathlib import Path
import fitz
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from agents.content_agent import process_content
from models.session import ContentProcessRequest
from middleware.cost_guard import (
    enforce_daily_quota,
    validate_file_size,
    MAX_PDF_SIZE_MB,
)

router = APIRouter()


@router.post("/upload")
async def upload_pdf(
    file: UploadFile = File(...),
    uid: str = Form(default=""),
):
    try:
        content_bytes = await file.read()

        # Validate PDF size — 10MB max
        validate_file_size(
            size_bytes=len(content_bytes),
            max_mb=MAX_PDF_SIZE_MB,
            file_type="PDF file",
        )

        # Validate file type by magic byte header
        if not content_bytes.startswith(b"%PDF"):
            raise HTTPException(
                status_code=400,
                detail={
                    "error": "Invalid file type",
                    "message": "Only PDF files are supported.",
                },
            )

        # Enforce daily upload quota
        if uid:
            enforce_daily_quota(uid=uid, resource="pdf_upload", limit=20)

        # Sanitize filename
        raw_name = file.filename or "document.pdf"
        filename = Path(raw_name).name

        # Process entirely in memory to prevent disk exhaustion and path traversal
        try:
            with fitz.open(stream=content_bytes, filetype="pdf") as document:
                extracted_chunks = [page.get_text("text") for page in document]
                page_count = len(document)
        except Exception as exc:
            raise HTTPException(status_code=400, detail="Failed to extract text from PDF.") from exc

        extracted_text = "\n".join(extracted_chunks).strip()

        return {
            "document_name": filename,
            "page_count": page_count,
            "extracted_text": extracted_text,
            "temp_file": "",
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"[CONTENT ROUTER] Upload error: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload PDF")


@router.post("/process")
async def process_document(body: ContentProcessRequest):
    result = await process_content(body.extracted_text)
    return {
        "document_name": body.document_name,
        "summary": result.get("summary", ""),
        "key_points": result.get("key_points", []),
        "topics": result.get("topics", []),
    }