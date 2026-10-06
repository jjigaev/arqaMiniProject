"""Create trips and database-level invariants."""

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("id", sa.String(128), primary_key=True),
        sa.Column("start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("payment", sa.String(4), nullable=False),
        sa.Column("commission", sa.Numeric(12, 2), nullable=False),
        sa.CheckConstraint("amount > 0", name="amount_positive"),
        sa.CheckConstraint("commission >= 0 AND commission <= amount", name="commission_range"),
        sa.CheckConstraint('"end" > start', name="end_after_start"),
        sa.CheckConstraint("payment IN ('cash', 'card')", name="payment_valid"),
        sa.CheckConstraint("length(trim(id)) > 0", name="id_nonempty"),
    )
    op.create_index("ix_trips_start", "trips", ["start"])


def downgrade() -> None:
    op.drop_index("ix_trips_start", table_name="trips")
    op.drop_table("trips")
