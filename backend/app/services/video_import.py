"""Download a source video from a YouTube (or other yt-dlp-supported) URL
so it can be run through the same clip pipeline as a direct upload."""
import os

import yt_dlp

from app.core.config import get_settings

settings = get_settings()


def download_video(url: str, out_dir: str) -> tuple[str, str]:
    """Returns (file_path, title)."""
    ydl_opts = {
        "outtmpl": f"{out_dir}/%(id)s.%(ext)s",
        "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
    }
    # Without real session cookies, YouTube frequently rejects even
    # ordinary public videos with "Please sign in" / bot-check errors.
    if settings.YTDLP_COOKIES_FILE and os.path.isfile(settings.YTDLP_COOKIES_FILE):
        ydl_opts["cookiefile"] = settings.YTDLP_COOKIES_FILE
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        file_path = ydl.prepare_filename(info)
        if not file_path.endswith(".mp4"):
            file_path = file_path.rsplit(".", 1)[0] + ".mp4"
        return file_path, info.get("title", "Imported video")
