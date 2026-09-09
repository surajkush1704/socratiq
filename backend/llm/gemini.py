import os
import httpx

GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'
GEMINI_MODEL = 'gemini-2.5-flash'


async def call_gemini(prompt: str, system_prompt: str) -> str:
    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        raise ValueError('GEMINI_API_KEY not set')

    print('[GEMINI] Calling API...')

    payload = {
        'system_instruction': {
            'parts': [{'text': system_prompt}]
        },
        'contents': [
            {'role': 'user', 'parts': [{'text': prompt}]}
        ],
        'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 1024
        }
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f'{GEMINI_BASE_URL}/models/{GEMINI_MODEL}:generateContent?key={api_key}',
            json=payload
        )
        print(f'[GEMINI] Status: {response.status_code}')
        if response.status_code != 200:
            safe_err = response.text[:300].encode('ascii', 'replace').decode('ascii')
            print(f'[GEMINI] Error body: {safe_err}')
        response.raise_for_status()
        data = response.json()
        return data['candidates'][0]['content']['parts'][0]['text']