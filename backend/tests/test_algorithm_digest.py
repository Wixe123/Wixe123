"""Tests for the daily trends-digest builder. The Celery task itself
(send_algorithm_digest_task) isn't covered here — these test the pure
fetch/build logic in isolation, matching the pattern used for metadata_ai.
"""
from datetime import datetime, timedelta, timezone

import pytest

from app.services import algorithm_digest


class FakeEntry(dict):
    """Minimal stand-in for feedparser's FeedParserDict entries, which
    support both dict-style .get() and attribute access."""

    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(name)


class FakeParsedFeed:
    def __init__(self, entries, bozo=False):
        self.entries = entries
        self.bozo = bozo


def _entry(title, link="https://example.com/a", summary="", days_ago=0):
    published = datetime.now(timezone.utc) - timedelta(days=days_ago)
    return FakeEntry(
        title=title,
        link=link,
        summary=summary,
        published_parsed=published.timetuple(),
    )


def test_fetch_recent_articles_raises_when_every_source_fails(monkeypatch):
    def always_raises(url):
        raise OSError("network unreachable")

    monkeypatch.setattr(algorithm_digest.feedparser, "parse", always_raises)

    with pytest.raises(ConnectionError):
        algorithm_digest.fetch_recent_articles()


def test_fetch_recent_articles_filters_old_entries(monkeypatch):
    def fake_parse(url):
        return FakeParsedFeed(
            entries=[
                _entry("Fresh post", days_ago=1),
                _entry("Stale post", days_ago=30),
            ]
        )

    monkeypatch.setattr(algorithm_digest.feedparser, "parse", fake_parse)

    articles = algorithm_digest.fetch_recent_articles()
    titles = [a["title"] for a in articles]
    assert "Fresh post" in titles
    assert "Stale post" not in titles


def test_fetch_recent_articles_tolerates_some_sources_failing(monkeypatch):
    calls = {"n": 0}

    def flaky_parse(url):
        calls["n"] += 1
        if calls["n"] == 1:
            raise OSError("this one source is down")
        return FakeParsedFeed(entries=[_entry("Still works", days_ago=0)])

    monkeypatch.setattr(algorithm_digest.feedparser, "parse", flaky_parse)

    articles = algorithm_digest.fetch_recent_articles()
    assert any(a["title"] == "Still works" for a in articles)


def test_build_digest_email_template_fallback_without_api_key(monkeypatch):
    monkeypatch.setattr(algorithm_digest.settings, "ANTHROPIC_API_KEY", "")
    articles = [
        {"source": "TubeFilter", "title": "Shorts get a new feature", "link": "https://x.test/1", "summary": "Details here."},
        {"source": "TubeFilter", "title": "Another update", "link": "https://x.test/2", "summary": ""},
    ]

    email = algorithm_digest.build_digest_email(articles)
    assert "TubeFilter" in email["html_body"]
    assert "Shorts get a new feature" in email["text_body"]
    assert "https://x.test/1" in email["html_body"]
    assert "ShortsForge daily trends briefing" in email["subject"]


def test_build_digest_email_handles_no_articles(monkeypatch):
    monkeypatch.setattr(algorithm_digest.settings, "ANTHROPIC_API_KEY", "")
    email = algorithm_digest.build_digest_email([])
    assert email["text_body"]
    assert email["html_body"]
