"""Local filesystem storage. Swap for an S3/GCS-backed implementation with
the same function signatures if you move off a single box."""
import os
import uuid

from app.core.config import get_settings

settings = get_settings()


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def uploads_dir(user_id: str) -> str:
    path = os.path.join(settings.STORAGE_ROOT, "uploads", user_id)
    _ensure_dir(path)
    return path


def clips_dir(video_id: str) -> str:
    path = os.path.join(settings.STORAGE_ROOT, "clips", video_id)
    _ensure_dir(path)
    return path


def branding_dir(user_id: str) -> str:
    path = os.path.join(settings.STORAGE_ROOT, "branding", user_id)
    _ensure_dir(path)
    return path


def style_profile_dir(profile_id: str) -> str:
    """Scratch space for a style analysis's downloaded reference
    video/audio — deleted once analysis finishes, since only the written
    findings are meant to persist, not the reference creator's content."""
    path = os.path.join(settings.STORAGE_ROOT, "style_profiles", profile_id)
    _ensure_dir(path)
    return path


def new_filename(original_name: str) -> str:
    ext = os.path.splitext(original_name)[1].lower() or ".mp4"
    return f"{uuid.uuid4()}{ext}"


def path_size_bytes(path: str) -> int:
    try:
        return os.path.getsize(path)
    except OSError:
        return 0


def total_storage_bytes() -> int:
    total = 0
    for root, _dirs, files in os.walk(settings.STORAGE_ROOT):
        for f in files:
            total += path_size_bytes(os.path.join(root, f))
    return total
