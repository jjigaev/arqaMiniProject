from collections.abc import Iterable
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import Trip
from app.schemas import DayOutput, DaySummary, TripInput, TripOutput

BUSINESS_TIMEZONE = "Asia/Qyzylorda"


class TripConflictError(Exception):
    """An existing trip ID was reused with different data."""


def summarize(trips: Iterable[TripOutput]) -> DaySummary:
    revenue = commission = cash = card = Decimal("0.00")
    count = 0
    for trip in trips:
        count += 1
        revenue += trip.amount
        commission += trip.commission
        if trip.payment == "cash":
            cash += trip.amount
        else:
            card += trip.amount
    return DaySummary(
        trip_count=count,
        revenue=revenue,
        commission=commission,
        net=revenue - commission,
        cash=cash,
        card=card,
    )


def day_bounds(day: date) -> tuple[datetime, datetime]:
    zone = ZoneInfo(BUSINESS_TIMEZONE)
    start = datetime.combine(day, time.min, tzinfo=zone)
    # Build both local midnights explicitly, rather than assuming every day is 24 hours.
    end = datetime.combine(day + timedelta(days=1), time.min, tzinfo=zone)
    return start.astimezone(UTC), end.astimezone(UTC)


def read_day(session: Session, day: date) -> DayOutput:
    start, end = day_bounds(day)
    records = session.scalars(
        select(Trip).where(Trip.start >= start, Trip.start < end).order_by(Trip.start, Trip.id)
    ).all()
    trips = [TripOutput.model_validate(record) for record in records]
    return DayOutput(
        date=day,
        timezone=BUSINESS_TIMEZONE,
        currency="KZT",
        summary=summarize(trips),
        trips=trips,
    )


def create_trip(session: Session, payload: TripInput) -> tuple[TripOutput, bool]:
    values = payload.model_dump()
    inserted = session.scalar(
        insert(Trip)
        .values(**values)
        .on_conflict_do_nothing(index_elements=[Trip.id])
        .returning(Trip)
    )
    if inserted is not None:
        return TripOutput.model_validate(inserted), True
    # A separate SELECT at READ COMMITTED sees a concurrent insert after ON CONFLICT waits.
    existing = session.get(Trip, payload.id)
    if existing is None:
        raise RuntimeError("Conflicting trip was not visible")
    result = TripOutput.model_validate(existing)
    if result.model_dump() != values:
        raise TripConflictError(payload.id)
    return result, False
