"""add wardrobe item visual analysis fields

Revision ID: 2f4f6d7e8a9b
Revises: 6f3d9b8a4c21
Create Date: 2026-05-22 16:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "2f4f6d7e8a9b"
down_revision: Union[str, Sequence[str], None] = "6f3d9b8a4c21"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "wardrobe_items",
        sa.Column("visual_description", sa.Text(), nullable=True),
    )
    op.add_column(
        "wardrobe_items",
        sa.Column("ai_detected_metadata", postgresql.JSON(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("wardrobe_items", "ai_detected_metadata")
    op.drop_column("wardrobe_items", "visual_description")
