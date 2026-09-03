import os
import io
import traceback
import httpx
from gtts import gTTS


# ── STT — GROQ WHISPER ────────────────────────────────────────────────────────

GROQ_WHISPER_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'
GROQ_WHISPER_MODEL = 'whisper-large-v3-turbo'


async def transcribe_audio(audio_bytes: bytes, filename: str = 'audio.webm') -> str:
    """
    Convert audio bytes to text using Groq Whisper.
    Falls back to Deepgram Nova-2 if Groq fails.
    Supported formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm
    """
    api_key = os.getenv('GROQ_API_KEY')
    if not api_key:
        print('[STT] GROQ_API_KEY not set, trying Deepgram...')
        return await transcribe_audio_deepgram(audio_bytes, filename)

    print(f'[STT] Transcribing {len(audio_bytes)} bytes, file: {filename}')

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
                    'language': 'en',
                }
            )

            print(f'[STT] Groq Whisper status: {response.status_code}')

            if response.status_code != 200:
                print(f'[STT] Groq error body: {response.text[:300]}')
                raise Exception(f'Groq Whisper failed: {response.status_code}')

            data = response.json()
            transcript = data.get('text', '').strip()
            print(f'[STT] Transcript: "{transcript}"')
            return transcript

    except Exception as e:
        print(f'[STT] Groq Whisper failed: {e}')
        print(traceback.format_exc())
        return await transcribe_audio_deepgram(audio_bytes, filename)


async def transcribe_audio_deepgram(
    audio_bytes: bytes,
    filename: str = 'audio.webm'
) -> str:
    """Deepgram Nova-2 STT fallback"""
    api_key = os.getenv('DEEPGRAM_API_KEY')
    if not api_key:
        raise Exception('No STT service available — both Groq and Deepgram keys missing')

    print(f'[STT FALLBACK] Trying Deepgram Nova-2...')

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
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                'https://api.deepgram.com/v1/listen'
                '?model=nova-2&language=en&smart_format=true',
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
            print(f'[STT FALLBACK] Deepgram transcript: "{transcript}"')
            return transcript

    except Exception as e:
        print(f'[STT FALLBACK] Deepgram also failed: {e}')
        raise Exception(f'All STT services failed. Last error: {e}')


# ── TTS — DEEPGRAM AURA ───────────────────────────────────────────────────────

DEEPGRAM_TTS_URL = 'https://api.deepgram.com/v1/speak'
DEFAULT_VOICE = 'aura-luna-en'


async def synthesize_speech(
    text: str,
    voice: str = DEFAULT_VOICE,
    speed: float = 1.0
) -> bytes:
    """
    Convert text to speech using Deepgram Aura.
    Falls back to gTTS if Deepgram fails.
    Returns raw audio bytes (mp3).
    """
    if not text or not text.strip():
        raise ValueError('Empty text provided for TTS')

    if len(text) > 500:
        sentences = text.split('. ')
        trimmed = ''
        for s in sentences:
            if len(trimmed) + len(s) < 500:
                trimmed += s + '. '
            else:
                break
        text = trimmed.strip() or text[:500]
        print(f'[TTS] Text trimmed to {len(text)} chars')

    print(f'[TTS] Synthesising {len(text)} chars with voice: {voice}')

    api_key = os.getenv('DEEPGRAM_API_KEY')

    if api_key:
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
    else:
        print('[TTS] No Deepgram key — using gTTS directly')

    return await synthesize_speech_gtts(text)


async def synthesize_speech_gtts(text: str) -> bytes:
    """
    gTTS offline fallback — free, no API key, slightly robotic voice.
    Runs synchronously but wrapped for async use.
    Returns mp3 bytes.
    """
    print(f'[TTS FALLBACK] gTTS synthesising {len(text)} chars...')
    try:
        import asyncio
        loop = asyncio.get_event_loop()

        def _synthesise():
            tts = gTTS(text=text, lang='en', slow=False)
            buffer = io.BytesIO()
            tts.write_to_fp(buffer)
            buffer.seek(0)
            return buffer.read()

        audio_bytes = await loop.run_in_executor(None, _synthesise)
        print(f'[TTS FALLBACK] gTTS audio: {len(audio_bytes)} bytes')
        return audio_bytes

    except Exception as e:
        print(f'[TTS FALLBACK] gTTS also failed: {e}')
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