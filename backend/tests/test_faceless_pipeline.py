"""Tests for the faceless explainer video pipeline: the _beat_durations
helper and the generate_faceless_video_task orchestration (with the
script/TTS/visuals/ffmpeg calls mocked out, same style as
test_auto_pipeline.py's render_clip_task tests)."""
from app.db.models import (
    ClipStatus,
    FacelessTopic,
    JobStatus,
    ProcessingJob,
    User,
    UserSettings,
    Video,
    VideoStatus,
)
from app.workers import tasks as tasks_module


def test_beat_durations_sum_to_total_duration():
    beats = [{"narration": "One two three."}, {"narration": "Four five six seven eight."}, {"narration": "Nine."}]
    durations = tasks_module._beat_durations(beats, 30.0)

    assert len(durations) == 3
    assert abs(sum(durations) - 30.0) < 1e-6
    # More words -> more time, all else equal.
    assert durations[1] > durations[0] > durations[2]


def test_beat_durations_enforces_minimum_even_for_tiny_beats():
    beats = [{"narration": "Hi."}, {"narration": "A very long narration sentence with many words in it."}]
    durations = tasks_module._beat_durations(beats, 5.0)

    assert abs(sum(durations) - 5.0) < 1e-6
    assert all(d > 0 for d in durations)


def _make_user_with_niche(session, **settings_kwargs):
    user = User(email="faceless@example.com", google_sub="sub-faceless")
    session.add(user)
    session.commit()
    settings_row = UserSettings(user_id=user.id, faceless_niche="space exploration", **settings_kwargs)
    session.add(settings_row)
    session.commit()
    return user, settings_row


def _patch_pipeline(monkeypatch, tmp_path, beats=None):
    beats = beats or [
        {"narration": "First fact.", "visual": {"type": "callout", "text": "First fact."}},
        {"narration": "Second fact here.", "visual": {"type": "callout", "text": "Second fact here."}},
    ]
    script = {"topic": "A specific space topic", "beats": beats}

    monkeypatch.setattr(tasks_module, "generate_script", lambda niche, recent_topics: script)
    monkeypatch.setattr(tasks_module.storage, "clips_dir", lambda video_id: str(tmp_path))
    monkeypatch.setattr(
        tasks_module.tts,
        "synthesize",
        lambda text, out_path, **k: {"audio_path": out_path, "words": [{"word": "w", "start": 0.0, "end": 0.3}], "engine": "espeak-ng"},
    )
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "get_duration_seconds", lambda path: 10.0)
    monkeypatch.setattr(
        tasks_module.explainer_visuals, "resolve_beat_visual", lambda beat, work_dir, i: ("static", f"{work_dir}/beat_{i}.png")
    )
    monkeypatch.setattr(tasks_module.subtitles, "build_ass", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "assemble_explainer_video", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.ffmpeg_utils, "generate_thumbnail", lambda *a, **k: None)
    monkeypatch.setattr(tasks_module.storage, "path_size_bytes", lambda path: 1234)
    monkeypatch.setattr(
        tasks_module,
        "generate_metadata",
        lambda *a, **k: {"title": "Generated title", "description": "d", "hashtags": [], "keywords": [], "seo_score": 5},
    )
    return script


def test_generate_faceless_video_task_creates_video_and_clip(session_factory, monkeypatch, tmp_path):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)
    _patch_pipeline(monkeypatch, tmp_path)

    session = session_factory()
    user, _settings = _make_user_with_niche(session)
    user_id = user.id
    session.close()

    upload_calls = []
    monkeypatch.setattr(tasks_module.upload_clip_task, "delay", lambda *a, **k: upload_calls.append(a))

    job = ProcessingJob(job_type=tasks_module.JobType.GENERATE_FACELESS_VIDEO)
    setup_session = session_factory()
    setup_session.add(job)
    setup_session.commit()
    job_id = job.id
    setup_session.close()

    tasks_module.generate_faceless_video_task.apply(args=(user_id, job_id))

    check = session_factory()
    videos = check.query(Video).filter_by(owner_id=user_id).all()
    assert len(videos) == 1
    video = videos[0]
    assert video.status == VideoStatus.ANALYZED
    assert video.title == "A specific space topic"
    assert video.source_type == "faceless_generated"

    clips = check.query(tasks_module.Clip).filter_by(video_id=video.id).all()
    assert len(clips) == 1
    clip = clips[0]
    assert clip.title == "Generated title"
    assert clip.status == ClipStatus.READY_FOR_REVIEW

    topics = check.query(FacelessTopic).filter_by(user_id=user_id).all()
    assert [t.topic for t in topics] == ["A specific space topic"]

    refreshed_job = check.get(ProcessingJob, job_id)
    assert refreshed_job.status == JobStatus.SUCCESS

    # No auto-upload toggle set, so it should stay pending review.
    assert upload_calls == []


def test_generate_faceless_video_task_auto_uploads_when_toggle_enabled(session_factory, monkeypatch, tmp_path):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)
    _patch_pipeline(monkeypatch, tmp_path)

    session = session_factory()
    user, _settings = _make_user_with_niche(session, faceless_auto_upload=True)
    user_id = user.id
    session.close()

    upload_calls = []
    monkeypatch.setattr(tasks_module.upload_clip_task, "delay", lambda *a, **k: upload_calls.append(a))

    tasks_module.generate_faceless_video_task.apply(args=(user_id, None))

    check = session_factory()
    clip = check.query(tasks_module.Clip).filter_by(video_id=check.query(Video).filter_by(owner_id=user_id).first().id).first()
    assert clip.status == ClipStatus.APPROVED
    assert len(upload_calls) == 1


def test_generate_faceless_video_task_fails_without_niche(session_factory, monkeypatch):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)

    session = session_factory()
    user = User(email="no-niche@example.com", google_sub="sub-no-niche")
    session.add(user)
    session.commit()
    session.add(UserSettings(user_id=user.id))
    session.commit()
    user_id = user.id
    session.close()

    job = ProcessingJob(job_type=tasks_module.JobType.GENERATE_FACELESS_VIDEO)
    setup_session = session_factory()
    setup_session.add(job)
    setup_session.commit()
    job_id = job.id
    setup_session.close()

    tasks_module.generate_faceless_video_task.apply(args=(user_id, job_id))

    check = session_factory()
    refreshed_job = check.get(ProcessingJob, job_id)
    assert refreshed_job.status == JobStatus.FAILED
    assert "niche" in refreshed_job.error_message.lower()
    assert check.query(Video).filter_by(owner_id=user_id).count() == 0


def test_generate_faceless_video_task_marks_video_failed_on_error(session_factory, monkeypatch, tmp_path):
    monkeypatch.setattr(tasks_module, "SessionLocal", session_factory)
    _patch_pipeline(monkeypatch, tmp_path)
    monkeypatch.setattr(
        tasks_module.ffmpeg_utils,
        "assemble_explainer_video",
        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("ffmpeg blew up")),
    )

    session = session_factory()
    user, _settings = _make_user_with_niche(session)
    user_id = user.id
    session.close()

    tasks_module.generate_faceless_video_task.apply(args=(user_id, None))

    check = session_factory()
    video = check.query(Video).filter_by(owner_id=user_id).first()
    assert video is not None
    assert video.status == VideoStatus.FAILED
    assert "ffmpeg blew up" in video.error_message
