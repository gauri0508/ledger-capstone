"""create expenses table

Revision ID: 0001
Revises:
Create Date: 2026-10-07

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "expenses",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("category", sa.String(50), nullable=False),
        sa.Column("note", sa.String(255), nullable=True),
        sa.Column("spent_on", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_expenses_category", "expenses", ["category"])
    op.create_index("ix_expenses_spent_on", "expenses", ["spent_on"])


def downgrade() -> None:
    op.drop_index("ix_expenses_spent_on", table_name="expenses")
    op.drop_index("ix_expenses_category", table_name="expenses")
    op.drop_table("expenses")
