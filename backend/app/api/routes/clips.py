from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_or_create_settings
from app.db.models import Clip, ClipStatus, JobType, ProcessingJob, User, Video
from app.db.session import get_db
from app.schemas.schemas import ClipOut, ClipUpdate
from app.workers.tasks import render_clip_task, upload_clip_task

router = APIRouter(prefix="/api/clips", tags=["clips"])


def _owned_clip(clip_id: str, user: User, db: Session) -> Clip:
    clip = db.get(Clip, clip_id)
    if not clip:
        raise HTTPException(404, "Clip not found")
    video = db.get(Video, clip.video_id)
    if not video or video.owner_id != user.id:
        raise HTTPException(404, "Clip not found")
    return clip


@router.get("", response_model=list[ClipOut])
def list_clips(status: ClipStatus | None = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    query = db.query(Clip).join(Video).filter(Video.owner_id == user.id)
    if status:
        query = query.filter(Clip.status == status)
    return query.order_by(Clip.created_at.desc()).all()


@router.get("/{clip_id}", response_model=ClipOut)
def get_clip(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _owned_clip(clip_id, user, db)


@router.patch("/{clip_id}", response_model=ClipOut)
def update_clip(clip_id: str, payload: ClipUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    data = payload.model_dump(exclude_unset=True)
    resubmit_render = "subtitle_style" in data or "branding_preset_id" in data
    for key, value in data.items():
        setattr(clip, key, value)
    db.commit()
    db.refresh(clip)
    if resubmit_render and clip.status in (ClipStatus.READY_FOR_REVIEW, ClipStatus.FAILED):
        clip.status = ClipStatus.PENDING_RENDER
        db.commit()
        job = ProcessingJob(job_type=JobType.RENDER_CLIP, video_id=clip.video_id, clip_id=clip.id)
        db.add(job)
        db.commit()
        render_clip_task.delay(clip.id, job.id)
    return clip


@router.post("/{clip_id}/approve", response_model=ClipOut)
def approve_clip(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    if clip.status != ClipStatus.READY_FOR_REVIEW:
        raise HTTPException(400, f"Clip is not ready for review (status={clip.status.value})")
    clip.status = ClipStatus.APPROVED
    db.commit()

    user_settings = get_or_create_settings(db, user)
    if user_settings.auto_upload_after_approval:
        return _enqueue_upload(clip, db)
    return clip


@router.post("/{clip_id}/reject", response_model=ClipOut)
def reject_clip(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    clip.status = ClipStatus.REJECTED
    db.commit()
    return clip


@router.post("/{clip_id}/upload", response_model=ClipOut)
def upload_clip(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    if clip.status not in (ClipStatus.APPROVED, ClipStatus.FAILED):
        raise HTTPException(400, f"Clip must be approved first (status={clip.status.value})")
    return _enqueue_upload(clip, db)


def _enqueue_upload(clip: Clip, db: Session) -> Clip:
    job = ProcessingJob(job_type=JobType.UPLOAD_CLIP, video_id=clip.video_id, clip_id=clip.id)
    db.add(job)
    db.commit()
    upload_clip_task.delay(clip.id, job.id)
    db.refresh(clip)
    return clip


@router.post("/{clip_id}/retry-render", response_model=ClipOut)
def retry_render(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    clip.status = ClipStatus.PENDING_RENDER
    db.commit()
    job = ProcessingJob(job_type=JobType.RENDER_CLIP, video_id=clip.video_id, clip_id=clip.id)
    db.add(job)
    db.commit()
    render_clip_task.delay(clip.id, job.id)
    return clip


@router.get("/{clip_id}/video")
def get_clip_video(
    clip_id: str, download: bool = False, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    clip = _owned_clip(clip_id, user, db)
    if not clip.file_path:
        raise HTTPException(404, "Clip not rendered yet")
    # Plain inline response for <video> preview playback; with ?download=true
    # the filename= kwarg makes Starlette send Content-Disposition: attachment,
    # which the browser honors as a real download regardless of how the link
    # was clicked (the HTML `download` attribute alone isn't reliable
    # cross-origin, e.g. frontend on :3000 fetching from backend on :8000).
    filename = f"{(clip.title or 'clip').strip()[:80]}.mp4" if download else None
    return FileResponse(clip.file_path, media_type="video/mp4", filename=filename)


@router.get("/{clip_id}/thumbnail")
def get_clip_thumbnail(clip_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    clip = _owned_clip(clip_id, user, db)
    if not clip.thumbnail_path:
        raise HTTPException(404, "Thumbnail not available")
    return FileResponse(clip.thumbnail_path, media_type="image/jpeg")
