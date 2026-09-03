import os
import httpx

GROQ_BASE_URL = 'https://api.groq.com/openai/v1'


async def call_groq(
    prompt: str,
    system_prompt: str,
    model: str = 'groq/compound',
    temperature: float = 0.4,
    max_tokens: int = 1024
) -> str:
    api_key = os.getenv('GROQ_API_KEY')
    if not api_key:
        raise ValueError('GROQ_API_KEY not set')

    print(f'[GROQ] Model: {model}, prompt length: {len(prompt)} chars')

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    payload = {
        'model': model,
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': prompt}
        ],
        'temperature': temperature,
        'max_tokens': max_tokens
    }

    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(
            f'{GROQ_BASE_URL}/chat/completions',
            headers=headers,
            json=payload
        )
        print(f'[GROQ] Status: {response.status_code}')
        if response.status_code != 200:
            print(f'[GROQ] Error: {response.text[:300]}')
        response.raise_for_status()
        data = response.json()
        return data['choices'][0]['message']['content']


async def call_groq_gemma(prompt: str, system_prompt: str) -> str:
    return await call_groq(
        prompt=prompt,
        system_prompt=system_prompt,
        model='groq/compound-mini',
        temperature=0.3
    )