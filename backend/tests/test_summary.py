from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.schemas import TripInput, TripOutput
from app.services import day_bounds, summarize


def test_assignment_summary(trip_payload):
    card = TripOutput.model_validate(trip_payload)
    cash = TripOutput.model_validate(
        {**trip_payload, "id": "t2", "amount": 1500, "commission": 225, "payment": "cash"}
    )
    assert summarize([card, cash]).model_dump(mode="json") == {
        "trip_count": 2,
        "revenue": "3900.00",
        "commission": "585.00",
        "net": "3315.00",
        "cash": "1500.00",
        "card": "2400.00",
    }


def test_empty_summary():
    summary = summarize([])
    assert summary.trip_count == 0
    assert summary.model_dump(mode="json") == {
        "trip_count": 0,
        "revenue": "0.00",
        "commission": "0.00",
        "net": "0.00",
        "cash": "0.00",
        "card": "0.00",
    }


def test_fractional_money_is_exact(trip_payload):
    trips = [
        TripOutput.model_validate({**trip_payload, "amount": amount, "commission": "0.00"})
        for amount in ["0.10", "0.20"]
    ]
    assert summarize(trips).revenue == Decimal("0.30")


def test_totals_can_exceed_single_trip_precision(trip_payload):
    trip = TripOutput.model_validate({**trip_payload, "amount": "9999999999.99", "commission": "0"})
    assert summarize([trip, trip]).model_dump(mode="json")["revenue"] == "19999999999.98"


def test_business_day_uses_local_midnights():
    assert day_bounds(date(2026, 10, 1)) == (
        datetime(2026, 9, 30, 19, tzinfo=UTC),
        datetime(2026, 10, 1, 19, tzinfo=UTC),
    )


@pytest.mark.parametrize(
    "changes",
    [
        {"amount": 0},
        {"amount": -1},
        {"amount": True},
        {"amount": "NaN"},
        {"amount": "Infinity"},
        {"amount": "10.001"},
        {"amount": "10000000000"},
        {"commission": -1},
        {"commission": 2401},
        {"commission": False},
        {"payment": "bitcoin"},
        {"id": "   "},
        {"start": "2026-10-01T08:10:00"},
        {"start": 1790838600},
        {"end": "2026-10-01T08:10:00+05:00"},
        {"end": "2026-10-01T08:09:00+05:00"},
        {"unknown": "value"},
    ],
)
def test_validation_rejects_bad_data(trip_payload, changes):
    with pytest.raises(ValidationError):
        TripInput.model_validate({**trip_payload, **changes})
