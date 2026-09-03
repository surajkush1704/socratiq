# Socratiq — Tech Stack

## Frontend
- Framework: Flutter (Android first)
- Language: Dart
- State management: setState for Phase 1-2, Provider from Phase 3+
- Local storage: Hive
- HTTP client: Dio
- Auth: Firebase Auth + Google Sign In
- Cloud DB: Firestore
- File picker: file_picker package
- Audio record: record package
- Audio playback: audioplayers package
- Fonts: Poppins via google_fonts package

## Backend
- Framework: FastAPI (Python)
- Server: Uvicorn
- Containerisation: Docker
- PDF extraction: PyMuPDF (fitz)
- Firebase admin: firebase-admin Python SDK
- HTTP client: httpx (async)
- Environment: python-dotenv

## Hosting
- MVP: Railway (Docker deploy)
- Long term: Oracle Cloud Always Free (4 OCPUs, 24GB RAM)
- Current dev: Local laptop on WiFi — `http://LOCAL_IP:8000`
- Backend must always start with `--host 0.0.0.0` for device access

## LLMs
- Gemini 2.0 Flash — Google AI Studio — Tutor + Evaluation Agent
- Groq Llama 3.3 70B — Groq Console — Content Agent primary + rotation backup
- Groq Gemma 2 9B — same Groq key — Reasoning primary + MCQ backup
- Mistral Small — Mistral Console — MCQ Agent primary
- Cloudflare Workers AI Llama 3.2 3B — Reasoning backup + overflow
- OpenRouter free models — full fallback pool, never hard blocks

## Speech
- STT Primary: Groq Whisper (same Groq key, 14400 req/day)
- STT Backup: Deepgram Nova-2 ($200 free credits)
- TTS Primary: Deepgram Aura (same $200 credit pool)
- TTS Backup: Google Cloud TTS (4M chars/month)
- TTS Offline fallback: gTTS (unlimited, no API key)

## Database
- Hive: all on-device content — PDFs, summaries, MCQs, sessions, audio cache
- Firestore: cloud analytics only — user profile, session logs, daily stats, streaks
- Both under same Firebase project: socratiq

## Auth
- Firebase Auth
- Google Sign-In provider
- Email/Password provider
- Firebase project name: socratiq (separate from Kino)

## LLM Fallback Chains
- Content Agent → Groq Llama 3.3 70B → Gemini → OpenRouter
- Tutor Agent → Gemini → Groq Llama → OpenRouter
- MCQ Agent → Mistral Small → Groq Gemma 2 9B → Cloudflare
- Evaluation Agent → Gemini → Groq Llama → OpenRouter
- Reasoning Agent → Groq Gemma 2 9B → Cloudflare → OpenRouter
- STT → Groq Whisper → Deepgram Nova-2
- TTS → Deepgram Aura → Google Cloud TTS → gTTS

## API Keys In .env
- GEMINI_API_KEY
- GROQ_API_KEY (covers Whisper + Llama + Gemma)
- MISTRAL_API_KEY
- CLOUDFLARE_API_TOKEN
- CLOUDFLARE_ACCOUNT_ID
- OPENROUTER_API_KEY
- DEEPGRAM_API_KEY

## Important Notes
- Gemini free tier burns out fast — always has Groq as fallback
- Groq is primary reliable workhorse for this project
- Content Agent switched from Kimi to Groq (Kimi ran out of credits)
- Never hardcode API keys — always read from os.getenv()
- firebase-admin-key.json in backend root — never commit to GitHub
