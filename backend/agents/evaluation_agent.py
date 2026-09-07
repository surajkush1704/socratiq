import json
import traceback
from llm.router import call_with_fallback
from typing import Optional, List

EVAL_SYSTEM_PROMPT = """You are an expert answer evaluator for a tutoring app.

Your job is to evaluate a student's answer against the correct answer
and the study material context.

OUTPUT FORMAT — return ONLY this JSON, nothing else, no markdown:
{
  "score": 8.5,
  "feedback": "Brief encouraging feedback message (1-2 sentences)",
  "correction": "What was missing or wrong, if anything (1 sentence, empty string if perfect)",
  "trigger_reasoning": false
}

RULES:
- score: float from 0.0 to 10.0
  - 9-10: Excellent — fully correct and well explained
  - 7-8: Good — mostly correct, minor gaps
  - 5-6: Partial — some understanding shown but key points missed
  - 3-4: Poor — mostly wrong but shows some effort
  - 0-2: Incorrect — fundamentally wrong
- trigger_reasoning: set to true if score is below 6.0 (needs Socratic follow-up)
- feedback: always encouraging, never harsh or condescending
- correction: empty string if score >= 8, otherwise explain what was missed
- For MCQ answers: score is either 10.0 (correct) or 0.0 (wrong)
- Do NOT output markdown. Pure JSON only."""


async def evaluate_answer(
    question: str,
    correct_answer: str,
    user_answer: str,
    context_summary: str,
    is_mcq: bool = False,
    selected_option: Optional[str] = None,
) -> dict:
    if is_mcq:
        # MCQ evaluation is deterministic — no LLM needed
        is_correct = user_answer.strip().lower() == correct_answer.strip().lower()
        score = 10.0 if is_correct else 0.0
        feedback = (
            'Correct! Well done.' if is_correct
            else f'Not quite. The correct answer is: {correct_answer}'
        )
        return {
            'score': score,
            'feedback': feedback,
            'correction': '' if is_correct else f'The correct answer was: {correct_answer}',
            'trigger_reasoning': not is_correct
        }

    prompt = f"""STUDY MATERIAL CONTEXT:
{context_summary}

QUESTION ASKED:
{question}

CORRECT ANSWER (reference):
{correct_answer}

STUDENT'S ANSWER:
{user_answer}

Evaluate the student's answer and return JSON:"""

    try:
        result = await call_with_fallback(
            agent_type='evaluation',
            prompt=prompt,
            system_prompt=EVAL_SYSTEM_PROMPT
        )

        print(f'[EVAL AGENT] Raw: {result[:50]}...')

        cleaned = result.strip()
        if cleaned.startswith('```json'):
            cleaned = cleaned[7:]
        if cleaned.startswith('```'):
            cleaned = cleaned[3:]
        if cleaned.endswith('```'):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Validate and clamp score
        score = float(parsed.get('score', 5.0))
        score = max(0.0, min(10.0, score))
        parsed['score'] = score
        parsed['trigger_reasoning'] = score < 6.0

        if 'feedback' not in parsed:
            parsed['feedback'] = 'Keep going!'
        if 'correction' not in parsed:
            parsed['correction'] = ''

        print(f'[EVAL AGENT] Score: {score}, Trigger reasoning: {parsed["trigger_reasoning"]}')
        return parsed

    except Exception as e:
        print(f'[EVAL AGENT] Error: {e}')
        print(traceback.format_exc())
        return {
            'score': 5.0,
            'feedback': 'Answer received. Keep going!',
            'correction': '',
            'trigger_reasoning': False
        }


async def get_reasoning_followup(
    question: str,
    user_wrong_answer: str,
    correct_answer: str,
    context_summary: str,
) -> str:
    REASONING_SYSTEM = """You are a Socratic tutor.
The student answered a question incorrectly.
Ask ONE short follow-up question that guides them to discover
the correct answer themselves — do not give the answer.
Keep it to one sentence. Be warm and encouraging.
Output plain text only — no JSON, no markdown."""

    prompt = f"""Original question: {question}
Student's wrong answer: {user_wrong_answer}
Correct answer: {correct_answer}
Context: {context_summary}

Ask a guiding follow-up question:"""

    try:
        return await call_with_fallback(
            agent_type='reasoning',
            prompt=prompt,
            system_prompt=REASONING_SYSTEM
        )
    except Exception as e:
        print(f'[REASONING] Error: {e}')
        return 'Let\'s think about this differently — what do you remember about this concept?'