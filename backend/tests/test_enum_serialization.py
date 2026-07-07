"""Regression tests for a real production bug: SQLAlchemy's Enum(PyEnum)
persists the member *name* (e.g. "PRIVATE") unless values_callable is set,
but the Postgres enum types only contain the lowercase .value strings. This
broke every single write to an enum column until app/db/models.py added
_enum_column(). These tests assert the persisted column value directly so a
future edit that drops values_callable fails loudly instead of only at
runtime against real Postgres.
"""
from sqlalchemy import text

from app.db.models import (
    Clip,
    ClipStatus,
    JobStatus,
    JobType,
    ProcessingJob,
    User,
    UserSettings,
    Video,
    VideoStatus,
    Visibility,
)


def _make_user(db):
    user = User(email="a@example.com", google_sub="sub-1")
    db.add(user)
    db.commit()
    return user


def test_video_status_persists_lowercase_value(db_session):
    user = _make_user(db_session)
    video = Video(owner_id=user.id, status=VideoStatus.UPLOADED)
    db_session.add(video)
    db_session.commit()

    raw = db_session.execute(text("SELECT status FROM videos WHERE id = :id"), {"id": video.id}).scalar()
    assert raw == "uploaded"


def test_clip_status_and_visibility_persist_lowercase_value(db_session):
    user = _make_user(db_session)
    video = Video(owner_id=user.id)
    db_session.add(video)
    db_session.commit()

    clip = Clip(
        video_id=video.id,
        start_seconds=0.0,
        end_seconds=10.0,
        status=ClipStatus.READY_FOR_REVIEW,
        visibility=Visibility.UNLISTED,
    )
    db_session.add(clip)
    db_session.commit()

    row = db_session.execute(
        text("SELECT status, visibility FROM clips WHERE id = :id"), {"id": clip.id}
    ).first()
    assert row.status == "ready_for_review"
    assert row.visibility == "unlisted"


def test_processing_job_type_and_status_persist_lowercase_value(db_session):
    job = ProcessingJob(job_type=JobType.RENDER_CLIP, status=JobStatus.RUNNING)
    db_session.add(job)
    db_session.commit()

    row = db_session.execute(
        text("SELECT job_type, status FROM processing_jobs WHERE id = :id"), {"id": job.id}
    ).first()
    assert row.job_type == "render_clip"
    assert row.status == "running"


def test_user_settings_default_visibility_persists_lowercase_value(db_session):
    user = _make_user(db_session)
    settings_row = UserSettings(user_id=user.id, default_visibility=Visibility.DRAFT)
    db_session.add(settings_row)
    db_session.commit()

    raw = db_session.execute(
        text("SELECT default_visibility FROM user_settings WHERE id = :id"), {"id": settings_row.id}
    ).scalar()
    assert raw == "draft"
