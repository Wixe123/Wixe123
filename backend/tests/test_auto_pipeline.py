"""Tests for the two automation features: auto-approve+upload clips above
a score threshold, and auto-importing new videos from a watched channel.
"""
from datetime import datetime, timedelta

from app.db.models import (
    Clip,
    ClipStatus,
    JobType,
    ProcessingJob,
    User,
    UserSettings,
    Video,
    VideoStatus,
    YouTubeCredential,
)
from app.workers import tasks as tasks_module


def _make_user_with_settings(session, **settings_kwargs):
    user = User(email="a@example.com", google_sub="sub-1")
    session.add(user)
    session.commit()
    settings_row = UserSettings(user_id=user.id, **settings_kwargs)
    session.add(settings_row)
    session.commit()
    return user, settings_row


def test_new_user_settings_default_to_auto_approve_enabled(session_factory):
    """Auto-upload above a score threshold is on by default (threshold 7)
    for any settings row that doesn't explicitly opt out, so a brand new
    account gets the hands-off pipeline without visiting Settings first."""
    session = session_factory()
    user = User(email="fresh@example.com", google_sub="sub-fresh")
    session.add(user)
    session.commit()
    settings_row = UserSettings(user_id=user.id)
    session.add(settings_row)
    session.commit()

    assert settings_row.auto_approve_score_threshold == 7.0


def test_render_clip_task_auto_approves_and_uploads_above_threshold(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user, _settings = _make_user_with_settings(session, auto_approve_score_threshold=5.0)
    video = Video(owner_id=user.id, file_path="/fake/source.mp4", transcript={"words": [], "segments": []})
    session.add(video)
    session.commit()
    clip = Clip(video_id=video.id, start_seconds=0.0, end_seconds=10.0, score=8.0, status=ClipStatus.PENDING_RENDER)
    session.add(clip)
    session.commit()
    clip_id = clip.id
    session.close()

    monkeypatch.setattr(tasks_module.storage, "clips_dir", lambda video_id: str(tasks_module.storage.settings.STORAGE_ROOT))
    monkeypatch.setattr(tasks_module.subtitles, "build_ass", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "render_clip", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "generate_thumbnail", lambda *a, **k: None)
    monkeypatch.setattr(
        tasks_module, "generate_metadata", lambda *a, **k: {"title": "t", "description": "d", "hashtags": [], "keywords": [], "seo_score": 0}
    )
    upload_calls = []
    monkeypatch.setattr(tasks_module.upload_clip_task, "delay", lambda *a, **k: upload_calls.append(a))

    tasks_module.render_clip_task.apply(args=(clip_id,))

    session2 = session_factory()
    refreshed = session2.get(Clip, clip_id)
    assert refreshed.status == ClipStatus.APPROVED
    assert len(upload_calls) == 1


def test_render_clip_task_leaves_clip_for_review_below_threshold(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user, _settings = _make_user_with_settings(session, auto_approve_score_threshold=9.0)
    video = Video(owner_id=user.id, file_path="/fake/source.mp4", transcript={"words": [], "segments": []})
    session.add(video)
    session.commit()
    clip = Clip(video_id=video.id, start_seconds=0.0, end_seconds=10.0, score=8.0, status=ClipStatus.PENDING_RENDER)
    session.add(clip)
    session.commit()
    clip_id = clip.id
    session.close()

    monkeypatch.setattr(tasks_module.storage, "clips_dir", lambda video_id: str(tasks_module.storage.settings.STORAGE_ROOT))
    monkeypatch.setattr(tasks_module.subtitles, "build_ass", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "render_clip", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "generate_thumbnail", lambda *a, **k: None)
    monkeypatch.setattr(
        tasks_module, "generate_metadata", lambda *a, **k: {"title": "t", "description": "d", "hashtags": [], "keywords": [], "seo_score": 0}
    )
    upload_calls = []
    monkeypatch.setattr(tasks_module.upload_clip_task, "delay", lambda *a, **k: upload_calls.append(a))

    tasks_module.render_clip_task.apply(args=(clip_id,))

    session2 = session_factory()
    refreshed = session2.get(Clip, clip_id)
    assert refreshed.status == ClipStatus.READY_FOR_REVIEW
    assert upload_calls == []


def test_check_channels_imports_new_video_and_skips_existing(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user, settings_row = _make_user_with_settings(session, auto_import_from_channel=True)
    session.add(YouTubeCredential(user_id=user.id, encrypted_refresh_token="enc-token"))
    session.add(Video(owner_id=user.id, source_url="https://www.youtube.com/watch?v=already_here"))
    session.commit()
    user_id = user.id
    session.close()

    monkeypatch.setattr(tasks_module, "decrypt_secret", lambda enc: "plain-refresh-token")
    monkeypatch.setattr(tasks_module.youtube_client, "credentials_from_refresh_token", lambda *a, **k: object())
    monkeypatch.setattr(tasks_module.youtube_client, "get_uploads_playlist_id", lambda creds: "UUplaylist")
    monkeypatch.setattr(
        tasks_module.youtube_client,
        "list_recent_channel_videos",
        lambda creds, playlist_id, since: [
            {"video_id": "already_here", "title": "Old", "published_at": datetime.utcnow() - timedelta(hours=2)},
            {"video_id": "brand_new", "title": "New upload", "published_at": datetime.utcnow() - timedelta(minutes=5)},
        ],
    )
    import_calls = []
    monkeypatch.setattr(tasks_module.import_from_url_task, "delay", lambda *a, **k: import_calls.append(a))

    tasks_module.check_channels_for_new_videos_task.apply()

    session2 = session_factory()
    urls = {v.source_url for v in session2.query(Video).filter_by(owner_id=user_id).all()}
    assert "https://www.youtube.com/watch?v=brand_new" in urls
    assert len(import_calls) == 1
    refreshed_settings = session2.query(UserSettings).filter_by(user_id=user_id).first()
    assert refreshed_settings.last_channel_check_at is not None


def test_check_channels_skips_users_without_credentials(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    _make_user_with_settings(session, auto_import_from_channel=True)  # no YouTubeCredential row
    session.commit()
    session.close()

    monkeypatch.setattr(
        tasks_module.youtube_client, "get_uploads_playlist_id", lambda creds: (_ for _ in ()).throw(AssertionError("should not be called"))
    )

    # Should not raise even though the watching user has no connected channel.
    tasks_module.check_channels_for_new_videos_task.apply()
