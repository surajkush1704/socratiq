import os

import httpx

KIMI_BASE_URL = "https://api.moonshot.ai/v1"
KIMI_MODEL = os.getenv("KIMI_MODEL", "moonshot-v1-8k")
MAX_PROMPT_CHARS = 20000


async def call_kimi(prompt: str, system_prompt: str) -> str:
    api_key = (os.getenv("KIMI_API_KEY") or "").strip()
    if not api_key:
        raise ValueError("KIMI_API_KEY is not set")

    try:
        print("[KIMI] Calling API")
        print(f"[KIMI] Model: {KIMI_MODEL}")
        print(f"[KIMI] Text length being sent: {len(prompt)} characters")

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": KIMI_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt[:MAX_PROMPT_CHARS]},
            ],
            "temperature": 0.3,
        }

        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{KIMI_BASE_URL}/chat/completions",
                headers=headers,
                json=payload,
            )

        print(f"[KIMI] Response status: {response.status_code}")
        print(f"[KIMI] Response body: {response.text[:500]}")

        response.raise_for_status()
        data = response.json()

        try:
            return data["choices"][0]["message"]["content"].strip()
        except (KeyError, IndexError, TypeError) as exc:
            raise ValueError("Unexpected Kimi response format") from exc
    except Exception as e:
        print(f"[KIMI CALL ERROR]: {str(e)}")
        raise