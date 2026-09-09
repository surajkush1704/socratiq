from llm.router import call_with_fallback
from typing import List, Dict

TUTOR_SYSTEM_PROMPT = """You are SocratiQ — a warm, human, encouraging personal AI tutor.
You are talking directly to your student 1-on-1 like a supportive friend and mentor.

RULES:
- Teach content ONLY from the provided study material.
- Provide thorough, clear, and engaging explanations (typically 1-2 rich, well-explained paragraphs). Never cut off after just a single short line.
- Use concrete analogies, real-world examples, and step-by-step logic so the concept clicks.
- Speak in warm, conversational, human language. Avoid dry textbook jargon.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Output clean plain text only so it sounds natural when spoken aloud.
- End with ONE thoughtful, open-ended question that encourages the student to reflect or test their understanding.
- If the student is stuck, break the concept down patiently and encourage them."""

TUTOR_CONTEXTUAL_PROMPTS = {
    'explain_differently': 'The student asked you to explain this differently. '
                           'Use an analogy or a completely different approach.',
    'give_example': 'The student wants a concrete real-world example of this concept.',
    'go_deeper': 'The student wants to go deeper. Expand on the concept with '
                 'more detail while staying within the study material.',
}


def _get_language_instruction(
    document_language: str,
    response_language: str,
) -> str:
    if document_language == 'sa' or response_language in ('sa', 'hi'):
        return """
LANGUAGE INSTRUCTIONS (MANDATORY & STRICT):
- The study material is in Sanskrit (संस्कृत) or Hindi (हिंदी).
- You MUST explain and respond entirely in Hindi (हिंदी).
- When citing original Sanskrit sutras, shlokas, or terms, quote the Sanskrit phrase directly, then explain its meaning, breakdown, and practical significance thoroughly in Hindi.
- Example: "यदा यदा हि धर्मस्य... — इसका अर्थ है कि जब-जब धर्म की हानि होती है..."
- Under NO circumstances respond in English. Do not use English words.
- All explanations, analogies, questions, and feedback must be in pure, easy-to-understand Hindi.
"""
    elif response_language == 'hi':
        return """
LANGUAGE INSTRUCTIONS (MANDATORY):
- The study document is in Hindi (हिंदी).
- You MUST respond entirely in Hindi.
- All explanations, questions, and feedback in Hindi only.
- Do not use English except for technical terms that have no Hindi equivalent.
"""
    elif response_language == 'en':
        return ""  # no instruction needed — English is default
    else:
        return f"""
LANGUAGE INSTRUCTIONS (MANDATORY):
- Respond in the same language as the document ({response_language}).
- All explanations and questions must be in that language.
- Do not switch to English.
"""


async def get_tutor_response(
    mode: str,
    summary: str,
    key_points: List[str],
    topics: List[str],
    current_topic: str,
    history: List[Dict[str, str]],
    user_input: str,
    contextual_type: str = None,
    document_language: str = 'en',
    response_language: str = 'en',
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
        'You are in LEARN mode. Explain the current concept thoroughly and clearly '
        'with intuitive analogies and examples, then ask ONE question to check understanding.'
        if mode == 'learn'
        else 'You are in REVISE mode. Provide a quick summary of the concept, '
             'then ask a focused question to test the student.'
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

    lang_instruction = _get_language_instruction(
        document_language, response_language
    )
    full_system = (lang_instruction + '\n\n' + TUTOR_SYSTEM_PROMPT).strip()

    return await call_with_fallback(
        agent_type='tutor',
        prompt=prompt,
        system_prompt=full_system
    )


async def get_opening_message(
    mode: str,
    document_name: str,
    summary: str,
    topics: List[str],
    document_language: str = 'en',
    response_language: str = 'en',
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

Write the opening message:"""

    base_system = (
        'You are SocratiQ, an AI tutor. Write a warm, engaging opening '
        'message for a tutoring session introducing what you will explore together. '
        'Do not use markdown. Output plain conversational text only.'
    )
    lang_instruction = _get_language_instruction(
        document_language, response_language
    )
    full_system = (lang_instruction + '\n\n' + base_system).strip()

    return await call_with_fallback(
        agent_type='tutor',
        prompt=prompt,
        system_prompt=full_system
    )