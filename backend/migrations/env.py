from alembic import context

from app.database import get_engine
from app.models import Base

target_metadata = Base.metadata


def run_migrations() -> None:
    if context.is_offline_mode():
        from app.config import get_settings

        context.configure(
            url=get_settings().database_url,
            target_metadata=target_metadata,
            literal_binds=True,
            dialect_opts={"paramstyle": "named"},
        )
        with context.begin_transaction():
            context.run_migrations()
    else:
        with get_engine().connect() as connection:
            context.configure(connection=connection, target_metadata=target_metadata)
            with context.begin_transaction():
                context.run_migrations()


run_migrations()
