"""Tests for the word-by-word pop-in caption builder: words must appear
progressively (one at a time, as spoken) and a line must never exceed
max_words_per_line words on screen at once."""
import re

from app.services import subtitles


def _word(text, start, end):
    return {"word": text, "start": start, "end": end}


def _dialogue_texts(ass_content: str) -> list[str]:
    texts = []
    for line in ass_content.splitlines():
        if not line.startswith("Dialogue:"):
            continue
        raw_text = line.split(",", 9)[-1]
        plain = re.sub(r"\{[^}]*\}", "", raw_text)
        texts.append(plain)
    return texts


def test_words_reveal_one_at_a_time(tmp_path):
    words = [
        _word("here's", 0.0, 0.4),
        _word("why", 0.5, 0.8),
        _word("nobody", 0.9, 1.3),
        _word("tells", 1.4, 1.7),
        _word("you", 1.8, 2.1),
    ]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=2.1, style={}, out_path=str(out_path))

    texts = _dialogue_texts(out_path.read_text())
    assert [t.split() for t in texts] == [
        ["here's"],
        ["here's", "why"],
        ["here's", "why", "nobody"],
        ["here's", "why", "nobody", "tells"],
        ["you"],
    ]


def test_line_never_exceeds_max_words_per_line(tmp_path):
    words = [_word(f"word{i}", i * 0.5, i * 0.5 + 0.4) for i in range(9)]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=4.5, style={"max_words_per_line": 3}, out_path=str(out_path))

    texts = _dialogue_texts(out_path.read_text())
    assert texts, "expected at least one caption event"
    for text in texts:
        assert len(text.split()) <= 3


def test_words_outside_clip_bounds_are_excluded(tmp_path):
    words = [
        _word("before", -1.0, -0.5),
        _word("inside", 0.0, 0.5),
        _word("after", 10.0, 10.5),
    ]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=1.0, style={}, out_path=str(out_path))

    texts = _dialogue_texts(out_path.read_text())
    joined = " ".join(texts)
    assert "before" not in joined
    assert "after" not in joined
    assert "inside" in joined
