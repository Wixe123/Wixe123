"""trending feed

Revision ID: 0006
Revises: 0005
Create Date: 2026-08-03

"""
from alembic import op
import sqlalchemy as sa

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("watched_channels", sa.Column("channel_title", sa.String(), server_default=""))
    op.add_column("watched_channels", sa.Column("avatar_url", sa.String(), server_default=""))
    op.add_column("watched_channels", sa.Column("subscriber_count", sa.Integer(), nullable=True))
    op.add_column("watched_channels", sa.Column("last_refreshed_at", sa.DateTime(), nullable=True))

    op.create_table(
        "trending_clips",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("watched_channel_id", sa.String(), sa.ForeignKey("watched_channels.id"), nullable=False),
        sa.Column("youtube_video_id", sa.String(), nullable=False),
        sa.Column("video_url", sa.String(), nullable=False),
        sa.Column("title", sa.String(), server_default=""),
        sa.Column("thumbnail_url", sa.String(), server_default=""),
        sa.Column("channel_title", sa.String(), server_default=""),
        sa.Column("channel_url", sa.String(), server_default=""),
        sa.Column("view_count", sa.Integer(), server_default="0"),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), server_default="0"),
        sa.Column("fetched_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("trending_clips")
    op.drop_column("watched_channels", "last_refreshed_at")
    op.drop_column("watched_channels", "subscriber_count")
    op.drop_column("watched_channels", "avatar_url")
    op.drop_column("watched_channels", "channel_title")
