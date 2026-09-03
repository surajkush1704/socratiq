import os
import httpx

OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1'
OPENROUTER_MODEL = 'meta-llama/llama-3.2-3b-instruct:free'


async def call_openrouter(prompt: str, system_prompt: str) -> str:
    api_key = os.getenv('OPENROUTER_API_KEY')
    if not api_key:
        raise ValueError('OPENROUTER_API_KEY not set')

    print(f'[OPENROUTER] Calling model: {OPENROUTER_MODEL}')

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://socratiq.app',
        'X-Title': 'Socratiq'
    }
    payload = {
        'model': OPENROUTER_MODEL,
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.4,
        'max_tokens': 1024
    }

    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(
            f'{OPENROUTER_BASE_URL}/chat/completions',
            headers=headers,
            json=payload
        )
        print(f'[OPENROUTER] Status: {response.status_code}')
        if response.status_code != 200:
            print(f'[OPENROUTER] Error: {response.text[:300]}')
        response.raise_for_status()
        data = response.json()
        return data['choices'][0]['message']['content']