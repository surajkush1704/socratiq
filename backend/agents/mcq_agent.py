import json
import traceback
from llm.router import call_with_fallback
from typing import List, Optional

MCQ_SYSTEM_PROMPT = """You are an expert question generator for a tutoring app.

Your job is to generate exactly ONE multiple choice question based on the
provided study material. The question must test real understanding, not
just memory.

OUTPUT FORMAT — return ONLY this JSON, nothing else, no markdown:
{
  "question": "The question text here?",
  "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
  "correct_index": 0,
  "explanation": "Brief explanation of why the correct answer is right (1-2 sentences)"
}

RULES:
- correct_index is 0-based (0=A, 1=B, 2=C, 3=D)
- All 4 options must be plausible — no obviously wrong distractors
- Question must be answerable from the study material provided
- Do NOT repeat questions already asked (check history)
- Difficulty level: medium — tests conceptual understanding not trivia
- No markdown. No code blocks. Pure JSON only."""


async def generate_mcq(
    summary: str,
    key_points: List[str],
    current_topic: str,
    previously_asked: List[str] = None,
    difficulty: str = 'medium'
) -> Optional[dict]:
    key_points_text = '\n'.join(f'- {kp}' for kp in key_points[:8])
    asked_text = ''
    if previously_asked:
        asked_text = '\n\nDO NOT repeat these questions:\n' + \
                     '\n'.join(f'- {q}' for q in previously_asked[-5:])

    prompt = f"""STUDY MATERIAL SUMMARY:
{summary}

KEY POINTS:
{key_points_text}

CURRENT TOPIC TO TEST: {current_topic}
DIFFICULTY: {difficulty}
{asked_text}

Generate ONE multiple choice question as JSON:"""

    try:
        result = await call_with_fallback(
            agent_type='mcq',
            prompt=prompt,
            system_prompt=MCQ_SYSTEM_PROMPT
        )

        print(f'[MCQ AGENT] Raw response: {result[:300]}')

        # Clean and parse JSON
        cleaned = result.strip()
        if cleaned.startswith('```json'):
            cleaned = cleaned[7:]
        if cleaned.startswith('```'):
            cleaned = cleaned[3:]
        if cleaned.endswith('```'):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Validate structure
        assert 'question' in parsed
        assert 'options' in parsed
        assert len(parsed['options']) == 4
        assert 'correct_index' in parsed
        assert 0 <= parsed['correct_index'] <= 3

        print(f'[MCQ AGENT] Generated: {parsed["question"][:80]}...')
        return parsed

    except json.JSONDecodeError as e:
        print(f'[MCQ AGENT] JSON parse error: {e}')
        print(f'[MCQ AGENT] Raw was: {result}')
        return None
    except Exception as e:
        print(f'[MCQ AGENT] Error: {e}')
        print(traceback.format_exc())
        return None


async def generate_test_set(
    summary: str,
    key_points: List[str],
    topics: List[str],
    count: int = 5,
    difficulty_spread: bool = True,
) -> List[dict]:
    """
    Generates a full set of MCQ questions for test mode.
    Spreads questions across topics evenly.
    Uses easy/medium/hard difficulty spread if enabled.
    Retries failed generations up to 2 times per slot.
    """
    questions = []
    asked = []
    difficulties = ['easy', 'medium', 'hard', 'medium', 'medium']

    for i in range(count):
        # Spread across topics cyclically
        topic = topics[i % len(topics)] if topics else 'general'
        difficulty = difficulties[i % len(difficulties)] if difficulty_spread else 'medium'

        # Try up to 2 times per slot
        q = None
        for attempt in range(2):
            q = await generate_mcq(
                summary=summary,
                key_points=key_points,
                current_topic=topic,
                previously_asked=asked,
                difficulty=difficulty,
            )
            if q:
                break
            print(f'[MCQ AGENT] Retry {attempt+1} for question {i+1}')

        if q:
            questions.append(q)
            asked.append(q['question'])
            print(f'[MCQ AGENT] Q{i+1}/{count} generated: {topic} [{difficulty}]')
        else:
            print(f'[MCQ AGENT] Failed to generate Q{i+1} after retries')

    print(f'[MCQ AGENT] Test set complete: {len(questions)}/{count} questions')
    return questions