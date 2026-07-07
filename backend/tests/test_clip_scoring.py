import wave

import numpy as np

from app.services.clip_scoring import find_candidates


def _write_wav(path, duration_s: float, framerate: int = 16000):
    n_samples = int(duration_s * framerate)
    t = np.linspace(0, duration_s, n_samples, endpoint=False)
    samples = (np.sin(2 * np.pi * 220 * t) * 3000).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(framerate)
        wf.writeframes(samples.tobytes())


def test_candidates_respect_min_and_max_duration(tmp_path):
    wav_path = tmp_path / "audio.wav"
    _write_wav(wav_path, duration_s=40)

    segments = [
        {"start": 0.0, "end": 5.0, "text": "here's why nobody tells you the secret"},
        {"start": 5.0, "end": 20.0, "text": "this changed everything and it was amazing"},
        {"start": 20.0, "end": 40.0, "text": "step one is the most important lesson"},
    ]
    candidates = find_candidates(segments, str(wav_path), min_seconds=10, max_seconds=30, max_clips=6, sensitivity=0.5)

    assert candidates
    for c in candidates:
        assert 10 <= (c.end - c.start) <= 30


def test_candidates_never_overlap(tmp_path):
    wav_path = tmp_path / "audio.wav"
    _write_wav(wav_path, duration_s=60)
    segments = [
        {"start": float(i * 5), "end": float(i * 5 + 5), "text": "here's why this is amazing and shocking"}
        for i in range(12)
    ]
    candidates = find_candidates(segments, str(wav_path), min_seconds=10, max_seconds=20, max_clips=4, sensitivity=0.8)

    for a in candidates:
        for b in candidates:
            if a is b:
                continue
            assert a.end <= b.start or a.start >= b.end


def test_candidates_capped_at_max_clips(tmp_path):
    wav_path = tmp_path / "audio.wav"
    _write_wav(wav_path, duration_s=120)
    segments = [
        {"start": float(i * 10), "end": float(i * 10 + 10), "text": "here's why this is amazing"}
        for i in range(12)
    ]
    candidates = find_candidates(segments, str(wav_path), min_seconds=10, max_seconds=15, max_clips=3, sensitivity=0.8)
    assert len(candidates) <= 3


def test_empty_segments_returns_no_candidates(tmp_path):
    wav_path = tmp_path / "audio.wav"
    _write_wav(wav_path, duration_s=5)
    assert find_candidates([], str(wav_path)) == []
