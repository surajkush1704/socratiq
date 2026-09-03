import traceback
from typing import Callable, List, Tuple
from llm.gemini import call_gemini
from llm.groq import call_groq, call_groq_gemma
from llm.mistral import call_mistral
from llm.cloudflare import call_cloudflare
from llm.openrouter import call_openrouter


# Chain definitions — ordered list of (name, callable) per agent type
CHAINS = {
    'tutor': [
        ('gemini', call_gemini),
        ('groq_llama', call_groq),
        ('openrouter', call_openrouter),
    ],
    'mcq': [
        ('mistral', call_mistral),
        ('groq_gemma', call_groq_gemma),
        ('cloudflare', call_cloudflare),
        ('openrouter', call_openrouter),
    ],
    'evaluation': [
        ('gemini', call_gemini),
        ('groq_llama', call_groq),
        ('openrouter', call_openrouter),
    ],
    'reasoning': [
        ('groq_gemma', call_groq_gemma),
        ('cloudflare', call_cloudflare),
        ('openrouter', call_openrouter),
    ],
    'content': [
        ('groq_llama', call_groq),
        ('gemini', call_gemini),
        ('openrouter', call_openrouter),
    ],
}


async def call_with_fallback(
    agent_type: str,
    prompt: str,
    system_prompt: str
) -> str:
    chain = CHAINS.get(agent_type)
    if not chain:
        raise ValueError(f'Unknown agent type: {agent_type}')

    last_error = None
    for name, fn in chain:
        try:
            print(f'[LLM ROUTER] Agent={agent_type} trying {name}...')
            result = await fn(prompt=prompt, system_prompt=system_prompt)
            print(f'[LLM ROUTER] {name} succeeded for {agent_type}')
            return result
        except Exception as e:
            print(f'[LLM ROUTER] {name} failed for {agent_type}: {e}')
            last_error = e
            continue

    raise Exception(
        f'All LLMs failed for agent {agent_type}. '
        f'Last error: {last_error}'
    )


# Backward compatibility helper for content agent
async def call_llm(prompt: str, system_prompt: str) -> str:
    return await call_with_fallback('content', prompt=prompt, system_prompt=system_prompt)