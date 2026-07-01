"""add item subtype to wardrobe items

Revision ID: b8d4c2e1f9a7
Revises: 7c1b9f3d2a11
Create Date: 2026-05-23 09:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b8d4c2e1f9a7"
down_revision: Union[str, Sequence[str], None] = "7c1b9f3d2a11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ITEM_SUBTYPE_VALUES = (
    "t_shirt",
    "polo",
    "shirt",
    "hoodie",
    "sweater",
    "tank_top",
    "shorts",
    "jeans",
    "joggers",
    "trousers",
    "sneakers",
    "running_shoes",
    "boots",
    "loafers",
    "sandals",
    "blazer",
    "coat",
    "raincoat",
    "puffer_jacket",
    "denim_jacket",
    "bag",
    "watch",
    "scarf",
    "hat",
    "belt",
)


def upgrade() -> None:
    subtype_values_sql = ", ".join(f"'{value}'" for value in ITEM_SUBTYPE_VALUES)
    op.execute(
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = 'item_subtype_enum'
            ) THEN
                CREATE TYPE item_subtype_enum AS ENUM ({subtype_values_sql});
            END IF;
        END
        $$;
        """
    )

    op.add_column(
        "wardrobe_items",
        sa.Column(
            "item_subtype",
            sa.Enum(*ITEM_SUBTYPE_VALUES, name="item_subtype_enum"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("wardrobe_items", "item_subtype")
    op.execute("DROP TYPE IF EXISTS item_subtype_enum")
