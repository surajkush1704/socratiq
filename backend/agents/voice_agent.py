import os
import io
import traceback
import httpx
from gtts import gTTS


# ── STT — GROQ WHISPER ────────────────────────────────────────────────────────

GROQ_WHISPER_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'
GROQ_WHISPER_MODEL = 'whisper-large-v3-turbo'


async def transcribe_audio(
    audio_bytes: bytes,
    filename: str = 'audio.m4a',
    language: str = 'en',
) -> str:
    """
    Language codes for Whisper:
    'en' = English, 'hi' = Hindi,
    'sa' = Sanskrit (Whisper supports it partially),
    'ta' = Tamil, 'te' = Telugu, 'kn' = Kannada,
    'bn' = Bengali, 'gu' = Gujarati, 'ml' = Malayalam

    For Sanskrit sessions where user may speak in either Hindi or
    Sanskrit, pass 'hi' as language — Whisper handles both
    Devanagari scripts correctly under 'hi'.
    """
    api_key = os.getenv('GROQ_API_KEY')
    whisper_lang = 'hi' if language == 'sa' else language

    print(f'[STT] Transcribing: lang={language}, '
          f'whisper_lang={whisper_lang}, size={len(audio_bytes)} bytes')

    if not api_key:
        print('[STT] GROQ_API_KEY not set, trying Deepgram...')
        return await transcribe_audio_deepgram(audio_bytes, filename, language=whisper_lang)

    try:
        ext = filename.split('.')[-1].lower()
        content_type_map = {
            'webm': 'audio/webm',
            'wav': 'audio/wav',
            'mp3': 'audio/mpeg',
            'm4a': 'audio/m4a',
            'mp4': 'audio/mp4',
            'ogg': 'audio/ogg',
            'flac': 'audio/flac',
        }
        content_type = content_type_map.get(ext, 'audio/m4a')

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                GROQ_WHISPER_URL,
                headers={'Authorization': f'Bearer {api_key}'},
                files={
                    'file': (filename, audio_bytes, content_type),
                },
                data={
                    'model': GROQ_WHISPER_MODEL,
                    'response_format': 'json',
                    'language': whisper_lang,
                }
            )

            print(f'[STT] Groq Whisper status: {response.status_code}')

            if response.status_code != 200:
                print(f'[STT] Groq error body: {response.text[:300]}')
                raise Exception(f'Groq Whisper failed: {response.status_code}')

            data = response.json()
            transcript = data.get('text', '').strip()
            print(f'[STT] Transcript: "{transcript[:80]}"')
            return transcript

    except Exception as e:
        print(f'[STT] Groq Whisper failed: {e}')
        print(traceback.format_exc())
        return await transcribe_audio_deepgram(audio_bytes, filename, language=whisper_lang)


async def transcribe_audio_deepgram(
    audio_bytes: bytes,
    filename: str = 'audio.webm',
    language: str = 'en',
) -> str:
    """Deepgram Nova-2 STT fallback"""
    api_key = os.getenv('DEEPGRAM_API_KEY')
    if not api_key:
        raise Exception('No STT service available — both Groq and Deepgram keys missing')

    print(f'[STT FALLBACK] Trying Deepgram Nova-2 (lang={language})...')

    ext = filename.split('.')[-1].lower()
    content_type_map = {
        'webm': 'audio/webm',
        'wav': 'audio/wav',
        'mp3': 'audio/mpeg',
        'm4a': 'audio/mp4',
        'ogg': 'audio/ogg',
    }
    content_type = content_type_map.get(ext, 'audio/webm')

    try:
        deepgram_lang = 'hi' if language in ('hi', 'sa') else 'en'
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f'https://api.deepgram.com/v1/listen?model=nova-2&language={deepgram_lang}&smart_format=true',
                headers={
                    'Authorization': f'Token {api_key}',
                    'Content-Type': content_type,
                },
                content=audio_bytes,
            )

            print(f'[STT FALLBACK] Deepgram status: {response.status_code}')

            if response.status_code != 200:
                raise Exception(f'Deepgram STT failed: {response.status_code} {response.text[:200]}')

            data = response.json()
            transcript = (
                data['results']['channels'][0]['alternatives'][0]['transcript']
            )
            print(f'[STT FALLBACK] Deepgram transcript: "{transcript[:50]}..."')
            return transcript

    except Exception as e:
        print(f'[STT FALLBACK] Deepgram also failed: {e}')
        raise Exception(f'All STT services failed. Last error: {e}')


# ── TTS ───────────────────────────────────────────────────────────────────────

DEEPGRAM_TTS_URL = 'https://api.deepgram.com/v1/speak'
DEFAULT_VOICE = 'aura-luna-en'


async def _synthesize_deepgram(text: str, voice: str = DEFAULT_VOICE, speed: float = 1.0) -> bytes:
    api_key = os.getenv('DEEPGRAM_API_KEY')
    if not api_key:
        print('[TTS] No Deepgram key — using gTTS directly')
        return await synthesize_speech_gtts(text, lang='en')

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f'{DEEPGRAM_TTS_URL}?model={voice}',
                headers={
                    'Authorization': f'Token {api_key}',
                    'Content-Type': 'application/json',
                },
                json={'text': text},
            )

            print(f'[TTS] Deepgram status: {response.status_code}')

            if response.status_code == 200:
                audio_bytes = response.content
                print(f'[TTS] Deepgram audio: {len(audio_bytes)} bytes')
                return audio_bytes
            else:
                print(f'[TTS] Deepgram error: {response.text[:200]}')
                raise Exception(f'Deepgram TTS failed: {response.status_code}')

    except Exception as e:
        print(f'[TTS] Deepgram failed: {e}. Falling back to gTTS...')
        return await synthesize_speech_gtts(text, lang='en')


async def _synthesize_google_cloud_tts(
    text: str,
    language_code: str = 'hi-IN',
) -> bytes:
    """
    Google Cloud TTS for Hindi and Sanskrit.
    Uses WaveNet voice for natural quality.
    Falls back to gTTS if Google Cloud fails or key unavailable.
    """
    import base64

    api_key = os.getenv('GOOGLE_CLOUD_TTS_KEY', '')

    if not api_key or 'your_google_cloud' in api_key or api_key == 'dummy':
        print('[TTS] No valid Google Cloud TTS key — using fast gTTS directly')
        lang = language_code.split('-')[0]  # 'hi-IN' → 'hi'
        return await synthesize_speech_gtts(text, lang=lang)

    voice_name = 'hi-IN-Wavenet-A'  # female, natural quality

    payload = {
        'input': {'text': text},
        'voice': {
            'languageCode': language_code,
            'name': voice_name,
            'ssmlGender': 'FEMALE',
        },
        'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
            'pitch': 0,
        },
    }

    url = f'https://texttospeech.googleapis.com/v1/text:synthesize?key={api_key}'

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, json=payload)
            print(f'[TTS GOOGLE] Status: {response.status_code}')

            if response.status_code == 200:
                data = response.json()
                audio_b64 = data['audioContent']
                audio_bytes = base64.b64decode(audio_b64)
                print(f'[TTS GOOGLE] Audio: {len(audio_bytes)} bytes')
                return audio_bytes
            else:
                print(f'[TTS GOOGLE] Error: {response.text[:200]}')
                raise Exception(f'Google TTS failed: {response.status_code}')

    except Exception as e:
        print(f'[TTS GOOGLE] Failed: {e} — using gTTS')
        lang = language_code.split('-')[0]
        return await synthesize_speech_gtts(text, lang=lang)


async def synthesize_speech(
    text: str,
    voice: str = DEFAULT_VOICE,
    speed: float = 1.0,
    language: str = 'en',
) -> bytes:
    """
    Routes TTS based on language:
    - English ('en') → Deepgram Aura (best quality)
    - Hindi ('hi') → Google Cloud TTS hi-IN WaveNet
    - Sanskrit ('sa') → Google Cloud TTS hi-IN (reads Sanskrit
      phonetically using Hindi voice — correct behavior)
    - Other Indian languages → gTTS with lang code
    - All fallback to gTTS
    """
    if not text or not text.strip():
        raise ValueError('Empty text for TTS')

    # Trim long text
    if len(text) > 500:
        sentences = text.split('।') if '।' in text else text.split('. ')
        trimmed = ''
        for s in sentences:
            if len(trimmed) + len(s) < 500:
                trimmed += s + ('।' if '।' in text else '. ')
            else:
                break
        text = trimmed.strip() or text[:500]

    print(f'[TTS] Language: {language}, chars: {len(text)}')

    # Route based on language
    if language in ('hi', 'sa'):
        # Sanskrit uses Hindi voice — reads Devanagari correctly
        return await _synthesize_google_cloud_tts(text, language_code='hi-IN')
    elif language == 'en':
        # English → Deepgram Aura (existing logic)
        return await _synthesize_deepgram(text, voice, speed)
    else:
        # Other Indian languages → gTTS
        return await synthesize_speech_gtts(text, lang=language)


async def synthesize_speech_gtts(text: str, lang: str = 'en') -> bytes:
    """
    gTTS offline fallback — free, no API key, slightly robotic voice.
    Runs asynchronously but wrapped for async use.
    Returns mp3 bytes.
    """
    import asyncio
    print(f'[TTS FALLBACK] gTTS lang={lang}, chars={len(text)}')
    try:
        loop = asyncio.get_event_loop()

        def _synthesise():
            tts = gTTS(text=text, lang=lang, slow=False)
            buffer = io.BytesIO()
            tts.write_to_fp(buffer)
            buffer.seek(0)
            return buffer.read()

        audio_bytes = await loop.run_in_executor(None, _synthesise)
        print(f'[TTS FALLBACK] gTTS audio: {len(audio_bytes)} bytes')
        return audio_bytes

    except Exception as e:
        print(f'[TTS FALLBACK] gTTS failed: {e}')
        print(traceback.format_exc())
        raise Exception(f'All TTS services failed: {e}')


def speed_label_to_float(speed_label: str) -> float:
    """Convert Flutter speed setting to Deepgram rate"""
    mapping = {
        'slow': 0.8,
        'normal': 1.0,
        'fast': 1.2,
    }
    return mapping.get(speed_label.lower(), 1.0)