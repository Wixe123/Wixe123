"""Builds .ass subtitle files with word-by-word pop-in animation from
Whisper word timestamps, for ffmpeg to burn in via the `subtitles` filter.

Words appear one at a time as they're spoken, building up a short line of
up to `max_words_per_line` words; once that cap is hit the next word starts
a fresh line (the old words disappear rather than scrolling), so at most
that many words are ever on screen at once."""
import re

EMOJI_MAP = {
    "love": "❤️", "money": "💰", "win": "🏆", "winning": "🏆", "fire": "🔥",
    "crazy": "🤯", "insane": "🤯", "funny": "😂", "laugh": "😂", "shocking": "😱",
    "secret": "🤫", "warning": "⚠️", "important": "❗", "idea": "💡", "growth": "📈",
    "fail": "❌", "success": "✅", "yes": "✅", "no": "❌", "time": "⏰",
    "fast": "⚡", "amazing": "🤩", "scary": "😨", "sad": "😢",
}

ALIGNMENT_BY_POSITION = {"bottom": 2, "center": 5, "top": 8}

# White first so the most common/default speaker reads as the "main" color;
# the rest are accents cycled in for other speakers.
SPEAKER_COLOR_PALETTE = ["#FFFFFF", "#FFD23F", "#5DD9C1", "#FF6B6B", "#9D8DF1"]
SPEAKER_TURN_GAP_SECONDS = 0.6


def _hex_to_ass_color(hex_color: str) -> str:
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        hex_color = "FFFFFF"
    r, g, b = hex_color[0:2], hex_color[2:4], hex_color[4:6]
    return f"&H00{b}{g}{r}".upper()


def _group_words(words: list[dict], max_words_per_line: int = 4) -> list[list[dict]]:
    lines: list[list[dict]] = []
    current: list[dict] = []
    for w in words:
        current.append(w)
        text = w["word"].strip()
        if len(current) >= max_words_per_line or text.endswith((".", "!", "?")):
            lines.append(current)
            current = []
    if current:
        lines.append(current)
    return lines


def _clean_word_timings(words: list[dict]) -> list[dict]:
    """Whisper's word-level timestamps aren't always perfectly monotonic —
    two words can occasionally come back with overlapping or out-of-order
    start/end times. Left alone, that produces two caption events active on
    screen at the same instant, rendering as stacked/overlapping text.
    Sorting and clamping each word's start to the previous word's end
    guarantees the reveal sequence below can never overlap."""
    cleaned: list[dict] = []
    prev_end = -1.0
    for w in sorted(words, key=lambda w: w["start"]):
        start = max(w["start"], prev_end)
        if w["end"] <= start:
            continue
        cleaned.append({**w, "start": start})
        prev_end = w["end"]
    return cleaned


def _assign_turn_colors(words: list[dict], palette: list[str], gap_s: float) -> list[str]:
    """Approximates "who's talking" by cycling the color palette whenever
    the gap between two consecutive words exceeds gap_s. This is a pause
    heuristic, not real speaker diarization (which needs a much heavier
    voice-identification model) — it reads well for back-and-forth
    conversation but a single speaker pausing mid-thought can flip colors
    when a real diarizer wouldn't."""
    colors = []
    palette_idx = 0
    prev_end = None
    for w in words:
        if prev_end is not None and w["start"] - prev_end > gap_s:
            palette_idx = (palette_idx + 1) % len(palette)
        colors.append(palette[palette_idx])
        prev_end = w["end"]
    return colors


def _maybe_emoji(word: str) -> str:
    clean = re.sub(r"[^a-zA-Z]", "", word).lower()
    return EMOJI_MAP.get(clean, "")


def _format_time(seconds: float) -> str:
    seconds = max(0.0, seconds)
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = seconds % 60
    return f"{h}:{m:02d}:{s:05.2f}"


def build_ass(
    words: list[dict],
    clip_start: float,
    clip_end: float,
    style: dict,
    out_path: str,
) -> str:
    # Playfair Display is bundled into the Docker image (see Dockerfile) so
    # this renders identically everywhere, regardless of what's on the host.
    font = style.get("font", "Playfair Display")
    base_color = _hex_to_ass_color(style.get("color", "#FFFFFF"))
    stroke_color = _hex_to_ass_color(style.get("stroke_color", "#000000"))
    alignment = ALIGNMENT_BY_POSITION.get(style.get("position", "center"), 5)
    emoji_enabled = style.get("emoji_enabled", True)
    font_size = style.get("font_size", 84)
    max_words_per_line = style.get("max_words_per_line", 2)
    lowercase = style.get("lowercase", True)
    # Only a Bold weight is bundled for Playfair Display, so default to it —
    # unlike the Inter/"light" style, this look is meant to read as bold serif.
    bold_flag = -1 if style.get("bold", True) else 0
    outline_width = style.get("outline_width", 2)
    speaker_colors_enabled = style.get("speaker_colors_enabled", True)
    speaker_palette = style.get("speaker_color_palette", SPEAKER_COLOR_PALETTE)
    # Only used when speaker_colors_enabled is off, to highlight the
    # just-revealed word against the already-shown ones.
    highlight_color = _hex_to_ass_color(style.get("highlight_color", style.get("color", "#FFFFFF")))

    clip_words = _clean_word_timings(
        {**w, "start": w["start"] - clip_start, "end": w["end"] - clip_start}
        for w in words
        if w["start"] >= clip_start and w["end"] <= clip_end
    )

    if speaker_colors_enabled:
        turn_colors = _assign_turn_colors(clip_words, speaker_palette, SPEAKER_TURN_GAP_SECONDS)
        for w, color in zip(clip_words, turn_colors):
            w["_color"] = _hex_to_ass_color(color)

    lines = _group_words(clip_words, max_words_per_line)

    # Flat, clip-relative time ordering across line boundaries so each
    # word's caption can hold until the very next word appears (no gaps
    # or flicker between the last word of one line and the first of the
    # next).
    flat_words = [w for line in lines for w in line]

    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,{font},{font_size},{base_color},{base_color},{stroke_color},&H00000000,{bold_flag},0,0,0,100,100,0,0,1,{outline_width},1,{alignment},60,60,120,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

    events = []
    word_index = 0
    for line in lines:
        for reveal_idx in range(len(line)):
            start_t = line[reveal_idx]["start"]
            # Hold until the next word anywhere in the clip appears, so
            # there's no blank flicker between words or between lines.
            next_word = flat_words[word_index + 1] if word_index + 1 < len(flat_words) else None
            end_t = next_word["start"] if next_word else line[reveal_idx]["end"] + 1.5
            word_index += 1
            if end_t <= start_t:
                continue

            parts = []
            for idx, w in enumerate(line[: reveal_idx + 1]):
                text = w["word"].strip()
                if lowercase:
                    text = text.lower()
                if emoji_enabled:
                    emoji = _maybe_emoji(text)
                    if emoji:
                        text = f"{text}{emoji}"
                if speaker_colors_enabled:
                    color = w.get("_color", base_color)
                else:
                    color = highlight_color if idx == reveal_idx else base_color
                parts.append(f"{{\\c{color}}}{text}")
            text_line = " ".join(parts)
            events.append(
                f"Dialogue: 0,{_format_time(start_t)},{_format_time(end_t)},Default,,0,0,0,,{text_line}"
            )

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(header)
        f.write("\n".join(events))

    return out_path
