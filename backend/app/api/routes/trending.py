from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import TrendingClip, User, WatchedChannel
from app.db.session import get_db
from app.schemas.schemas import TrendingClipOut, WatchedChannelDetail, WatchedChannelOut
from app.workers.tasks import refresh_trending_feed_task

router = APIRouter(prefix="/api/trending", tags=["trending"])


@router.get("", response_model=list[TrendingClipOut])
def list_trending(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return (
        db.query(TrendingClip)
        .filter_by(user_id=user.id)
        .order_by(TrendingClip.view_count.desc())
        .all()
    )


@router.post("/refresh")
def refresh_trending(user: User = Depends(get_current_user)):
    refresh_trending_feed_task.delay(user_id=user.id)
    return {"status": "queued"}


@router.get("/channels/{channel_id}", response_model=WatchedChannelDetail)
def get_trending_channel(channel_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    channel = db.get(WatchedChannel, channel_id)
    if not channel or channel.user_id != user.id:
        raise HTTPException(404, "Watched channel not found")

    clips = (
        db.query(TrendingClip)
        .filter_by(watched_channel_id=channel.id)
        .order_by(TrendingClip.view_count.desc())
        .all()
    )
    channel_out = WatchedChannelOut.model_validate(channel)
    return WatchedChannelDetail(
        **channel_out.model_dump(),
        clips=[TrendingClipOut.model_validate(c) for c in clips],
    )
