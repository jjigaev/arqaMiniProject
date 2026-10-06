from datetime import date
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_session
from app.schemas import DayOutput, TripInput, TripOutput
from app.services import TripConflictError, create_trip, read_day

app = FastAPI(title="Дневник смен водителя", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)
DatabaseSession = Annotated[Session, Depends(get_session)]


@app.get("/api/days/{day}", response_model=DayOutput)
def get_day(day: date, session: DatabaseSession) -> DayOutput:
    if day in (date.min, date.max):
        raise HTTPException(status_code=422, detail="Date is outside supported timezone boundaries")
    return read_day(session, day)


@app.post(
    "/api/trips",
    response_model=TripOutput,
    status_code=201,
    responses={
        200: {"description": "Identical trip already exists"},
        409: {"description": "ID conflict"},
    },
)
def post_trip(payload: TripInput, response: Response, session: DatabaseSession) -> TripOutput:
    try:
        result, created = create_trip(session, payload)
        session.commit()
    except TripConflictError as error:
        session.rollback()
        raise HTTPException(
            status_code=409, detail="Trip ID already exists with different data"
        ) from error
    response.status_code = 201 if created else 200
    return result
