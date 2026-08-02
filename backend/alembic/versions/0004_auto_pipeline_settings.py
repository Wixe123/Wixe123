"""auto-approve threshold and channel-watch settings

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-02

"""
from alembic import op
import sqlalchemy as sa

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user_settings", sa.Column("auto_approve_score_threshold", sa.Float(), nullable=True))
    op.add_column(
        "user_settings",
        sa.Column("auto_import_from_channel", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.add_column("user_settings", sa.Column("last_channel_check_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("user_settings", "last_channel_check_at")
    op.drop_column("user_settings", "auto_import_from_channel")
    op.drop_column("user_settings", "auto_approve_score_threshold")
