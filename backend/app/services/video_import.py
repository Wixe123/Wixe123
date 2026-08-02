"""Download a source video from a YouTube (or other yt-dlp-supported) URL
so it can be run through the same clip pipeline as a direct upload."""
import os

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


def resolve_channel_latest_video(channel_url: str) -> tuple[str, str] | None:
    """Given a channel URL (e.g. youtube.com/@handle), returns
    (video_url, title) for its most recent public upload, or None if
    nothing could be resolved. Uses flat extraction — this only reads the
    channel's video list, it doesn't download anything."""
    url = channel_url.rstrip("/")
    if not url.endswith("/videos"):
        url += "/videos"
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
