import asyncio
import os
import httpx
from dotenv import load_dotenv
load_dotenv()

async def test_groq_gemini():
    api_key_groq = os.getenv('GROQ_API_KEY')
    api_key_gemini = os.getenv('GEMINI_API_KEY')

    async with httpx.AsyncClient() as client:
        # Groq tests
        for model in ['llama3-8b-8192', 'llama-3.1-8b-instant', 'gemma2-9b-it', 'mixtral-8x7b-32768']:
            rg = await client.post(
                'https://api.groq.com/openai/v1/chat/completions',
                headers={'Authorization': f'Bearer {api_key_groq}'},
                json={
                    'model': model,
                    'messages': [{'role': 'user', 'content': 'Hello'}],
                    'max_tokens': 50
                }
            )
            print(f"Groq {model}:", rg.status_code, rg.text[:100] if rg.status_code != 200 else "OK")

        # Gemini model list check
        r_list = await client.get(f'https://generativelanguage.googleapis.com/v1beta/models?key={api_key_gemini}')
        if r_list.status_code == 200:
            models = [m['name'] for m in r_list.json().get('models', []) if 'generateContent' in m.get('supportedGenerationMethods', [])]
            print("Gemini Available Models:", models[:5])
        else:
            print("Gemini List status:", r_list.status_code, r_list.text[:150])

if __name__ == "__main__":
    asyncio.run(test_groq_gemini())
