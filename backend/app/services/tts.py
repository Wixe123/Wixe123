"""Free narration voice. Tries edge-tts first (Microsoft's neural voices,
no API key, but an unofficial endpoint that occasionally rejects requests
from some networks) and falls back to espeak-ng (genuinely offline,
always available, noticeably more robotic) if that fails.

Either path returns {"audio_path": str, "words": [{"word","start","end"}]}
in the same shape subtitles.build_ass already expects."""
import asyncio
import logging
import subprocess

from app.services import ffmpeg_utils

logger = logging.getLogger(__name__)

DEFAULT_VOICE = "en-US-GuyNeural"


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
    try:
        words = asyncio.run(_edge_tts_async(text, out_path, voice))
        return {"audio_path": out_path, "words": words, "engine": "edge-tts"}
    except Exception as exc:  # noqa: BLE001
        logger.warning("edge-tts failed (%s), falling back to espeak-ng", exc)
        words = _espeak_fallback(text, out_path)
        return {"audio_path": out_path, "words": words, "engine": "espeak-ng"}
