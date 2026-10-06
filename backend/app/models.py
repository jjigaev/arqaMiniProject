from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, Index, Numeric, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Trip(Base):
    __tablename__ = "trips"
    __table_args__ = (
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint("commission >= 0 AND commission <= amount", name="commission_range"),
        CheckConstraint('"end" > start', name="end_after_start"),
        CheckConstraint("payment IN ('cash', 'card')", name="payment_valid"),
        CheckConstraint("length(trim(id)) > 0", name="id_nonempty"),
        Index("ix_trips_start", "start"),
    )
    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    payment: Mapped[str] = mapped_column(String(4), nullable=False)
    commission: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
