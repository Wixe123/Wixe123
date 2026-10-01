"""style profiles

Revision ID: 0002
Revises: 0001
Create Date: 2026-08-02

"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "style_profiles",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("source_url", sa.String(), nullable=False),
        sa.Column("creator_label", sa.String(), server_default=""),
        sa.Column("status", sa.String(), server_default="analyzing"),
        sa.Column("hook_analysis", sa.Text(), server_default=""),
        sa.Column("pacing_analysis", sa.Text(), server_default=""),
        sa.Column("structure_analysis", sa.Text(), server_default=""),
        sa.Column("summary", sa.Text(), server_default=""),
        sa.Column("error_message", sa.Text(), server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("style_profiles")
