from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import StyleProfile, User, WatchedChannel
from app.db.session import get_db
from app.schemas.schemas import StyleProfileOut, WatchedChannelCreate, WatchedChannelOut
from app.services import video_import
from app.workers.tasks import analyze_style_task

router = APIRouter(prefix="/api/watched-channels", tags=["watched-channels"])


@router.get("", response_model=list[WatchedChannelOut])
def list_watched_channels(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(WatchedChannel).filter_by(user_id=user.id).order_by(WatchedChannel.created_at.desc()).all()


@router.post("", response_model=WatchedChannelOut)
def create_watched_channel(
    payload: WatchedChannelCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    channel = WatchedChannel(user_id=user.id, channel_url=payload.channel_url, label=payload.label)
    db.add(channel)
    db.commit()
    db.refresh(channel)
    return channel


@router.delete("/{channel_id}")
def delete_watched_channel(channel_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    channel = db.get(WatchedChannel, channel_id)
    if not channel or channel.user_id != user.id:
        raise HTTPException(404, "Watched channel not found")
    db.delete(channel)
    db.commit()
    return {"ok": True}


@router.post("/{channel_id}/analyze", response_model=StyleProfileOut)
def analyze_watched_channel(channel_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    channel = db.get(WatchedChannel, channel_id)
    if not channel or channel.user_id != user.id:
        raise HTTPException(404, "Watched channel not found")

    try:
        resolved = video_import.resolve_channel_latest_video(channel.channel_url)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(502, f"Could not resolve a video from this channel: {exc}") from exc
    if not resolved:
        raise HTTPException(404, "No public videos found on this channel.")
    video_url, title = resolved

    profile = StyleProfile(
        user_id=user.id,
        source_url=video_url,
        creator_label=channel.label or title,
        status="analyzing",
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    analyze_style_task.delay(profile.id)
    return profile
