from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import JobStatus, ProcessingJob, User, Video
from app.db.session import get_db
from app.schemas.schemas import JobOut
from app.workers.celery_app import celery_app

router = APIRouter(prefix="/api/jobs", tags=["jobs"])


def _user_job_query(db: Session, user: User):
    return (
        db.query(ProcessingJob)
        .join(Video, ProcessingJob.video_id == Video.id)
        .filter(Video.owner_id == user.id)
    )


@router.get("", response_model=list[JobOut])
def list_jobs(status: JobStatus | None = None, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    query = _user_job_query(db, user)
    if status:
        query = query.filter(ProcessingJob.status == status)
    return query.order_by(ProcessingJob.created_at.desc()).limit(200).all()


def _owned_job(job_id: str, user: User, db: Session) -> ProcessingJob:
    job = db.get(ProcessingJob, job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    video = db.get(Video, job.video_id) if job.video_id else None
    if not video or video.owner_id != user.id:
        raise HTTPException(404, "Job not found")
    return job


@router.post("/{job_id}/cancel", response_model=JobOut)
def cancel_job(job_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    job = _owned_job(job_id, user, db)
    if job.celery_task_id:
        celery_app.control.revoke(job.celery_task_id, terminate=True)
    job.status = JobStatus.CANCELLED
    db.commit()
    return job


@router.post("/{job_id}/pause", response_model=JobOut)
def pause_job(job_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    job = _owned_job(job_id, user, db)
    if job.celery_task_id:
        celery_app.control.revoke(job.celery_task_id)
    job.status = JobStatus.PAUSED
    db.commit()
    return job


@router.post("/{job_id}/retry", response_model=JobOut)
def retry_job(job_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    from app.workers.tasks import analyze_video_task, render_clip_task, upload_clip_task

    job = _owned_job(job_id, user, db)
    job.status = JobStatus.QUEUED
    job.attempts += 1
    job.error_message = ""
    db.commit()

    dispatch = {
        "analyze_video": lambda: analyze_video_task.delay(job.video_id, job.id),
        "render_clip": lambda: render_clip_task.delay(job.clip_id, job.id),
        "upload_clip": lambda: upload_clip_task.delay(job.clip_id, job.id),
    }
    fn = dispatch.get(job.job_type.value)
    if fn:
        fn()
    return job
