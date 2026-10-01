from datetime import datetime, timedelta

from app.db.models import TrendingClip, User, WatchedChannel
from app.services import video_import
from app.workers import tasks as tasks_module


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


def _entry(video_id, days_ago, view_count=1000, title="A short"):
    upload_date = (datetime.utcnow() - timedelta(days=days_ago)).strftime("%Y%m%d")
    return {
        "id": video_id,
        "title": title,
        "upload_date": upload_date,
        "view_count": view_count,
        "duration": 45,
        "thumbnails": [{"url": f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"}],
    }


def test_fetch_channel_weekly_shorts_filters_to_recent_and_parses_channel_info(monkeypatch):
    info = {
        "channel": "Big Creator",
        "channel_follower_count": 5_000_000,
        "thumbnails": [{"url": "https://example.com/avatar.jpg"}],
        "entries": [
            _entry("recent1", days_ago=1, view_count=2_000_000, title="Recent viral short"),
            _entry("old1", days_ago=30, view_count=9_000_000, title="Old short"),
        ],
    }
    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", _FakeYDL(info))

    result = video_import.fetch_channel_weekly_shorts("https://www.youtube.com/@bigcreator")

    assert result["channel_title"] == "Big Creator"
    assert result["subscriber_count"] == 5_000_000
    assert result["avatar_url"] == "https://example.com/avatar.jpg"
    video_ids = [v["youtube_video_id"] for v in result["videos"]]
    assert video_ids == ["recent1"]
    assert result["videos"][0]["view_count"] == 2_000_000
    assert result["videos"][0]["video_url"] == "https://www.youtube.com/watch?v=recent1"


def test_fetch_channel_weekly_shorts_uses_shorts_tab_url(monkeypatch):
    seen_urls = []

    class RecordingYDL(_FakeYDL):
        def extract_info(self, url, download=False):
            seen_urls.append(url)
            return self._info

    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", RecordingYDL({"entries": []}))
    video_import.fetch_channel_weekly_shorts("https://www.youtube.com/@bigcreator/videos")
    assert seen_urls == ["https://www.youtube.com/@bigcreator/shorts"]


def test_fetch_channel_weekly_shorts_skips_entries_without_id(monkeypatch):
    info = {"entries": [{"title": "no id here"}]}
    monkeypatch.setattr(video_import.yt_dlp, "YoutubeDL", _FakeYDL(info))
    result = video_import.fetch_channel_weekly_shorts("https://www.youtube.com/@bigcreator")
    assert result["videos"] == []


def test_refresh_trending_feed_task_replaces_clips_and_updates_channel_cache(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user = User(email="a@example.com", google_sub="sub-1")
    session.add(user)
    session.commit()
    channel = WatchedChannel(user_id=user.id, channel_url="https://www.youtube.com/@bigcreator", label="Big Creator")
    session.add(channel)
    session.commit()
    channel_id = channel.id
    user_id = user.id
    # A stale clip from a previous refresh that should be wiped out.
    session.add(
        TrendingClip(
            user_id=user_id,
            watched_channel_id=channel_id,
            youtube_video_id="stale",
            video_url="https://www.youtube.com/watch?v=stale",
            title="Stale",
        )
    )
    session.commit()
    session.close()

    monkeypatch.setattr(
        tasks_module.video_import,
        "fetch_channel_weekly_shorts",
        lambda channel_url: {
            "channel_title": "Big Creator Official",
            "avatar_url": "https://example.com/avatar.jpg",
            "subscriber_count": 12_000_000,
            "videos": [
                {
                    "youtube_video_id": "fresh1",
                    "video_url": "https://www.youtube.com/watch?v=fresh1",
                    "title": "Fresh viral short",
                    "thumbnail_url": "https://i.ytimg.com/vi/fresh1/hqdefault.jpg",
                    "view_count": 3_000_000,
                    "published_at": datetime.utcnow(),
                    "duration_seconds": 30,
                }
            ],
        },
    )

    tasks_module.refresh_trending_feed_task.apply(kwargs={"user_id": user_id})

    session2 = session_factory()
    refreshed_channel = session2.get(WatchedChannel, channel_id)
    assert refreshed_channel.channel_title == "Big Creator Official"
    assert refreshed_channel.subscriber_count == 12_000_000
    assert refreshed_channel.last_refreshed_at is not None

    clips = session2.query(TrendingClip).filter_by(watched_channel_id=channel_id).all()
    assert len(clips) == 1
    assert clips[0].youtube_video_id == "fresh1"
    assert clips[0].channel_title == "Big Creator Official"


def test_refresh_trending_feed_task_skips_failing_channel_and_continues(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user = User(email="b@example.com", google_sub="sub-2")
    session.add(user)
    session.commit()
    bad_channel = WatchedChannel(user_id=user.id, channel_url="https://www.youtube.com/@broken")
    good_channel = WatchedChannel(user_id=user.id, channel_url="https://www.youtube.com/@good")
    session.add_all([bad_channel, good_channel])
    session.commit()
    good_id = good_channel.id
    bad_url = bad_channel.channel_url
    user_id = user.id
    session.close()

    def fake_fetch(channel_url):
        if channel_url == bad_url:
            raise ConnectionError("channel unreachable")
        return {
            "channel_title": "Good Channel",
            "avatar_url": "",
            "subscriber_count": None,
            "videos": [],
        }

    monkeypatch.setattr(tasks_module.video_import, "fetch_channel_weekly_shorts", fake_fetch)

    tasks_module.refresh_trending_feed_task.apply(kwargs={"user_id": user_id})

    session2 = session_factory()
    refreshed_good = session2.get(WatchedChannel, good_id)
    assert refreshed_good.channel_title == "Good Channel"
