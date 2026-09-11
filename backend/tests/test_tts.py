import base64

from app.services import tts


def test_words_from_character_alignment_groups_by_whitespace():
    text = "Hi there"
    characters = list(text)
    starts = [i * 0.1 for i in range(len(characters))]
    ends = [s + 0.1 for s in starts]

    words = tts._words_from_character_alignment(characters, starts, ends)

    assert [w["word"] for w in words] == ["Hi", "there"]
    assert words[0]["start"] == 0.0
    assert words[1]["start"] > words[0]["end"]


def test_elevenlabs_tts_writes_audio_and_returns_words(monkeypatch, tmp_path):
    fake_audio = b"fake-mp3-bytes"

    class _FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "audio_base64": base64.b64encode(fake_audio).decode(),
                "alignment": {
                    "characters": ["H", "i"],
                    "character_start_times_seconds": [0.0, 0.1],
                    "character_end_times_seconds": [0.1, 0.2],
                },
            }

    monkeypatch.setattr(tts.httpx, "post", lambda *a, **k: _FakeResponse())

    out_path = str(tmp_path / "out.mp3")
    words = tts._elevenlabs_tts("Hi", out_path, "some-voice-id")

    assert words == [{"word": "Hi", "start": 0.0, "end": 0.2}]
    with open(out_path, "rb") as f:
        assert f.read() == fake_audio


def test_synthesize_uses_elevenlabs_when_configured(monkeypatch, tmp_path):
    monkeypatch.setattr(tts.settings, "ELEVENLABS_API_KEY", "fake-key")
    fake_words = [{"word": "Hi", "start": 0.0, "end": 0.3}]
    monkeypatch.setattr(tts, "_elevenlabs_tts", lambda text, out_path, voice_id: fake_words)

    out_path = str(tmp_path / "out.mp3")
    result = tts.synthesize("Hi", out_path)

    assert result["engine"] == "elevenlabs"
    assert result["words"] == fake_words


def test_synthesize_falls_back_to_edge_tts_when_elevenlabs_fails(monkeypatch, tmp_path):
    monkeypatch.setattr(tts.settings, "ELEVENLABS_API_KEY", "fake-key")

    def failing_elevenlabs(text, out_path, voice_id):
        raise RuntimeError("elevenlabs quota exceeded")

    monkeypatch.setattr(tts, "_elevenlabs_tts", failing_elevenlabs)

    fake_words = [{"word": "Hi", "start": 0.0, "end": 0.3}]

    async def fake_edge_tts_async(text, out_path, voice):
        return fake_words

    monkeypatch.setattr(tts, "_edge_tts_async", fake_edge_tts_async)

    out_path = str(tmp_path / "out.mp3")
    result = tts.synthesize("Hi", out_path)

    assert result["engine"] == "edge-tts"


def test_synthesize_skips_elevenlabs_when_no_api_key(monkeypatch, tmp_path):
    monkeypatch.setattr(tts.settings, "ELEVENLABS_API_KEY", "")
    monkeypatch.setattr(
        tts, "_elevenlabs_tts", lambda *a, **k: (_ for _ in ()).throw(AssertionError("should not be called"))
    )
    fake_words = [{"word": "Hi", "start": 0.0, "end": 0.3}]

    async def fake_edge_tts_async(text, out_path, voice):
        return fake_words

    monkeypatch.setattr(tts, "_edge_tts_async", fake_edge_tts_async)

    out_path = str(tmp_path / "out.mp3")
    result = tts.synthesize("Hi", out_path)

    assert result["engine"] == "edge-tts"


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
