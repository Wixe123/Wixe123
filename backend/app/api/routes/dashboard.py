from datetime import datetime, time

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.db.models import Clip, ClipStatus, JobStatus, JobType, ProcessingJob, User, Video
from app.db.session import get_db
from app.schemas.schemas import DashboardStats
from app.services.storage import total_storage_bytes

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])
settings = get_settings()


def _today_start() -> datetime:
    return datetime.combine(datetime.utcnow().date(), time.min)


@router.get("/stats", response_model=DashboardStats)
def stats(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    since = _today_start()

    videos_today = db.query(Video).filter(Video.owner_id == user.id, Video.created_at >= since).count()

    shorts_today = (
        db.query(Clip).join(Video).filter(Video.owner_id == user.id, Clip.created_at >= since).count()
    )

    job_query = db.query(ProcessingJob).join(Video, ProcessingJob.video_id == Video.id).filter(
        Video.owner_id == user.id
    )
    queue_length = job_query.filter(ProcessingJob.status == JobStatus.QUEUED).count()
    processing_count = job_query.filter(ProcessingJob.status == JobStatus.RUNNING).count()
    failed_count = job_query.filter(ProcessingJob.status == JobStatus.FAILED).count()

    uploaded_today = (
        db.query(Clip)
        .join(Video)
        .filter(Video.owner_id == user.id, Clip.status == ClipStatus.UPLOADED, Clip.updated_at >= since)
        .count()
    )

    api_calls_today = job_query.filter(
        ProcessingJob.job_type == JobType.UPLOAD_CLIP, ProcessingJob.created_at >= since
    ).count()

    return DashboardStats(
        videos_today=videos_today,
        shorts_created_today=shorts_today,
        queue_length=queue_length,
        processing_count=processing_count,
        failed_count=failed_count,
        uploaded_today=uploaded_today,
        storage_used_bytes=total_storage_bytes(),
        storage_quota_bytes=settings.STORAGE_QUOTA_BYTES,
        api_calls_today=api_calls_today,
    )
