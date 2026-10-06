from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://diary:diary_dev@localhost:5433/shift_diary"
    cors_origins: list[str] = ["http://localhost:3000", "http://127.0.0.1:3000"]
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env", extra="ignore"
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
