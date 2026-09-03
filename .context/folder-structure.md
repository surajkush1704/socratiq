# Socratiq — Complete Folder Structure

## Root

D:\socratiq
├── .context/ → AntiGravity context files (this folder)
├── backend/ → FastAPI backend
└── mobile/ → Flutter app


## Backend

backend/
├── main.py → FastAPI app entry, route registration, CORS
├── orchestrator.py → Core routing logic, mode handler
├── Dockerfile → Docker config
├── requirements.txt → Python dependencies
├── railway.json → Railway deploy config
├── .env → All API keys (never commit)
├── firebase-admin-key.json → Firebase service account (never commit)
├── .gitignore
├── temp/ → Temporary PDF storage during processing
├── agents/
│ ├── init.py
│ ├── content_agent.py → PDF processing via Groq (runs once, cached)
│ ├── tutor_agent.py → Concept explanation via Gemini
│ ├── mcq_agent.py → MCQ generation via Mistral
│ ├── evaluation_agent.py → Answer scoring via Gemini
│ ├── reasoning_agent.py → Socratic follow-up via Groq Gemma
│ └── voice_agent.py → STT (Groq Whisper) + TTS (Deepgram/gTTS)
├── routers/
│ ├── init.py
│ ├── content.py → POST /content/upload, /content/process
│ ├── session.py → POST /session/start, /session/end
│ ├── interaction.py → POST /interact (main session loop)
│ ├── voice.py → POST /voice/stt, /voice/tts
│ └── sync.py → POST /sync/session, /sync/usage, GET /user/stats
├── models/
│ ├── init.py
│ ├── session.py → Session and ContentProcessRequest Pydantic models
│ ├── interaction.py → Interaction flow Pydantic models
│ └── user.py → User and analytics Pydantic models
├── db/
│ ├── init.py
│ └── firestore.py → Firebase Admin init + Firestore client
└── llm/
├── init.py
├── router.py → Round-robin fallback chain logic
├── gemini.py → Gemini 2.0 Flash client
├── groq.py → Groq Llama + Gemma + Whisper client
├── mistral.py → Mistral Small client
├── cloudflare.py → Cloudflare Workers AI client
└── openrouter.py → OpenRouter fallback client


## Mobile

mobile/
├── pubspec.yaml
├── android/
│ └── app/
│ └── google-services.json → Firebase config (never commit)
└── lib/
├── main.dart → App entry, Firebase + Hive init
├── app.dart → MaterialApp, theme, named routes
├── app_theme.dart → All colours, shadows, ThemeData
├── screens/
│ ├── splash/
│ │ └── splash_screen.dart
│ ├── auth/
│ │ └── login_screen.dart
│ ├── home/
│ │ └── home_screen.dart
│ ├── library/
│ │ └── library_screen.dart
│ ├── upload/
│ │ └── upload_screen.dart
│ ├── session/
│ │ ├── mode_select.dart
│ │ ├── learn_screen.dart
│ │ ├── test_screen.dart
│ │ └── result_screen.dart
│ ├── dashboard/
│ │ └── dashboard_screen.dart
│ └── settings/
│ └── settings_screen.dart
├── widgets/
│ ├── floating_nav.dart → Floating pill nav widget
│ ├── voice_mic_button.dart → Voice orb with all states
│ ├── mcq_card.dart → MCQ bottom sheet widget
│ ├── score_display.dart → Score number display
│ ├── topic_chip.dart → Topic pill chip
│ └── stat_tile.dart → Dashboard stat card
├── services/
│ ├── api_service.dart → All FastAPI calls via Dio
│ ├── auth_service.dart → Firebase Auth methods
│ ├── voice_service.dart → Record + playback audio
│ ├── hive_service.dart → Local Hive read/write
│ └── sync_service.dart → Background Firestore sync
├── models/
│ ├── session_model.dart
│ ├── mcq_model.dart
│ ├── content_model.dart
│ └── user_model.dart
└── providers/
├── session_provider.dart
├── auth_provider.dart
└── content_provider.dart


## Git
- One repo: socratiq
- Root .gitignore covers both backend and mobile secrets
- Never commit: .env, firebase-admin-key.json, google-services.json
