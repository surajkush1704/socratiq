import asyncio
import os
import httpx
from dotenv import load_dotenv
load_dotenv()

async def test_live():
    # 1. Gemini gemini-2.5-flash
    api_key = os.getenv('GEMINI_API_KEY')
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            f'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}',
            json={
                'contents': [{'role': 'user', 'parts': [{'text': 'Say hello in 5 words'}]}]
            }
        )
        print("1. Gemini gemini-2.5-flash status:", r.status_code)

        # 2. Groq groq/compound
        g_key = os.getenv('GROQ_API_KEY')
        rg = await client.post(
            'https://api.groq.com/openai/v1/chat/completions',
            headers={'Authorization': f'Bearer {g_key}'},
            json={
                'model': 'groq/compound',
                'messages': [{'role': 'user', 'content': 'Say hello in 5 words'}],
                'max_tokens': 50
            }
        )
        print("2. Groq groq/compound status:", rg.status_code)

        # 3. Mistral mistral-small-latest
        m_key = os.getenv('MISTRAL_API_KEY')
        rm = await client.post(
            'https://api.mistral.ai/v1/chat/completions',
            headers={'Authorization': f'Bearer {m_key}'},
            json={
                'model': 'mistral-small-latest',
                'messages': [{'role': 'user', 'content': 'Say hello in 5 words'}]
            }
        )
        print("3. Mistral mistral-small-latest status:", rm.status_code)

        # 4. Cloudflare @cf/meta/llama-3.2-3b-instruct
        cf_token = os.getenv('CLOUDFLARE_API_TOKEN')
        cf_acc = os.getenv('CLOUDFLARE_ACCOUNT_ID')
        url = f'https://api.cloudflare.com/client/v4/accounts/{cf_acc}/ai/run/@cf/meta/llama-3.2-3b-instruct'
        rcf = await client.post(url, headers={'Authorization': f'Bearer {cf_token}'}, json={'messages': [{'role': 'user', 'content': 'Say hello in 5 words'}]})
        print("4. Cloudflare status:", rcf.status_code)

if __name__ == "__main__":
    asyncio.run(test_live())
