import os

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.db.models import JobType, ProcessingJob, User, Video, VideoStatus
from app.db.session import get_db
from app.schemas.schemas import ClipOut, ImportYoutubeRequest, VideoOut
from app.services import ffmpeg_utils, storage
from app.workers.tasks import analyze_video_task, import_from_url_task

router = APIRouter(prefix="/api/videos", tags=["videos"])
settings = get_settings()

ALLOWED_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv"}


@router.get("", response_model=list[VideoOut])
def list_videos(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Video).filter_by(owner_id=user.id).order_by(Video.created_at.desc()).all()


@router.post("", response_model=VideoOut)
def upload_video(
    file: UploadFile,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"Unsupported format {ext}. Allowed: {sorted(ALLOWED_EXTENSIONS)}")

    dest_dir = storage.uploads_dir(user.id)
    filename = storage.new_filename(file.filename or "video.mp4")
    dest_path = os.path.join(dest_dir, filename)

    size = 0
    with open(dest_path, "wb") as out:
        while chunk := file.file.read(1024 * 1024):
            size += len(chunk)
            if size > settings.MAX_UPLOAD_BYTES:
                out.close()
                os.remove(dest_path)
                raise HTTPException(413, "File too large")
            out.write(chunk)

    duration = 0.0
    try:
        duration = ffmpeg_utils.get_duration_seconds(dest_path)
    except Exception:
        pass

    video = Video(
        owner_id=user.id,
        title=os.path.splitext(file.filename or "video")[0],
        source_type="upload",
        file_path=dest_path,
        size_bytes=size,
        duration_seconds=duration,
        status=VideoStatus.UPLOADED,
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    job = ProcessingJob(job_type=JobType.ANALYZE_VIDEO, video_id=video.id)
    db.add(job)
    db.commit()
    analyze_video_task.delay(video.id, job.id)

    return video


@router.post("/import", response_model=VideoOut)
def import_video(
    payload: ImportYoutubeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    video = Video(
        owner_id=user.id,
        title="",
        source_type="youtube_url",
        source_url=payload.url,
        status=VideoStatus.UPLOADED,
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    job = ProcessingJob(job_type=JobType.ANALYZE_VIDEO, video_id=video.id)
    db.add(job)
    db.commit()
    import_from_url_task.delay(video.id, job.id)

    return video


@router.get("/{video_id}", response_model=VideoOut)
def get_video(video_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    video = db.get(Video, video_id)
    if not video or video.owner_id != user.id:
        raise HTTPException(404, "Video not found")
    return video


@router.get("/{video_id}/clips", response_model=list[ClipOut])
def get_video_clips(video_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    video = db.get(Video, video_id)
    if not video or video.owner_id != user.id:
        raise HTTPException(404, "Video not found")
    return video.clips


@router.delete("/{video_id}")
def delete_video(video_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    video = db.get(Video, video_id)
    if not video or video.owner_id != user.id:
        raise HTTPException(404, "Video not found")
    db.delete(video)
    db.commit()
    return {"ok": True}
