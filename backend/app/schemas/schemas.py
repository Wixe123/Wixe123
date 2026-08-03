from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.db.models import ClipStatus, JobStatus, JobType, VideoStatus, Visibility


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str
    name: str
    avatar_url: str


class VideoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    title: str
    source_type: str
    duration_seconds: float
    size_bytes: int
    status: VideoStatus
    error_message: str
    created_at: datetime


class ClipOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    video_id: str
    start_seconds: float
    end_seconds: float
    score: float
    score_reasons: list
    status: ClipStatus
    file_path: str
    thumbnail_path: str
    title: str
    description: str
    hashtags: list
    keywords: list
    seo_score: float
    visibility: Visibility
    playlist_id: str
    scheduled_at: datetime | None
    subtitle_style: dict
    youtube_video_id: str
    error_message: str
    created_at: datetime


class ClipUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    hashtags: list[str] | None = None
    visibility: Visibility | None = None
    playlist_id: str | None = None
    scheduled_at: datetime | None = None
    subtitle_style: dict | None = None
    branding_preset_id: str | None = None


class ImportYoutubeRequest(BaseModel):
    url: str


class JobOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    job_type: JobType
    status: JobStatus
    video_id: str | None
    clip_id: str | None
    attempts: int
    progress: float
    error_message: str
    created_at: datetime
    updated_at: datetime


class AnalyticsOverview(BaseModel):
    period_days: int
    start: str
    end: str
    views: int
    watch_time_minutes: float
    average_view_duration_seconds: float
    likes: int
    comments: int
    shares: int
    subscribers_gained: int
    views_delta_pct: float | None
    watch_time_delta_pct: float | None
    subscribers_delta_pct: float | None


class ClipPerformance(BaseModel):
    clip_id: str
    youtube_video_id: str
    title: str
    views: int
    watch_time_minutes: float
    average_view_duration_seconds: float
    average_view_percentage: float
    likes: int
    comments: int
    score: float
    score_reasons: list[str]


class TrendPoint(BaseModel):
    date: str
    views: int
    watch_time_minutes: float


class TopVideo(BaseModel):
    video_id: str
    title: str
    thumbnail: str
    views: int
    watch_time_minutes: float
    likes: int


class DashboardStats(BaseModel):
    videos_today: int
    shorts_created_today: int
    queue_length: int
    processing_count: int
    failed_count: int
    uploaded_today: int
    storage_used_bytes: int
    storage_quota_bytes: int
    api_calls_today: int


class BrandingPresetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    logo_path: str
    watermark_path: str
    intro_path: str
    outro_path: str
    font_family: str
    primary_color: str
    accent_color: str
    is_default: bool


class BrandingPresetIn(BaseModel):
    name: str
    logo_path: str = ""
    watermark_path: str = ""
    intro_path: str = ""
    outro_path: str = ""
    font_family: str = "Inter"
    primary_color: str = "#7C3AED"
    accent_color: str = "#22D3EE"
    is_default: bool = False


class UserSettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    subtitle_font: str
    subtitle_color: str
    subtitle_highlight_color: str
    subtitle_stroke_color: str
    subtitle_position: str
    subtitle_emoji_enabled: bool
    subtitle_language: str
    export_quality: str
    clip_min_seconds: int
    clip_max_seconds: int
    max_clips_per_video: int
    ai_sensitivity: float
    default_visibility: Visibility
    auto_upload_after_approval: bool
    default_branding_preset_id: str | None
    active_style_profile_id: str | None
    auto_approve_score_threshold: float | None
    auto_import_from_channel: bool


class StyleProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    source_url: str
    creator_label: str
    status: str
    hook_analysis: str
    pacing_analysis: str
    structure_analysis: str
    summary: str
    error_message: str
    created_at: datetime


class StyleProfileCreate(BaseModel):
    source_url: str
    creator_label: str = ""


class WatchedChannelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    channel_url: str
    label: str
    created_at: datetime
    channel_title: str
    avatar_url: str
    subscriber_count: int | None
    last_refreshed_at: datetime | None


class WatchedChannelCreate(BaseModel):
    channel_url: str
    label: str = ""


class TrendingClipOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    watched_channel_id: str
    youtube_video_id: str
    video_url: str
    title: str
    thumbnail_url: str
    channel_title: str
    channel_url: str
    view_count: int
    published_at: datetime | None
    duration_seconds: int


class WatchedChannelDetail(WatchedChannelOut):
    clips: list[TrendingClipOut] = []


class UserSettingsIn(BaseModel):
    subtitle_font: str | None = None
    subtitle_color: str | None = None
    subtitle_highlight_color: str | None = None
    subtitle_stroke_color: str | None = None
    subtitle_position: str | None = None
    subtitle_emoji_enabled: bool | None = None
    subtitle_language: str | None = None
    export_quality: str | None = None
    clip_min_seconds: int | None = None
    clip_max_seconds: int | None = None
    max_clips_per_video: int | None = None
    ai_sensitivity: float | None = None
    default_visibility: Visibility | None = None
    auto_upload_after_approval: bool | None = None
    default_branding_preset_id: str | None = None
    active_style_profile_id: str | None = None
    auto_approve_score_threshold: float | None = None
    auto_import_from_channel: bool | None = None
