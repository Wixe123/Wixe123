"""Download a source video from a YouTube (or other yt-dlp-supported) URL
so it can be run through the same clip pipeline as a direct upload."""
import os
from datetime import datetime, timedelta

import yt_dlp

from app.core.config import get_settings

settings = get_settings()


def _ydl_opts(extra: dict | None = None) -> dict:
    opts = {"noplaylist": True, "quiet": True}
    if settings.YTDLP_COOKIES_FILE and os.path.isfile(settings.YTDLP_COOKIES_FILE):
        opts["cookiefile"] = settings.YTDLP_COOKIES_FILE
    if extra:
        opts.update(extra)
    return opts


def _channel_tab_url(channel_url: str, tab: str) -> str:
    url = channel_url.rstrip("/")
    for suffix in ("/videos", "/shorts", "/streams", "/featured"):
        if url.endswith(suffix):
            url = url[: -len(suffix)]
            break
    return f"{url}/{tab}"


def resolve_channel_latest_video(channel_url: str) -> tuple[str, str] | None:
    """Given a channel URL (e.g. youtube.com/@handle), returns
    (video_url, title) for its most recent public upload, or None if
    nothing could be resolved. Uses flat extraction — this only reads the
    channel's video list, it doesn't download anything."""
    url = _channel_tab_url(channel_url, "videos")
    ydl_opts = _ydl_opts({"extract_flat": True, "playlistend": 1})
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        entries = info.get("entries") or []
        if not entries:
            return None
        first = entries[0]
        video_id = first.get("id") or first.get("url")
        if not video_id:
            return None
        video_url = f"https://www.youtube.com/watch?v={video_id}" if "://" not in video_id else video_id
        return video_url, first.get("title", "")


def _best_thumbnail(obj: dict) -> str:
    thumbs = obj.get("thumbnails") or []
    return thumbs[-1]["url"] if thumbs else ""


def fetch_channel_weekly_shorts(channel_url: str, max_items: int = 12, days: int = 7) -> dict:
    """Pulls public metadata (title/thumbnail/view count) for a channel's
    recent Shorts and keeps whichever were published within the last
    `days` days, for the Trending feed. Nothing is downloaded — playback
    in the app happens through YouTube's own embed player."""
    url = _channel_tab_url(channel_url, "shorts")
    ydl_opts = _ydl_opts({"playlistend": max_items, "ignoreerrors": True})
    cutoff = datetime.utcnow() - timedelta(days=days)

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False) or {}

    entries = [e for e in (info.get("entries") or []) if e]

    videos = []
    for e in entries:
        video_id = e.get("id")
        if not video_id:
            continue
        published_at = None
        upload_date = e.get("upload_date")
        if upload_date:
            try:
                published_at = datetime.strptime(upload_date, "%Y%m%d")
            except ValueError:
                published_at = None
        if published_at and published_at < cutoff:
            continue
        videos.append(
            {
                "youtube_video_id": video_id,
                "video_url": f"https://www.youtube.com/watch?v={video_id}",
                "title": e.get("title", ""),
                "thumbnail_url": _best_thumbnail(e) or f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg",
                "view_count": int(e.get("view_count") or 0),
                "published_at": published_at,
                "duration_seconds": int(e.get("duration") or 0),
            }
        )

    return {
        "channel_title": info.get("channel") or info.get("uploader") or "",
        "avatar_url": _best_thumbnail(info),
        "subscriber_count": info.get("channel_follower_count"),
        "videos": videos,
    }


def download_video(url: str, out_dir: str) -> tuple[str, str]:
    """Returns (file_path, title)."""
    # Without real session cookies, YouTube frequently rejects even
    # ordinary public videos with "Please sign in" / bot-check errors —
    # handled by _ydl_opts adding cookiefile when YTDLP_COOKIES_FILE is set.
    ydl_opts = _ydl_opts(
        {
            "outtmpl": f"{out_dir}/%(id)s.%(ext)s",
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "merge_output_format": "mp4",
        }
    )
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        file_path = ydl.prepare_filename(info)
        if not file_path.endswith(".mp4"):
            file_path = file_path.rsplit(".", 1)[0] + ".mp4"
        return file_path, info.get("title", "Imported video")
