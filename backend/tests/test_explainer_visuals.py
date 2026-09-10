import json
import os
from urllib.error import URLError

from app.services import explainer_visuals


def test_render_chart_writes_a_file(tmp_path):
    out_path = str(tmp_path / "chart.png")
    explainer_visuals.render_chart(
        {"chart_type": "bar", "title": "Population", "labels": ["A", "B"], "values": [10, 20], "unit": "M"},
        out_path,
    )
    assert os.path.exists(out_path)
    assert os.path.getsize(out_path) > 0


def test_render_callout_writes_a_file(tmp_path):
    out_path = str(tmp_path / "callout.png")
    explainer_visuals.render_callout("A striking fact", out_path)
    assert os.path.exists(out_path)
    assert os.path.getsize(out_path) > 0


def test_search_wikimedia_image_returns_none_on_network_failure(tmp_path, monkeypatch):
    def fail_urlopen(*a, **k):
        raise URLError("blocked")

    monkeypatch.setattr(explainer_visuals.urllib.request, "urlopen", fail_urlopen)

    assert explainer_visuals.search_wikimedia_image("Voyager 1", str(tmp_path / "img.jpg")) is None


def test_search_wikimedia_image_skips_disallowed_licenses(tmp_path, monkeypatch):
    data = {
        "query": {
            "pages": {
                "1": {
                    "imageinfo": [
                        {
                            "mime": "image/jpeg",
                            "url": "https://example.invalid/photo.jpg",
                            "extmetadata": {"LicenseShortName": {"value": "All rights reserved"}},
                        }
                    ]
                }
            }
        }
    }

    class _FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return json.dumps(data).encode()

    monkeypatch.setattr(explainer_visuals.urllib.request, "urlopen", lambda *a, **k: _FakeResponse())

    assert explainer_visuals.search_wikimedia_image("some place", str(tmp_path / "img.jpg")) is None


def test_resolve_beat_visual_prefers_chart_when_data_present(tmp_path, monkeypatch):
    monkeypatch.setattr(
        explainer_visuals,
        "search_wikimedia_image",
        lambda *a, **k: (_ for _ in ()).throw(AssertionError("should not be called")),
    )
    beat = {"narration": "x", "visual": {"type": "chart", "labels": ["A"], "values": [1]}}

    kind, path = explainer_visuals.resolve_beat_visual(beat, str(tmp_path), 0)

    assert kind == "static"
    assert os.path.exists(path)


def test_resolve_beat_visual_falls_back_to_callout_when_image_search_fails(tmp_path, monkeypatch):
    monkeypatch.setattr(explainer_visuals, "search_wikimedia_image", lambda *a, **k: None)
    beat = {"narration": "Some fact about a place.", "visual": {"type": "image", "query": "a place"}}

    kind, path = explainer_visuals.resolve_beat_visual(beat, str(tmp_path), 0)

    assert kind == "static"
    assert path.endswith("_callout.png")
    assert os.path.exists(path)


def test_resolve_beat_visual_returns_photo_when_image_found(tmp_path, monkeypatch):
    def fake_search(query, out_path, timeout=15):
        with open(out_path, "wb") as f:
            f.write(b"fake-jpeg-bytes")
        return out_path

    monkeypatch.setattr(explainer_visuals, "search_wikimedia_image", fake_search)
    beat = {"narration": "x", "visual": {"type": "image", "query": "a place"}}

    kind, path = explainer_visuals.resolve_beat_visual(beat, str(tmp_path), 0)

    assert kind == "photo"
    assert os.path.exists(path)
