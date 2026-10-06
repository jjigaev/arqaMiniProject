from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Trip
from app.seed import import_trips
from app.services import TripConflictError

pytestmark = pytest.mark.integration


def test_repeated_post_returns_same_trip_once(client, trip_payload, db_engine):
    first = client.post("/api/trips", json=trip_payload)
    repeated = client.post("/api/trips", json=trip_payload)
    assert first.status_code == 201
    assert repeated.status_code == 200
    assert repeated.json() == first.json()
    with Session(db_engine) as session:
        assert session.scalar(select(func.count()).select_from(Trip)) == 1
    assert client.get("/api/days/2026-10-01").json()["summary"]["revenue"] == "2400.00"


def test_same_id_changed_data_is_conflict(client, trip_payload):
    first = client.post("/api/trips", json=trip_payload)
    conflicting = client.post("/api/trips", json={**trip_payload, "amount": 3000})
    assert conflicting.status_code == 409
    assert client.get("/api/days/2026-10-01").json()["trips"] == [first.json()]


def test_different_id_is_a_different_trip(client, trip_payload):
    assert client.post("/api/trips", json=trip_payload).status_code == 201
    assert client.post("/api/trips", json={**trip_payload, "id": "t2"}).status_code == 201
    assert client.get("/api/days/2026-10-01").json()["summary"]["trip_count"] == 2


def test_equivalent_timezone_and_money_are_idempotent(client, trip_payload):
    assert client.post("/api/trips", json=trip_payload).status_code == 201
    normalized = {
        **trip_payload,
        "start": "2026-10-01T03:10:00Z",
        "end": "2026-10-01T03:32:00Z",
        "amount": "2400.00",
        "commission": "360.00",
    }
    assert client.post("/api/trips", json=normalized).status_code == 200


def test_concurrent_retries_only_insert_once(client, trip_payload, db_engine):
    barrier = Barrier(6)

    def send(_):
        barrier.wait(timeout=10)
        return client.post("/api/trips", json=trip_payload)

    with ThreadPoolExecutor(max_workers=6) as executor:
        responses = list(executor.map(send, range(6)))
    assert sorted(response.status_code for response in responses) == [200] * 5 + [201]
    assert all(response.json() == responses[0].json() for response in responses)
    with Session(db_engine) as session:
        assert session.scalar(select(func.count()).select_from(Trip)) == 1


def test_day_boundaries_and_overnight_trip(client, trip_payload):
    trips = [
        ("before", "2026-09-30T23:59:00+05:00", "2026-10-01T00:01:00+05:00"),
        ("first", "2026-09-30T19:00:00Z", "2026-09-30T19:10:00Z"),
        ("overnight", "2026-10-01T23:59:00+05:00", "2026-10-02T00:10:00+05:00"),
        ("next", "2026-10-02T00:00:00+05:00", "2026-10-02T00:20:00+05:00"),
    ]
    for identifier, start, end in trips:
        assert (
            client.post(
                "/api/trips", json={**trip_payload, "id": identifier, "start": start, "end": end}
            ).status_code
            == 201
        )
    day = client.get("/api/days/2026-10-01").json()
    assert [trip["id"] for trip in day["trips"]] == ["first", "overnight"]
    assert day["summary"]["revenue"] == "4800.00"
    assert day["timezone"] == "Asia/Qyzylorda"


def test_empty_day(client):
    response = client.get("/api/days/2026-10-04")
    assert response.status_code == 200
    assert response.json()["trips"] == []
    assert response.json()["summary"]["trip_count"] == 0
    assert response.json()["summary"]["net"] == "0.00"


@pytest.mark.parametrize("day", ["bad-date", "2026-02-30", "9999-12-31", "0001-01-01"])
def test_bad_date(client, day):
    assert client.get(f"/api/days/{day}").status_code == 422


@pytest.mark.parametrize(
    "changes", [{"amount": 0}, {"end": "2026-10-01T08:00:00+05:00"}, {"payment": "other"}]
)
def test_api_validation_does_not_write(client, trip_payload, changes):
    assert client.post("/api/trips", json={**trip_payload, **changes}).status_code == 422
    assert client.get("/api/days/2026-10-01").json()["summary"]["trip_count"] == 0


def test_json_import_is_repeatable(client, db_engine):
    path = Path(__file__).resolve().parents[2] / "data" / "trips.json"
    if not path.exists():
        path = Path("/data/trips.json")
    with Session(db_engine) as session, session.begin():
        assert import_trips(session, path) == (9, 0)
    with Session(db_engine) as session, session.begin():
        assert import_trips(session, path) == (0, 9)
    assert client.get("/api/days/2026-10-01").json()["summary"]["net"] == "3315.00"


def test_conflicting_import_rolls_back_every_insert(client, db_engine, trip_payload, tmp_path):
    import json

    assert client.post("/api/trips", json=trip_payload).status_code == 201
    path = tmp_path / "conflicting.json"
    path.write_text(
        json.dumps(
            [
                {**trip_payload, "id": "new-trip"},
                {**trip_payload, "amount": 3000},
            ]
        ),
        encoding="utf-8",
    )
    with pytest.raises(TripConflictError), Session(db_engine) as session, session.begin():
        import_trips(session, path)
    assert client.get("/api/days/2026-10-01").json()["summary"]["trip_count"] == 1
