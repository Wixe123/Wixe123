"""YouTube Analytics API (v2) integration — live channel and per-video
performance so the dashboard can show what's actually working, not just
what got uploaded. Requires the `yt-analytics.readonly` scope granted
alongside the upload scope in youtube_client.YOUTUBE_SCOPES; accounts
connected before that scope was added need to reconnect once."""
from datetime import date, timedelta

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

OVERVIEW_METRICS = "views,estimatedMinutesWatched,averageViewDuration,likes,comments,shares,subscribersGained"
VIDEO_METRICS = "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,likes,comments,shares"


def _date_range(days: int) -> tuple[str, str]:
    end = date.today()
    start = end - timedelta(days=days)
    return start.isoformat(), end.isoformat()


def get_channel_overview(credentials: Credentials, days: int = 28) -> dict:
    """Channel-wide totals for the last `days` days, plus the prior period
    of equal length so the frontend can show a trend delta."""
    analytics = build("youtubeAnalytics", "v2", credentials=credentials)
    start, end = _date_range(days)
    prev_end = (date.fromisoformat(start) - timedelta(days=1)).isoformat()
    prev_start = (date.fromisoformat(prev_end) - timedelta(days=days - 1)).isoformat()

    def _totals(start_date: str, end_date: str) -> dict:
        resp = analytics.reports().query(
            ids="channel==MINE",
            startDate=start_date,
            endDate=end_date,
            metrics=OVERVIEW_METRICS,
        ).execute()
        rows = resp.get("rows") or []
        if not rows:
            return {}
        headers = [h["name"] for h in resp["columnHeaders"]]
        return dict(zip(headers, rows[0]))

    current = _totals(start, end)
    previous = _totals(prev_start, prev_end)
    return {"period_days": days, "start": start, "end": end, "current": current, "previous": previous}


def get_video_performance(credentials: Credentials, video_ids: list[str], days: int = 28) -> dict[str, dict]:
    """Per-video metrics for a specific set of video IDs (the clips this
    app uploaded), keyed by video id. Videos with no traffic in the window
    simply won't have a row and are omitted."""
    if not video_ids:
        return {}
    analytics = build("youtubeAnalytics", "v2", credentials=credentials)
    start, end = _date_range(days)
    resp = analytics.reports().query(
        ids="channel==MINE",
        startDate=start,
        endDate=end,
        metrics=VIDEO_METRICS,
        dimensions="video",
        filters=f"video=={','.join(video_ids)}",
        sort="-views",
        maxResults=len(video_ids),
    ).execute()
    headers = [h["name"] for h in resp.get("columnHeaders", [])]
    rows = resp.get("rows") or []
    return {row[0]: dict(zip(headers, row)) for row in rows}


def get_top_channel_videos(credentials: Credentials, days: int = 28, max_results: int = 10) -> list[dict]:
    """Top-performing videos on the whole channel in the window (not just
    ones uploaded by this app) — useful for spotting patterns to copy."""
    analytics = build("youtubeAnalytics", "v2", credentials=credentials)
    start, end = _date_range(days)
    resp = analytics.reports().query(
        ids="channel==MINE",
        startDate=start,
        endDate=end,
        metrics=VIDEO_METRICS,
        dimensions="video",
        sort="-views",
        maxResults=max_results,
    ).execute()
    headers = [h["name"] for h in resp.get("columnHeaders", [])]
    rows = resp.get("rows") or []
    return [dict(zip(headers, row)) for row in rows]
