# GitHub Pages

GitHub Pages размещает Flutter Web. FastAPI и PostgreSQL работают на отдельном хостинге; серверный Python и контейнеры на Pages не запускаются. [Документация GitHub](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages).

## Статус

При последней проверке GitHub Pages ещё не включён (`has_pages: false`), переменная `API_BASE_URL` не задана. Проект Neon `arqaMiniProject` (`bitter-tooth-75023788`), ветка `production`, проверен через CLI; регион AWS Frankfurt, PostgreSQL 18. Пользователь подключил репозиторий к Render, но Web Service ещё не создал. Workflow и Blueprint подготовлены локально; в origin ещё не отправлены. Публичный API и сайт ещё не развёрнуты.

## Бесплатный хостинг для демо

Условия проверены 7 октября 2026 года; перед созданием сервисов нужно сверить актуальные тарифы.

| Часть | Сервис | Ограничение |
|---|---|---|
| Flutter Web | GitHub Pages | Статический хостинг; API размещается отдельно |
| FastAPI | Render Free | 750 часов на workspace в месяц; сон после 15 минут простоя, пробуждение около минуты |
| PostgreSQL | Neon Free | 1 GB на проект, 100 CU-часов в месяц; Free не является временным trial |

Render Postgres Free не выбран: база истекает через 30 дней. При исчерпании лимитов Render без платёжного метода приостанавливает сервисы или новые сборки. Neon Free не требует карты. Для этого небольшого демо такая связка подходит по нашей оценке; доступность без задержек после простоя она не обеспечивает. Источники: [Render Free](https://render.com/docs/free), [Neon Free](https://neon.com/pricing), [обновление лимитов Neon](https://neon.com/blog/neon-free-plan-1-gb-per-project).

### 1. Neon

1. Зарегистрироваться в [Neon](https://console.neon.tech/) и создать отдельный проект на Free. По возможности выбрать AWS Frankfurt, рядом с API.
2. Открыть **Connect**, выбрать прямое подключение PostgreSQL и скопировать connection string. Сохранить TLS-параметры, включая `sslmode=require`.
3. Для нашего SQLAlchemy/psycopg заменить только префикс `postgresql://` на `postgresql+psycopg://`. Пароль, имя хоста, базу и параметры оставить как в Neon. Пример формата с вымышленными данными:

   ```text
   postgresql+psycopg://USER:PASSWORD@HOST/DATABASE?sslmode=require
   ```

Строку с паролем вводить в секретное окружение Render. В репозиторий, GitHub Pages и `API_BASE_URL` она не попадает.

В текущем рабочем каталоге уже установлены Neon CLI 8.0.11 и восемь Neon skills для Codex; выполнен вход и создана привязка `.neon` к проекту/ветке выше. MCP зарегистрирован глобально в конфигурации Codex с OAuth и ограничением на этот проект; доступность его инструментов в текущей сессии ещё не подтверждена. Если инструменты не появились, обновить подключения или перезапустить Codex и пройти OAuth для MCP при запросе. Вход CLI и вход MCP — отдельные авторизации.

`neon.ts` содержит предоставленную пользователем политику приватного bucket `uploads`; `neon config plan` и `neon deploy --no-env-pull` сообщили, что облачная конфигурация уже соответствует ей. Новые облачные ресурсы этим запуском не созданы. Оболочка `preview` поддерживается, но CLI предупреждает, что она устарела; файл сохранён в запрошенном виде. Это конфигурация Neon, она не запускает FastAPI и не применяет миграции приложения. [Справка neon.ts](https://neon.com/docs/reference/neon-ts).

PostgreSQL-переменные сохранены отдельно командой `neon env pull --service postgres --file .env.neon`. Этот файл игнорируется Git; локальный `.env` не изменён. Для Render взять значение `DATABASE_URL_UNPOOLED` (прямое подключение, без `-pooler` в hostname) и заменить префикс схемы, как описано выше: текущий Docker CMD использует одну строку и для Alembic, и для API. Локальные секреты не публиковать.

Neon CLI, skills, MCP, `neon.ts`, npm-файлы и bucket `uploads` — локальные инструменты настройки, они не требуются приложению. По решению пользователя файлы этих инструментов не включены в репозиторий; они исключены через локальный `.git/info/exclude`. На свежем clone строку подключения достаточно взять в Neon Console → Connect, без установки Node.js и Neon CLI.

### 2. Render

Репозиторий уже подключён. Теперь в [Render Dashboard](https://dashboard.render.com/) выбрать **New → Web Service** и `jjigaev/arqaMiniProject`.

| Поле | Значение |
|---|---|
| Name | `arqa-mini-api` или другое свободное имя |
| Branch | `main` |
| Region | Frankfurt |
| Language / Runtime | Docker |
| Root Directory | Оставить пустым |
| Dockerfile Path | `./backend/Dockerfile` |
| Docker Build Context Directory | `.` |
| Instance Type | Free |
| Health Check Path (Advanced) | `/docs` |
| Auto-Deploy | Off |

Root Directory остаётся пустым, потому что Dockerfile копирует и `backend/`, и `data/` из корня. Docker Command / Start Command не переопределять: используется CMD из Dockerfile. [Docker в Render](https://render.com/docs/docker), [monorepo](https://render.com/docs/monorepo-support).

В **Environment Variables** добавить:

| Key | Value |
|---|---|
| `DATABASE_URL` | Прямая строка Neon с префиксом `postgresql+psycopg://` и сохранённым `sslmode=require` |
| `CORS_ORIGINS` | `["https://jjigaev.github.io"]` |
| `PORT` | `8000` |

Затем нажать **Create Web Service** / **Deploy Web Service**. При старте контейнер сам применит миграции и импортирует примеры без дублей. Дождаться успешного deploy, открыть выданный Render HTTPS-адрес с `/docs`, затем `/api/days/2026-10-01`. Сверить сводку: две поездки, выручка `3900.00`, комиссия `585.00`, «на руки» `3315.00`. После этого использовать адрес API без `/docs` и без `/api` в `API_BASE_URL` на GitHub.

Альтернатива после публикации конфигурации в main: **New → Blueprint**, этот репозиторий и файл [render.yaml](../render.yaml). Blueprint содержит те же значения и запросит секрет `DATABASE_URL` при создании. При ручном создании Web Service ждать появления Blueprint в GitHub не требуется: Dockerfile уже опубликован.

Автоматические deploy отключены (`autoDeployTrigger: off`); последующие изменения выкладываются вручную через Render после проверки. Health check `/docs` проверяет HTTP-сервер без постоянных запросов к спящей базе. Работоспособность БД отдельно проверяется запросом дня. Поля конфигурации: [Blueprint reference](https://render.com/docs/blueprint-spec), [порт Render](https://render.com/docs/web-services#port-binding).

На Pages ожидание GET увеличено до 90 секунд через `API_READ_TIMEOUT_SECONDS`, чтобы дать API время проснуться. POST сохраняет таймаут 15 секунд и безопасный повтор с прежними ID/данными. Это запас времени, а не гарантия пробуждения: после ошибки доступна повторная загрузка. Перед показом демо можно открыть `/docs` и дождаться ответа.

## Перед публикацией

1. Разместить PostgreSQL и FastAPI по инструкции выше. API должен иметь публичный HTTPS-адрес.
2. На хостинге API задать `DATABASE_URL` и `CORS_ORIGINS=["https://jjigaev.github.io"]`. CORS использует origin без пути `/arqaMiniProject/`. Локальный compose остаётся конфигурацией разработки с локальными origin; для публичного запуска нужно изменить окружение backend на целевом хостинге.
3. В репозитории открыть **Settings → Secrets and variables → Actions → Variables**. Создать repository variable `API_BASE_URL`, например `https://api.example.com`, без `/api` в конце. Пример адреса не является работающим API. Адрес включается в публичную JS-сборку; пароли и ключи в эту переменную не добавлять.
4. В **Settings → Pages → Build and deployment → Source** выбрать **GitHub Actions**.
5. После коммита и push workflow запустится при изменении Flutter-кода или самого workflow на main. Для первого запуска и после изменения `API_BASE_URL` можно использовать **Actions → GitHub Pages → Run workflow** на main.

Ожидаемый адрес проекта: `https://jjigaev.github.io/arqaMiniProject/`. Это будущий адрес, а не подтверждение выполненной публикации.

## Сборка

[Workflow](../.github/workflows/pages.yaml) использует Flutter 3.47.6 из официального репозитория, lockfile, анализатор и тесты клиента. В Pages загружается только `frontend/build/web`.

Базовый путь берётся из `actions/configure-pages`: для адреса проекта это `/arqaMiniProject/`, для собственного домена может быть `/`. Параметр `--base-href` позволяет загрузить JS, шрифты и остальные ресурсы из подкаталога. [Сборка Flutter Web](https://docs.flutter.dev/deployment/web), [workflows Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

Пустой, локальный или HTTP-адрес API останавливает workflow до публикации. Автоматический fallback на JSON и сохранение поездок только в браузере не добавляются: рабочее приложение продолжает использовать серверную валидацию, PostgreSQL и идемпотентность.

## Проверка опубликованного приложения

- Открыть сайт, убедиться в отсутствии 404 у ресурсов и ошибок mixed content / CORS.
- Переключить день, проверить сводку и список с публичного API.
- Добавить синтетическую поездку через форму и убедиться, что повтор запроса не создаёт дубль.
- Проверить узкий экран и календарь; сверить статус успешного deploy в Actions.

До появления публичного API эти проверки выполнить нельзя. Локальные тесты не подтверждают успешную публичную публикацию.

## Что проверено локально

- `actionlint 1.7.12`: workflow проходит проверку.
- Проверка адреса API из workflow выполнена на восьми вариантах: пустое значение, HTTP, локальные адреса, credentials/query в URL и корректные HTTPS-адреса.
- `flutter pub get --enforce-lockfile` и release-сборка с `--base-href /arqaMiniProject/` прошли. Выходной каталог отдельный, локальная рабочая сборка не заменялась.
- В результате проверены `<base href="/arqaMiniProject/">`, наличие bootstrap и подстановка compile-time URL. Для этой проверки использован зарезервированный пример `https://api.example.com`; к нему не выполнялись запросы, это не настроенный хостинг.
- Тег Flutter 3.47.6 подтверждён в официальном Git-репозитории. GitHub Actions и deploy пока не запускались.
- `render.yaml` проходит проверку по официальной JSON Schema Render. Это проверка структуры; создание ресурсов и подключение к Neon ещё не проверялись.
- После настройки ожидания холодного API: `flutter analyze` без замечаний, 18 Flutter-тестов проходят. Новые сценарии проверяют ответ через 60 секунд, предел ожидания GET и неопределённый результат POST через 15 секунд.
- Повторная release-сборка с `API_READ_TIMEOUT_SECONDS=90` успешна; в выходных файлах подтверждены базовый путь, bootstrap, адрес-пример и длительность 90 секунд. Это не проверка реального холодного запуска Render.
