import os
from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app import database
from app.database import get_session
from app.main import app


@pytest.fixture
def trip_payload():
    return {
        "id": "t1",
        "start": "2026-10-01T08:10:00+05:00",
        "end": "2026-10-01T08:32:00+05:00",
        "amount": 2400,
        "payment": "card",
        "commission": 360,
    }


@pytest.fixture
def db_engine(monkeypatch):
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set TEST_DATABASE_URL to run PostgreSQL integration tests")
    if not url.startswith("postgresql"):
        pytest.fail("Integration tests require PostgreSQL")
    # Only our random schema is created/dropped; development tables are never truncated.
    schema = f"diary_test_{uuid4().hex}"
    admin = create_engine(url)
    with admin.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    monkeypatch.setattr(database, "get_engine", lambda: engine)
    try:
        config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
        command.upgrade(config, "head")
        yield engine
    finally:
        engine.dispose()
        with admin.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


@pytest.fixture
def client(db_engine):
    def session_override():
        with Session(db_engine) as session:
            yield session

    app.dependency_overrides[get_session] = session_override
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
