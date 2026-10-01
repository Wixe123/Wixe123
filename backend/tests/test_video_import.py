from app.services import video_import


class _FakeYDL:
    def __init__(self, info):
        self._info = info

    def __call__(self, opts):
        self._last_opts = opts
        return self

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def extract_info(self, url, download=False):
        return self._info


def test_resolve_channel_latest_video_returns_most_recent(monkeypatch):
    fake = _FakeYDL({"entries": [{"id": "abc123", "title": "Newest upload"}, {"id": "old999", "title": "Older"}]})
    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", fake)

    result = video_import.resolve_channel_latest_video("https://www.youtube.com/@somecreator")
    assert result == ("https://www.youtube.com/watch?v=abc123", "Newest upload")


def test_resolve_channel_latest_video_appends_videos_path(monkeypatch):
    seen_urls = []

    class RecordingYDL(_FakeYDL):
        def extract_info(self, url, download=False):
            seen_urls.append(url)
            return self._info

    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", RecordingYDL({"entries": [{"id": "x", "title": "t"}]}))
    video_import.resolve_channel_latest_video("https://www.youtube.com/@somecreator")
    assert seen_urls == ["https://www.youtube.com/@somecreator/videos"]


def test_resolve_channel_latest_video_returns_none_when_no_entries(monkeypatch):
    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", _FakeYDL({"entries": []}))
    assert video_import.resolve_channel_latest_video("https://www.youtube.com/@somecreator") is None
