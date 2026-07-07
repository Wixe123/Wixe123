"""Generates YouTube title/description/hashtags/keywords/SEO score for a
clip. Uses Claude when ANTHROPIC_API_KEY is set, otherwise falls back to a
deterministic template built from the transcript — no network dependency
required to run the app end-to-end."""
import json
import re

from app.core.config import get_settings

settings = get_settings()

STOPWORDS = {
    "the", "a", "an", "is", "are", "was", "were", "and", "or", "but", "to",
    "of", "in", "on", "for", "with", "this", "that", "it", "you", "i", "we",
    "so", "just", "like", "be", "as", "at", "by", "from",
}


def _keywords_from_text(text: str, limit: int = 8) -> list[str]:
    words = re.findall(r"[a-zA-Z']+", text.lower())
    freq: dict[str, int] = {}
    for w in words:
        if len(w) < 4 or w in STOPWORDS:
            continue
        freq[w] = freq.get(w, 0) + 1
    ranked = sorted(freq.items(), key=lambda kv: kv[1], reverse=True)
    return [w for w, _ in ranked[:limit]]


def _template_metadata(transcript_text: str, reasons: list[str]) -> dict:
    keywords = _keywords_from_text(transcript_text)
    snippet = transcript_text.strip().split(".")[0][:80].strip()
    title = (snippet or "Watch this clip").rstrip(",") + " #shorts"
    title = title[:95]

    # Hashtags can't contain apostrophes etc. (breaks on most platforms) even
    # though keywords/tags keep contractions like "here's" intact.
    hashtags = [f"#{re.sub(r'[^a-z0-9]', '', k)}" for k in keywords[:5]] + ["#shorts"]
    hashtags = [h for h in hashtags if len(h) > 1]
    description = (
        f"{snippet}...\n\n"
        f"Highlighted for: {', '.join(reasons) if reasons else 'strong moment'}.\n\n"
        + " ".join(hashtags)
    )
    seo_score = min(100.0, 40 + 6 * len(keywords) + 5 * len(reasons))
    return {
        "title": title,
        "description": description,
        "hashtags": hashtags,
        "keywords": keywords,
        "seo_score": round(seo_score, 1),
    }


def _claude_metadata(transcript_text: str, reasons: list[str]) -> dict | None:
    if not settings.ANTHROPIC_API_KEY:
        return None
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        prompt = (
            "You write metadata for a YouTube Short. Given the transcript "
            "below, return strict JSON with keys: title (<=95 chars, "
            "punchy, include relevant emotion/curiosity hook), description "
            "(2-3 sentences plus hashtags), hashtags (array of 5-8 strings "
            "starting with #), keywords (array of 5-10 lowercase strings), "
            "seo_score (0-100 number).\n\n"
            f"Why this moment was selected: {', '.join(reasons) or 'strong moment'}\n\n"
            f"Transcript:\n{transcript_text[:4000]}"
        )
        response = client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=600,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "".join(block.text for block in response.content if hasattr(block, "text"))
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if not match:
            return None
        return json.loads(match.group(0))
    except Exception:
        return None


def generate_metadata(transcript_text: str, reasons: list[str]) -> dict:
    result = _claude_metadata(transcript_text, reasons)
    if result:
        return result
    return _template_metadata(transcript_text, reasons)
