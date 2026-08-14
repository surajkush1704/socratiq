import json
import traceback
from typing import Any

from llm.router import call_llm

SYSTEM_PROMPT = """You are an expert academic content analyser. You receive raw text extracted from a PDF study document. You must return a JSON object with exactly these keys:
- summary: a clear 3-5 sentence summary of the entire document
- key_points: a list of 5-10 most important points as strings
- topics: a list of the main topic names as short strings (2-5 words each)
Return only valid JSON. No markdown. No explanation. No preamble. No code blocks."""

DEFAULT_RESPONSE = {
    "summary": "Unable to generate summary right now.",
    "key_points": [],
    "topics": [],
}


async def process_content(extracted_text: str) -> dict[str, Any]:
    if not extracted_text.strip():
        return DEFAULT_RESPONSE.copy()

    result = ""
    try:
        trimmed_text = extracted_text[:500000]
        print(f"[CONTENT AGENT] Sending {len(trimmed_text)} chars to LLM router")

        result = await call_llm(
            prompt=trimmed_text,
            system_prompt=SYSTEM_PROMPT,
        )

        print(f"[CONTENT AGENT] Raw response: {result[:300]}")

        cleaned = result.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        summary = parsed.get("summary", "")
        key_points = parsed.get("key_points", [])
        topics = parsed.get("topics", [])

        if not isinstance(summary, str):
            summary = ""
        if not isinstance(key_points, list):
            key_points = []
        if not isinstance(topics, list):
            topics = []

        return {
            "summary": summary.strip(),
            "key_points": [str(item).strip() for item in key_points if str(item).strip()],
            "topics": [str(item).strip() for item in topics if str(item).strip()],
        }
    except json.JSONDecodeError as e:
        print(f"[CONTENT AGENT] JSON parse error: {e}")
        print(f"[CONTENT AGENT] Raw result was: {result}")
        return {
            "summary": "Unable to parse summary. Try again.",
            "key_points": [],
            "topics": [],
        }
    except Exception as e:
        print(f"[CONTENT AGENT] Error: {str(e)}")
        print(traceback.format_exc())
        return DEFAULT_RESPONSE.copy()