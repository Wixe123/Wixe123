"""Tests for the posting-cadence scheduler: spreading approved clips out
over time instead of publishing a whole backlog at once."""
from datetime import datetime, timedelta

from app.db.models import Clip, ClipStatus, User, Video
from app.services.scheduling import next_scheduled_slot


_email_counter = [0]


def _make_user_with_video(session):
    _email_counter[0] += 1
    user = User(email=f"user{_email_counter[0]}@example.com", google_sub=f"sub-{_email_counter[0]}")
    session.add(user)
    session.commit()
    video = Video(owner_id=user.id, file_path="/fake/source.mp4")
    session.add(video)
    session.commit()
    return user, video


def test_next_scheduled_slot_is_one_interval_out_when_nothing_queued(session_factory):
    session = session_factory()
    user, _video = _make_user_with_video(session)
    now = datetime(2026, 1, 1, 0, 0, 0)

    slot = next_scheduled_slot(session, user.id, cadence_per_day=4, now=now)

    assert slot == now + timedelta(hours=6)


def test_next_scheduled_slot_stacks_after_the_latest_future_slot(session_factory):
    session = session_factory()
    user, video = _make_user_with_video(session)
    now = datetime(2026, 1, 1, 0, 0, 0)
    existing = Clip(
        video_id=video.id, start_seconds=0, end_seconds=10, status=ClipStatus.APPROVED,
        scheduled_at=now + timedelta(hours=6),
    )
    session.add(existing)
    session.commit()

    slot = next_scheduled_slot(session, user.id, cadence_per_day=4, now=now)

    assert slot == now + timedelta(hours=12)


def test_next_scheduled_slot_ignores_past_slots(session_factory):
    session = session_factory()
    user, video = _make_user_with_video(session)
    now = datetime(2026, 1, 1, 12, 0, 0)
    stale = Clip(
        video_id=video.id, start_seconds=0, end_seconds=10, status=ClipStatus.UPLOADED,
        scheduled_at=now - timedelta(days=3),
    )
    session.add(stale)
    session.commit()

    slot = next_scheduled_slot(session, user.id, cadence_per_day=2, now=now)

    assert slot == now + timedelta(hours=12)


def test_next_scheduled_slot_ignores_other_users_clips(session_factory):
    session = session_factory()
    user, _video = _make_user_with_video(session)
    other_user, other_video = _make_user_with_video(session)
    now = datetime(2026, 1, 1, 0, 0, 0)
    other_clip = Clip(
        video_id=other_video.id, start_seconds=0, end_seconds=10, status=ClipStatus.APPROVED,
        scheduled_at=now + timedelta(hours=1),
    )
    session.add(other_clip)
    session.commit()

    slot = next_scheduled_slot(session, user.id, cadence_per_day=4, now=now)

    assert slot == now + timedelta(hours=6)
