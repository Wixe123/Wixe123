"""watched channels

Revision ID: 0005
Revises: 0004
Create Date: 2026-08-02

"""
from alembic import op
import sqlalchemy as sa

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "watched_channels",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("channel_url", sa.String(), nullable=False),
        sa.Column("label", sa.String(), server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("watched_channels")
