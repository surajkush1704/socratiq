import os

import httpx

MISTRAL_BASE_URL = "https://api.mistral.ai/v1"
MISTRAL_MODEL = "mistral-small-latest"
MAX_PROMPT_CHARS = 80000


async def call_mistral(prompt: str, system_prompt: str) -> str:
    api_key = (os.getenv("MISTRAL_API_KEY") or "").strip()
    if not api_key:
        raise ValueError("MISTRAL_API_KEY is not set")

    print(f"[MISTRAL] Model: {MISTRAL_MODEL}, text length: {len(prompt)} chars")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": MISTRAL_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt[:MAX_PROMPT_CHARS]},
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{MISTRAL_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )

    print(f"[MISTRAL] Status: {response.status_code}")
    response.raise_for_status()
    data = response.json()

    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError("Unexpected Mistral response format") from exc