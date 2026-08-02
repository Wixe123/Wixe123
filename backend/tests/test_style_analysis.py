from app.services import style_analysis


def test_detects_hook_phrase_in_opening_segments():
    segments = [
        {"start": 0.0, "end": 3.0, "text": "Here's why nobody tells you this secret."},
        {"start": 3.0, "end": 8.0, "text": "It changed everything about how I approach it."},
    ]
    findings = style_analysis.analyze_style({"segments": segments})
    assert "here's why" in findings["hook_analysis"].lower()


def test_no_hook_phrase_reports_visual_hook_instead():
    segments = [
        {"start": 0.0, "end": 3.0, "text": "So I went to the store yesterday."},
        {"start": 3.0, "end": 8.0, "text": "It was a normal afternoon honestly."},
    ]
    findings = style_analysis.analyze_style({"segments": segments})
    assert "visual" in findings["hook_analysis"].lower() or "tonal" in findings["hook_analysis"].lower()


def test_fast_delivery_flagged_as_high_energy():
    # ~30 words across 5 seconds is well above the 2.3 words/sec threshold
    text = "word " * 30
    segments = [{"start": 0.0, "end": 5.0, "text": text.strip()}]
    findings = style_analysis.analyze_style({"segments": segments})
    assert "fast" in findings["pacing_analysis"].lower()


def test_empty_transcript_does_not_crash():
    findings = style_analysis.analyze_style({"segments": []})
    assert findings["hook_analysis"]
    assert findings["pacing_analysis"] == ""


def test_summary_empty_without_api_key(monkeypatch):
    monkeypatch.setattr(style_analysis.settings, "ANTHROPIC_API_KEY", "")
    segments = [{"start": 0.0, "end": 3.0, "text": "Here's why this matters a lot."}]
    findings = style_analysis.analyze_style({"segments": segments})
    assert findings["summary"] == ""
