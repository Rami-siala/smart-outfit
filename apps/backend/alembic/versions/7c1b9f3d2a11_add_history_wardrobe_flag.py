"""add history wardrobe flag

Revision ID: 7c1b9f3d2a11
Revises: 2f4f6d7e8a9b
Create Date: 2026-05-22 18:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "7c1b9f3d2a11"
down_revision: Union[str, Sequence[str], None] = "2f4f6d7e8a9b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "ai_outfit_history",
        sa.Column(
            "used_selected_wardrobe_items",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("ai_outfit_history", "used_selected_wardrobe_items")
