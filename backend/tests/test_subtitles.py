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
    subtitles.build_ass(
        words, clip_start=0.0, clip_end=2.1, style={"max_words_per_line": 4}, out_path=str(out_path)
    )

    texts = _dialogue_texts(out_path.read_text())
    assert [t.split() for t in texts] == [
        ["here's"],
        ["here's", "why"],
        ["here's", "why", "nobody"],
        ["here's", "why", "nobody", "tells"],
        ["you"],
    ]


def test_default_max_words_per_line_is_two(tmp_path):
    words = [
        _word("here's", 0.0, 0.4),
        _word("why", 0.5, 0.8),
        _word("nobody", 0.9, 1.3),
    ]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=1.3, style={}, out_path=str(out_path))

    texts = _dialogue_texts(out_path.read_text())
    for text in texts:
        assert len(text.split()) <= 2


def test_default_position_is_center(tmp_path):
    words = [_word("hi", 0.0, 0.4)]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=0.4, style={}, out_path=str(out_path))

    content = out_path.read_text()
    style_line = next(l for l in content.splitlines() if l.startswith("Style: Default,"))
    alignment = style_line.split(",")[18]
    assert alignment == "5"  # libass center-middle alignment code


def test_line_never_exceeds_max_words_per_line(tmp_path):
    words = [_word(f"word{i}", i * 0.5, i * 0.5 + 0.4) for i in range(9)]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=4.5, style={"max_words_per_line": 3}, out_path=str(out_path))

    texts = _dialogue_texts(out_path.read_text())
    assert texts, "expected at least one caption event"
    for text in texts:
        assert len(text.split()) <= 3


def _dialogue_time_ranges(ass_content: str) -> list[tuple[str, str]]:
    ranges = []
    for line in ass_content.splitlines():
        if not line.startswith("Dialogue:"):
            continue
        parts = line.split(",")
        ranges.append((parts[1], parts[2]))
    return ranges


def _to_seconds(ass_time: str) -> float:
    h, m, s = ass_time.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


def test_overlapping_word_timestamps_never_produce_overlapping_events(tmp_path):
    # Regression: Whisper occasionally emits out-of-order/overlapping word
    # timestamps, which used to render as two caption events stacked on
    # screen at once (reported as "two fonts overlapping each other").
    words = [
        _word("thought", 0.0, 0.6),
        _word("of", 0.4, 0.9),  # overlaps the previous word's end
        _word("a", 0.85, 1.0),
        _word("stupid", 0.7, 1.4),  # starts before the previous word ends
        _word("name", 1.4, 1.8),
    ]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(words, clip_start=0.0, clip_end=1.8, style={}, out_path=str(out_path))

    ranges = [(_to_seconds(s), _to_seconds(e)) for s, e in _dialogue_time_ranges(out_path.read_text())]
    for i in range(len(ranges) - 1):
        assert ranges[i][1] <= ranges[i + 1][0], f"events {i} and {i + 1} overlap: {ranges[i]} vs {ranges[i + 1]}"


def test_speaker_colors_cycle_on_long_pauses(tmp_path):
    words = [
        _word("hello", 0.0, 0.4),
        _word("there", 0.4, 0.8),
        # long gap here should trigger a color change (new "speaker")
        _word("hi", 2.0, 2.4),
        _word("back", 2.4, 2.8),
    ]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(
        words, clip_start=0.0, clip_end=2.8, style={"max_words_per_line": 4}, out_path=str(out_path)
    )

    content = out_path.read_text()
    # The final event reveals all four words; the first two should be in
    # the default white and the last two in a different accent color.
    dialogue_lines = [l for l in content.splitlines() if l.startswith("Dialogue:")]
    last_event = dialogue_lines[-1]
    colors_in_order = re.findall(r"\\c(&H[0-9A-F]+)", last_event)
    assert colors_in_order[0] == colors_in_order[1]
    assert colors_in_order[2] == colors_in_order[3]
    assert colors_in_order[0] != colors_in_order[2]


def test_speaker_colors_can_be_disabled(tmp_path):
    words = [_word("hi", 0.0, 0.4), _word("there", 2.0, 2.4)]
    out_path = tmp_path / "clip.ass"
    subtitles.build_ass(
        words,
        clip_start=0.0,
        clip_end=2.4,
        style={"max_words_per_line": 2, "speaker_colors_enabled": False, "color": "#FFFFFF", "highlight_color": "#FFD23F"},
        out_path=str(out_path),
    )
    content = out_path.read_text()
    dialogue_lines = [l for l in content.splitlines() if l.startswith("Dialogue:")]
    last_event = dialogue_lines[-1]
    colors_in_order = re.findall(r"\\c(&H[0-9A-F]+)", last_event)
    # base color for the earlier word, highlight color for the just-revealed one
    assert colors_in_order[0] == subtitles._hex_to_ass_color("#FFFFFF")
    assert colors_in_order[1] == subtitles._hex_to_ass_color("#FFD23F")


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
