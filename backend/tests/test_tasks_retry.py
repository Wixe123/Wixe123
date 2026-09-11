"""Regression tests for the retry wiring in app/workers/tasks.py.

All four Celery tasks declare bind=True, max_retries=N, but previously
never called self.retry() — a transient ffmpeg or network blip immediately
failed the whole job with no retry, silently making that config dead. These
tests check the classifier directly, then drive a real task through
Celery's synchronous `.apply()` to confirm it actually retries a transient
failure and recovers, while a permanent error still fails without retrying.
"""
import subprocess
from unittest.mock import MagicMock

from googleapiclient.errors import HttpError

from app.db.models import User, Video, VideoStatus
from app.workers import tasks as tasks_module


def _http_error(status: int) -> HttpError:
    resp = MagicMock()
    resp.status = status
    return HttpError(resp, b"error body")


def test_is_transient_classifies_ffmpeg_and_network_errors_as_retryable():
    assert tasks_module._is_transient(subprocess.CalledProcessError(1, ["ffmpeg"]))
    assert tasks_module._is_transient(ConnectionError())
    assert tasks_module._is_transient(TimeoutError())
    assert tasks_module._is_transient(_http_error(503))


def test_is_transient_treats_bad_input_and_auth_errors_as_permanent():
    assert not tasks_module._is_transient(RuntimeError("YouTube channel not connected."))
    assert not tasks_module._is_transient(ValueError("bad data"))
    assert not tasks_module._is_transient(_http_error(403))


def test_import_from_url_task_retries_transient_failure_then_succeeds(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user = User(email="a@example.com", google_sub="sub-1")
    session.add(user)
    session.commit()
    video = Video(owner_id=user.id, source_url="https://example.com/v.mp4")
    session.add(video)
    session.commit()
    video_id = video.id
    session.close()

    calls = {"n": 0}

    def flaky_download(url, out_dir):
        calls["n"] += 1
        if calls["n"] < 2:
            raise ConnectionError("network blip")
        return "/tmp/fake.mp4", "Fake Title"

    monkeypatch.setattr(tasks_module.video_import, "download_video", flaky_download)
    monkeypatch.setattr(tasks_module.storage, "path_size_bytes", lambda p: 123)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "get_duration_seconds", lambda p: 10.0)
    monkeypatch.setattr(tasks_module.analyze_video_task, "delay", lambda *a, **k: None)

    tasks_module.import_from_url_task.apply(args=(video_id,))

    assert calls["n"] == 2, "expected exactly one retry before success"
    session2 = session_factory()
    refreshed = session2.get(Video, video_id)
    assert refreshed.status != VideoStatus.FAILED
    assert refreshed.file_path == "/tmp/fake.mp4"


def test_import_from_url_task_does_not_retry_permanent_failure(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user = User(email="b@example.com", google_sub="sub-2")
    session.add(user)
    session.commit()
    video = Video(owner_id=user.id, source_url="not a real url")
    session.add(video)
    session.commit()
    video_id = video.id
    session.close()

    calls = {"n": 0}

    def always_bad_url(url, out_dir):
        calls["n"] += 1
        raise ValueError("unsupported URL")

    monkeypatch.setattr(tasks_module.video_import, "download_video", always_bad_url)

    tasks_module.import_from_url_task.apply(args=(video_id,))

    assert calls["n"] == 1, "permanent errors must not be retried"
    session2 = session_factory()
    refreshed = session2.get(Video, video_id)
    assert refreshed.status == VideoStatus.FAILED
