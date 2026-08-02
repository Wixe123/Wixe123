from fastapi import APIRouter, Depends, HTTPException
from google.oauth2.credentials import Credentials
from googleapiclient.errors import HttpError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import decrypt_secret
from app.db.models import Clip, ClipStatus, User, Video
from app.db.session import get_db
from app.schemas.schemas import AnalyticsOverview, ClipPerformance, TopVideo, TrendPoint
from app.services import youtube_analytics
from app.services.youtube_client import YOUTUBE_SCOPES, credentials_from_refresh_token, get_video_titles

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


def _credentials_for(user: User) -> Credentials:
    if not user.youtube_credential:
        raise HTTPException(400, "Connect your YouTube channel in Settings first.")
    try:
        refresh_token = decrypt_secret(user.youtube_credential.encrypted_refresh_token)
        return credentials_from_refresh_token(refresh_token, YOUTUBE_SCOPES)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(400, f"Could not authenticate with YouTube: {exc}") from exc


def _pct_delta(current: float, previous: float) -> float | None:
    if not previous:
        return None
    return round((current - previous) / previous * 100, 1)


@router.get("/overview", response_model=AnalyticsOverview)
def overview(days: int = 28, user: User = Depends(get_current_user)):
    credentials = _credentials_for(user)
    try:
        data = youtube_analytics.get_channel_overview(credentials, days=days)
    except HttpError as exc:
        raise HTTPException(
            502,
            "YouTube Analytics request failed. If you connected your channel before analytics "
            "support was added, reconnect it in Settings to grant the new permission. "
            f"({exc})",
        ) from exc

    current = data["current"]
    previous = data["previous"]
    views = int(current.get("views", 0))
    watch_minutes = float(current.get("estimatedMinutesWatched", 0))
    subs = int(current.get("subscribersGained", 0))

    return AnalyticsOverview(
        period_days=data["period_days"],
        start=data["start"],
        end=data["end"],
        views=views,
        watch_time_minutes=watch_minutes,
        average_view_duration_seconds=float(current.get("averageViewDuration", 0)),
        likes=int(current.get("likes", 0)),
        comments=int(current.get("comments", 0)),
        shares=int(current.get("shares", 0)),
        subscribers_gained=subs,
        views_delta_pct=_pct_delta(views, float(previous.get("views", 0))),
        watch_time_delta_pct=_pct_delta(watch_minutes, float(previous.get("estimatedMinutesWatched", 0))),
        subscribers_delta_pct=_pct_delta(subs, float(previous.get("subscribersGained", 0))),
    )


@router.get("/clips", response_model=list[ClipPerformance])
def clip_performance(days: int = 28, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    credentials = _credentials_for(user)

    uploaded_clips = (
        db.query(Clip)
        .join(Video)
        .filter(Video.owner_id == user.id, Clip.status == ClipStatus.UPLOADED, Clip.youtube_video_id != "")
        .all()
    )
    if not uploaded_clips:
        return []

    video_ids = [c.youtube_video_id for c in uploaded_clips]
    try:
        performance = youtube_analytics.get_video_performance(credentials, video_ids, days=days)
    except HttpError as exc:
        raise HTTPException(
            502,
            "YouTube Analytics request failed. If you connected your channel before analytics "
            "support was added, reconnect it in Settings to grant the new permission. "
            f"({exc})",
        ) from exc

    results = []
    for clip in uploaded_clips:
        metrics = performance.get(clip.youtube_video_id, {})
        results.append(
            ClipPerformance(
                clip_id=clip.id,
                youtube_video_id=clip.youtube_video_id,
                title=clip.title,
                views=int(metrics.get("views", 0)),
                watch_time_minutes=float(metrics.get("estimatedMinutesWatched", 0)),
                average_view_duration_seconds=float(metrics.get("averageViewDuration", 0)),
                average_view_percentage=float(metrics.get("averageViewPercentage", 0)),
                likes=int(metrics.get("likes", 0)),
                comments=int(metrics.get("comments", 0)),
                score=clip.score,
                score_reasons=clip.score_reasons or [],
            )
        )
    results.sort(key=lambda r: r.views, reverse=True)
    return results


@router.get("/trend", response_model=list[TrendPoint])
def trend(days: int = 28, user: User = Depends(get_current_user)):
    credentials = _credentials_for(user)
    try:
        rows = youtube_analytics.get_daily_trend(credentials, days=days)
    except HttpError as exc:
        raise HTTPException(
            502,
            "YouTube Analytics request failed. If you connected your channel before analytics "
            "support was added, reconnect it in Settings to grant the new permission. "
            f"({exc})",
        ) from exc

    return [
        TrendPoint(
            date=str(row.get("day", "")),
            views=int(row.get("views", 0)),
            watch_time_minutes=float(row.get("estimatedMinutesWatched", 0)),
        )
        for row in rows
    ]


@router.get("/top-videos", response_model=list[TopVideo])
def top_videos(days: int = 28, user: User = Depends(get_current_user)):
    credentials = _credentials_for(user)
    try:
        rows = youtube_analytics.get_top_channel_videos(credentials, days=days, max_results=10)
    except HttpError as exc:
        raise HTTPException(
            502,
            "YouTube Analytics request failed. If you connected your channel before analytics "
            "support was added, reconnect it in Settings to grant the new permission. "
            f"({exc})",
        ) from exc

    video_ids = [row.get("video", "") for row in rows if row.get("video")]
    titles = get_video_titles(credentials, video_ids)

    results = []
    for row in rows:
        video_id = row.get("video", "")
        info = titles.get(video_id, {})
        results.append(
            TopVideo(
                video_id=video_id,
                title=info.get("title", "Untitled"),
                thumbnail=info.get("thumbnail", ""),
                views=int(row.get("views", 0)),
                watch_time_minutes=float(row.get("estimatedMinutesWatched", 0)),
                likes=int(row.get("likes", 0)),
            )
        )
    return results
