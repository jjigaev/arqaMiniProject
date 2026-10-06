---
version: alpha
name: "Дневник смен водителя"
description: "Лагуна: мята, бирюзовый и коралл; доход слева, понятный журнал справа."
colors:
  primary: "#08786C"
  ink: "#163B37"
  muted: "#5A716C"
  background: "#F0F7F4"
  surface: "#FFFFFF"
  border: "#D7E7DF"
  danger: "#B3261E"
  cash: "#8D422E"
  cashSurface: "#FFEDE7"
  cardSurface: "#E1F3EB"
  incomeSurface: "#C9F1E4"
  coral: "#FFAD98"
  onCoral: "#502B24"
typography:
  sans:
    fontFamily: "Segoe UI, Arial, sans-serif"
  display:
    fontFamily: "Bahnschrift, Arial, sans-serif"
rounded:
  DEFAULT: "24px"
  control: "10px"
spacing:
  page-max: "1240px"
  section-gap: "24px"
components:
  button:
    height: "48px"
  dialog:
    width: "560px"
  list:
    padding: "24px"
---

# Дневник смен водителя Design System

## Overview
### Creative North Star
Выбранное пользователем направление B — «Лагуна». Мятная поверхность выделяет доход после комиссии, бирюзовый обозначает действия, коралл добавляет тёплый акцент. Дата, сводка и журнал образуют один рабочий экран для ежедневного использования водителем.
### Product context and register
- Audience: один водитель, проверяющий поездки и доход за день; также проверяющий тестовое задание.
- Market: демонстрационный проект с KZT, согласно согласованному плану; рыночные или финансовые интеграции отсутствуют.
- Locale: русский, Gregorian, Asia/Qyzylorda. Никакого перехода к часовому поясу браузера.
- Usage: браузер на ноутбуке или телефоне; основная задача — выбрать день, посмотреть суммы, добавить поездку.
- Register: product. Спокойный рабочий экран, без маркетингового hero.
- Anti-references: биржевой терминал, лендинг такси, декоративная карта маршрутов.
- Runtime ownership: `frontend/lib/theme.dart` — канонические токены; этот файл отражает их. Цвета адаптируются через ThemeData, суммы через DiaryTheme.number; DOM scrollbar в web/index.html отражает те же muted/background значения. Проверка дрейфа: `scripts/check_design.py`.

## Colors
Светлая тема. Primary — основное действие и выбранные контролы. Ink — основной текст; incomeSurface — фон итогового блока; coral — знак бренда и доля наличных в полосе оплаты. Surface — журнал. Muted — пояснения. Cash/card имеют текстовые подписи, а цвет лишь дополняет их. Danger — ошибка с текстом и действием восстановления.

## Typography
Segoe UI с Arial fallback обеспечивает кириллицу без загрузки веб-шрифтов. Bahnschrift с Arial fallback используется для чисел с табличной шириной; итог 50–52px с адаптацией длинных сумм, строки 14–20px; дата 32–42px. Высота строки чисел 1.1, пояснений 1.4–1.45. Основной текст 15px, пояснения 13px. Нет зависимости от внешних font CDN.

## Layout
Максимальная ширина 1240px. Поля 42px на широком экране и 20px на узком. От 760px сводка слева (265–310px), журнал справа. Ниже 760px блоки идут последовательно, добавление закреплено снизу в отдельной SafeArea вне скролла. При ширине журнала от 640px поездки имеют общие колонки; ниже — блоки с временем, оплатой, суммой, комиссией и доходом. Крупные суммы в компактной строке переносятся в отдельный ряд. Скролл принадлежит странице; длинное модальное окно имеет собственный скролл. День ограничивает набор записей; весь список за день доступен без скрытой пагинации.

## Elevation & Depth
Светлые поверхности разделяются границами. Тени применяются только к модальному окну. Градиентов и blur нет.

## Shapes
Контейнеры 24px, кнопки/поля 10px, подписи оплаты 8px. Круглый коралловый знак бренда. Разделители обозначают строки журнала.

## Components
### Canonical UI Map
| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Date | Flutter showDatePicker + TripForm | AGENTS.md, DiaryController | calendar / typed UTC+5 | frontend/test/diary_test.dart |
| Form | TripForm / Form / TextFormField | AGENTS.md | create | frontend/test/diary_test.dart |
| Scrollbar | DiaryTheme / web/index.html | theme.dart | page / modal | browser inspection |
| Toast | ScaffoldMessenger | DiaryScreen | success | frontend/test/diary_test.dart |
| CRUD | DiaryController / DiaryApi | FastAPI schemas and services | create / retry | frontend/test/diary_test.dart, backend/tests/test_api.py |

### Foundational visual states
Используются Material 3 контроли с hover, focus, pressed, disabled. Loading — именованный CircularProgressIndicator. Ошибки сохраняются до восстановления, поля сохраняются. Форма блокирует повторный submit и сохраняет ширину кнопки.
### Buttons and actions
FilledButton — «Добавить поездку»/«Сохранить поездку». OutlinedButton — календарь и повтор загрузки. IconButton с русскими tooltip — соседние дни. Никаких действий удаления.
### Navigation and data display
Один экран. Календарь задаёт date-only значение; API и controller владеют загрузкой. Журнал упорядочен по началу. Наличные/карта, сумма, комиссия и доход подписаны текстом. Диапазон дня использует самое позднее окончание; переход через полночь отмечается числом дней, у поездки видна дата окончания.
### Forms and overlays
Date — локализованный Flutter showDatePicker. В форме начало и окончание имеют отдельный календарь с отображением dd/MM/yyyy и showTimePicker с точностью до минуты, всегда 24 часа. Денежные поля ограничены MoneyInputFormatter: цифры, один десятичный разделитель, до двух дробных знаков; неверная вставка отклоняется целиком. Payment — SegmentedButton с двумя видимыми вариантами, без dropdown. Form — Form/TextFormField и TripForm. Toast — единый ScaffoldMessenger. CRUD — DiaryController. Неопределённый исход POST сохраняет ID и payload в памяти контроллера; повтор отправляет те же данные. Закрытие формы сохраняет неопределённый запрос. Закрытие с несохранёнными правками требует app-owned диалог.
### Iconography
Material Icons outlined, обычно 20–24px; иконки действий имеют доступные подписи.
### Motion
Только стандартная обратная связь Material; фоновых анимаций нет. При reduce motion стандартные Flutter контроли следуют платформенному предпочтению.
### Content and data visualization
Краткий русский текст, конкретные действия. День явно показывает UTC+5. Деньги с разделением тысяч, знак ₸; комиссии и суммы передаются точно в minor units. «На руки» означает доход после комиссии, не баланс банковского счёта. Полоса оплаты показывает реальное соотношение наличной и карточной выручки; при нуле она нейтральная и имеет доступную текстовую подпись.

## Do's and Don'ts
- Do: всегда показывать дату рядом со сводкой.
- Do: сохранять введённые значения при ошибке и старый ID при неопределённом ответе.
- Don't: использовать timezone браузера или double для денег.
- Don't: добавлять декоративные метрики, графики или сведения о реализации в рабочий экран.

## Design research
Пользователь оценил основной экран как слишком шаблонный. [Исследование Driversnote, Everlance и Gridwise](docs/DESIGN_REFERENCES.md) фиксирует источники, ограничения проверки и направление следующего редизайна: компактный светлый журнал, общие колонки, расчёт смены в одном блоке. После сравнения трёх интерактивных концептов пользователь выбрал B — «Лагуну»: понятность и удобство для ежедневного использования. Эта система и Flutter-токены обновлены вместе; вспомогательные HTML-демки остаются материалами исследования.
