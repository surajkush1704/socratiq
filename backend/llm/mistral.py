import os
import httpx

MISTRAL_BASE_URL = 'https://api.mistral.ai/v1'
MISTRAL_MODEL = 'mistral-small-latest'


async def call_mistral(prompt: str, system_prompt: str) -> str:
    api_key = os.getenv('MISTRAL_API_KEY')
    if not api_key:
        raise ValueError('MISTRAL_API_KEY not set')

    print(f'[MISTRAL] Calling model: {MISTRAL_MODEL}')

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    payload = {
        'model': MISTRAL_MODEL,
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 1024
    }

    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(
            f'{MISTRAL_BASE_URL}/chat/completions',
            headers=headers,
            json=payload
        )
        print(f'[MISTRAL] Status: {response.status_code}')
        if response.status_code != 200:
            print(f'[MISTRAL] Error: {response.text[:300]}')
        response.raise_for_status()
        data = response.json()
        return data['choices'][0]['message']['content']