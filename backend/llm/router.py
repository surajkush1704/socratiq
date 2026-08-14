"""
LLM Fallback Router
-------------------
Tries providers in order. If a provider returns HTTP 429 (rate limit) or
HTTP 503 (unavailable), it automatically moves to the next one.
Any other error (auth failure, bad response, etc.) is raised immediately.

Provider order:
  1. Gemini        — primary, highest quality
  2. Groq           — very fast, generous free tier
  3. Mistral        — reliable fallback
  4. Kimi           — moonshot-v1-8k, good for longer docs
  5. OpenRouter     — meta-fallback, routes to Gemini 2.0 Flash
"""

import httpx

from llm.gemini import call_gemini
from llm.groq import call_groq
from llm.kimi import call_kimi
from llm.mistral import call_mistral
from llm.openrouter import call_openrouter

# (name, callable) — order matters
_PROVIDERS = [
    ("Gemini", call_gemini),
    ("Groq", call_groq),
    ("Mistral", call_mistral),
    ("Kimi", call_kimi),
    ("OpenRouter", call_openrouter),
]

# HTTP status codes that mean "slow down, try someone else"
_RATE_LIMIT_CODES = {429, 503, 529}


async def call_llm(prompt: str, system_prompt: str) -> str:
    """
    Call the first available LLM provider, falling back automatically
    on rate-limit (429/503) errors.
    """
    last_error: Exception | None = None

    for name, fn in _PROVIDERS:
        try:
            print(f"[LLM ROUTER] Trying {name}...")
            result = await fn(prompt=prompt, system_prompt=system_prompt)
            print(f"[LLM ROUTER] ✓ {name} succeeded")
            return result

        except httpx.HTTPStatusError as e:
            if e.response.status_code in _RATE_LIMIT_CODES:
                print(
                    f"[LLM ROUTER] {name} rate-limited "
                    f"(HTTP {e.response.status_code}), trying next provider..."
                )
                last_error = e
                continue
            # Any other HTTP error (auth, bad request, etc.) — fail fast
            print(f"[LLM ROUTER] {name} failed with HTTP {e.response.status_code}: {e}")
            raise

        except ValueError as e:
            # Missing API key — skip silently and try next
            print(f"[LLM ROUTER] {name} skipped: {e}")
            last_error = e
            continue

        except Exception as e:
            print(f"[LLM ROUTER] {name} unexpected error: {e}")
            raise

    raise RuntimeError(
        f"All LLM providers exhausted. Last error: {last_error}"
    )