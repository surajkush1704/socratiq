import traceback
from llm.router import call_with_fallback
from typing import List, Optional

# ── SYSTEM PROMPTS ────────────────────────────────────────────────────────────

SOCRATIC_SYSTEM = """You are SocratiQ — a warm, friendly Socratic AI tutor.
The student answered a question incorrectly or incompletely.
Your job is to guide them gently to discover the answer themselves — never give the answer directly.

RULES:
- Ask ONE short guiding question only.
- Be warm, encouraging, and natural — speak like a friend in person.
- Keep your response under 30 words.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Start with a gentle, friendly acknowledgement then ask the guiding question.
- Output clean plain spoken text only."""

HINT_SYSTEM = """You are SocratiQ — a patient, supportive AI tutor.
The student has answered incorrectly twice. Give a friendly, helpful hint.

RULES:
- Give a concrete partial hint that narrows down the answer.
- Follow with ONE short question to confirm understanding.
- Keep it under 40 words.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Be warm and encouraging. Output clean plain spoken text only."""

REVEAL_SYSTEM = """You are SocratiQ — a compassionate AI tutor.
Explain the correct answer clearly in simple terms and move forward.

RULES:
- Explain why the correct answer is correct in 2-3 simple sentences.
- End with a friendly, encouraging remark.
- Keep it under 60 words.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Output clean plain spoken text only."""

DEEPEN_SYSTEM = """You are SocratiQ — an encouraging AI tutor.
The student answered correctly! Praise them and gently explore further.

RULES:
- Acknowledge their correct answer warmly.
- Ask ONE friendly follow-up question that explores why it works.
- Keep it under 35 words.
- CRITICAL: Do NOT use any markdown formatting (no asterisks **, no headers #, no bullet points -).
- Output clean plain spoken text only."""


# ── REASONING DEPTH TRACKER ───────────────────────────────────────────────────

class ReasoningTracker:
    """
    Tracks how many times a student has struggled with the same
    concept in a session. Decides which strategy to use:
    - attempt 1: Socratic guiding question
    - attempt 2: Stronger hint + question
    - attempt 3+: Reveal answer + move on
    """
    def __init__(self):
        # Maps question_text → attempt count
        self._attempts: dict[str, int] = {}

    def record_struggle(self, question: str) -> int:
        """Increment and return attempt count for this question"""
        key = question[:80]  # use first 80 chars as key
        self._attempts[key] = self._attempts.get(key, 0) + 1
        return self._attempts[key]

    def get_attempt_count(self, question: str) -> int:
        key = question[:80]
        return self._attempts.get(key, 0)

    def reset_question(self, question: str):
        key = question[:80]
        self._attempts.pop(key, None)


# ── REASONING RESPONSES ───────────────────────────────────────────────────────

async def get_socratic_followup(
    question: str,
    user_wrong_answer: str,
    correct_answer: str,
    context_summary: str,
    attempt_number: int = 1,
) -> str:
    """
    Returns a Socratic follow-up response based on how many
    times the student has struggled with this question.

    attempt_number=1 → gentle guiding question
    attempt_number=2 → stronger hint + question
    attempt_number=3+ → reveal answer + encouragement
    """
    print(f'[REASONING] Socratic followup, attempt #{attempt_number}')
    print(f'[REASONING] Q: {question[:50]}...')
    print(f'[REASONING] Wrong answer: {user_wrong_answer[:50]}')

    if attempt_number >= 3:
        return await _reveal_answer(
            question=question,
            correct_answer=correct_answer,
            context_summary=context_summary,
        )
    elif attempt_number == 2:
        return await _give_hint(
            question=question,
            user_wrong_answer=user_wrong_answer,
            correct_answer=correct_answer,
            context_summary=context_summary,
        )
    else:
        return await _socratic_question(
            question=question,
            user_wrong_answer=user_wrong_answer,
            correct_answer=correct_answer,
            context_summary=context_summary,
        )


async def _socratic_question(
    question: str,
    user_wrong_answer: str,
    correct_answer: str,
    context_summary: str,
) -> str:
    """Attempt 1 — gentle guiding question, no hint"""
    prompt = f"""Context from study material:
{context_summary[:600]}

Original question: {question}
Student's answer: {user_wrong_answer}
Correct answer (do NOT reveal): {correct_answer}

Write a gentle guiding question that leads the student
toward the correct reasoning without giving the answer:"""

    try:
        result = await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=SOCRATIC_SYSTEM,
        )
        print(f'[REASONING] Socratic response: {result[:50]}...')
        return result.strip()
    except Exception as e:
        print(f'[REASONING] Socratic question failed: {e}')
        return (
            "Let's think about this step by step — "
            "what do you remember from the material about this concept?"
        )


async def _give_hint(
    question: str,
    user_wrong_answer: str,
    correct_answer: str,
    context_summary: str,
) -> str:
    """Attempt 2 — more direct hint, closer to the answer"""
    prompt = f"""Context: {context_summary[:600]}

Question: {question}
Student's wrong answer (twice): {user_wrong_answer}
Correct answer (reveal partially, not fully): {correct_answer}

Give a partial hint that narrows things down significantly,
followed by one short question:"""

    try:
        result = await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=HINT_SYSTEM,
        )
        print(f'[REASONING] Hint response: {result[:50]}...')
        return result.strip()
    except Exception as e:
        print(f'[REASONING] Hint failed: {e}')
        return (
            f"Here is a clue: think about the relationship between "
            f"the key concepts in this topic. "
            f"Does that help you reconsider?"
        )


async def _reveal_answer(
    question: str,
    correct_answer: str,
    context_summary: str,
) -> str:
    """Attempt 3+ — reveal the answer with explanation"""
    prompt = f"""Context: {context_summary[:600]}

Question: {question}
Correct answer: {correct_answer}

Explain why this is correct in 2-3 sentences, then add
an encouraging closing statement:"""

    try:
        result = await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=REVEAL_SYSTEM,
        )
        print(f'[REASONING] Reveal response: {result[:50]}...')
        return result.strip()
    except Exception as e:
        print(f'[REASONING] Reveal failed: {e}')
        return (
            f"The correct answer is: {correct_answer}. "
            f"This concept takes time to fully absorb — "
            f"the fact that you kept trying shows real dedication. "
            f"Let's move on and come back to this later."
        )


async def get_deepening_question(
    question: str,
    correct_answer: str,
    user_correct_answer: str,
    context_summary: str,
) -> Optional[str]:
    """
    For students who answered correctly but shallowly.
    Returns a deeper follow-up question to push further thinking.
    Only fires occasionally — not after every correct answer.
    """
    prompt = f"""Context: {context_summary[:400]}

Question: {question}
Student's correct answer: {user_correct_answer}

Ask a probing follow-up that explores the WHY or edge cases:"""

    try:
        result = await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=DEEPEN_SYSTEM,
        )
        print(f'[REASONING] Deepening question: {result[:50]}...')
        return result.strip()
    except Exception as e:
        print(f'[REASONING] Deepening question failed: {e}')
        return None


async def get_encouragement(
    score: float,
    questions_attempted: int,
    document_name: str,
) -> str:
    """
    Short motivational message at key moments:
    - After first question answered
    - After 5 questions completed
    - When student has struggled 3+ times in a row
    """
    ENCOURAGE_SYSTEM = """You are SocratiQ, an encouraging AI tutor.
    Write a short (max 20 words) motivational message for the student.
    Be genuine and specific — not generic or cheesy.
    Output plain text only."""

    context = (
        f"Student has attempted {questions_attempted} questions "
        f"on '{document_name}' with score {score:.1f}/10."
    )

    if score >= 8:
        prompt = f"{context} They are doing excellently. Acknowledge their mastery."
    elif score >= 6:
        prompt = f"{context} They are making good progress. Encourage continued effort."
    else:
        prompt = f"{context} They are struggling. Offer compassionate encouragement."

    try:
        result = await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=ENCOURAGE_SYSTEM,
        )
        return result.strip()
    except Exception:
        if score >= 8:
            return "Outstanding work! You clearly understand this material."
        elif score >= 6:
            return "Good progress — keep going, you're building strong understanding."
        else:
            return "Every question is helping you learn — keep at it!"