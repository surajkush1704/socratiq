import os

import httpx

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
OPENROUTER_MODEL = "google/gemini-2.0-flash-001"  # fast + free tier
MAX_PROMPT_CHARS = 80000


async def call_openrouter(prompt: str, system_prompt: str) -> str:
    api_key = (os.getenv("OPENROUTER_API_KEY") or "").strip()
    if not api_key:
        raise ValueError("OPENROUTER_API_KEY is not set")

    print(f"[OPENROUTER] Model: {OPENROUTER_MODEL}, text length: {len(prompt)} chars")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://socratiq.app",
        "X-Title": "Socratiq",
    }

    payload = {
        "model": OPENROUTER_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt[:MAX_PROMPT_CHARS]},
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )

    print(f"[OPENROUTER] Status: {response.status_code}")
    response.raise_for_status()
    data = response.json()

    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError("Unexpected OpenRouter response format") from exc