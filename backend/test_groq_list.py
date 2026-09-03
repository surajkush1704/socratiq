import asyncio
import os
import httpx
from dotenv import load_dotenv
load_dotenv()

async def list_groq():
    api_key_groq = os.getenv('GROQ_API_KEY')
    async with httpx.AsyncClient() as client:
        rg = await client.get(
            'https://api.groq.com/openai/v1/models',
            headers={'Authorization': f'Bearer {api_key_groq}'}
        )
        print("Groq models:", [m['id'] for m in rg.json().get('data', [])])

if __name__ == "__main__":
    asyncio.run(list_groq())
