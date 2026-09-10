from app.services import tts


def test_synthesize_uses_edge_tts_when_it_succeeds(monkeypatch, tmp_path):
    fake_words = [{"word": "Hi", "start": 0.0, "end": 0.3}]

    async def fake_edge_tts_async(text, out_path, voice):
        return fake_words

    monkeypatch.setattr(tts, "_edge_tts_async", fake_edge_tts_async)

    out_path = str(tmp_path / "out.mp3")
    result = tts.synthesize("Hi", out_path)

    assert result["engine"] == "edge-tts"
    assert result["words"] == fake_words
    assert result["audio_path"] == out_path


def test_synthesize_falls_back_to_espeak_on_edge_tts_failure(monkeypatch, tmp_path):
    async def failing_edge_tts_async(text, out_path, voice):
        raise RuntimeError("403 from edge-tts endpoint")

    monkeypatch.setattr(tts, "_edge_tts_async", failing_edge_tts_async)
    monkeypatch.setattr(
        tts, "_espeak_fallback", lambda text, out_path: [{"word": "Hi", "start": 0.0, "end": 0.3}]
    )

    out_path = str(tmp_path / "out.wav")
    result = tts.synthesize("Hi", out_path)

    assert result["engine"] == "espeak-ng"
    assert result["words"] == [{"word": "Hi", "start": 0.0, "end": 0.3}]


def test_espeak_fallback_produces_monotonic_word_timings(monkeypatch, tmp_path):
    out_path = str(tmp_path / "out.wav")

    monkeypatch.setattr(tts.subprocess, "run", lambda *a, **k: None)
    monkeypatch.setattr(tts.ffmpeg_utils, "get_duration_seconds", lambda path: 4.0)

    words = tts._espeak_fallback("This is a short test sentence.", out_path)

    assert [w["word"] for w in words] == ["This", "is", "a", "short", "test", "sentence."]
    for prev, nxt in zip(words, words[1:]):
        assert prev["start"] <= prev["end"] <= nxt["start"]
    assert words[-1]["end"] <= 4.0


def test_espeak_fallback_handles_empty_text(monkeypatch, tmp_path):
    out_path = str(tmp_path / "out.wav")
    monkeypatch.setattr(tts.subprocess, "run", lambda *a, **k: None)
    monkeypatch.setattr(tts.ffmpeg_utils, "get_duration_seconds", lambda path: 0.0)

    assert tts._espeak_fallback("", out_path) == []
