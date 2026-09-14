from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_or_create_settings
from app.db.models import ProcessingJob, JobType, User
from app.db.session import get_db
from app.workers.tasks import generate_faceless_video_task

router = APIRouter(prefix="/api/faceless", tags=["faceless"])


@router.post("/generate")
def generate_faceless_video(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user_settings = get_or_create_settings(db, user)
    if not user_settings.faceless_niche:
        raise HTTPException(400, "Set a niche in Settings first.")

    job = ProcessingJob(job_type=JobType.GENERATE_FACELESS_VIDEO)
    db.add(job)
    db.commit()
    db.refresh(job)
    generate_faceless_video_task.delay(user.id, job.id)
    return {"status": "queued", "job_id": job.id}
