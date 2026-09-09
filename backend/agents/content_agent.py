import json
import re
import traceback
from typing import Any

from llm.router import call_llm

from utils.language_detector import detect_language

SYSTEM_PROMPT = """You are an expert academic content analyser. You receive raw text extracted from a PDF study document. You must return a JSON object with exactly these keys:
- summary: a clear 3-5 sentence summary of the entire document
- key_points: a list of 5-10 most important points as strings
- topics: a list of the main topic names as short strings (2-5 words each)

Return ONLY valid JSON format:
{
  "summary": "3-5 sentence summary...",
  "key_points": ["point 1", "point 2"],
  "topics": ["topic 1", "topic 2"]
}
Do NOT include markdown formatting or extra text outside the JSON object.

IMPORTANT LANGUAGE RULE:

Extract summary and key_points in the SAME language as the input document.
If the document is in Sanskrit, write summary and key_points in Sanskrit.
If the document is in Hindi, write in Hindi.
If in English, write in English.
topics list should also be in the document language.
Return only valid JSON. The language of values must match the document."""


def _build_fallback_summary(extracted_text: str) -> dict[str, Any]:
    doc_lang, resp_lang, lang_name = detect_language(extracted_text)
    text = extracted_text.strip()
    if not text:
        return {
            "summary": "This PDF appears to contain visual pages or scanned images. You can still ask your SocratiQ AI Tutor questions directly about this document!",
            "key_points": ["Visual or image-based PDF document uploaded.", "Use AI Tutor for interactive Q&A."],
            "topics": ["Document Notes", "Study Material"],
            "document_language": doc_lang,
            "response_language": resp_lang,
            "language_display_name": lang_name,
        }

    # Extract first ~400 characters for fallback summary
    clean_lines = [line.strip() for line in text.splitlines() if line.strip() and len(line.strip()) > 10]
    fallback_summary = " ".join(clean_lines[:4])
    if len(fallback_summary) > 400:
        fallback_summary = fallback_summary[:400] + "..."
    if not fallback_summary:
        fallback_summary = text[:300] + "..."

    return {
        "summary": fallback_summary,
        "key_points": clean_lines[4:9] if len(clean_lines) >= 9 else (clean_lines[:5] or ["Study notes and key concepts."]),
        "topics": ["Study Notes", "Key Concepts"],
        "document_language": doc_lang,
        "response_language": resp_lang,
        "language_display_name": lang_name,
    }


async def process_content(extracted_text: str) -> dict[str, Any]:
    doc_lang, resp_lang, lang_name = detect_language(extracted_text)
    if not extracted_text.strip():
        return _build_fallback_summary(extracted_text)

    result = ""
    try:
        trimmed_text = extracted_text[:80000]
        print(f"[CONTENT AGENT] Sending {len(trimmed_text)} chars to LLM router")

        result = await call_llm(
            prompt=trimmed_text,
            system_prompt=SYSTEM_PROMPT,
        )

        print(f"[CONTENT AGENT] Raw response: {result[:50]}...")

        # Clean markdown codeblocks
        cleaned = result.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        # Regex fallback to extract JSON object if model included extra text
        match = re.search(r'\{.*\}', cleaned, re.DOTALL)
        if match:
            cleaned = match.group(0)

        parsed = json.loads(cleaned)

        summary = parsed.get("summary", "")
        key_points = parsed.get("key_points", [])
        topics = parsed.get("topics", [])

        if not isinstance(summary, str) or not summary.strip():
            fallback = _build_fallback_summary(extracted_text)
            summary = fallback["summary"]

        if not isinstance(key_points, list) or not key_points:
            key_points = ["Key concepts covered in document."]

        if not isinstance(topics, list) or not topics:
            topics = ["Study Notes"]

        return {
            "summary": summary.strip(),
            "key_points": [str(item).strip() for item in key_points if str(item).strip()],
            "topics": [str(item).strip() for item in topics if str(item).strip()],
            "document_language": doc_lang,
            "response_language": resp_lang,
            "language_display_name": lang_name,
        }
    except json.JSONDecodeError as e:
        print(f"[CONTENT AGENT] JSON parse error: {e}")
        print(f"[CONTENT AGENT] Raw result was: {result}")
        fallback = _build_fallback_summary(extracted_text)
        if result and len(result.strip()) > 20:
            fallback["summary"] = result.strip()
        return fallback
    except Exception as e:
        print(f"[CONTENT AGENT] Error: {str(e)}")
        print(traceback.format_exc())
        return _build_fallback_summary(extracted_text)