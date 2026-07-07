from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_or_create_settings
from app.db.models import User
from app.db.session import get_db
from app.schemas.schemas import UserSettingsIn, UserSettingsOut

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=UserSettingsOut)
def get_settings_route(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return get_or_create_settings(db, user)


@router.put("", response_model=UserSettingsOut)
def update_settings(payload: UserSettingsIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = get_or_create_settings(db, user)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(row, key, value)
    db.commit()
    db.refresh(row)
    return row
