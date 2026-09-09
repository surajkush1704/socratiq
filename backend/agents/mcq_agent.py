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


def _get_mcq_language_rule(
    document_language: str,
    response_language: str,
    mode: str = 'learn',
) -> str:
    if document_language == 'sa':
        # Sanskrit document — MCQs in Sanskrit always
        # regardless of response language
        return """
LANGUAGE RULE (MANDATORY):
- This is a Sanskrit document. Generate the question and ALL four options
  in Sanskrit (Devanagari script) only.
- The question must be grammatically correct Sanskrit.
- The correct_index and explanation can be in Hindi to help the student.
- Format: question and options in Sanskrit, explanation in Hindi.
"""
    elif document_language == 'hi':
        return """
LANGUAGE RULE (MANDATORY):
- This is a Hindi document. Generate question and all options in Hindi.
- explanation also in Hindi.
- Do not use English.
"""
    else:
        return ""  # English default


async def generate_mcq(
    summary: str,
    key_points: List[str],
    current_topic: str,
    previously_asked: List[str] = None,
    difficulty: str = 'medium',
    document_language: str = 'en',
    response_language: str = 'en',
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

    lang_rule = _get_mcq_language_rule(document_language, response_language)
    full_system = (lang_rule + '\n\n' + MCQ_SYSTEM_PROMPT).strip()

    try:
        result = await call_with_fallback(
            agent_type='mcq',
            prompt=prompt,
            system_prompt=full_system
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
        print(f'[MCQ AGENT] Raw was: {result[:50]}...')
        return None
    except Exception as e:
        print(f'[MCQ AGENT] Error: {e}')
        print(traceback.format_exc())
        return None


BATCH_MCQ_SYSTEM_PROMPT = """You are an expert examination and test generator for a tutoring app.
Your job is to generate a comprehensive test with multiple choice questions based on the study material.

OUTPUT FORMAT — return ONLY a valid JSON array of question objects, with NO markdown formatting:
[
  {
    "question": "The question text here?",
    "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
    "correct_index": 0,
    "difficulty": "easy",
    "explanation": "Brief explanation of why the correct answer is right (1-2 sentences)"
  }
]

RULES:
- correct_index is 0-based (0=A, 1=B, 2=C, 3=D)
- Exactly 4 plausible options per question
- Every question must test real understanding of the provided study material
- Distribute difficulties strictly as requested (easy, medium, hard)
- Easy questions test core definitions and fundamental facts
- Medium questions test comprehension and application of principles
- Hard questions test deep synthesis, analysis, edge cases, or multi-step reasoning
- Return ONLY valid JSON array. No markdown code blocks, no preamble."""


async def generate_test_set(
    summary: str,
    key_points: List[str],
    topics: List[str],
    count: int = 15,
    difficulty_spread: bool = True,
    document_language: str = 'en',
    response_language: str = 'en',
) -> List[dict]:
    """
    Generates a full set of MCQ questions for test mode.
    For 15 questions: generates 5 easy, 5 medium, 5 hard questions.
    For other counts: splits into balanced thirds.
    First attempts high-speed batch generation, then falls back to individual generation.
    """
    # Calculate difficulty distribution
    if count == 15:
        easy_count, med_count, hard_count = 5, 5, 5
    elif count >= 3:
        easy_count = count // 3
        med_count = count // 3
        hard_count = count - (easy_count + med_count)
    else:
        easy_count, med_count, hard_count = 0, count, 0

    topics_text = ', '.join(topics) if topics else 'All covered topics'
    key_points_text = '\n'.join(f'- {kp}' for kp in key_points[:12])

    batch_prompt = f"""STUDY MATERIAL SUMMARY:
{summary}

KEY POINTS:
{key_points_text}

TOPICS:
{topics_text}

TASK:
Generate exactly {count} multiple choice questions:
- {easy_count} Easy questions (fundamental definitions, core facts)
- {med_count} Medium questions (application, conceptual understanding)
- {hard_count} Hard questions (complex deduction, tricky distinction, synthesis)

Cover all topics evenly.
Return ONLY a JSON array of {count} objects matching the format."""

    lang_rule = _get_mcq_language_rule(document_language, response_language, mode='test')
    full_batch_system = (lang_rule + '\n\n' + BATCH_MCQ_SYSTEM_PROMPT).strip()

    try:
        print(f'[MCQ AGENT] Generating test set of {count} questions ({easy_count}E / {med_count}M / {hard_count}H)...')
        result = await call_with_fallback(
            agent_type='mcq',
            prompt=batch_prompt,
            system_prompt=full_batch_system
        )

        cleaned = result.strip()
        if cleaned.startswith('```json'):
            cleaned = cleaned[7:]
        if cleaned.startswith('```'):
            cleaned = cleaned[3:]
        if cleaned.endswith('```'):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        if isinstance(parsed, list) and len(parsed) > 0:
            valid_questions = []
            for item in parsed:
                if (
                    isinstance(item, dict) and
                    'question' in item and
                    'options' in item and
                    isinstance(item['options'], list) and
                    len(item['options']) == 4 and
                    'correct_index' in item and
                    isinstance(item['correct_index'], int) and
                    0 <= item['correct_index'] <= 3
                ):
                    valid_questions.append({
                        'question': str(item['question']),
                        'options': [str(opt) for opt in item['options']],
                        'correct_index': int(item['correct_index']),
                        'difficulty': str(item.get('difficulty', 'medium')).lower(),
                        'explanation': str(item.get('explanation', '')),
                    })

            if len(valid_questions) >= min(count, 5):
                print(f'[MCQ AGENT] Batch generation succeeded with {len(valid_questions)} valid questions')
                return valid_questions[:count]

    except Exception as e:
        print(f'[MCQ AGENT] Batch test generation error: {e}, falling back to slot generation')

    # Fallback: sequential / slot generation
    questions = []
    asked = []
    difficulties = (['easy'] * easy_count) + (['medium'] * med_count) + (['hard'] * hard_count)
    if not difficulties:
        difficulties = ['medium'] * count

    for i in range(count):
        topic = topics[i % len(topics)] if topics else 'general'
        diff = difficulties[i % len(difficulties)] if difficulty_spread else 'medium'

        q = None
        for attempt in range(2):
            q = await generate_mcq(
                summary=summary,
                key_points=key_points,
                current_topic=topic,
                previously_asked=asked,
                difficulty=diff,
                document_language=document_language,
                response_language=response_language,
            )
            if q:
                break
            print(f'[MCQ AGENT] Retry {attempt+1} for question {i+1}')

        if q:
            q['difficulty'] = diff
            questions.append(q)
            asked.append(q['question'])
            print(f'[MCQ AGENT] Q{i+1}/{count} generated: {topic} [{diff}]')
        else:
            print(f'[MCQ AGENT] Failed to generate Q{i+1} after retries')

    print(f'[MCQ AGENT] Test set complete: {len(questions)}/{count} questions')
    return questions