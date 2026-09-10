"""Narration voice, cheapest-to-priciest fallback chain: ElevenLabs (a real
premium narrator voice, only when ELEVENLABS_API_KEY is set — costs money
per character) -> edge-tts (Microsoft's neural voices, free, no API key,
but an unofficial endpoint that occasionally rejects requests from some
networks) -> espeak-ng (genuinely offline, always available, noticeably
more robotic).

Every path returns {"audio_path": str, "words": [{"word","start","end"}]}
in the same shape subtitles.build_ass already expects."""
import asyncio
import base64
import logging
import subprocess

import httpx

from app.core.config import get_settings
from app.services import ffmpeg_utils

logger = logging.getLogger(__name__)
settings = get_settings()

DEFAULT_VOICE = "en-US-GuyNeural"

ELEVENLABS_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/with-timestamps"


def _words_from_character_alignment(characters: list[str], starts: list[float], ends: list[float]) -> list[dict]:
    """ElevenLabs' timestamped endpoint gives per-character timing, not
    per-word — group consecutive non-whitespace characters into words,
    taking the first character's start and the last character's end."""
    words: list[dict] = []
    current_chars: list[str] = []
    current_start = None
    current_end = None
    for ch, start, end in zip(characters, starts, ends):
        if ch.isspace():
            if current_chars:
                words.append({"word": "".join(current_chars), "start": current_start, "end": current_end})
                current_chars = []
                current_start = None
            continue
        if current_start is None:
            current_start = start
        current_chars.append(ch)
        current_end = end
    if current_chars:
        words.append({"word": "".join(current_chars), "start": current_start, "end": current_end})
    return words


def _elevenlabs_tts(text: str, out_path: str, voice_id: str) -> list[dict]:
    response = httpx.post(
        ELEVENLABS_TTS_URL.format(voice_id=voice_id),
        headers={"xi-api-key": settings.ELEVENLABS_API_KEY, "Content-Type": "application/json"},
        json={"text": text, "model_id": "eleven_multilingual_v2"},
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()

    with open(out_path, "wb") as f:
        f.write(base64.b64decode(data["audio_base64"]))

    alignment = data["alignment"]
    words = _words_from_character_alignment(
        alignment["characters"], alignment["character_start_times_seconds"], alignment["character_end_times_seconds"]
    )
    if not words:
        raise RuntimeError("elevenlabs returned no timing data")
    return words


async def _edge_tts_async(text: str, out_path: str, voice: str) -> list[dict]:
    import edge_tts

    communicate = edge_tts.Communicate(text, voice)
    words: list[dict] = []
    with open(out_path, "wb") as f:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                f.write(chunk["data"])
            elif chunk["type"] == "WordBoundary":
                start = chunk["offset"] / 10_000_000
                dur = chunk["duration"] / 10_000_000
                words.append({"word": chunk["text"], "start": start, "end": start + dur})
    if not words:
        raise RuntimeError("edge-tts returned no audio/word data")
    return words


def _espeak_fallback(text: str, out_path: str) -> list[dict]:
    """No word-boundary events from espeak's CLI, so timing is estimated
    from word length against the real rendered audio duration. espeak
    speaks at a very constant rate, so this tracks reasonably well —
    nowhere near as precise as edge-tts's real timestamps, but usable."""
    cmd = ["espeak-ng", "-v", "en-us+m3", "-s", "165", "-w", out_path, text]
    subprocess.run(cmd, capture_output=True, text=True, check=True)

    duration = ffmpeg_utils.get_duration_seconds(out_path)
    raw_words = text.split()
    if not raw_words:
        return []

    weights = []
    for w in raw_words:
        weight = len(w) + 1.0
        if w.endswith((".", "!", "?")):
            weight += 5.0
        elif w.endswith(","):
            weight += 2.0
        weights.append(weight)
    total_weight = sum(weights)
    scale = duration / total_weight if total_weight else 0

    words = []
    cursor = 0.0
    for w, weight in zip(raw_words, weights):
        dur = weight * scale
        words.append({"word": w, "start": round(cursor, 3), "end": round(cursor + dur * 0.75, 3)})
        cursor += dur
    return words


def synthesize(text: str, out_path: str, voice: str = DEFAULT_VOICE) -> dict:
    if settings.ELEVENLABS_API_KEY:
        try:
            words = _elevenlabs_tts(text, out_path, settings.ELEVENLABS_VOICE_ID)
            return {"audio_path": out_path, "words": words, "engine": "elevenlabs"}
        except Exception as exc:  # noqa: BLE001
            logger.warning("elevenlabs failed (%s), falling back to edge-tts", exc)

    try:
        words = asyncio.run(_edge_tts_async(text, out_path, voice))
        return {"audio_path": out_path, "words": words, "engine": "edge-tts"}
    except Exception as exc:  # noqa: BLE001
        logger.warning("edge-tts failed (%s), falling back to espeak-ng", exc)
        words = _espeak_fallback(text, out_path)
        return {"audio_path": out_path, "words": words, "engine": "espeak-ng"}
