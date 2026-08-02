import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _enum_column(enum_cls):
    """sa.Enum(SomePyEnum) persists the member *name* (e.g. "PRIVATE") by
    default, not its .value ("private") — but the Postgres enum type
    created by the Alembic migration only has the lowercase values.
    values_callable makes SQLAlchemy store/compare by .value instead."""
    return Enum(enum_cls, values_callable=lambda obj: [e.value for e in obj])


class VideoStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    TRANSCRIBING = "transcribing"
    ANALYZING = "analyzing"
    ANALYZED = "analyzed"
    FAILED = "failed"


class ClipStatus(str, enum.Enum):
    PENDING_RENDER = "pending_render"
    RENDERING = "rendering"
    READY_FOR_REVIEW = "ready_for_review"
    APPROVED = "approved"
    SCHEDULED = "scheduled"
    UPLOADING = "uploading"
    UPLOADED = "uploaded"
    FAILED = "failed"
    REJECTED = "rejected"


class Visibility(str, enum.Enum):
    PUBLIC = "public"
    UNLISTED = "unlisted"
    PRIVATE = "private"
    DRAFT = "draft"


class JobStatus(str, enum.Enum):
    QUEUED = "queued"
    RUNNING = "running"
    PAUSED = "paused"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"


class JobType(str, enum.Enum):
    ANALYZE_VIDEO = "analyze_video"
    RENDER_CLIP = "render_clip"
    UPLOAD_CLIP = "upload_clip"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str] = mapped_column(String, default="")
    avatar_url: Mapped[str] = mapped_column(String, default="")
    google_sub: Mapped[str] = mapped_column(String, unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    videos: Mapped[list["Video"]] = relationship(back_populates="owner", cascade="all, delete-orphan")
    settings: Mapped["UserSettings"] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")
    branding_presets: Mapped[list["BrandingPreset"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    youtube_credential: Mapped["YouTubeCredential"] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")
    style_profiles: Mapped[list["StyleProfile"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class YouTubeCredential(Base):
    __tablename__ = "youtube_credentials"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    channel_id: Mapped[str] = mapped_column(String, default="")
    channel_title: Mapped[str] = mapped_column(String, default="")
    encrypted_refresh_token: Mapped[str] = mapped_column(Text)
    scopes: Mapped[str] = mapped_column(String, default="")
    connected_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates="youtube_credential")


class Video(Base):
    __tablename__ = "videos"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    title: Mapped[str] = mapped_column(String, default="")
    source_type: Mapped[str] = mapped_column(String, default="upload")  # upload | youtube_url
    source_url: Mapped[str] = mapped_column(String, default="")
    file_path: Mapped[str] = mapped_column(String, default="")
    duration_seconds: Mapped[float] = mapped_column(Float, default=0)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[VideoStatus] = mapped_column(_enum_column(VideoStatus), default=VideoStatus.UPLOADED)
    error_message: Mapped[str] = mapped_column(Text, default="")
    transcript: Mapped[dict] = mapped_column(JSON, default=dict)  # {segments:[...], words:[...]}
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner: Mapped[User] = relationship(back_populates="videos")
    clips: Mapped[list["Clip"]] = relationship(back_populates="video", cascade="all, delete-orphan")


class Clip(Base):
    __tablename__ = "clips"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    video_id: Mapped[str] = mapped_column(ForeignKey("videos.id"))
    start_seconds: Mapped[float] = mapped_column(Float)
    end_seconds: Mapped[float] = mapped_column(Float)
    score: Mapped[float] = mapped_column(Float, default=0)
    score_reasons: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[ClipStatus] = mapped_column(_enum_column(ClipStatus), default=ClipStatus.PENDING_RENDER)
    file_path: Mapped[str] = mapped_column(String, default="")
    thumbnail_path: Mapped[str] = mapped_column(String, default="")

    title: Mapped[str] = mapped_column(String, default="")
    description: Mapped[str] = mapped_column(Text, default="")
    hashtags: Mapped[list] = mapped_column(JSON, default=list)
    keywords: Mapped[list] = mapped_column(JSON, default=list)
    seo_score: Mapped[float] = mapped_column(Float, default=0)

    visibility: Mapped[Visibility] = mapped_column(_enum_column(Visibility), default=Visibility.PRIVATE)
    playlist_id: Mapped[str] = mapped_column(String, default="")
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    subtitle_style: Mapped[dict] = mapped_column(JSON, default=dict)
    branding_preset_id: Mapped[str | None] = mapped_column(ForeignKey("branding_presets.id"), nullable=True)

    youtube_video_id: Mapped[str] = mapped_column(String, default="")
    error_message: Mapped[str] = mapped_column(Text, default="")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    video: Mapped[Video] = relationship(back_populates="clips")
    branding_preset: Mapped["BrandingPreset"] = relationship()


class ProcessingJob(Base):
    __tablename__ = "processing_jobs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    job_type: Mapped[JobType] = mapped_column(_enum_column(JobType))
    status: Mapped[JobStatus] = mapped_column(_enum_column(JobStatus), default=JobStatus.QUEUED)
    video_id: Mapped[str | None] = mapped_column(ForeignKey("videos.id"), nullable=True)
    clip_id: Mapped[str | None] = mapped_column(ForeignKey("clips.id"), nullable=True)
    celery_task_id: Mapped[str] = mapped_column(String, default="")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    progress: Mapped[float] = mapped_column(Float, default=0)
    error_message: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class BrandingPreset(Base):
    __tablename__ = "branding_presets"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String)
    logo_path: Mapped[str] = mapped_column(String, default="")
    watermark_path: Mapped[str] = mapped_column(String, default="")
    intro_path: Mapped[str] = mapped_column(String, default="")
    outro_path: Mapped[str] = mapped_column(String, default="")
    font_family: Mapped[str] = mapped_column(String, default="Inter")
    primary_color: Mapped[str] = mapped_column(String, default="#CCA660")
    accent_color: Mapped[str] = mapped_column(String, default="#F2F1EE")
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates="branding_presets")


class UserSettings(Base):
    __tablename__ = "user_settings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)

    subtitle_font: Mapped[str] = mapped_column(String, default="Bebas Neue")
    subtitle_color: Mapped[str] = mapped_column(String, default="#FFFFFF")
    subtitle_highlight_color: Mapped[str] = mapped_column(String, default="#FFFFFF")
    subtitle_stroke_color: Mapped[str] = mapped_column(String, default="#000000")
    subtitle_position: Mapped[str] = mapped_column(String, default="center")  # bottom|center|top
    subtitle_emoji_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    subtitle_language: Mapped[str] = mapped_column(String, default="en")

    export_quality: Mapped[str] = mapped_column(String, default="1080p")  # 720p|1080p|4k
    clip_min_seconds: Mapped[int] = mapped_column(Integer, default=15)
    clip_max_seconds: Mapped[int] = mapped_column(Integer, default=60)
    max_clips_per_video: Mapped[int] = mapped_column(Integer, default=6)
    ai_sensitivity: Mapped[float] = mapped_column(Float, default=0.5)  # 0..1, lower = more clips

    default_visibility: Mapped[Visibility] = mapped_column(_enum_column(Visibility), default=Visibility.PRIVATE)
    auto_upload_after_approval: Mapped[bool] = mapped_column(Boolean, default=False)
    default_branding_preset_id: Mapped[str | None] = mapped_column(ForeignKey("branding_presets.id"), nullable=True)
    # When set, new clip titles/descriptions are written to emulate this
    # StyleProfile's analyzed hook/tone/structure (see metadata_ai.py).
    active_style_profile_id: Mapped[str | None] = mapped_column(ForeignKey("style_profiles.id"), nullable=True)
    # When set, a clip scoring at or above this skips manual review and
    # uploads immediately once rendered (see render_clip_task). None/unset
    # means every clip still needs a manual Approve click, same as before.
    auto_approve_score_threshold: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Poll the connected channel's uploads for new videos and auto-import
    # them, instead of requiring a manual upload/URL-import each time.
    auto_import_from_channel: Mapped[bool] = mapped_column(Boolean, default=False)
    last_channel_check_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    user: Mapped[User] = relationship(back_populates="settings")


class StyleProfile(Base):
    """A reference video the user points the analyzer at (a creator/clip
    whose approach they want to deliberately emulate) plus the extracted
    style findings — hook pattern, pacing, structure. This never stores or
    re-publishes the reference creator's actual content, only a written
    analysis of their technique."""

    __tablename__ = "style_profiles"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    source_url: Mapped[str] = mapped_column(String)
    creator_label: Mapped[str] = mapped_column(String, default="")
    status: Mapped[str] = mapped_column(String, default="analyzing")  # analyzing|ready|failed
    hook_analysis: Mapped[str] = mapped_column(Text, default="")
    pacing_analysis: Mapped[str] = mapped_column(Text, default="")
    structure_analysis: Mapped[str] = mapped_column(Text, default="")
    summary: Mapped[str] = mapped_column(Text, default="")
    error_message: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates="style_profiles")
