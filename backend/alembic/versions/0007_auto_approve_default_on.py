"""turn auto-approve/upload on by default

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-09

Sets auto_approve_score_threshold to 7.0 for any existing settings row
that hasn't already made an explicit choice (still NULL), so clips
scoring 7+ start auto-uploading without a manual Settings toggle. Rows
that already have a value (on or explicitly left off) are left alone —
this only fills in the previously-unset default, it doesn't override a
choice you already made.
"""
from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("user_settings", "auto_approve_score_threshold", server_default="7.0")
    op.execute(
        "UPDATE user_settings SET auto_approve_score_threshold = 7.0 WHERE auto_approve_score_threshold IS NULL"
    )


def downgrade() -> None:
    op.alter_column("user_settings", "auto_approve_score_threshold", server_default=None)
