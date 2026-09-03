# Socratiq — Agent Architecture

## How Agents Work
- Each agent = one system prompt + one LLM API call
- No LangChain, no LangGraph — pure FastAPI functions
- Orchestrator is a Python function not an LLM
- All agents are grounded on uploaded content — no hallucination outside PDF

## Orchestrator
- File: backend/orchestrator.py
- Type: FastAPI Python function
- Reads: session mode + current state
- Routes to: correct agent in correct order
- Returns: combined JSON response to Flutter in one payload
- Never calls LLM directly — delegates to agents

## Content Agent
- File: backend/agents/content_agent.py
- Runs: once per PDF — result cached in Hive forever
- Input: raw extracted text from PyMuPDF
- Output: { summary, key_points, topics }
- Primary LLM: Groq Llama 3.3 70B
- Fallback: Gemini → OpenRouter
- System prompt: extract summary (3-5 sentences), key_points (5-10 items), topics (2-5 word strings)
- Returns only valid JSON — no markdown no preamble
- Text trimmed to 80000 chars before sending to Groq

## Tutor Agent
- File: backend/agents/tutor_agent.py
- Role: explains concepts simply and clearly
- Input: topic + content summary + key points + conversation history
- Output: plain text explanation
- Primary LLM: Gemini 2.0 Flash
- Fallback: Groq Llama 3.3 70B → OpenRouter
- Behaviour: friendly, simple language, progressive teaching
- Constraint: must stay grounded in uploaded content only

## MCQ Agent
- File: backend/agents/mcq_agent.py
- Role: generates 4-option multiple choice questions
- Input: topic + key points + difficulty level
- Output: { question, options: [A,B,C,D], correct_index, explanation }
- Primary LLM: Mistral Small
- Fallback: Groq Gemma 2 9B → Cloudflare Llama 3.2
- Returns only valid JSON always
- Questions grounded in content — no outside knowledge

## Evaluation Agent
- File: backend/agents/evaluation_agent.py
- Role: scores user answers 0-10
- Input: question + correct answer + user answer + context
- Output: { score, feedback, correction }
- Primary LLM: Gemini 2.0 Flash
- Fallback: Groq Llama 3.3 70B → OpenRouter
- Score below 6 triggers Reasoning Agent

## Reasoning Agent
- File: backend/agents/reasoning_agent.py
- Role: Socratic follow-up when user score is below 6
- Input: question + user's wrong answer + correct answer
- Output: a single "why" follow-up question to push deeper thinking
- Primary LLM: Groq Gemma 2 9B
- Fallback: Cloudflare Llama 3.2 → OpenRouter
- Constraint: never creates long debates — one follow-up only

## Voice Agent — STT
- File: backend/agents/voice_agent.py
- Role: converts user audio to text
- Input: audio blob (wav/m4a) from Flutter
- Output: transcribed text string
- Primary: Groq Whisper API
- Fallback: Deepgram Nova-2

## Voice Agent — TTS
- File: backend/agents/voice_agent.py (same file)
- Role: converts AI text response to audio
- Input: text string
- Output: audio file (mp3)
- Primary: Deepgram Aura
- Fallback: Google Cloud TTS → gTTS offline

## Session Flow — Learn Mode
1. Orchestrator reads mode = learn
2. Tutor Agent explains current topic
3. MCQ Agent generates one question
4. User answers via voice or tap
5. Evaluation Agent scores
6. If score below 6 → Reasoning Agent asks follow-up
7. Tutor Agent responds to follow-up
8. Next topic or retry same topic

## Session Flow — Revise Mode
1. Skip Tutor Agent explanation
2. MCQ Agent fires immediately
3. User answers
4. Evaluation Agent scores with quick feedback
5. Next question

## Session Flow — Test Mode
1. MCQ Agent generates full set (5-10 questions)
2. No feedback shown during test
3. All answers collected
4. Evaluation Agent scores all at end
5. Result screen shown
