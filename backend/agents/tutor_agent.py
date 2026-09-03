from llm.router import call_with_fallback
from typing import List, Dict

TUTOR_SYSTEM_PROMPT = """You are SocratiQ — a warm, human, encouraging personal AI tutor.
You are talking directly to your student 1-on-1 like a supportive friend and mentor.

RULES:
- Teach content ONLY from the provided study material.
- Keep explanations concise, natural, and conversational — 2-3 sentences maximum.
- Speak in warm, simple, human language. Avoid robotic textbook phrasing.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Output clean plain text only so it sounds natural when spoken aloud.
- After explaining a concept, end with ONE friendly question to check understanding.
- If the student is stuck, offer a gentle breakdown with encouragement.
- Keep responses under 80 words."""

TUTOR_CONTEXTUAL_PROMPTS = {
    'explain_differently': 'The student asked you to explain this differently. '
                           'Use an analogy or a completely different approach.',
    'give_example': 'The student wants a concrete real-world example of this concept.',
    'go_deeper': 'The student wants to go deeper. Expand on the concept with '
                 'more detail while staying within the study material.',
}


async def get_tutor_response(
    mode: str,
    summary: str,
    key_points: List[str],
    topics: List[str],
    current_topic: str,
    history: List[Dict[str, str]],
    user_input: str,
    contextual_type: str = None,
) -> str:
    key_points_text = '\n'.join(f'- {kp}' for kp in key_points[:8])
    topics_text = ', '.join(topics)

    history_text = ''
    for msg in history[-6:]:  # last 6 messages only — context window control
        role = 'Student' if msg['role'] == 'user' else 'Tutor'
        history_text += f'{role}: {msg["content"]}\n'

    contextual_note = ''
    if contextual_type and contextual_type in TUTOR_CONTEXTUAL_PROMPTS:
        contextual_note = f'\n\nSPECIAL INSTRUCTION: {TUTOR_CONTEXTUAL_PROMPTS[contextual_type]}'

    mode_instruction = (
        'You are in LEARN mode. Explain the current concept clearly '
        'in 2-3 sentences, then ask ONE question to check understanding.'
        if mode == 'learn'
        else 'You are in REVISE mode. Skip the explanation. '
             'Ask a focused question about the current topic directly.'
    )

    prompt = f"""STUDY MATERIAL SUMMARY:
{summary}

KEY POINTS:
{key_points_text}

TOPICS IN THIS DOCUMENT: {topics_text}
CURRENT TOPIC: {current_topic}

MODE: {mode_instruction}

CONVERSATION HISTORY:
{history_text}
Student: {user_input}

{contextual_note}

Respond as the Tutor:"""

    return await call_with_fallback(
        agent_type='tutor',
        prompt=prompt,
        system_prompt=TUTOR_SYSTEM_PROMPT
    )


async def get_opening_message(
    mode: str,
    document_name: str,
    summary: str,
    topics: List[str],
) -> str:
    topics_text = ', '.join(topics[:5])
    mode_instruction = (
        'In Learn mode: greet warmly, briefly say what you will teach, '
        'then start with the first concept.'
        if mode == 'learn'
        else 'In Revise mode: greet briefly and jump straight into '
             'the first revision question without any preamble.'
        if mode == 'revise'
        else 'In Test mode: tell the student the test is about to begin '
             'and that you will ask questions without hints.'
    )

    prompt = f"""Document: {document_name}
Summary: {summary}
Topics: {topics_text}

{mode_instruction}

Write the opening message (under 60 words):"""

    system = (
        'You are SocratiQ, an AI tutor. Write a warm, concise opening '
        'message for a tutoring session. Keep it under 60 words. '
        'Do not use markdown. Output plain conversational text only.'
    )

    return await call_with_fallback(
        agent_type='tutor',
        prompt=prompt,
        system_prompt=system
    )