import asyncio
from dotenv import load_dotenv
load_dotenv()

from llm.gemini import call_gemini
from llm.groq import call_groq, call_groq_gemma
from llm.mistral import call_mistral
from llm.cloudflare import call_cloudflare
from llm.openrouter import call_openrouter

async def test_all():
    print("--- TESTING GEMINI ---")
    try:
        r = await call_gemini("Hello", "You are a helpful assistant.")
        print("GEMINI SUCCESS:", r[:100])
    except Exception as e:
        print("GEMINI ERROR:", e)

    print("\n--- TESTING GROQ ---")
    try:
        r = await call_groq("Hello", "You are a helpful assistant.")
        print("GROQ SUCCESS:", r[:100])
    except Exception as e:
        print("GROQ ERROR:", e)

    print("\n--- TESTING MISTRAL ---")
    try:
        r = await call_mistral("Hello", "You are a helpful assistant.")
        print("MISTRAL SUCCESS:", r[:100])
    except Exception as e:
        print("MISTRAL ERROR:", e)

    print("\n--- TESTING OPENROUTER ---")
    try:
        r = await call_openrouter("Hello", "You are a helpful assistant.")
        print("OPENROUTER SUCCESS:", r[:100])
    except Exception as e:
        print("OPENROUTER ERROR:", e)

    print("\n--- TESTING CLOUDFLARE ---")
    try:
        r = await call_cloudflare("Hello", "You are a helpful assistant.")
        print("CLOUDFLARE SUCCESS:", r[:100])
    except Exception as e:
        print("CLOUDFLARE ERROR:", e)

if __name__ == "__main__":
    asyncio.run(test_all())
