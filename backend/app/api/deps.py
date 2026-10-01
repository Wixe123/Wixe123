from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.models import User, UserSettings
from app.db.session import get_db

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    token: str | None = None,
    db: Session = Depends(get_db),
) -> User:
    # `token` query param exists only so <video>/<img> tags (which can't set
    # an Authorization header) can load protected media; prefer the header.
    raw_token = credentials.credentials if credentials else token
    if not raw_token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    user_id = decode_access_token(raw_token)
    if not user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return user


def get_or_create_settings(db: Session, user: User) -> UserSettings:
    if user.settings:
        return user.settings
    settings_row = UserSettings(user_id=user.id)
    db.add(settings_row)
    db.commit()
    db.refresh(settings_row)
    return settings_row
