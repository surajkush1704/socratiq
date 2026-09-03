import asyncio
import os
import httpx
from dotenv import load_dotenv
load_dotenv()

async def test_models():
    api_key_gemini = os.getenv('GEMINI_API_KEY')
    api_key_groq = os.getenv('GROQ_API_KEY')
    api_key_openrouter = os.getenv('OPENROUTER_API_KEY')

    async with httpx.AsyncClient() as client:
        # Test Gemini gemini-1.5-flash
        r = await client.post(
            f'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key_gemini}',
            json={'contents': [{'role': 'user', 'parts': [{'text': 'hi'}]}]}
        )
        print("Gemini 1.5-flash status:", r.status_code)

        # Test Groq llama-3.1-8b-instant / llama3-8b-8192 / llama-3.3-70b-versatile
        for model in ['llama-3.1-8b-instant', 'llama-3.3-70b-versatile', 'llama3-8b-8192', 'gemma2-9b-it']:
            rg = await client.post(
                'https://api.groq.com/openai/v1/chat/completions',
                headers={'Authorization': f'Bearer {api_key_groq}'},
                json={'model': model, 'messages': [{'role': 'user', 'content': 'hi'}]}
            )
            print(f"Groq {model} status:", rg.status_code)

        # Test OpenRouter free models
        for om in ['meta-llama/llama-3.1-8b-instruct:free', 'google/gemini-2.0-flash-exp:free', 'mistralai/mistral-7b-instruct:free', 'qwen/qwen-2.5-7b-instruct:free']:
            ro = await client.post(
                'https://openrouter.ai/api/v1/chat/completions',
                headers={'Authorization': f'Bearer {api_key_openrouter}'},
                json={'model': om, 'messages': [{'role': 'user', 'content': 'hi'}]}
            )
            print(f"OpenRouter {om} status:", ro.status_code)

if __name__ == "__main__":
    asyncio.run(test_models())
