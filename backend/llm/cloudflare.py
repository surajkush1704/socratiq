import os
import httpx

CLOUDFLARE_MODEL = '@cf/meta/llama-3.2-3b-instruct'


async def call_cloudflare(prompt: str, system_prompt: str) -> str:
    token = os.getenv('CLOUDFLARE_API_TOKEN')
    account_id = os.getenv('CLOUDFLARE_ACCOUNT_ID')
    if not token or not account_id:
        raise ValueError('CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID not set')

    print(f'[CLOUDFLARE] Calling model: {CLOUDFLARE_MODEL}')

    url = f'https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run/{CLOUDFLARE_MODEL}'
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    payload = {
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': prompt}
        ]
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        print(f'[CLOUDFLARE] Status: {response.status_code}')
        if response.status_code != 200:
            print(f'[CLOUDFLARE] Error: {response.text[:300]}')
        response.raise_for_status()
        data = response.json()
        return data['result']['response']