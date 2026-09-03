# Socratiq — Build Phases

## Phase 0 — Setup ✅ DONE
- All API keys obtained: Groq, Mistral, Cloudflare, OpenRouter, Deepgram
- Firebase project "socratiq" created (separate from Kino)
- Firebase Auth enabled: Google + Email providers
- Firestore enabled: asia-south1 region
- google-services.json downloaded → mobile/android/app/
- firebase-admin-key.json downloaded → backend/
- Railway account created
- Flutter project created at D:\socratiq\mobile
- FastAPI project created at D:\socratiq\backend
- Full folder structure scaffolded
- Dockerfile written
- All API keys in backend/.env

## Phase 1 — PDF Processing ✅ DONE
- PyMuPDF PDF text extraction working
- Content Agent working with Groq Llama 3.3 70B as primary
- Gemini fallback implemented (Gemini key hit limit, Groq now primary)
- LLM fallback chain router built and tested
- Hive local storage implemented
- Upload screen built with all states (idle, selected, processing, done, error)
- ContentModel created and saved to Hive after processing
- TopicChip widget built
- Tested via PowerShell — summary, key_points, topics all returned correctly
- Note: Kimi was original Content Agent but ran out of credits — replaced with Groq

## Phase 2 — Auth + App Shell ✅ DONE
- AppTheme v3 design system implemented across all screens
- GlassNav floating pill navigation with blur and glow
- Firebase Auth integration
- Splash screen with auth check
- Login screen: Google Sign-In + Email/Password
- Home screen: top bar, Hero tutor card, Bento rows, recent PDFs, stats strip
- Library screen: PDF list, search, floating upload button
- Mode Select screen: Learn, Revise, Test mode cards
- Settings screen: profile, voice speed, tutor voice, storage, sign out
- Connect all screens with named routes

## Phase 3 — Multi-Agent Text Session Loop ✅ DONE
- Pydantic models for session and interaction schemas
- Multi-agent router fallback chain: Gemini 2.5 Flash, Groq Compound, Mistral Small, Cloudflare Llama 3.2 3B
- Tutor Agent, MCQ Agent, and Evaluation Agent modules
- In-memory session orchestrator handling transcript history, score tracking, and MCQ generation
- FastAPI session routes (/session/start, /session/end, /interaction/interact)
- Flutter LearnScreen text interaction loop with live backend integration
- Verified with 5-test PowerShell suite (100% success)

## Phase 4 — Voice Layer ✅ DONE
- Groq Whisper API → POST /voice/stt (STT primary)
- Deepgram Nova-2 → STT fallback
- Deepgram Aura → POST /voice/tts (TTS primary, natural voice)
- gTTS → TTS offline fallback (always works, no API key)
- VoiceService: startRecording/stopRecording/transcribeAudio/speakText
- Audio recorded as m4a (16kHz mono, 64kbps) — optimal for Whisper
- LearnScreen mic button: tap+hold to record, release to send
- Recording indicator: red pulsing dot on orb when active
- Listening rings: cyan expanding rings during recording
- Speaking rings: blue rings during TTS playback
- TTS auto-plays every AI response
- Voice speed preference: Slow/Normal/Fast → saved to ApiService.voiceSpeed
- Voice selector: Luna/Asteria/Stella/Orion/Arcas → saved to ApiService.voiceId
- Text input toggle: keyboard icon switches between voice and text mode
- Both voice and text input work simultaneously — voice is primary

## Phase 5 — Reasoning Agent + Adaptive Testing ✅ DONE

### Reasoning Agent
- reasoning_agent.py fully implemented with 4 strategies:
  - Attempt 1: Socratic guiding question (never reveals answer)
  - Attempt 2: Stronger hint + question (partial reveal)
  - Attempt 3+: Full answer reveal + encouragement + topic advance
  - Deepening questions for excellent answers (score >= 9, every 4th interaction)
- ReasoningTracker: tracks per-question attempt count per session
- _reasoning_trackers dict: separate from SessionState, keyed by session_id
- Milestone encouragement every 5 questions via get_encouragement()
- Reasoning messages shown in LearnScreen with lavender tint + brain icon
- trigger_reasoning flag passed to Flutter via InteractResponse

### Adaptive Testing
- POST /session/generate-test: generates full MCQ set before test starts
- generate_test_set: spreads questions across topics, easy/medium/hard spread
- POST /session/submit-test: evaluates all answers, returns full breakdown
- TestScreen: loads questions on mount, collects answers locally
- Segmented progress bar: one segment per question, filled when answered
- Dot navigator: tap any dot to jump to that question
- Previous/Next navigation: can review and change answers before submit
- Unanswered questions warning dialog before final submission
- ResultScreen: accepts weakTopics and performanceLabel from backend
- ModeSelectScreen: Test mode routes to TestScreen, not LearnScreen

## Phase 6 — Progress and Sync ✅ DONE
- backend/db/firestore.py: full Firestore db layer with Firebase Admin SDK init, user profile CRUD, session logging, daily stats, streak calculation logic, aggregate stats, and composite index fallback.
- backend/routers/sync.py: FastAPI sync endpoints (/sync/profile, /sync/session, /sync/stats/{uid}, /sync/activity/{uid}, /sync/document-history/{uid}, /sync/profile/{uid}).
- backend/orchestrator.py: end_session() automatically calculates duration, topics, and syncs session to Firestore.
- SyncService (mobile/lib/services/sync_service.dart): fully rewritten to sync profile, sessions, stats, activity, and document history via Dio HTTP requests to FastAPI backend.
- SplashScreen & AuthService: sync user profile to Firestore automatically on app launch and authentication (Google/Email).
- LearnScreen & TestScreen: automatically sync session log, duration, score, correct/attempted questions, and topics to Firestore upon session completion.
- HomeScreen: live stats strip (streak, today's time, total sessions, average score) and live activity feed.
- DashboardScreen: fully rewritten with animated streak hero, Bento cards, 7-day weekly activity bar chart, performance ring, topic mastery, and live session history feed.
- LibraryScreen: fetches and displays last studied date per document from Firestore.

## Phase 7 — Polish and Ship
- All animations refined
- Fallback handling for every API with user-visible error messages
- Offline mode: local content works, graceful error when no internet
- Edge cases: empty PDF, failed upload, rate limit, Firestore write failure
- Final end-to-end test with friend
- Backend moved from Railway to Oracle Cloud Always Free
- APK built and shared with friend

## Key Decisions Made
- Groq is primary workhorse — most reliable free tier
- Gemini key burns fast — always needs Groq fallback ready
- Kimi replaced by Groq for Content Agent (credits ran out)
- Firestore replaces Neon PostgreSQL — simpler, same Firebase project
- gTTS as offline TTS fallback — zero cost, always works
- Local IP used during development — Railway deploy in Phase 7
- One monorepo: D:\socratiq\ with backend/ and mobile/ inside
