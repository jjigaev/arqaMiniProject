import argparse
import json
from decimal import Decimal
from pathlib import Path

from pydantic import TypeAdapter
from sqlalchemy.orm import Session

from app.database import get_engine
from app.schemas import TripInput
from app.services import create_trip


def import_trips(session: Session, path: Path) -> tuple[int, int]:
    payloads = TypeAdapter(list[TripInput]).validate_python(
        json.loads(path.read_text(encoding="utf-8"), parse_float=Decimal)
    )
    created = repeated = 0
    for payload in payloads:
        _, is_new = create_trip(session, payload)
        created += int(is_new)
        repeated += int(not is_new)
    return created, repeated


def main() -> None:
    parser = argparse.ArgumentParser(description="Import trips JSON atomically and idempotently")
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    with Session(get_engine()) as session, session.begin():
        created, repeated = import_trips(session, args.path)
    print(f"Imported: {created}; already present: {repeated}")


if __name__ == "__main__":
    main()
