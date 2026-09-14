from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import StyleProfile, User
from app.db.session import get_db
from app.schemas.schemas import StyleProfileCreate, StyleProfileOut
from app.workers.tasks import analyze_style_task

router = APIRouter(prefix="/api/style-profiles", tags=["style"])


@router.get("", response_model=list[StyleProfileOut])
def list_style_profiles(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(StyleProfile).filter_by(user_id=user.id).order_by(StyleProfile.created_at.desc()).all()


@router.post("", response_model=StyleProfileOut)
def create_style_profile(
    payload: StyleProfileCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    profile = StyleProfile(
        user_id=user.id,
        source_url=payload.source_url,
        creator_label=payload.creator_label,
        status="analyzing",
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    analyze_style_task.delay(profile.id)
    return profile


@router.get("/{profile_id}", response_model=StyleProfileOut)
def get_style_profile(profile_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    profile = db.get(StyleProfile, profile_id)
    if not profile or profile.user_id != user.id:
        raise HTTPException(404, "Style profile not found")
    return profile


@router.delete("/{profile_id}")
def delete_style_profile(profile_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    profile = db.get(StyleProfile, profile_id)
    if not profile or profile.user_id != user.id:
        raise HTTPException(404, "Style profile not found")
    db.delete(profile)
    db.commit()
    return {"ok": True}
