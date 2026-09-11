"""active style profile setting

Revision ID: 0003
Revises: 0002
Create Date: 2026-08-02

"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_settings",
        sa.Column("active_style_profile_id", sa.String(), sa.ForeignKey("style_profiles.id"), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("user_settings", "active_style_profile_id")
