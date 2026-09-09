import re
from typing import Tuple

# Unicode ranges for Indian scripts
DEVANAGARI_RANGE = (0x0900, 0x097F)
TAMIL_RANGE      = (0x0B80, 0x0BFF)
TELUGU_RANGE     = (0x0C00, 0x0C7F)
KANNADA_RANGE    = (0x0C80, 0x0CFF)
BENGALI_RANGE    = (0x0980, 0x09FF)
GUJARATI_RANGE   = (0x0A80, 0x0AFF)
MALAYALAM_RANGE  = (0x0D00, 0x0D7F)

# Sanskrit-specific characters that rarely appear in modern Hindi
# Vedic extensions, visarga patterns, specific conjunct consonants
SANSKRIT_MARKERS = [
    'ः',   # visarga — very common in Sanskrit, rare in modern Hindi prose
    'ॐ',   # Om symbol
    'ऽ',   # avagraha
    '।',   # dandā (also used in Hindi but far more frequent in Sanskrit)
]

# Sanskrit vocabulary patterns — common Sanskrit words
SANSKRIT_WORD_PATTERNS = [
    r'\bनमः\b', r'\bश्रीः\b', r'\bइति\b', r'\bच\b',
    r'\bतथा\b', r'\bयदा\b', r'\bतदा\b', r'\bएव\b',
    r'\bहि\b', r'\bवै\b', r'\bअपि\b', r'\bतु\b',
    r'\bएतत्\b', r'\bसः\b', r'\bसा\b', r'\bतत्\b',
    r'\bश्लोक', r'\bमन्त्र', r'\bसूत्र', r'\bवेद',
    r'\bउपनिषद', r'\bगीता', r'\bपुराण',
]


def _count_chars_in_range(text: str, start: int, end: int) -> int:
    return sum(1 for ch in text if start <= ord(ch) <= end)


def _get_script_percentages(text: str) -> dict:
    total = max(len(text), 1)
    return {
        'devanagari': _count_chars_in_range(text, *DEVANAGARI_RANGE) / total,
        'tamil':      _count_chars_in_range(text, *TAMIL_RANGE) / total,
        'telugu':     _count_chars_in_range(text, *TELUGU_RANGE) / total,
        'kannada':    _count_chars_in_range(text, *KANNADA_RANGE) / total,
        'bengali':    _count_chars_in_range(text, *BENGALI_RANGE) / total,
        'gujarati':   _count_chars_in_range(text, *GUJARATI_RANGE) / total,
        'malayalam':  _count_chars_in_range(text, *MALAYALAM_RANGE) / total,
    }


def _is_sanskrit(text: str) -> bool:
    """
    Distinguish Sanskrit from Hindi within Devanagari script.
    Uses visarga frequency and vocabulary patterns.
    Sanskrit tends to have high visarga density and classical vocab.
    """
    # Count Sanskrit markers
    marker_count = sum(text.count(m) for m in SANSKRIT_MARKERS)
    
    # Count Sanskrit vocabulary patterns
    pattern_count = sum(
        len(re.findall(p, text))
        for p in SANSKRIT_WORD_PATTERNS
    )
    
    # Visarga density — Sanskrit has visarga (ः) very frequently
    # More than 0.3% of total characters being visarga → strongly Sanskrit
    visarga_density = text.count('ः') / max(len(text), 1)
    
    score = marker_count + pattern_count * 2
    
    print(f'[LANG DETECT] Sanskrit score={score}, '
          f'visarga_density={visarga_density:.4f}')
    
    return score >= 3 or visarga_density >= 0.003


def detect_language(text: str) -> Tuple[str, str, str]:
    """
    Detects document language from extracted text.
    
    Returns tuple of:
    - document_language: the language of the document content
      ('en', 'hi', 'sa', 'ta', 'te', 'kn', 'bn', 'gu', 'ml')
    - response_language: the language the tutor should respond in
      ('en', 'hi') — Sanskrit uses Hindi as bridge
    - display_name: human-readable name for UI display
    
    Logic:
    - English (Latin) script → 'en', respond 'en'
    - Devanagari, identified as Sanskrit → 'sa', respond 'hi'
    - Devanagari, identified as Hindi → 'hi', respond 'hi'
    - Tamil → 'ta', respond 'ta'
    - Telugu → 'te', respond 'te'
    - Kannada → 'kn', respond 'kn'
    - Bengali → 'bn', respond 'bn'
    - Gujarati → 'gu', respond 'gu'
    - Malayalam → 'ml', respond 'ml'
    """
    if not text or len(text.strip()) < 50:
        return 'en', 'en', 'English'
    
    scripts = _get_script_percentages(text)
    dominant = max(scripts, key=scripts.get)
    dominant_pct = scripts[dominant]
    
    print(f'[LANG DETECT] Script percentages: {scripts}')
    print(f'[LANG DETECT] Dominant: {dominant} ({dominant_pct:.1%})')
    
    # If no Indian script is dominant (less than 10% of characters)
    # treat as English
    if dominant_pct < 0.10:
        return 'en', 'en', 'English'
    
    if dominant == 'devanagari':
        if _is_sanskrit(text):
            print('[LANG DETECT] → Sanskrit (respond in Hindi)')
            return 'sa', 'hi', 'Sanskrit'
        else:
            print('[LANG DETECT] → Hindi')
            return 'hi', 'hi', 'Hindi'
    
    lang_map = {
        'tamil':    ('ta', 'ta', 'Tamil'),
        'telugu':   ('te', 'te', 'Telugu'),
        'kannada':  ('kn', 'kn', 'Kannada'),
        'bengali':  ('bn', 'bn', 'Bengali'),
        'gujarati': ('gu', 'gu', 'Gujarati'),
        'malayalam':('ml', 'ml', 'Malayalam'),
    }
    
    return lang_map.get(dominant, ('en', 'en', 'English'))
