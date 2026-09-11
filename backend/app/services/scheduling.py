"""Spreads a backlog of approved clips out over time instead of letting
them all publish the moment they're approved. Reuses the upload
pipeline's existing publish_at mechanism (upload_clip_task already
uploads immediately but tells YouTube to keep the video private until
clip.scheduled_at) — this only decides what that timestamp should be."""
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.db.models import Clip, Video


def next_scheduled_slot(db: Session, user_id: str, cadence_per_day: int, now: datetime | None = None) -> datetime:
    """Returns the next publish slot for this user, spaced so at most
    `cadence_per_day` clips go out per day. If nothing is already queued
    in the future, the first clip gets one spacing interval from now
    (rather than instantly) so a big batch doesn't all land at once."""
    now = now or datetime.utcnow()
    spacing = timedelta(hours=24 / cadence_per_day)

    last = (
        db.query(Clip)
        .join(Video)
        .filter(Video.owner_id == user_id, Clip.scheduled_at.isnot(None), Clip.scheduled_at > now)
        .order_by(Clip.scheduled_at.desc())
        .first()
    )
    if last and last.scheduled_at:
        return last.scheduled_at + spacing
    return now + spacing
