"""Analyzes a reference video's transcript to extract a repeatable "style
profile" — hook pattern, pacing, sentence rhythm — so the user can
deliberately apply the same approach to their own (different) content.

There's no reliable "find me the biggest Shorts creators right now" API —
YouTube doesn't expose one. This works the other way around: point it at
one specific reference video and get back what pattern to copy. It never
stores or republishes the reference creator's actual content, only a
written analysis of their technique.
"""
from app.core.config import get_settings
from app.services.clip_scoring import EDUCATIONAL_MARKERS, EMOTIONAL_WORDS, HOOK_PHRASES, QUESTION_MARKERS

settings = get_settings()


def _heuristic_findings(segments: list[dict]) -> dict:
    if not segments:
        return {
            "hook": "No speech detected to analyze.",
            "pacing": "",
            "structure": "",
        }

    full_text = " ".join(s["text"] for s in segments).lower()
    opening_text = " ".join(s["text"] for s in segments[:2]).lower()

    hook_hits = [p for p in HOOK_PHRASES if p in opening_text]
    question_hits = [p for p in QUESTION_MARKERS if p in opening_text]
    emo_hits = [w for w in EMOTIONAL_WORDS if w in full_text]
    edu_hits = [w for w in EDUCATIONAL_MARKERS if w in full_text]

    word_count = len(full_text.split())
    duration = segments[-1]["end"] - segments[0]["start"]
    words_per_second = word_count / duration if duration else 0
    avg_segment_seconds = duration / len(segments) if segments else 0

    hook_keywords = hook_hits + question_hits
    hook = (
        f"Opens with: {', '.join(hook_keywords)}"
        if hook_keywords
        else "No scripted hook phrase/question in the opening lines — the hook is likely "
        "visual or tonal (a strong first frame, a jump cut, delivery energy) rather than "
        "what's said."
    )
    pacing = (
        f"~{words_per_second:.1f} words/sec, averaging a new beat every "
        f"~{avg_segment_seconds:.1f}s ("
        f"{'fast, high-energy delivery' if words_per_second > 2.3 else 'measured, deliberate pacing'})."
    )
    structure = (
        f"Emotional language: {', '.join(emo_hits[:5]) if emo_hits else 'none detected'}. "
        f"Educational framing (steps/lessons): {', '.join(edu_hits[:5]) if edu_hits else 'none detected'}."
    )
    return {"hook": hook, "pacing": pacing, "structure": structure}


def _claude_summary(transcript_text: str, heuristics: dict) -> str:
    if not settings.ANTHROPIC_API_KEY:
        return ""
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        prompt = (
            "You reverse-engineer what makes a short-form video's structure work, so "
            "another creator can deliberately apply the same pattern to their own "
            "(different) content — not copy the content itself. Given this transcript "
            "and some measured stats, write a short actionable style guide (150-250 "
            "words): how it hooks in the first 2-3 seconds, its pacing/rhythm, sentence "
            "structure, and one concrete thing to try replicating. Plain text, no "
            "markdown headers.\n\n"
            f"Measured stats — hook: {heuristics['hook']} | pacing: {heuristics['pacing']} | "
            f"structure: {heuristics['structure']}\n\n"
            f"Transcript:\n{transcript_text[:4000]}"
        )
        response = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=500,
            messages=[{"role": "user", "content": prompt}],
        )
        return "".join(block.text for block in response.content if hasattr(block, "text")).strip()
    except Exception:
        return ""


def analyze_style(transcript: dict) -> dict:
    """transcript: {"segments": [...], "words": [...]} from
    transcription.transcribe(). Returns hook_analysis/pacing_analysis/
    structure_analysis/summary — summary is "" if no ANTHROPIC_API_KEY is
    set, in which case the three heuristic fields stand alone."""
    segments = transcript.get("segments", [])
    heuristics = _heuristic_findings(segments)
    transcript_text = " ".join(s["text"] for s in segments)

    return {
        "hook_analysis": heuristics["hook"],
        "pacing_analysis": heuristics["pacing"],
        "structure_analysis": heuristics["structure"],
        "summary": _claude_summary(transcript_text, heuristics),
    }
