"""add dress_shirt item subtype

Revision ID: e4b1c2d3f4a5
Revises: b8d4c2e1f9a7
Create Date: 2026-06-18 12:15:00.000000

"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "e4b1c2d3f4a5"
down_revision: Union[str, Sequence[str], None] = "b8d4c2e1f9a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'item_subtype_enum'
                  AND e.enumlabel = 'dress_shirt'
            ) THEN
                ALTER TYPE item_subtype_enum ADD VALUE 'dress_shirt' AFTER 'shirt';
            END IF;
        END
        $$;
        """
    )


def downgrade() -> None:
    # PostgreSQL enums cannot easily remove a single value safely in-place.
    pass
