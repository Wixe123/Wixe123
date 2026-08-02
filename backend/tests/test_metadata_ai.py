import re

from app.services import metadata_ai


def test_generate_metadata_falls_back_to_template_without_api_key(monkeypatch):
    monkeypatch.setattr(metadata_ai.settings, "ANTHROPIC_API_KEY", "")
    result = metadata_ai.generate_metadata(
        "Here's why nobody tells you the truth about your biggest mistake.",
        ["hook phrase"],
    )
    assert result["title"]
    assert result["hashtags"][-1] == "#shorts"
    assert 0 <= result["seo_score"] <= 100


def test_hashtags_strip_apostrophes_and_symbols():
    # Regression: "#here's" is invalid on most platforms even though the
    # keyword itself ("here's") should keep its apostrophe.
    result = metadata_ai._template_metadata(
        "Here's why nobody tells you the secret to winning.", []
    )
    assert "here's" in result["keywords"]
    for hashtag in result["hashtags"]:
        assert re.match(r"^#[a-z0-9]+$", hashtag), hashtag


def test_hashtags_never_contain_empty_placeholder():
    result = metadata_ai._template_metadata("study study study practice practice", [])
    assert all(len(h) > 1 for h in result["hashtags"])


def test_generate_metadata_accepts_style_guide_without_crashing(monkeypatch):
    # Without an API key the template fallback has no way to apply a style
    # guide (it isn't generating prose) — it should just ignore it cleanly
    # rather than erroring on the extra argument.
    monkeypatch.setattr(metadata_ai.settings, "ANTHROPIC_API_KEY", "")
    result = metadata_ai.generate_metadata(
        "Here's why nobody tells you the truth.",
        ["hook phrase"],
        style_guide="Fast-paced, punchy, opens with a bold claim.",
    )
    assert result["title"]
