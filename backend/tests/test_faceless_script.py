import json

import pytest

from app.services import faceless_script


class _FakeBlock:
    def __init__(self, text):
        self.text = text


class _FakeMessages:
    def __init__(self, response_text):
        self._response_text = response_text

    def create(self, **kwargs):
        return type("Resp", (), {"content": [_FakeBlock(self._response_text)]})()


class _FakeAnthropic:
    def __init__(self, response_text):
        self.messages = _FakeMessages(response_text)


def test_generate_script_requires_api_key(monkeypatch):
    monkeypatch.setattr(faceless_script.settings, "ANTHROPIC_API_KEY", "")

    with pytest.raises(faceless_script.ScriptGenerationError):
        faceless_script.generate_script("space exploration", [])


def test_generate_script_parses_model_json(monkeypatch):
    monkeypatch.setattr(faceless_script.settings, "ANTHROPIC_API_KEY", "fake-key")
    payload = {
        "topic": "Why Voyager 1 still works",
        "beats": [
            {"narration": "Voyager 1 launched in 1977.", "visual": {"type": "callout", "text": "1977"}},
            {"narration": "It is now in interstellar space.", "visual": {"type": "image", "query": "Voyager 1 spacecraft"}},
        ],
    }
    monkeypatch.setattr(
        "anthropic.Anthropic", lambda api_key: _FakeAnthropic(json.dumps(payload))
    )

    result = faceless_script.generate_script("space exploration", ["The Apollo program"])

    assert result["topic"] == "Why Voyager 1 still works"
    assert len(result["beats"]) == 2
    assert result["beats"][0]["visual"]["type"] == "callout"


def test_generate_script_raises_on_missing_json(monkeypatch):
    monkeypatch.setattr(faceless_script.settings, "ANTHROPIC_API_KEY", "fake-key")
    monkeypatch.setattr("anthropic.Anthropic", lambda api_key: _FakeAnthropic("not json at all"))

    with pytest.raises(faceless_script.ScriptGenerationError):
        faceless_script.generate_script("space exploration", [])


def test_generate_script_raises_on_empty_beats(monkeypatch):
    monkeypatch.setattr(faceless_script.settings, "ANTHROPIC_API_KEY", "fake-key")
    monkeypatch.setattr(
        "anthropic.Anthropic", lambda api_key: _FakeAnthropic(json.dumps({"topic": "x", "beats": []}))
    )

    with pytest.raises(faceless_script.ScriptGenerationError):
        faceless_script.generate_script("space exploration", [])


def test_full_narration_text_joins_beats():
    beats = [{"narration": "First sentence."}, {"narration": "Second sentence."}, {}]
    assert faceless_script.full_narration_text(beats) == "First sentence. Second sentence."
