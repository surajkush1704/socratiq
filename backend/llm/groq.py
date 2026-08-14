import os

import httpx

GROQ_BASE_URL = "https://api.groq.com/openai/v1"
GROQ_MODEL = "llama-3.3-70b-versatile"
MAX_PROMPT_CHARS = 80000


async def call_groq(prompt: str, system_prompt: str) -> str:
    api_key = (os.getenv("GROQ_API_KEY") or "").strip()
    if not api_key:
        raise ValueError("GROQ_API_KEY is not set")

    print(f"[GROQ] Model: {GROQ_MODEL}, text length: {len(prompt)} chars")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": GROQ_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt[:MAX_PROMPT_CHARS]},
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{GROQ_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )

    print(f"[GROQ] Status: {response.status_code}")
    response.raise_for_status()
    data = response.json()

    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError("Unexpected Groq response format") from exc