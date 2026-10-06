FROM python:3.11-slim
WORKDIR /app
COPY backend /app
COPY data /data
RUN pip install --no-cache-dir -c requirements.lock -e ".[test]"
EXPOSE 8000
CMD ["sh", "-c", "alembic upgrade head && python -m app.seed /data/trips.json && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
