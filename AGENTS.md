# Driver shift diary: agent instructions

## Scope and collaboration
- Build the agreed mini-project: FastAPI, PostgreSQL, Flutter Web.
- Work on `main`. Do not commit, publish, or create a PR without explicit user permission. When the user authorizes a commit, also push it to `origin/main` in the same task unless the user explicitly asks to keep it local. Keep commits in separate parts when requested.
- Keep changes small and reviewable. Do not introduce authentication, queues, additional services, or unrelated features.
- Before editing, read the relevant source and this file. Preserve the user's changes.

## Code discovery
- Prefer the codebase-memory MCP graph (`list_projects`/`index_status`, `search_graph`, `trace_path`, `get_code_snippet`) when available.
- Use Verify evidence by default. After identifying candidate paths, check their index coverage; read any missing or stale ranges before relying on graph results.
- If graph tools are unavailable, use targeted source reads and `rg`. State the limitation; never claim graph verification that did not run.

## Business rules
- A single driver's diary; money is KZT, the business timezone is `Asia/Qyzylorda` (UTC+5).
- Attribute the whole trip to the local date of its start. Query a half-open interval `[day start, next day start)`.
- Revenue is the sum of amounts; net is revenue minus commission. Cash/card breakdown is gross revenue.
- Use `Decimal` / PostgreSQL `NUMERIC(12,2)`. API responses serialize money as strings with two decimal places. Flutter uses integer minor units, never floating-point arithmetic for money.
- Require a nonempty ID, timezone-aware timestamps, `amount > 0`, `end > start`, payment `cash|card`, and `0 <= commission <= amount`.
- ID identifies the trip. First insert returns 201; the same ID and normalized payload returns 200; changed data with the same ID returns 409 without overwriting.
- Enforce uniqueness in PostgreSQL, including concurrent requests. A client retry must reuse its original ID and payload.

## Verification and documentation
- Run backend unit and integration tests; integration tests use an isolated PostgreSQL schema/database, not SQLite or the development data.
- Run `ruff check`, `ruff format --check`, `flutter analyze`, `flutter test`, and `flutter build web` as applicable.
- Verify loading, empty, error/retry, stale date requests, successful creation, and narrow-screen behavior.
- Keep `README.md`, `DESIGN.md`, API examples, migrations, and tests consistent with the implementation.
- Keep documentation focused on application behavior, architecture, setup, and verification. Do not create AI notes, agent activity journals, or sections describing AI usage; the user explicitly does not want them.
- Never commit secrets, local environments, SDKs, build outputs, or database files.
