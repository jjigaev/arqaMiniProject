# Дневник смен водителя

Мини-проект на **FastAPI + PostgreSQL + Flutter Web**. Один водитель, выбор дня, список поездок, точная сводка и добавление поездки без дублей.

[Демо](https://jjigaev.github.io/arqaMiniProject/) · [Swagger UI](https://arqaminiproject.onrender.com/docs) · [Архитектура](docs/ARCHITECTURE.md)

[Основной экран](docs/screenshots/day-desktop.jpg) · [Форма](docs/screenshots/add-trip.jpg) · [Узкий экран](docs/screenshots/day-mobile.jpg)

## Возможности

- API возвращает поездки и сводку за выбранный день одним запросом.
- Клиент показывает число поездок, выручку, комиссию, «на руки», наличные/карту; позволяет переключать дни и добавлять поездки.
- Мятная сводка слева, журнал справа с доходом каждой поездки. На телефоне блоки перестраиваются, добавление закреплено снизу.
- В форме дата выбирается из календаря (`дд/мм/гггг`), время отдельно (`ЧЧ:мм`, 24 часа). Сумма и комиссия допускают только цифры и один десятичный разделитель, до двух дробных знаков.
- Повторный POST с тем же ID и данными не создаёт запись, включая одновременную отправку. Изменённые данные с тем же ID возвращают 409.
- При неопределённом результате POST клиент сохраняет ID и данные для безопасного повтора.
- Импорт JSON, миграция Alembic, тесты расчётов, API и клиента.

## Быстрый запуск

Нужны Docker с запущенным сервером и Flutter SDK. Проверяется на Python 3.11, Flutter 3.47.6 / Dart 3.13.5. Python внутри контейнера устанавливается автоматически.

Из корня репозитория:

```bash
docker compose up -d --build
```

Compose поднимает PostgreSQL и API, применяет миграцию и импортирует `data/trips.json`. Настройки по умолчанию предназначены для локальной разработки. Для изменения скопируйте `.env.example` в `.env`.

В другом терминале:

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000
```

- Клиент: http://localhost:3000
- Swagger UI: http://localhost:8000/docs
- Пример дня: http://localhost:8000/api/days/2026-10-01
- PostgreSQL: `localhost:5433`, база `shift_diary`.

При первом открытии выбран **2 октября 2026**: в исходном JSON шесть поездок за этот день. Перейдите на 1 октября, чтобы увидеть пример из задания. Начальную дату можно передать через `?date=2026-10-01`.

Остановка: `docker compose down`. Данные остаются в Docker volume; повторный старт и импорт не создают дублей.

### Windows и кириллица в пути

Если Dart LSP выдаёт `FormatException` из каталога с кириллицей, используйте свободную букву диска для ASCII-пути:

```powershell
# Сначала убедитесь, что R: свободен.
subst R: (Get-Location).Path
Set-Location R:\frontend
flutter analyze
# После завершения выйдите из R: и удалите только сопоставление:
Set-Location C:\
subst R: /d
```

Сопоставление не переносит и не удаляет исходники. Для запуска достаточно Flutter SDK в PATH.

## Публичное демо и хостинг

| Сервис | Роль | Настройка в проекте |
|---|---|---|
| [GitHub Pages](https://jjigaev.github.io/arqaMiniProject/) | Отдаёт собранный Flutter Web; приложение работает в браузере | [.github/workflows/pages.yaml](.github/workflows/pages.yaml) |
| [Render](https://arqaminiproject.onrender.com/docs) | Запускает FastAPI в Docker | [backend/Dockerfile](backend/Dockerfile), [render.yaml](render.yaml) |
| Neon | Хранит поездки в PostgreSQL | [backend/app/config.py](backend/app/config.py), [backend/app/database.py](backend/app/database.py) |

Браузер обращается к Render по HTTPS, а FastAPI подключается к Neon по строке `DATABASE_URL`. GitHub Pages не обращается к базе и не выполняет Python. Подробный путь запросов и соответствующий код: [архитектура](docs/ARCHITECTURE.md).

Настройки опубликованного приложения:

| Где задать | Переменная | Значение |
|---|---|---|
| GitHub → Settings → Secrets and variables → Actions → Variables | `API_BASE_URL` | `https://arqaminiproject.onrender.com` |
| Render → Environment | `DATABASE_URL` | Прямая строка подключения Neon с префиксом `postgresql+psycopg://` и TLS-параметром `sslmode=require` |
| Render → Environment | `CORS_ORIGINS` | `["https://jjigaev.github.io"]` |
| Render → Environment | `PORT` | `8000`, согласно Dockerfile |

Строку Neon взять в Console → Connect, выбрав прямое подключение без `-pooler` в hostname. Заменить только начальный `postgresql://` на `postgresql+psycopg://`, сохранив пароль, базу и TLS-параметры. Прямое подключение используется и API, и Alembic. `DATABASE_URL` остаётся в секретном окружении Render; в GitHub и клиентскую сборку передаётся только публичный адрес API.

Для Pages выбран Source → GitHub Actions. Workflow проверяет адрес API, запускает `flutter analyze` и `flutter test`, собирает клиент с базовым путём Pages и публикует результат. Он запускается при изменении `frontend/` или самого workflow в `main`; после изменения `API_BASE_URL` нужно вручную выполнить Actions → GitHub Pages → Run workflow, поскольку адрес встраивается при сборке.

Render собирает Dockerfile из корня репозитория: Root Directory пустой, Dockerfile Path — `./backend/Dockerfile`, Docker Build Context — `.`. При старте контейнер применяет миграции, импортирует JSON без дублей и запускает Uvicorn. `render.yaml` задаёт Free-план, Frankfurt и ручное обновление сервиса; при ручном создании Web Service эти параметры задаются в панели Render. Для следующего релиза API используется Manual Deploy → Deploy latest commit. Health check `/docs` проверяет HTTP-сервер; подключение к БД проверяется запросом `/api/days/2026-10-01`. Корневой `/` у API возвращает 404 — интерфейс размещён на Pages.

После простоя бесплатный API может запускаться с задержкой. Pages-сборка ждёт GET до 90 секунд через `API_READ_TIMEOUT_SECONDS`; локальное значение — 15 секунд. POST ждёт 15 секунд и при неопределённом результате предлагает безопасный повтор с прежними ID и данными.

## API

### GET /api/days/{date}

`date` — календарная дата `YYYY-MM-DD` в часовом поясе приложения.

```json
{
  "date": "2026-10-01",
  "timezone": "Asia/Qyzylorda",
  "currency": "KZT",
  "summary": {
    "trip_count": 2,
    "revenue": "3900.00",
    "commission": "585.00",
    "net": "3315.00",
    "cash": "1500.00",
    "card": "2400.00"
  },
  "trips": [
    {"id":"t1","start":"2026-10-01T03:10:00Z","end":"2026-10-01T03:32:00Z","amount":"2400.00","payment":"card","commission":"360.00"},
    {"id":"t2","start":"2026-10-01T04:05:00Z","end":"2026-10-01T04:20:00Z","amount":"1500.00","payment":"cash","commission":"225.00"}
  ]
}
```

День без поездок возвращает 200, пустой список и нулевые суммы. Поездки отсортированы по началу, затем по ID. Сводка рассчитывается по тому же набору, что и список.

### POST /api/trips

```bash
curl -i http://localhost:8000/api/trips \
  -H 'Content-Type: application/json' \
  -d '{"id":"manual-1","start":"2026-10-01T10:00:00+05:00","end":"2026-10-01T10:25:00+05:00","amount":2000,"payment":"cash","commission":300}'
```

В PowerShell:

```powershell
$trip = @{ id='manual-1'; start='2026-10-01T10:00:00+05:00'; end='2026-10-01T10:25:00+05:00'; amount=2000; payment='cash'; commission=300 }
Invoke-RestMethod -Uri http://localhost:8000/api/trips -Method Post -ContentType application/json -Body ($trip | ConvertTo-Json)
```

| Результат | HTTP |
|---|---|
| Новая поездка | 201 |
| Тот же ID и те же нормализованные данные | 200, существующая поездка |
| Тот же ID, другие данные | 409 |
| Невалидные данные | 422 |

На входе деньги — JSON-числа или десятичные строки. На выходе — строки с двумя знаками после запятой. Эквивалентные UTC-смещения и `2400` / `"2400.00"` считаются одинаковыми данными.

## Правила и ограничения

- KZT; комиссия передаётся готовой суммой, а не процентом.
- «На руки» = выручка − комиссия. Это доход после комиссии, не баланс банковского счёта.
- Наличные/карта — суммы до комиссии; их сумма равна выручке.
- PostgreSQL хранит `TIMESTAMPTZ`, API отдаёт UTC, клиент показывает фиксированный UTC+5 (`Asia/Qyzylorda`). Часовой пояс браузера не влияет на день.
- Поездка целиком относится к дню начала. Поездка через полночь учитывается в первом дне. Выборка использует `[полночь, следующая полночь)`.
- Деньги: `Decimal` в Python, `NUMERIC(12,2)` в БД, целые minor units во Flutter. На входе до 10 целых и 2 дробных знаков; нет молчаливого округления. Итоги могут превышать сумму одной поездки.
- `id` обязателен, до 128 символов. Уникальность обеспечивает первичный ключ БД, вставка — `ON CONFLICT DO NOTHING`. После конфликта сравниваются данные, запись не обновляется.
- Проверки: `amount > 0`, `end > start`, timestamps с UTC-смещением, `payment: cash|card`, `0 <= commission <= amount`. Ключевые ограничения продублированы в БД.
- Одинаковые данные с разными ID считаются разными поездками. Клиент создаёт UUID и повторяет его при неопределённом исходе POST.
- Неподтверждённая отправка сохраняется в памяти контроллера при закрытии формы. Перезагрузка вкладки очищает черновик. Форма блокирует изменение неподтверждённых данных и предлагает повтор; постоянного offline-хранилища нет.
- Старый ответ при переключении дня игнорируется. Загрузка, пустой день и ошибка с повтором имеют отдельные состояния.

## Тесты и проверки

Все backend-тесты:

```bash
docker compose --profile test run --build --rm tests
```

Используется отдельная PostgreSQL `test-db`. Каждому интеграционному тесту создаётся случайная схема, применяются настоящие миграции; удаляется только эта схема. SQLite и подмена уникальности не используются.

Проверяются сводка из задания, пустой день, точные дроби, валидация, границы дня, поездка через полночь, эквивалентные UTC-смещения, повторный импорт, повтор POST, конфликт ID и шесть одновременных запросов.

Flutter:

```bash
cd frontend
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8000
```

Проверяются деньги, timezone, поздний ответ, сохранение ID/payload при повторе, HTTP 200 при повторе, ожидание холодного API, навигация, числовой ввод, календарь и точное время, поездка через полночь и узкий экран. Палитра и правила интерфейса описаны в [DESIGN.md](DESIGN.md).

Локальная разработка backend на Windows:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -c backend/requirements.lock -e 'backend[test]'
.\.venv\Scripts\python.exe -m pytest backend/tests -m 'not integration' -q
.\.venv\Scripts\python.exe -m ruff check backend scripts
.\.venv\Scripts\python.exe -m ruff format --check backend scripts
.\.venv\Scripts\python.exe scripts/check_design.py
```

На Linux/macOS используйте `python3` и `.venv/bin/python`. Для локального API поднимите `docker compose up -d db`, затем из `backend` выполните `alembic upgrade head`, `python -m app.seed ../data/trips.json`, `uvicorn app.main:app --reload` в своём venv.

Повторный импорт в контейнер:

```bash
docker compose exec backend python -m app.seed /data/trips.json
```

Импорт выполняется одной транзакцией. При невалидных данных или конфликте ID весь импорт откатывается.

## Структура

```text
backend/app/          API, схемы, модель, расчёты и импорт
backend/migrations/   схема PostgreSQL
backend/tests/        unit и integration тесты
frontend/lib/         модели, API, контроллер, экран и форма
frontend/test/        тесты клиента
data/trips.json       девять поездок за три дня
scripts/              проверка дизайн-токенов
DESIGN.md             решения по интерфейсу
docs/ARCHITECTURE.md  связь хостингов, конфигурация и путь запросов в коде
docs/screenshots/     экран приложения на разных размерах
.github/workflows/    сборка и публикация Flutter Web
render.yaml          конфигурация API на Render
compose.yaml         локальные API, PostgreSQL и тестовое окружение
```

Python-зависимости зафиксированы в `backend/requirements.lock`, Dart — в `frontend/pubspec.lock`.
