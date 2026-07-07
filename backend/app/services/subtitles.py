"""Builds .ass subtitle files with word-by-word highlight animation from
Whisper word timestamps, for ffmpeg to burn in via the `subtitles` filter."""
import re

EMOJI_MAP = {
    "love": "❤️", "money": "💰", "win": "🏆", "winning": "🏆", "fire": "🔥",
    "crazy": "🤯", "insane": "🤯", "funny": "😂", "laugh": "😂", "shocking": "😱",
    "secret": "🤫", "warning": "⚠️", "important": "❗", "idea": "💡", "growth": "📈",
    "fail": "❌", "success": "✅", "yes": "✅", "no": "❌", "time": "⏰",
    "fast": "⚡", "amazing": "🤩", "scary": "😨", "sad": "😢",
}

ALIGNMENT_BY_POSITION = {"bottom": 2, "center": 5, "top": 8}


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
    font = style.get("font", "Helvetica Neue")
    base_color = _hex_to_ass_color(style.get("color", "#FFFFFF"))
    highlight_color = _hex_to_ass_color(style.get("highlight_color", "#CCA660"))
    stroke_color = _hex_to_ass_color(style.get("stroke_color", "#000000"))
    alignment = ALIGNMENT_BY_POSITION.get(style.get("position", "bottom"), 2)
    emoji_enabled = style.get("emoji_enabled", True)
    font_size = style.get("font_size", 68)
    # "bold" defaults to False for a clean/editorial caption look (thin
    # weight, subtle outline) rather than the heavy MrBeast-style default.
    bold_flag = -1 if style.get("bold", False) else 0
    outline_width = style.get("outline_width", 2)

    clip_words = [
        {**w, "start": w["start"] - clip_start, "end": w["end"] - clip_start}
        for w in words
        if w["start"] >= clip_start and w["end"] <= clip_end
    ]
    lines = _group_words(clip_words)

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
    for line in lines:
        for active_idx, active_word in enumerate(line):
            start_t = active_word["start"]
            end_t = active_word["end"]
            if end_t <= start_t:
                continue
            parts = []
            for idx, w in enumerate(line):
                text = w["word"].strip()
                if emoji_enabled:
                    emoji = _maybe_emoji(text)
                    if emoji:
                        text = f"{text}{emoji}"
                color = highlight_color if idx == active_idx else base_color
                parts.append(f"{{\\c{color}}}{text}")
            text_line = " ".join(parts)
            events.append(
                f"Dialogue: 0,{_format_time(start_t)},{_format_time(end_t)},Default,,0,0,0,,{text_line}"
            )

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(header)
        f.write("\n".join(events))

    return out_path
