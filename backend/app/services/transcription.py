"""Word-level transcription via faster-whisper. Runs on CPU by default;
set WHISPER_DEVICE=cuda on a GPU box for a large speedup."""
import logging
from functools import lru_cache

from faster_whisper import WhisperModel

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


@lru_cache
def _get_model() -> WhisperModel:
    return WhisperModel(
        settings.WHISPER_MODEL_SIZE,
        device=settings.WHISPER_DEVICE,
        compute_type=settings.WHISPER_COMPUTE_TYPE,
    )


def transcribe(audio_path: str, language: str | None = None) -> dict:
    """Returns {"language": str, "segments": [{start,end,text}],
    "words": [{start,end,word}]}"""
    model = _get_model()
    segments_iter, info = model.transcribe(
        audio_path,
        language=language,
        word_timestamps=True,
        vad_filter=True,
    )

    segments = []
    words = []
    for seg in segments_iter:
        segments.append({"start": seg.start, "end": seg.end, "text": seg.text.strip()})
        for w in seg.words or []:
            words.append({"start": w.start, "end": w.end, "word": w.word.strip()})

    return {"language": info.language, "segments": segments, "words": words}
