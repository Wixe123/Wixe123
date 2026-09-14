"""Builds the daily "what's changing with the YouTube/Shorts algorithm"
email digest: pulls recent posts from a handful of creator-economy RSS
feeds, then (if ANTHROPIC_API_KEY is set) asks Claude to synthesize them
into a short, actionable briefing. Falls back to a plain formatted list of
headlines if no API key is set — this always produces something mailable,
same pattern as metadata_ai.py's template fallback.

Nothing here is tied to any specific channel — this is general trend/news
commentary, not an analysis of the user's own YouTube performance (that's
what the in-app Analytics page + youtube_analytics.py already cover)."""
import html
import logging
import re
from datetime import datetime, timedelta, timezone

import feedparser

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

TREND_SOURCES = [
    ("YouTube Official Blog", "https://blog.youtube/rss/"),
    ("TubeFilter", "https://www.tubefilter.com/feed/"),
    ("Social Media Today", "https://www.socialmediatoday.com/feeds/news/"),
    ("VidIQ Blog", "https://vidiq.com/blog/feed/"),
]

MAX_PER_SOURCE = 5
MAX_AGE_DAYS = 3


def _strip_html(raw: str) -> str:
    text = re.sub(r"<[^>]+>", " ", raw or "")
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def fetch_recent_articles() -> list[dict]:
    """Raises ConnectionError if every source failed (real network outage,
    as opposed to one feed being temporarily reorganized) so the caller's
    existing transient-failure retry logic kicks in."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=MAX_AGE_DAYS)
    articles: list[dict] = []
    reachable_sources = 0

    for source_name, url in TREND_SOURCES:
        try:
            parsed = feedparser.parse(url)
        except Exception:
            logger.warning("Failed to fetch trend source %s", source_name, exc_info=True)
            continue
        if getattr(parsed, "bozo", False) and not parsed.entries:
            continue
        reachable_sources += 1

        for entry in parsed.entries[:MAX_PER_SOURCE]:
            published = None
            if getattr(entry, "published_parsed", None):
                published = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
            if published and published < cutoff:
                continue
            articles.append(
                {
                    "source": source_name,
                    "title": _strip_html(entry.get("title", "")),
                    "link": entry.get("link", ""),
                    "summary": _strip_html(entry.get("summary", ""))[:400],
                }
            )

    if reachable_sources == 0:
        raise ConnectionError("Could not reach any trend source (all RSS feeds failed).")
    return articles


def _template_digest(articles: list[dict]) -> tuple[str, str]:
    """(text_body, html_body) — plain grouped headline list, no AI needed."""
    if not articles:
        text = "No fresh posts from any tracked source in the last few days."
        return text, f"<p>{text}</p>"

    by_source: dict[str, list[dict]] = {}
    for a in articles:
        by_source.setdefault(a["source"], []).append(a)

    text_lines = []
    html_parts = []
    for source, items in by_source.items():
        text_lines.append(f"\n{source}")
        html_parts.append(f"<h3>{html.escape(source)}</h3><ul>")
        for a in items:
            text_lines.append(f"  - {a['title']} ({a['link']})")
            link = html.escape(a["link"])
            title = html.escape(a["title"])
            summary_html = f"<br><small>{html.escape(a['summary'])}</small>" if a["summary"] else ""
            html_parts.append(f'<li><a href="{link}">{title}</a>{summary_html}</li>')
        html_parts.append("</ul>")

    return "\n".join(text_lines).strip(), "".join(html_parts)


def _claude_digest(articles: list[dict]) -> tuple[str, str] | None:
    if not settings.ANTHROPIC_API_KEY or not articles:
        return None
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        source_text = "\n\n".join(
            f"[{a['source']}] {a['title']}\n{a['summary']}" for a in articles
        )
        prompt = (
            "You write a short daily briefing for a YouTube Shorts creator on what's "
            "changing with the algorithm/platform and what's working right now. Given "
            "these recent headlines/summaries from creator-economy sources, write a "
            "concise briefing (150-250 words) in plain text: 2-4 sections with short "
            "headers, each a couple of punchy sentences — no fluff, no generic advice "
            "not grounded in the source material below. If the material doesn't say "
            "much of substance, say so briefly instead of padding it out.\n\n"
            f"{source_text[:6000]}"
        )
        response = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=500,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "".join(block.text for block in response.content if hasattr(block, "text")).strip()
        if not text:
            return None
        html_body = "".join(f"<p>{html.escape(line)}</p>" for line in text.split("\n") if line.strip())
        return text, html_body
    except Exception:
        logger.warning("Claude digest synthesis failed, falling back to template", exc_info=True)
        return None


def build_digest_email(articles: list[dict]) -> dict:
    """Returns {"subject", "text_body", "html_body"}."""
    date_str = datetime.now(timezone.utc).strftime("%B %d, %Y")
    synthesized = _claude_digest(articles)
    body_text, body_html = synthesized if synthesized else _template_digest(articles)

    sources_footer_text = "\n\nSources: " + ", ".join(sorted({a["source"] for a in articles})) if articles else ""
    sources_footer_html = (
        "<p><small>Sources: " + ", ".join(sorted({a["source"] for a in articles})) + "</small></p>"
        if articles
        else ""
    )

    return {
        "subject": f"ShortsForge daily trends briefing — {date_str}",
        "text_body": body_text + sources_footer_text,
        "html_body": f"<h2>Daily YouTube/Shorts trends briefing</h2>{body_html}{sources_footer_html}",
    }
