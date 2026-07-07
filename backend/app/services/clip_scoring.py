"""Heuristic "virality" scorer.

This is deliberately not presented as a trained ML model — Opus Clip's
actual scoring model is proprietary and unavailable. Instead this combines
signals that correlate with clip-worthy moments: audio energy peaks
(excitement/emphasis), speech rate, hook/question/emotional keyword hits,
and sentence boundaries (so clips start/end on clean cuts). It's a
reasonable, inspectable starting point — tune the weights in Settings
(`ai_sensitivity`) or replace this module with a real model later.
"""
import wave
from dataclasses import dataclass, field

import numpy as np

HOOK_PHRASES = [
    "here's why", "here is why", "the reason", "nobody tells you", "secret",
    "mistake", "you won't believe", "this changed", "stop doing", "never do",
    "the truth about", "what if i told you", "in this video", "let me show you",
]
QUESTION_MARKERS = ["?", "why", "how", "what if", "did you know"]
EMOTIONAL_WORDS = [
    "amazing", "insane", "crazy", "shocking", "unbelievable", "love", "hate",
    "terrifying", "hilarious", "incredible", "worst", "best", "scared", "excited",
]
EDUCATIONAL_MARKERS = ["step", "first", "second", "third", "finally", "tip", "lesson", "learn"]


@dataclass
class ClipCandidate:
    start: float
    end: float
    score: float
    reasons: list[str] = field(default_factory=list)


def _read_wav_rms(wav_path: str, window_s: float = 1.0) -> list[float]:
    with wave.open(wav_path, "rb") as wf:
        framerate = wf.getframerate()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)
        samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0

    window_size = max(int(framerate * window_s), 1)
    rms = []
    for i in range(0, len(samples), window_size):
        chunk = samples[i:i + window_size]
        if len(chunk) == 0:
            continue
        rms.append(float(np.sqrt(np.mean(chunk ** 2)) + 1e-9))
    return rms


def _energy_at(rms: list[float], t: float, window_s: float = 1.0) -> float:
    idx = int(t / window_s)
    if not rms:
        return 0.0
    idx = max(0, min(idx, len(rms) - 1))
    return rms[idx]


def _keyword_hits(text: str, phrases: list[str]) -> int:
    lowered = text.lower()
    return sum(1 for p in phrases if p in lowered)


def find_candidates(
    segments: list[dict],
    audio_wav_path: str,
    min_seconds: int = 15,
    max_seconds: int = 60,
    max_clips: int = 6,
    sensitivity: float = 0.5,
) -> list[ClipCandidate]:
    """segments: [{start, end, text}] from transcription. Slides a window
    over sentence-boundary-aligned segments, scores each, then greedily
    picks the top non-overlapping candidates."""
    if not segments:
        return []

    rms = _read_wav_rms(audio_wav_path)
    avg_energy = float(np.mean(rms)) if rms else 0.0

    raw_candidates: list[ClipCandidate] = []
    n = len(segments)
    for i in range(n):
        acc_text = ""
        start = segments[i]["start"]
        for j in range(i, n):
            acc_text += " " + segments[j]["text"]
            end = segments[j]["end"]
            duration = end - start
            if duration < min_seconds:
                continue
            if duration > max_seconds:
                break

            reasons = []
            score = 0.0

            hook_hits = _keyword_hits(acc_text, HOOK_PHRASES)
            if hook_hits:
                score += 2.0 * hook_hits
                reasons.append("hook phrase")

            question_hits = _keyword_hits(acc_text, QUESTION_MARKERS)
            if question_hits:
                score += 1.0 * question_hits
                reasons.append("question/curiosity")

            emo_hits = _keyword_hits(acc_text, EMOTIONAL_WORDS)
            if emo_hits:
                score += 1.5 * emo_hits
                reasons.append("emotional language")

            edu_hits = _keyword_hits(acc_text, EDUCATIONAL_MARKERS)
            if edu_hits:
                score += 1.0 * edu_hits
                reasons.append("educational structure")

            words = len(acc_text.split())
            speech_rate = words / duration if duration else 0
            if speech_rate > 2.3:
                score += 1.5
                reasons.append("high energy delivery")

            window_energy = _energy_at(rms, start)
            if avg_energy > 0 and window_energy > avg_energy * 1.2:
                score += 1.5
                reasons.append("audio energy peak")

            if i == 0:
                score += 0.5
                reasons.append("opening hook")

            raw_candidates.append(ClipCandidate(start=start, end=end, score=score, reasons=reasons))

    # Lower sensitivity value = more permissive (more candidates kept).
    threshold = max(0.0, (1 - sensitivity) * 1.5)
    filtered = [c for c in raw_candidates if c.score >= threshold] or raw_candidates
    filtered.sort(key=lambda c: c.score, reverse=True)

    selected: list[ClipCandidate] = []
    for c in filtered:
        if any(not (c.end <= s.start or c.start >= s.end) for s in selected):
            continue
        selected.append(c)
        if len(selected) >= max_clips:
            break

    selected.sort(key=lambda c: c.start)
    return selected
