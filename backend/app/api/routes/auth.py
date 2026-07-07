import secrets

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.security import create_access_token, encrypt_secret
from app.db.models import User, YouTubeCredential
from app.db.session import get_db
from app.schemas.schemas import UserOut
from app.services.youtube_client import (
    LOGIN_SCOPES,
    YOUTUBE_SCOPES,
    build_auth_url,
    exchange_code,
    fetch_userinfo,
    get_my_channel,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])
settings = get_settings()

_state_store: set[str] = set()  # dev-scale CSRF state cache; swap for Redis if you add multiple API instances


@router.get("/google/login")
def google_login():
    state = secrets.token_urlsafe(24)
    _state_store.add(state)
    url = build_auth_url(LOGIN_SCOPES, settings.GOOGLE_REDIRECT_URI, state)
    return {"auth_url": url}


@router.get("/google/callback")
def google_callback(code: str, state: str, db: Session = Depends(get_db)):
    if state not in _state_store:
        raise HTTPException(400, "Invalid state")
    _state_store.discard(state)

    credentials = exchange_code(code, LOGIN_SCOPES, settings.GOOGLE_REDIRECT_URI)
    userinfo = fetch_userinfo(credentials)

    user = db.query(User).filter_by(google_sub=userinfo["id"]).first()
    if not user:
        user = User(
            email=userinfo["email"],
            name=userinfo.get("name", ""),
            avatar_url=userinfo.get("picture", ""),
            google_sub=userinfo["id"],
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user.id)
    return RedirectResponse(f"{settings.FRONTEND_URL}/login/callback?token={token}")


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.get("/youtube/connect")
def youtube_connect(user: User = Depends(get_current_user)):
    state = secrets.token_urlsafe(24) + f"|{user.id}"
    _state_store.add(state)
    url = build_auth_url(YOUTUBE_SCOPES, settings.YOUTUBE_REDIRECT_URI, state)
    return {"auth_url": url}


@router.get("/youtube/callback")
def youtube_callback(code: str, state: str, db: Session = Depends(get_db)):
    if state not in _state_store:
        raise HTTPException(400, "Invalid state")
    _state_store.discard(state)
    user_id = state.split("|")[-1]
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")

    credentials = exchange_code(code, YOUTUBE_SCOPES, settings.YOUTUBE_REDIRECT_URI)
    channel = get_my_channel(credentials) or {}

    existing = db.query(YouTubeCredential).filter_by(user_id=user.id).first()
    encrypted = encrypt_secret(credentials.refresh_token) if credentials.refresh_token else (
        existing.encrypted_refresh_token if existing else ""
    )
    if existing:
        existing.encrypted_refresh_token = encrypted
        existing.channel_id = channel.get("id", "")
        existing.channel_title = channel.get("title", "")
        existing.scopes = " ".join(YOUTUBE_SCOPES)
    else:
        db.add(YouTubeCredential(
            user_id=user.id,
            encrypted_refresh_token=encrypted,
            channel_id=channel.get("id", ""),
            channel_title=channel.get("title", ""),
            scopes=" ".join(YOUTUBE_SCOPES),
        ))
    db.commit()

    return RedirectResponse(f"{settings.FRONTEND_URL}/settings?youtube_connected=1")


@router.get("/youtube/status")
def youtube_status(user: User = Depends(get_current_user)):
    if not user.youtube_credential:
        return {"connected": False}
    return {
        "connected": True,
        "channel_title": user.youtube_credential.channel_title,
        "channel_id": user.youtube_credential.channel_id,
    }
