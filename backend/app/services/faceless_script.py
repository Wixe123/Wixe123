"""Picks a fresh topic within the user's niche and writes a Vox-style
explainer script broken into "beats" — each beat is one narration
sentence/segment paired with what should be on screen while it plays
(a photo/map search query, a chart to render, or a big text callout).

Requires ANTHROPIC_API_KEY. Unlike metadata_ai.py's title/description
generation, there's no sensible template fallback here — picking a real
topic and writing accurate narration needs an actual model, not string
templates."""
import json
import re

from app.core.config import get_settings

settings = get_settings()


class ScriptGenerationError(RuntimeError):
    pass


def generate_script(niche: str, recent_topics: list[str]) -> dict:
    """Returns {"topic": str, "beats": [{"narration": str, "visual": {...}}]}.

    visual.type is one of:
      - "image": {"type": "image", "query": "<wikimedia commons search query>"}
      - "chart": {"type": "chart", "chart_type": "bar"|"line", "title": str,
                  "labels": [str], "values": [number], "unit": str}
      - "comparison": {"type": "comparison", "left_label": str, "right_label": str,
                        "left_value": str, "right_value": str,
                        "left_query": str, "right_query": str}
        (left_query/right_query are optional wikimedia searches for a real
        photo per side; left_value/right_value are optional short numbers
        or phrases to show when there's no photo)
      - "callout": {"type": "callout", "text": str}
    """
    if not settings.ANTHROPIC_API_KEY:
        raise ScriptGenerationError(
            "ANTHROPIC_API_KEY is required for faceless video generation — "
            "picking a real topic and writing accurate narration needs an "
            "actual model, there's no template fallback for this feature."
        )

    import anthropic

    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    avoid = (
        "Avoid repeating any of these recently-covered topics: " + "; ".join(recent_topics)
        if recent_topics
        else ""
    )
    prompt = (
        f"You write short (45-65 second) Vox-style explainer video scripts for a "
        f'faceless YouTube Shorts channel about "{niche}". {avoid}\n\n'
        "Ground rules:\n"
        "- Pick ONE specific, narrow topic within the niche — not a broad overview.\n"
        "- Only cite facts/figures you're confident are well-established and "
        "easily verifiable. Never invent precise statistics for dramatic effect — "
        "if you're not sure of a real number, describe the fact in words instead "
        "of putting a specific figure on it.\n"
        "- Write in short, punchy sentences meant to be read aloud by narration.\n"
        "- Break the script into 5-9 beats. Each beat is one or two sentences of "
        "narration plus ONE visual for what's on screen while it plays.\n"
        "- Use a 'chart' visual only when you have real comparable numbers to plot.\n"
        "- Use a 'comparison' visual for a clear before/after or head-to-head "
        "contrast (two time periods, two options, two outcomes) — give short "
        "left/right labels and, if you have them, short left/right values (a "
        "number or a few words). Only add left_query/right_query when a real, "
        "specific photo for each side would exist on Wikimedia Commons.\n"
        "- Use a 'callout' visual for a single striking phrase or number, no chart needed.\n"
        "- Use an 'image' visual otherwise, with a specific, literal search query "
        "for a real photo/map that would exist on Wikimedia Commons (e.g. a place, "
        "person, or historical event name) — not an abstract concept.\n\n"
        "Return strict JSON, no markdown fences, matching this shape:\n"
        "{\n"
        '  "topic": "string",\n'
        '  "beats": [\n'
        "    {\n"
        '      "narration": "string",\n'
        '      "visual": {"type": "image", "query": "string"}\n'
        "        | {\"type\": \"chart\", \"chart_type\": \"bar\"|\"line\", \"title\": \"string\", "
        '"labels": ["string"], "values": [number], "unit": "string"}\n'
        "        | {\"type\": \"comparison\", \"left_label\": \"string\", \"right_label\": \"string\", "
        '"left_value": "string", "right_value": "string", "left_query": "string", "right_query": "string"}\n'
        '        | {"type": "callout", "text": "string"}\n'
        "    }\n"
        "  ]\n"
        "}"
    )
    try:
        response = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=1500,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "".join(block.text for block in response.content if hasattr(block, "text"))
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if not match:
            raise ScriptGenerationError("Model response didn't contain JSON.")
        data = json.loads(match.group(0))
    except ScriptGenerationError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise ScriptGenerationError(f"Script generation failed: {exc}") from exc

    beats = data.get("beats") or []
    if not beats:
        raise ScriptGenerationError("Model returned no beats.")
    return {"topic": data.get("topic", "").strip() or "Untitled topic", "beats": beats}


def full_narration_text(beats: list[dict]) -> str:
    return " ".join(b["narration"].strip() for b in beats if b.get("narration"))
