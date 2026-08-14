import os

import httpx

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
GEMINI_MODEL = "gemini-2.0-flash"


async def call_gemini(prompt: str, system_prompt: str) -> str:
    api_key = (os.getenv("GEMINI_API_KEY") or "").strip()
    if not api_key:
        raise ValueError("GEMINI_API_KEY is not set")

    print(f"[GEMINI] Using key: {api_key[:10]}...")
    print(f"[GEMINI] Text length: {len(prompt)} characters")

    payload = {
        "system_instruction": {
            "parts": [{"text": system_prompt}],
        },
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ],
        "generationConfig": {
            "temperature": 0.3,
            "maxOutputTokens": 2048,
        },
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{GEMINI_BASE_URL}/models/{GEMINI_MODEL}:generateContent?key={api_key}",
            json=payload,
        )

    print(f"[GEMINI STATUS]: {response.status_code}")
    print(f"[GEMINI BODY]: {response.text[:500]}")

    response.raise_for_status()
    data = response.json()

    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError("Unexpected Gemini response format") from exc