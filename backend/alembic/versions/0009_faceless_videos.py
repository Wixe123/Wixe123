"""faceless video generation

Revision ID: 0009
Revises: 0008
Create Date: 2026-09-10

"""
from alembic import op
import sqlalchemy as sa

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user_settings", sa.Column("faceless_niche", sa.String(), nullable=True))
    op.add_column("user_settings", sa.Column("faceless_auto_upload", sa.Boolean(), server_default="false"))

    op.create_table(
        "faceless_topics",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("topic", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    # New ProcessingJob.job_type value — Postgres can't add an enum value
    # inside the migration's normal transaction block.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE jobtype ADD VALUE IF NOT EXISTS 'generate_faceless_video'")


def downgrade() -> None:
    op.drop_table("faceless_topics")
    op.drop_column("user_settings", "faceless_auto_upload")
    op.drop_column("user_settings", "faceless_niche")
