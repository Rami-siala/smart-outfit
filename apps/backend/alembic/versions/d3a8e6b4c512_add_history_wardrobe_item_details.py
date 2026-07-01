"""add history wardrobe item details

Revision ID: d3a8e6b4c512
Revises: 7c1b9f3d2a11
Create Date: 2026-05-23 10:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "d3a8e6b4c512"
down_revision: Union[str, Sequence[str], None] = "7c1b9f3d2a11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "ai_outfit_history",
        sa.Column("wardrobe_items_used_details", sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("ai_outfit_history", "wardrobe_items_used_details")
