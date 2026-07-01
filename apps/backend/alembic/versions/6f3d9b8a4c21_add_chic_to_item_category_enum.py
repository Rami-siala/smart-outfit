"""add chic to item category enum

Revision ID: 6f3d9b8a4c21
Revises: ac59bf3daa4c
Create Date: 2026-05-21 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "6f3d9b8a4c21"
down_revision: Union[str, Sequence[str], None] = "ac59bf3daa4c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM pg_type t
                JOIN pg_enum e ON t.oid = e.enumtypid
                WHERE t.typname = 'item_category_enum'
                  AND e.enumlabel = 'formal'
            ) THEN
                ALTER TYPE item_category_enum RENAME VALUE 'formal' TO 'chic';
            ELSIF NOT EXISTS (
                SELECT 1
                FROM pg_type t
                JOIN pg_enum e ON t.oid = e.enumtypid
                WHERE t.typname = 'item_category_enum'
                  AND e.enumlabel = 'chic'
            ) THEN
                ALTER TYPE item_category_enum ADD VALUE 'chic';
            END IF;
        END
        $$;
        """
    )


def downgrade() -> None:
    pass
