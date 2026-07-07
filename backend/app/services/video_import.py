"""Download a source video from a YouTube (or other yt-dlp-supported) URL
so it can be run through the same clip pipeline as a direct upload."""
import yt_dlp


def download_video(url: str, out_dir: str) -> tuple[str, str]:
    """Returns (file_path, title)."""
    ydl_opts = {
        "outtmpl": f"{out_dir}/%(id)s.%(ext)s",
        "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        file_path = ydl.prepare_filename(info)
        if not file_path.endswith(".mp4"):
            file_path = file_path.rsplit(".", 1)[0] + ".mp4"
        return file_path, info.get("title", "Imported video")
