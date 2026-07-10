"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-07-07

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM as PGEnum

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

# create_type=False on every enum: they're explicitly created once up front
# in upgrade() below. Without this, SQLAlchemy also tries to auto-create
# the enum type the first time each column using it appears in a
# create_table() call — and visibility/clip_status etc. are each reused
# across multiple tables, so the second table hits "type already exists".
# Note this only takes effect via postgresql.ENUM specifically — the
# generic sa.Enum(create_type=False) silently ignores the kwarg when
# adapted to the postgres dialect.
video_status = PGEnum(
    "uploaded", "transcribing", "analyzing", "analyzed", "failed",
    name="videostatus", create_type=False,
)
clip_status = PGEnum(
    "pending_render", "rendering", "ready_for_review", "approved", "scheduled",
    "uploading", "uploaded", "failed", "rejected", name="clipstatus", create_type=False,
)
visibility = PGEnum("public", "unlisted", "private", "draft", name="visibility", create_type=False)
job_status = PGEnum(
    "queued", "running", "paused", "success", "failed", "cancelled",
    name="jobstatus", create_type=False,
)
job_type = PGEnum("analyze_video", "render_clip", "upload_clip", name="jobtype", create_type=False)


def upgrade() -> None:
    bind = op.get_bind()
    for enum in (video_status, clip_status, visibility, job_status, job_type):
        enum.create(bind, checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("email", sa.String(), unique=True, index=True, nullable=False),
        sa.Column("name", sa.String(), server_default=""),
        sa.Column("avatar_url", sa.String(), server_default=""),
        sa.Column("google_sub", sa.String(), unique=True, index=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "branding_presets",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("logo_path", sa.String(), server_default=""),
        sa.Column("watermark_path", sa.String(), server_default=""),
        sa.Column("intro_path", sa.String(), server_default=""),
        sa.Column("outro_path", sa.String(), server_default=""),
        sa.Column("font_family", sa.String(), server_default="Inter"),
        sa.Column("primary_color", sa.String(), server_default="#CCA660"),
        sa.Column("accent_color", sa.String(), server_default="#F2F1EE"),
        sa.Column("is_default", sa.Boolean(), server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "youtube_credentials",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("channel_id", sa.String(), server_default=""),
        sa.Column("channel_title", sa.String(), server_default=""),
        sa.Column("encrypted_refresh_token", sa.Text(), nullable=False),
        sa.Column("scopes", sa.String(), server_default=""),
        sa.Column("connected_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "user_settings",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("subtitle_font", sa.String(), server_default="Playfair Display"),
        sa.Column("subtitle_color", sa.String(), server_default="#FFFFFF"),
        sa.Column("subtitle_highlight_color", sa.String(), server_default="#FFFFFF"),
        sa.Column("subtitle_stroke_color", sa.String(), server_default="#000000"),
        sa.Column("subtitle_position", sa.String(), server_default="center"),
        sa.Column("subtitle_emoji_enabled", sa.Boolean(), server_default=sa.true()),
        sa.Column("subtitle_language", sa.String(), server_default="en"),
        sa.Column("export_quality", sa.String(), server_default="1080p"),
        sa.Column("clip_min_seconds", sa.Integer(), server_default="15"),
        sa.Column("clip_max_seconds", sa.Integer(), server_default="60"),
        sa.Column("max_clips_per_video", sa.Integer(), server_default="6"),
        sa.Column("ai_sensitivity", sa.Float(), server_default="0.5"),
        sa.Column("default_visibility", visibility, server_default="private"),
        sa.Column("auto_upload_after_approval", sa.Boolean(), server_default=sa.false()),
        sa.Column("default_branding_preset_id", sa.String(), sa.ForeignKey("branding_presets.id"), nullable=True),
    )

    op.create_table(
        "videos",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("owner_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(), server_default=""),
        sa.Column("source_type", sa.String(), server_default="upload"),
        sa.Column("source_url", sa.String(), server_default=""),
        sa.Column("file_path", sa.String(), server_default=""),
        sa.Column("duration_seconds", sa.Float(), server_default="0"),
        sa.Column("size_bytes", sa.Integer(), server_default="0"),
        sa.Column("status", video_status, server_default="uploaded"),
        sa.Column("error_message", sa.Text(), server_default=""),
        sa.Column("transcript", sa.JSON(), server_default="{}"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "clips",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("video_id", sa.String(), sa.ForeignKey("videos.id"), nullable=False),
        sa.Column("start_seconds", sa.Float(), nullable=False),
        sa.Column("end_seconds", sa.Float(), nullable=False),
        sa.Column("score", sa.Float(), server_default="0"),
        sa.Column("score_reasons", sa.JSON(), server_default="[]"),
        sa.Column("status", clip_status, server_default="pending_render"),
        sa.Column("file_path", sa.String(), server_default=""),
        sa.Column("thumbnail_path", sa.String(), server_default=""),
        sa.Column("title", sa.String(), server_default=""),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("hashtags", sa.JSON(), server_default="[]"),
        sa.Column("keywords", sa.JSON(), server_default="[]"),
        sa.Column("seo_score", sa.Float(), server_default="0"),
        sa.Column("visibility", visibility, server_default="private"),
        sa.Column("playlist_id", sa.String(), server_default=""),
        sa.Column("scheduled_at", sa.DateTime(), nullable=True),
        sa.Column("subtitle_style", sa.JSON(), server_default="{}"),
        sa.Column("branding_preset_id", sa.String(), sa.ForeignKey("branding_presets.id"), nullable=True),
        sa.Column("youtube_video_id", sa.String(), server_default=""),
        sa.Column("error_message", sa.Text(), server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "processing_jobs",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("job_type", job_type, nullable=False),
        sa.Column("status", job_status, server_default="queued"),
        sa.Column("video_id", sa.String(), sa.ForeignKey("videos.id"), nullable=True),
        sa.Column("clip_id", sa.String(), sa.ForeignKey("clips.id"), nullable=True),
        sa.Column("celery_task_id", sa.String(), server_default=""),
        sa.Column("attempts", sa.Integer(), server_default="0"),
        sa.Column("progress", sa.Float(), server_default="0"),
        sa.Column("error_message", sa.Text(), server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("processing_jobs")
    op.drop_table("clips")
    op.drop_table("videos")
    op.drop_table("user_settings")
    op.drop_table("youtube_credentials")
    op.drop_table("branding_presets")
    op.drop_table("users")

    bind = op.get_bind()
    for enum in (job_type, job_status, visibility, clip_status, video_status):
        enum.drop(bind, checkfirst=True)
