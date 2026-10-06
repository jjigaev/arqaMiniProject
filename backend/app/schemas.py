from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Annotated, Literal, Self

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    PlainSerializer,
    StringConstraints,
    field_validator,
    model_validator,
)

Money = Annotated[
    Decimal,
    Field(max_digits=12, decimal_places=2, allow_inf_nan=False),
    PlainSerializer(lambda value: format(value, ".2f"), return_type=str),
]
TotalMoney = Annotated[
    Decimal, PlainSerializer(lambda value: format(value, ".2f"), return_type=str)
]


class TripInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=128)]
    start: AwareDatetime
    end: AwareDatetime
    amount: Annotated[Money, Field(gt=0)]
    payment: Literal["cash", "card"]
    commission: Annotated[Money, Field(ge=0)]

    @field_validator("start", "end", mode="before")
    @classmethod
    def timestamps_are_iso(cls, value: object) -> object:
        if not isinstance(value, (str, datetime)):
            raise ValueError("Use an ISO 8601 timestamp with a timezone")
        return value

    @field_validator("amount", "commission", mode="before")
    @classmethod
    def money_is_not_boolean(cls, value: object) -> object:
        if isinstance(value, bool):
            raise ValueError("Money must be a number, not a boolean")
        return value

    @model_validator(mode="after")
    def validate_trip(self) -> Self:
        if self.end <= self.start:
            raise ValueError("End must be later than start")
        if self.commission > self.amount:
            raise ValueError("Commission must not exceed amount")
        self.start = self.start.astimezone(UTC)
        self.end = self.end.astimezone(UTC)
        return self


class TripOutput(TripInput):
    model_config = ConfigDict(from_attributes=True, extra="forbid")


class DaySummary(BaseModel):
    trip_count: int
    revenue: TotalMoney
    commission: TotalMoney
    net: TotalMoney
    cash: TotalMoney
    card: TotalMoney


class DayOutput(BaseModel):
    date: date
    timezone: str
    currency: str
    summary: DaySummary
    trips: list[TripOutput]
