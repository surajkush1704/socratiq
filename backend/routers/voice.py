import traceback
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import Response, JSONResponse
from agents.voice_agent import (
    transcribe_audio,
    synthesize_speech,
    speed_label_to_float
)
from middleware.cost_guard import (
    enforce_daily_quota,
    validate_file_size,
    MAX_AUDIO_SIZE_MB,
)

router = APIRouter()


@router.post('/stt')
async def speech_to_text(
    audio: UploadFile = File(...),
    session_id: str = Form(default=''),
    uid: str = Form(default=''),
    language: str = Form(default='en'),
):
    """
    Endpoint: POST /voice/stt
    Accepts: multipart/form-data with 'audio' file and optional language
    Returns: JSON { transcript: string, duration_ms: int }
    """
    try:
        print(f'[STT ROUTER] Received audio: '
              f'filename={audio.filename}, '
              f'language={language}, '
              f'content_type={audio.content_type}, '
              f'session={session_id[:8] if session_id else "none"}')

        audio_bytes = await audio.read()

        # Validate audio file size
        validate_file_size(
            size_bytes=len(audio_bytes),
            max_mb=MAX_AUDIO_SIZE_MB,
            file_type='Audio file',
        )

        # Enforce daily STT quota
        if uid:
            enforce_daily_quota(uid=uid, resource='stt', limit=100)

        print(f'[STT ROUTER] Audio size: {len(audio_bytes)} bytes')

        if len(audio_bytes) < 100:
            raise HTTPException(
                status_code=400,
                detail='Audio file too small — recording may have failed'
            )

        filename = audio.filename or 'audio.m4a'
        transcript = await transcribe_audio(
            audio_bytes,
            filename,
            language=language,
        )

        if not transcript or not transcript.strip():
            return JSONResponse(content={
                'transcript': '',
                'error': 'No speech detected in audio',
                'success': False,
            })

        return JSONResponse(content={
            'transcript': transcript.strip(),
            'success': True,
            'char_count': len(transcript),
        })

    except HTTPException:
        raise
    except Exception as e:
        print(f'[STT ROUTER] Error: {e}')
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail='Speech-to-text processing failed'
        )


@router.post('/tts')
async def text_to_speech(
    text: str = Form(...),
    voice: str = Form(default='aura-luna-en'),
    speed: str = Form(default='normal'),
    session_id: str = Form(default=''),
    language: str = Form(default='en'),
):
    """
    Endpoint: POST /voice/tts
    Accepts: multipart/form-data with text, voice, speed, language
    Returns: audio/mpeg binary (mp3)
    """
    try:
        print(f'[TTS ROUTER] language={language}, text={text[:60]}...')

        if not text or not text.strip():
            raise HTTPException(
                status_code=400,
                detail='Text cannot be empty'
            )

        speed_float = speed_label_to_float(speed)
        audio_bytes = await synthesize_speech(
            text=text.strip(),
            voice=voice,
            speed=speed_float,
            language=language,
        )

        print(f'[TTS ROUTER] Returning {len(audio_bytes)} bytes of audio')

        return Response(
            content=audio_bytes,
            media_type='audio/mpeg',
            headers={
                'Content-Disposition': 'inline; filename="response.mp3"',
                'Content-Length': str(len(audio_bytes)),
                'X-Voice': voice,
                'X-Speed': speed,
                'X-Language': language,
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f'[TTS ROUTER] Error: {e}')
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail=f'TTS failed: {str(e)}'
        )


@router.get('/voices')
async def list_voices():
    """Returns available Deepgram Aura voices"""
    return {
        'voices': [
            {'id': 'aura-luna-en', 'name': 'Luna', 'gender': 'female', 'style': 'soft'},
            {'id': 'aura-asteria-en', 'name': 'Asteria', 'gender': 'female', 'style': 'warm'},
            {'id': 'aura-stella-en', 'name': 'Stella', 'gender': 'female', 'style': 'bright'},
            {'id': 'aura-athena-en', 'name': 'Athena', 'gender': 'female', 'style': 'british'},
            {'id': 'aura-orion-en', 'name': 'Orion', 'gender': 'male', 'style': 'confident'},
            {'id': 'aura-arcas-en', 'name': 'Arcas', 'gender': 'male', 'style': 'warm'},
        ],
        'default': 'aura-luna-en',
    }


@router.post('/tts/stream')
async def text_to_speech_stream(
    text: str = Form(...),
    voice: str = Form(default='aura-luna-en'),
    speed: str = Form(default='normal'),
):
    return await text_to_speech(text=text, voice=voice, speed=speed)