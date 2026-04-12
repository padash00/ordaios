# ORDA — Полное Техническое Задание
## Версия 1.0 | Апрель 2026

---

## СОДЕРЖАНИЕ

1. [Обзор экосистемы](#1-обзор-экосистемы)
2. [Текущее состояние (что готово)](#2-текущее-состояние)
3. [Фаза 1 — iOS: Завершение текущего](#фаза-1--ios-завершение-текущего)
4. [Фаза 2 — iOS: Критические пробелы](#фаза-2--ios-критические-пробелы)
5. [Фаза 3 — iOS: Клиентский опыт](#фаза-3--ios-клиентский-опыт)
6. [Фаза 4 — iOS: Продвинутые фичи](#фаза-4--ios-продвинутые-фичи)
7. [Фаза 5 — Electron Point](#фаза-5--electron-point)
8. [Фаза 6 — Web (сайт)](#фаза-6--web-сайт)
9. [База данных — новые таблицы](#9-база-данных--новые-таблицы)
10. [Архитектура и стандарты кода](#10-архитектура-и-стандарты-кода)

---

## 1. ОБЗОР ЭКОСИСТЕМЫ

### 1.1 Компоненты системы

```
ORDA ECOSYSTEM
│
├── Web App (Next.js 15 + Supabase)
│   URL: ordaops.kz / f16finance
│   Назначение: стратегия, финансы, управление
│   Роли: owner, admin, manager, marketer
│
├── iOS App (SwiftUI + MVVM)
│   Назначение: мобильный контроль + клиентский опыт
│   Роли: все роли + клиент
│
├── Electron Point (Electron + React)
│   Назначение: POS-терминал в точке
│   Роли: operator, point-admin
│
└── Telegram Bot
    Назначение: уведомления, отчёты, AI
    Интеграция: web + iOS
```

### 1.2 Типы точек (Point Types)

| Тип | Пример | Ключевые функции |
|-----|--------|-----------------|
| `gaming_club` | Компьютерный клуб | Станции, сессии, арена, время |
| `retail` | Магазин | Товары, корзина, штрихкоды |
| `coworking` | Коворкинг | Рабочие места, пакеты времени |
| `cafe` | Кафе | Меню, предзаказ, столики |
| `mixed` | F16 (клуб + магазин) | Комбинация |

Тип точки определяется в `point_projects` таблице → iOS адаптирует UI.

### 1.3 Роли и доступы

| Роль | Web | iOS | Electron |
|------|-----|-----|----------|
| `owner` | Полный доступ | SuperAdmin shell | — |
| `admin` | Операции + финансы | Admin shell | point-admin |
| `manager` | Операции | Admin shell (ограничен) | — |
| `marketer` | Клиенты + задачи | Marketer shell | — |
| `operator` | Свои данные | Operator shell | Основной пользователь |
| `client` | Профиль + баллы | Client shell | — |

### 1.4 Принцип синхронизации iOS ↔ Electron

```
Оба клиента → один API → одна база Supabase
Нет отдельной синхронизации — данные общие изначально.

Electron открыл смену → iOS сразу видит в OperatorShiftsView
iOS подтвердил задачу → Electron видит обновлённый статус
```

---

## 2. ТЕКУЩЕЕ СОСТОЯНИЕ

### 2.1 iOS — что готово (✅)

```
Auth & Security:
├── ✅ Login (email + operator mode)
├── ✅ Password reset (deep link)
├── ✅ AppLock (Face ID / Touch ID + timeout)
└── ✅ Session management

Admin — Финансы:
├── ✅ Доходы (CRUD + категории)
├── ✅ Расходы (CRUD + категории)
├── ✅ Прибыльность (P&L)
├── ✅ Аналитика (месячный отчёт + drill-down по дню)
└── ✅ KPI дашборд

Admin — Операции:
├── ✅ Задачи (создание, назначение, статусы, комментарии + фото)
├── ✅ Смены (просмотр, публикация)
├── ✅ Операторы (список, профиль)
├── ✅ Клиенты (список, история)
├── ✅ Зарплата (еженедельная, выплаты, корректировки, PDF)
└── ✅ Point Devices (CRUD, токены, флаги)

Operator:
├── ✅ Дашборд (обзор)
├── ✅ Задачи (просмотр, ответы, комментарии + фото)
├── ✅ Смены (просмотр, подтверждение недели)
├── ✅ Зарплата (еженедельная + графики)
├── ✅ Профиль + QR-вход на кассу
├── ✅ Live Activity (активная смена)
└── ✅ Calendar + Local Notifications (задачи)

Client:
├── ✅ Профиль (home)
├── ✅ Баллы (баланс + история + tier)
├── ✅ Бронирования (список + создание + пагинация)
└── ✅ Поддержка (тикеты + создание)

iOS Native:
├── ✅ Live Activity (смена оператора)
├── ✅ Local Notifications (задачи)
├── ✅ Calendar sync (задачи)
├── ✅ QR Scanner (DataScannerViewController)
└── ✅ WidgetBridge (логика готова, нужен Xcode target)
```

### 2.2 iOS — что частично (⚠️)

```
├── ⚠️ P0/Point терминал — API есть, UI ~40%
├── ⚠️ Widget — логика готова, target не подключён
├── ⚠️ Arena — нет экрана
└── ⚠️ Inventory — базово, без полного CRUD
```

### 2.3 iOS — чего нет (❌)

```
Критично:
├── ❌ Открытие/закрытие смены из iOS
├── ❌ Калькулятор смены
├── ❌ Cashflow экран
├── ❌ Telegram отправка отчётов
├── ❌ AI Assistant чат

Важно:
├── ❌ Скидки
├── ❌ Expense Templates
├── ❌ Staff salary
├── ❌ Operator Analytics (личная статистика оператора)
├── ❌ Operator Career History
├── ❌ Ratings (рейтинг операторов)
├── ❌ Birthdays (дни рождения)
├── ❌ Audit Logs
├── ❌ Role Permissions управление
├── ❌ Shift swap (обмен сменами)
└── ❌ Broadcast сообщения

iOS-native (нет нигде в КЗ):
├── ❌ Apple Wallet (PassKit) — карта лояльности
├── ❌ Orda Market (каталог для клиентов)
├── ❌ Orda Pay (внутренний баланс)
├── ❌ Достижения + реферальная программа
├── ❌ Arena (статус станций)
├── ❌ Smart Notifications (AI алерты)
└── ❌ Голосовые заметки к задачам
```

---

## ФАЗА 1 — iOS: ЗАВЕРШЕНИЕ ТЕКУЩЕГО

**Срок:** 1–2 дня
**Цель:** Закрыть всё что логически готово, но не подключено

---

### F1.1 Widget Target — подключить в Xcode

**Статус:** Логика готова (`OperatorWidgetBridge`, `OperatorOverviewWidget`)
**Проблема:** Widget Extension Target не добавлен в Xcode проект

**Шаги:**
```
1. Xcode → File → New → Target → Widget Extension
   Name: OperatorWidgetExtension
   Bundle ID: com.padash00.orda.widget

2. App Groups — включить для обоих targets:
   Main app: group.com.padash00.orda.client
   Widget: group.com.padash00.orda.client

3. OperatorWidgetBridge.swift → сменить UserDefaults на:
   UserDefaults(suiteName: "group.com.padash00.orda.client")

4. Перенести файлы в widget target membership:
   - OperatorWidgetExtension/OperatorOverviewWidget.swift
   - OperatorWidgetExtension/OperatorWidgetExtensionBundle.swift

5. Проверить Info.plist widget target — NSWidgetWantsLocation = false
```

**Виды виджетов:**
```swift
// Small (2x2): баллы клиента или статус смены
// Medium (4x2): задачи + смена оператора  
// Large (4x4): дашборд руководителя (выручка, точки, смены)
```

**Файлы:**
- `OperatorWidgetExtension/OperatorOverviewWidget.swift` — уже готов
- `OperatorWidgetExtension/OperatorWidgetExtensionBundle.swift` — уже готов
- `Core/Services/OperatorWidgetBridge.swift` — изменить suite name

---

### F1.2 Smoke Test всех ролей

**Проверить каждую роль по чек-листу:**

```
Owner:
□ Вход → SuperAdmin shell открывается
□ Видит все компании
□ Переход в Admin модули работает

Admin/Manager:
□ Финансы: добавить доход → список обновился
□ Зарплата: неделя ← → → навигация
□ PDF зарплаты: генерируется и открывается Share Sheet
□ Задача: создать → назначить оператору → статус меняется
□ Аналитика: tap на день → drill-down открывается

Operator:
□ Задача: ответить + оставить комментарий с фото
□ Смена: подтвердить неделю
□ QR-вход: сканер открывается (на реальном устройстве)
□ Live Activity: появляется при активной смене
□ Calendar: задача с due_date → событие в Календаре iOS

Client:
□ Баллы: баланс отображается
□ Tier прогресс-бар работает
□ Бронирование: создать → появилось в списке
□ Тикет: отправить сообщение → статус "отправлено"
```

---

### F1.3 Исправление QR карточки клиента

**Проблема:** `LoyaltyQRSheet` генерирует QR с `"loyalty:1240pts"` — это бесполезно для кассира.

**Нужно:** QR должен содержать `customer_id` из профиля.

**Файл:** `Orda Control/Features/Points/PointsView.swift`

```swift
// БЫЛО:
if let qrImage = generateQR(text: "loyalty:\(points)pts")

// НАДО:
// PointsSummary должен содержать customer_id
// Получаем из API /api/client/points → поле customer_id или user_id
if let qrImage = generateQR(text: "orda://client/\(summary.customerId)")

// Формат QR: "orda://client/{uuid}"
// Electron Point сканирует → находит клиента по UUID → начисляет баллы
```

**Изменения в модели:**
```swift
// ClientModels.swift — добавить поле в PointsSummary:
struct PointsSummary: Decodable {
    let customerId: String  // ← добавить
    let points: Int
    // ...
    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"  // ← добавить
        // ...
    }
}
```

---

### F1.4 Токены в Keychain (безопасность)

**Проблема:** JWT токены хранятся в `UserDefaults` — небезопасно.

**Файл:** `Core/Auth/SessionStore.swift`

```swift
// Создать: Core/Security/KeychainHelper.swift

final class KeychainHelper {
    static let shared = KeychainHelper()
    
    func save(_ data: Data, key: String) { ... }  // SecItemAdd
    func load(key: String) -> Data? { ... }        // SecItemCopyMatching
    func delete(key: String) { ... }               // SecItemDelete
}

// Константы:
// "orda.auth.token"       — access token
// "orda.auth.refresh"     — refresh token
// "orda.auth.userEmail"   — email пользователя
```

**Что перенести:**
- `sessionStore.session?.token` → Keychain
- `sessionStore.session?.userEmail` → Keychain (можно UserDefaults)

---

## ФАЗА 2 — iOS: КРИТИЧЕСКИЕ ПРОБЕЛЫ

**Срок:** 1–2 недели
**Цель:** Закрыть функции без которых приложение неполное

---

### F2.1 Открытие / Закрытие смены из iOS

**Зачем:** Оператор может работать без Electron. iOS = полноценная замена при необходимости.

**API:**
```
POST /api/point/shift-report   — открыть смену
PATCH /api/point/shift-report  — обновить данные смены
POST /api/point/shift-report/close — закрыть смену
GET  /api/point/shift-report   — текущая смена
```

**Новые файлы:**
```
Features/Operator/OperatorShiftManagerView.swift
```

**UI — экран управления сменой:**
```
Состояние 1: Смена не открыта
┌────────────────────────────────┐
│  Новая смена                   │
│  ○ Дневная (08:00–20:00)       │
│  ● Ночная  (20:00–08:00)       │
│                                │
│  Точка: [выпадающий список]    │
│                                │
│  [  Открыть смену  ]           │
└────────────────────────────────┘

Состояние 2: Смена открыта
┌────────────────────────────────┐
│  ◉ СМЕНА ИДЁТ                  │
│  Дневная · Астана Молл         │
│  Начало: 08:00                 │
│  Прошло: 4ч 23мин              │
│                                │
│  ─── Итоги смены ───           │
│  Наличные:     45 000 ₸        │
│  Kaspi:       120 000 ₸        │
│  Расходы:      12 000 ₸        │
│  ─────────────────────         │
│  ИТОГО:       153 000 ₸  ✅    │
│                                │
│  [Обновить данные]             │
│  [Закрыть смену →]             │
└────────────────────────────────┘

Состояние 3: Закрытие смены
┌────────────────────────────────┐
│  Закрытие смены                │
│                                │
│  Наличные в кассе: [_______]  ₸│
│  Kaspi сумма:      [_______]  ₸│
│  Расходы:          [_______]  ₸│
│  Комментарий:      [_______]   │
│                                │
│  ─── Расчёт ───                │
│  Доход:       165 000 ₸        │
│  Расходы:    - 12 000 ₸        │
│  Итог:        153 000 ₸  ✅    │
│                                │
│  [  Отправить в Telegram  ]    │
│  [  Закрыть смену  ]           │
└────────────────────────────────┘
```

**ViewModel:**
```swift
// Features/Operator/OperatorShiftManagerViewModel.swift
@MainActor
final class OperatorShiftManagerViewModel: ObservableObject {
    @Published var currentShift: PointShiftReport?
    @Published var isLoading = false
    @Published var shiftType: String = "day" // "day" | "night"
    @Published var cashAmount: Double = 0
    @Published var kaspiAmount: Double = 0
    @Published var expenses: Double = 0
    @Published var comment: String = ""
    
    var totalIncome: Double { cashAmount + kaspiAmount }
    var netResult: Double { totalIncome - expenses }
    var isPositive: Bool { netResult >= 0 }
    
    func openShift(pointId: String) async { ... }
    func closeShift() async { ... }
    func sendToTelegram() async { ... }
}
```

**Модель:**
```swift
// Models/ShiftModels.swift (новый файл)
struct PointShiftReport: Decodable, Identifiable {
    let id: String
    let pointId: String?
    let shiftType: String?       // "day" | "night"
    let openedAt: String?
    let closedAt: String?
    let cashAmount: Double?
    let kaspiAmount: Double?
    let expenses: Double?
    let netResult: Double?
    let comment: String?
    let status: String?          // "open" | "closed"
    let operatorId: String?
}
```

**Live Activity обновление:**
```swift
// После openShift() → запустить Live Activity
await OperatorShiftLiveActivityManager.shared.sync(with: shift)
```

---

### F2.2 Cashflow экран

**Зачем:** Владелец и руководитель должны видеть движение денег — не просто доходы/расходы, а сальдо по времени.

**API:**
```
GET /api/admin/cashflow?from=2026-04-01&to=2026-04-30&companyId=...
```

**Ответ API (предполагаемый):**
```json
{
  "period": { "from": "2026-04-01", "to": "2026-04-30" },
  "openingBalance": 500000,
  "totalIncome": 1200000,
  "totalExpenses": 450000,
  "closingBalance": 1250000,
  "daily": [
    { "date": "2026-04-01", "income": 45000, "expenses": 12000, "balance": 533000 }
  ]
}
```

**Файлы:**
```
Features/Admin/AdminCashflowView.swift
Features/Admin/AdminCashflowViewModel.swift
```

**UI:**
```
┌────────────────────────────────┐
│  Cashflow  [Апрель 2026  ▾]    │
│                                │
│  Открывающий остаток           │
│  500 000 ₸                     │
│                                │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │+1.2M │ │-450к │ │=1.25M│   │
│  │Приход│ │Расход│ │Остаток   │
│  └──────┘ └──────┘ └──────┘   │
│                                │
│  [Swift Charts — area chart]   │
│  Баланс по дням ────────────   │
│                                │
│  ─── По дням ───               │
│  01 апр   +45 000  -12 000    │
│  02 апр   +67 000  -8 000     │
│  ...                           │
└────────────────────────────────┘
```

**Добавить в AdminShell:**
```swift
// AdminContractsViews.swift — добавить модуль в хаб
ModuleCard(title: "Cashflow", icon: "arrow.left.arrow.right.circle.fill",
           color: AppTheme.Colors.accentBlue) {
    AdminCashflowView(service: service)
}
```

---

### F2.3 Telegram интеграция из iOS

**Зачем:** Главный канал коммуникации в КЗ — Telegram. Отчёты должны лететь туда одним нажатием.

**API:**
```
GET  /api/telegram/status              — статус бота
POST /api/telegram/send-report         — отправить отчёт смены
POST /api/telegram/send                — кастомное сообщение
GET  /api/telegram/allowed-users       — список пользователей
POST /api/telegram/salary-snapshot     — зарплатный снапшот
```

**Новый файл:**
```
Features/Admin/AdminTelegramView.swift
```

**UI — экран Telegram Hub:**
```
┌────────────────────────────────┐
│  Telegram                      │
│                                │
│  ● Бот подключён               │ ← статус
│  @OrdaBot · 12 пользователей   │
│                                │
│  ─── Быстрые действия ───      │
│                                │
│  [📊 Отчёт смены]              │ → send-report
│  [💰 Зарплатный снапшот]       │ → salary-snapshot
│  [📝 Кастомное сообщение]      │ → send (sheet)
│                                │
│  ─── История отправок ───      │
│  Сегодня 18:00  Отчёт смены ✓  │
│  Вчера   17:45  Зарплата ✓     │
└────────────────────────────────┘
```

**Добавить кнопку в ShiftManager:**
```swift
// После закрытия смены → кнопка "Отправить в Telegram"
// POST /api/telegram/send-report с данными закрытой смены
```

---

### F2.4 AI Assistant чат

**Зачем:** Killer feature. Владелец/руководитель спрашивает — AI отвечает на основе данных бизнеса.

**API:**
```
POST /api/ai/assistant
Body: { "message": "Почему упала выручка на прошлой неделе?", "context": "company_id" }
Response: { "reply": "...", "charts": [...] }
```

**Новый файл:**
```
Features/Analytics/AdminAIAssistantView.swift
```

**UI:**
```
┌────────────────────────────────┐
│  AI Аналитик          [⚙️]    │
│                                │
│  ┌──────────────────────────┐  │
│  │ 🤖 Привет! Я анализирую  │  │
│  │ данные F16. Задайте      │  │
│  │ любой вопрос о бизнесе.  │  │
│  └──────────────────────────┘  │
│                                │
│  ┌──────────────────────────┐  │
│  │ Почему выручка упала     │  │ ← пользователь
│  │ в пятницу?               │  │
│  └──────────────────────────┘  │
│                                │
│  ┌──────────────────────────┐  │
│  │ 🤖 В пятницу 11 апр.     │  │
│  │ было 3 смены вместо      │  │
│  │ обычных 5. Операторы     │  │
│  │ Алибек и Дана отсутств.  │  │
│  │ Рекомендую: [График ▸]   │  │
│  └──────────────────────────┘  │
│                                │
│  ─── Быстрые вопросы ───       │
│  [Выручка за неделю]           │
│  [Топ операторов]              │
│  [Прогноз на месяц]            │
│                                │
│  [___ Написать вопрос ___] [➤] │
└────────────────────────────────┘
```

**ViewModel:**
```swift
@MainActor
final class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var isLoading = false
    @Published var inputText = ""
    
    struct AIMessage: Identifiable {
        let id = UUID()
        let role: Role  // .user | .assistant
        let content: String
        let timestamp: Date
        enum Role { case user, assistant }
    }
    
    func send() async {
        let userMsg = inputText
        inputText = ""
        messages.append(.init(role: .user, content: userMsg, timestamp: .now))
        // POST /api/ai/assistant
        // append response
    }
}
```

---

### F2.5 Arena — статус станций

**Зачем:** Для игровых клубов. Клиент видит свободные станции с телефона.

**API:**
```
GET  /api/admin/arena          — список станций (admin)
GET  /api/point/arena          — станции точки (operator)
POST /api/point/arena/start    — запустить сессию
POST /api/point/arena/stop     — остановить сессию
```

**Файлы:**
```
Features/Admin/AdminArenaView.swift     — для admin
Features/Operator/OperatorArenaView.swift — для operator
```

**UI — сетка станций:**
```
┌────────────────────────────────┐
│  Arena · F16 Astana   [🔄]    │
│  Свободно: 8 / Занято: 12     │
│                                │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐     │
│  │ 1 │ │ 2 │ │ 3 │ │ 4 │     │
│  │🟢 │ │🔴 │ │🔴 │ │🟢 │     │
│  │   │ │01:│ │00:│ │   │     │
│  │   │ │23 │ │45 │ │   │     │
│  └───┘ └───┘ └───┘ └───┘     │
│                                │
│  🟢 Свободна                   │
│  🔴 Занята (таймер)            │
│  🟡 Скоро освободится          │
│                                │
│  Tap на занятую → детали:      │
│  Клиент: Алия Б.               │
│  Начало: 14:23                 │
│  Баланс: 45 мин                │
│  [Завершить сессию]            │
└────────────────────────────────┘
```

**Модель:**
```swift
struct ArenaStation: Decodable, Identifiable {
    let id: String
    let number: Int
    let status: String      // "free" | "busy" | "reserved"
    let sessionStart: String?
    let sessionMinutes: Int?
    let clientName: String?
    let clientBalance: Double?
}
```

**Обновление:** polling каждые 30 секунд (`Timer.publish(every: 30, ...)`)

---

### F2.6 Личная аналитика оператора

**Зачем:** Оператор видит свои результаты — мотивация, геймификация.

**API:**
```
GET /api/admin/operator-analytics?operatorId={id}&period=month
```

**Файл:**
```
Features/Operator/OperatorMyAnalyticsView.swift
```

**UI:**
```
┌────────────────────────────────┐
│  Мои результаты   [Апрель ▾]  │
│                                │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │  24  │ │  6   │ │ 88%  │   │
│  │Задач │ │Смен  │ │Оценка│   │
│  │  ✅  │ │  ✅  │ │      │   │
│  └──────┘ └──────┘ └──────┘   │
│                                │
│  [Swift Charts — bar chart]    │
│  Задачи по неделям ──────────  │
│                                │
│  [Swift Charts — bar chart]    │
│  Зарплата по неделям ────────  │
│                                │
│  Место в рейтинге: 3 из 12 🏅  │
│  ▓▓▓▓▓▓▓▓░░  8 место             │
└────────────────────────────────┘
```

---

### F2.7 Рейтинг операторов

**API:**
```
GET /api/admin/ratings?period=month&companyId=...
```

**Добавить в:** `AdminContractsViews.swift` — новая вкладка в операторском модуле

**UI:**
```
Топ операторов — Апрель 2026

🥇  Алибек Сейткали    42 задачи   8 смен
🥈  Дана Ахметова      38 задачи   7 смен
🥉  Нурлан Кожахметов  31 задача   6 смен
    ...
```

---

### F2.8 Дни рождения сотрудников

**API:**
```
GET /api/admin/birthdays
```

**Добавить:** Карточка на главном экране Admin + push уведомление в день рождения

```swift
// В AdminDashboardView добавить:
if let bday = todaysBirthdays.first {
    BirthdayCard(name: bday.name, position: bday.position)
}

// Local Notification (ежегодный):
UNCalendarNotificationTrigger(
    dateMatching: DateComponents(month: bday.month, day: bday.day),
    repeats: true
)
```

---

### F2.9 Обмен сменами (Shift Swap)

**Новая функция — нет на сайте.**

**Логика:**
```
1. Оператор открывает свою смену
2. Нажимает "Найти замену"
3. Указывает причину
4. Коллеги получают push: "Алибек ищет замену на 15 апреля дн."
5. Кто-то нажимает "Возьму смену"
6. Руководитель получает запрос на подтверждение
7. После подтверждения — смена переназначена
```

**Новые эндпоинты (нужны в БД и API):**
```
POST /api/operator/shift-swap-request   — запросить замену
GET  /api/operator/shift-swap-requests  — входящие запросы
POST /api/operator/shift-swap-accept    — принять
POST /api/admin/shift-swap-approve      — подтвердить (admin)
```

**Новая таблица:** `shift_swap_requests` (см. раздел 9)

---

### F2.10 Expense Templates (Шаблоны расходов)

**API:**
```
GET    /api/admin/expense-templates
POST   /api/admin/expense-templates
DELETE /api/admin/expense-templates/{id}
```

**UI:** В экране добавления расхода — кнопка "Из шаблона":
```
[+ Новый расход]  [📋 Из шаблона]

Мои шаблоны:
├── Аренда офиса — 150 000 ₸ / мес
├── Интернет — 15 000 ₸ / мес
└── Зарплата охранника — 80 000 ₸ / мес
```

---

## ФАЗА 3 — iOS: КЛИЕНТСКИЙ ОПЫТ

**Срок:** 2–3 недели
**Цель:** Сделать клиентскую часть уникальной в КЗ

---

### F3.1 Apple Wallet — Orda Pass

**Зачем:** Клиент показывает карту в Wallet — не нужно открывать приложение. Обновляется при каждом начислении.

**Библиотека:** `PassKit` (встроен в iOS)

**Файл:**
```
Features/Points/OrdaPassGenerator.swift
```

**Структура Pass (.pkpass):**
```json
{
  "formatVersion": 1,
  "passTypeIdentifier": "pass.com.padash00.orda.loyalty",
  "teamIdentifier": "XXXXXXXXXX",
  "organizationName": "Orda",
  "description": "Карта лояльности Orda",
  "backgroundColor": "rgb(124, 111, 247)",
  "foregroundColor": "rgb(255, 255, 255)",
  "storeCard": {
    "primaryFields": [{
      "key": "balance",
      "label": "Баллы",
      "value": "1 240"
    }],
    "secondaryFields": [{
      "key": "tier",
      "label": "Уровень",
      "value": "Gold"
    }]
  },
  "barcode": {
    "message": "orda://client/{customer_id}",
    "format": "PKBarcodeFormatQR"
  }
}
```

**Обновление Pass:**
```swift
// При каждом изменении баланса:
// 1. Сгенерировать новый .pkpass файл
// 2. PKPassLibrary().replace(existingPass, with: newPass)
// Или: push notification → система обновляет pass автоматически
```

**Нужно на сервере:**
```
POST /api/client/wallet-pass  — сгенерировать/обновить pass
// Сервер формирует .pkpass, подписывает сертификатом Apple
// Требует: Apple Developer Certificate (Pass Type ID)
```

---

### F3.2 Orda Market — каталог для клиентов

**Зачем:** Клиент видит товары точки прямо в приложении. Для магазинов — предзаказ.

**API (существующий):**
```
GET /api/point/products?pointId=...   — список товаров
POST /api/point/inventory-sales        — продажа (для оператора)
```

**Нужен новый клиентский endpoint:**
```
GET /api/client/catalog?pointId=...   — каталог для клиента (публичный)
POST /api/client/preorder              — предзаказ
```

**Файл:**
```
Features/Home/OrdaMarketView.swift
```

**UI:**
```
┌────────────────────────────────┐
│  Каталог · F16 Astana   [🔍]  │
│                                │
│  [Все] [Напитки] [Снэки] [+]  │
│                                │
│  ┌──────────┐ ┌──────────┐    │
│  │  [фото]  │ │  [фото]  │    │
│  │ Ред Булл │ │ Чипсы    │    │
│  │  500 ₸   │ │  350 ₸   │    │
│  │ [+ Заказ]│ │ [+ Заказ]│    │
│  └──────────┘ └──────────┘    │
│                                │
│  [Корзина (2 товара) — 850 ₸] │
└────────────────────────────────┘

→ Корзина:
┌────────────────────────────────┐
│  Ваш заказ                     │
│                                │
│  Ред Булл × 1      500 ₸       │
│  Чипсы × 1         350 ₸       │
│  ─────────────────────────     │
│  Итого:            850 ₸       │
│  Баллы к зачтению: -85 ₸       │
│  К оплате:         765 ₸       │
│                                │
│  [  Оформить предзаказ  ]      │
│  Оператор подготовит заказ     │
└────────────────────────────────┘
```

---

### F3.3 Orda Pay — внутренний баланс

**Зачем:** Клиент пополняет баланс через Kaspi → платит в точке без наличных.

**Новые таблицы:** `client_balance`, `client_balance_transactions` (см. раздел 9)

**Новые endpoints:**
```
GET  /api/client/balance              — текущий баланс
POST /api/client/balance/topup        — пополнение (через Kaspi deeplink)
GET  /api/client/balance/transactions — история операций
```

**Kaspi интеграция:**
```swift
// Deep link для пополнения:
let kaspiURL = URL(string: "kaspi://pay?amount=5000&account=\(clientId)")!
UIApplication.shared.open(kaspiURL)

// После пополнения Kaspi webhook → наш сервер → обновить баланс
// Клиент получает push: "Пополнено: +5 000 ₸"
```

**UI:**
```
┌────────────────────────────────┐
│  Мой кошелёк                   │
│                                │
│         5 000 ₸                │
│       Текущий баланс           │
│                                │
│  [+ Пополнить через Kaspi]     │
│                                │
│  ─── История ───               │
│  +5 000 ₸  Пополнение  10 апр │
│  -850 ₸    Предзаказ   09 апр  │
│  -1 200 ₸  Оплата      08 апр  │
└────────────────────────────────┘
```

---

### F3.4 Достижения и геймификация

**Нет нигде в КЗ.** Клиенты возвращаются ради бейджей.

**Новая таблица:** `client_achievements` (см. раздел 9)

**Список достижений:**
```
🎯 Первый шаг      — первая покупка
🔥 Завсегдатай     — 10 посещений
💎 Платиновый      — 50 посещений
🤝 Друзья          — пригласил 1 друга
👥 Амбассадор      — пригласил 5 друзей
⭐ Звезда          — достиг Gold уровня
💰 Большой чек     — разовая покупка 10 000+₸
🎂 Именинник       — зашёл в день рождения
```

**Реферальная программа:**
```
Клиент делится ссылкой/кодом →
Друг регистрируется по ссылке →
Оба получают +200 баллов автоматически
```

**Новые endpoints:**
```
GET  /api/client/achievements          — мои достижения
GET  /api/client/referral-code         — мой реферальный код
POST /api/public/client/register       — регистрация (добавить referral_code)
```

**UI:**
```
┌────────────────────────────────┐
│  Достижения         3 / 8 ✅   │
│                                │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐  │
│  │ 🎯 │ │ 🔥 │ │ 💎 │ │ 🤝 │  │
│  │ ✅ │ │ ✅ │ │    │ │ ✅ │  │
│  └────┘ └────┘ └────┘ └────┘  │
│                                │
│  ─── Реферальная программа ── │
│  Ваш код: ALIYA2026            │
│  [Поделиться ссылкой]          │
│  Приглашено: 3 друга           │
│  Заработано: +600 баллов       │
└────────────────────────────────┘
```

---

### F3.5 Бронирование станций (для клубов)

**Зачем:** Клиент бронирует станцию заранее — не нужно стоять в очереди.

**Новые endpoints:**
```
GET  /api/client/stations?pointId=...  — статус станций
POST /api/client/station-booking       — забронировать
DELETE /api/client/station-booking/{id} — отменить
```

**UI:**
```
┌────────────────────────────────┐
│  F16 Astana · Станции          │
│  Свободно: 8 из 20             │
│                                │
│  Выберите время:               │
│  [14:00] [15:00] [16:00] [17:00]│
│                                │
│  Доступные станции в 15:00:    │
│  Станция 3, 7, 12, 15, 18     │
│                                │
│  [Забронировать на 2 часа]     │
│  Стоимость: 1 000 ₸            │
│  Баллы: -100 ₸                 │
└────────────────────────────────┘
```

---

### F3.6 Push Notifications (APNs)

**Зачем:** Клиент должен знать когда начислили баллы, изменился статус тикета, освободилась станция.

**Серверная часть (добавить в API):**
```
POST /api/client/register-device     — зарегистрировать APNs token
DELETE /api/client/unregister-device — отключить
```

**iOS:**
```swift
// AppDelegate / SceneDelegate:
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
UIApplication.shared.registerForRemoteNotifications()

// При получении token:
// POST /api/client/register-device { "token": "...", "platform": "ios" }
```

**Типы уведомлений:**
```
points_earned:   "Начислено +150 баллов за покупку"
points_redeemed: "Списано 500 баллов. Скидка применена"
booking_status:  "Ваша бронь подтверждена на 15:00"
support_reply:   "Ответ на ваш запрос №1234"
station_free:    "Станция №5 освободилась"
achievement:     "Новое достижение: 🔥 Завсегдатай!"
birthday:        "🎂 С днём рождения! +500 баллов в подарок"
```

---

## ФАЗА 4 — iOS: ПРОДВИНУТЫЕ ФИЧИ

**Срок:** 3–4 недели
**Цель:** iOS-нативные фичи которых нет нигде в КЗ

---

### F4.1 Smart Notifications — AI алерты

**Зачем:** Владелец не хочет получать спам. Только важное.

**Логика (серверная, cron):**
```
Каждый час проверяем:
├── Точка не открылась в обычное время → alert
├── Выручка за день -30% vs средняя → alert
├── Клиент не приходил 30 дней → retention alert
└── Склад: товар заканчивается (< 5 единиц) → alert
```

**Новый endpoint:**
```
GET /api/admin/smart-alerts   — активные алерты
```

**iOS:**
```swift
// При загрузке дашборда — показать алерты
// Каждый алерт — карточка с Action:
// "Точка Almaly не открылась в 09:00" → [Позвонить оператору] [Открыть смену]
```

---

### F4.2 Голосовые заметки к задачам

**Зачем:** Оператор на бегу — говорит вместо того чтобы печатать.

**iOS:**
```swift
// AVAudioRecorder → записать аудио
// Загрузить в Supabase Storage → получить URL
// Отправить URL как часть комментария
// Клиент воспроизводит: AVPlayer

// Или: Whisper API → транскрибировать → отправить текст + аудио
```

**Файл:**
```
Shared/Audio/VoiceNoteRecorder.swift
```

---

### F4.3 Broadcast сообщения

**Зачем:** Руководитель пишет всем операторам сразу.

**Новые endpoints:**
```
POST /api/admin/broadcast          — отправить всем
GET  /api/operator/broadcasts      — входящие сообщения
```

**UI:**
```
Admin: кнопка "Объявление" в операторах → sheet с текстом + фото → отправить
Operator: новая вкладка "Объявления" или badge на главной
```

---

### F4.4 Spotlight Search

**Файл:**
```
Core/Services/SpotlightIndexer.swift
```

```swift
import CoreSpotlight

// Индексировать при загрузке данных:
// Операторы → CSSearchableItem(uniqueIdentifier: "operator/\(id)", ...)
// Задачи → CSSearchableItem(uniqueIdentifier: "task/\(id)", ...)
// Клиенты → CSSearchableItem(uniqueIdentifier: "client/\(id)", ...)

// Deep link: onContinueUserActivity → открыть нужный экран
```

---

### F4.5 Siri App Intents

**Файл:**
```
Core/Intents/OrdaAppIntents.swift
```

```swift
import AppIntents

struct OpenShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть кассу Orda"
    func perform() async throws -> some IntentResult {
        // Открыть QR сканер
    }
}

struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Проверить баллы Orda"
    func perform() async throws -> some ReturnsValue<Int> {
        // Вернуть баланс
    }
}
```

---

### F4.6 Оператор Feed (внутренняя лента)

**Зачем:** Мотивация команды. Руководитель хвалит, делится результатами.

**Новые endpoints:**
```
GET  /api/admin/feed      — лента
POST /api/admin/feed      — опубликовать пост
POST /api/admin/feed/like — лайкнуть
```

**Новая таблица:** `operator_feed` (см. раздел 9)

**UI:**
```
┌────────────────────────────────┐
│  Лента команды                 │
│                                │
│  👤 Руководитель · 2ч назад    │
│  🔥 Рекорд! Astana Mall        │
│  сделала 450 000 ₸ за день!   │
│  Спасибо команде!              │
│  [фото точки]                  │
│  ❤️ 8   💬 3                   │
│  ────────────────────────────  │
│  🏆 Алибек выполнил 30 задач   │
│  за апрель! Новое достижение.  │
│  ❤️ 12                         │
└────────────────────────────────┘
```

---

## ФАЗА 5 — ELECTRON POINT

**Срок:** После завершения iOS Фаз 1-3
**Цель:** Улучшить POS-терминал, добавить iOS-синхронизацию

---

### E5.1 Улучшение ShiftPage — калькулятор смены

**Что есть:** Базовое закрытие смены.

**Что добавить:**
```
├── Авто-подтягивание данных POS (сумма продаж за смену)
├── Ручной ввод наличных (сверка с фактической кассой)
├── Расхождение: факт vs POS → выделить красным
├── История последних 5 смен для сравнения
└── Одна кнопка "Отправить в Telegram + закрыть смену"
```

---

### E5.2 ScannerPage — штрихкод + быстрая продажа

**Что добавить:**
```
├── Поиск товара по штрихкоду (camera scan)
├── Быстрое добавление в продажу (1 tap)
├── Kaspi QR прямо на экране кассы
├── Списание баллов: поле "QR клиента" → scan → применить скидку
└── Чек на email/телефон (вместо бумаги)
```

---

### E5.3 Offline режим

**Что есть:** Базовая offline поддержка.

**Что добавить:**
```
├── LocalStorage (IndexedDB) → хранить товары и клиентов локально
├── Очередь операций при offline → sync при восстановлении
├── Индикатор: "Offline режим · 3 операции в очереди"
└── Конфликты: если данные изменились пока были offline → показать diff
```

---

### E5.4 ArenaPage — управление станциями

**Что добавить:**
```
├── Drag-and-drop: переместить клиента на другую станцию
├── Quick extend: +30 мин / +1 час одним нажатием
├── Групповое управление: выбрать несколько станций → действие
├── Статистика: % загрузки в реальном времени
└── Очередь: кто ждёт свободную станцию
```

---

### E5.5 InventoryRequestPage — улучшение

**Что добавить:**
```
├── Штрихкод сканирование при создании заявки
├── Шаблоны заявок (стандартный набор расходников)
├── Статус в реальном времени (Admin одобрил → уведомление)
└── История заявок с фильтрами
```

---

### E5.6 iOS-Electron синхронизация (видимость)

**Что должен видеть iOS когда Electron работает:**
```
1. Оператор в iOS → смотрит текущие продажи точки (read-only)
2. Руководитель видит: какие точки сейчас работают (смена открыта)
3. Live Activity у оператора обновляется на основе данных Electron
4. Если Electron упал → iOS показывает "Касса недоступна" + кнопка открыть смену из iOS
```

---

## ФАЗА 6 — WEB (САЙТ)

**Срок:** После Electron
**Цель:** Закрыть пробелы на сайте, добавить функции которых нет

---

### W6.1 Страницы которых нет

```
├── /operator-achievements     — достижения операторов
├── /operator-salary-system    — обзорная система зарплат
├── /client-analytics          — аналитика по клиентской базе
└── /broadcast                 — рассылка сообщений команде
```

---

### W6.2 Улучшение существующих страниц

```
/salary:
└── Экспорт в Excel (xlsx) — руководитель требует таблицу

/analytics:
├── Сравнение периодов (этот месяц vs прошлый)
└── Export PNG/PDF любого графика

/operators/[id]/profile:
├── Карьерная история (timeline)
├── Личная аналитика (графики задач/смен)
└── Достижения оператора

/tasks:
└── Kanban вид (drag-and-drop между статусами)
```

---

### W6.3 Telegram Bot — расширение

```
Новые команды бота:
/смена     — статус текущих смен всех точек
/выручка   — выручка за сегодня
/задачи    — открытые задачи по точке
/рейтинг   — топ операторов за месяц
/баллы     — баланс клиента (для клиентского бота)
```

---

## 9. БАЗА ДАННЫХ — НОВЫЕ ТАБЛИЦЫ

### 9.1 `shift_swap_requests`

```sql
CREATE TABLE shift_swap_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID REFERENCES operators(id),  -- кто просит замену
  shift_id      UUID REFERENCES shifts(id),      -- какая смена
  acceptor_id   UUID REFERENCES operators(id),  -- кто берёт (nullable)
  reason        TEXT,
  status        TEXT DEFAULT 'pending',          -- pending|accepted|approved|rejected
  admin_comment TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  resolved_at   TIMESTAMPTZ
);
```

### 9.2 `client_achievements`

```sql
CREATE TABLE client_achievements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   UUID REFERENCES customers(id),
  achievement   TEXT NOT NULL,  -- 'first_purchase'|'10_visits'|'referral' etc.
  unlocked_at   TIMESTAMPTZ DEFAULT NOW(),
  points_earned INT DEFAULT 0,
  UNIQUE(customer_id, achievement)
);
```

### 9.3 `client_referrals`

```sql
CREATE TABLE client_referrals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id    UUID REFERENCES customers(id),  -- кто пригласил
  referred_id    UUID REFERENCES customers(id),  -- кого пригласили
  referral_code  TEXT UNIQUE NOT NULL,
  bonus_given    BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Добавить поле в customers:
ALTER TABLE customers ADD COLUMN referral_code TEXT UNIQUE;
ALTER TABLE customers ADD COLUMN referred_by   UUID REFERENCES customers(id);
```

### 9.4 `client_balance`

```sql
CREATE TABLE client_balance (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID UNIQUE REFERENCES customers(id),
  amount      DECIMAL(12,2) DEFAULT 0,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE client_balance_transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  amount      DECIMAL(12,2),           -- положительное = пополнение
  type        TEXT,                    -- 'topup'|'payment'|'refund'
  reference   TEXT,                    -- kaspi transaction id или order id
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 9.5 `operator_feed`

```sql
CREATE TABLE operator_feed (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID REFERENCES operators(id),
  company_id UUID REFERENCES companies(id),
  content    TEXT NOT NULL,
  image_url  TEXT,
  likes      INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE operator_feed_likes (
  feed_id     UUID REFERENCES operator_feed(id),
  operator_id UUID REFERENCES operators(id),
  PRIMARY KEY (feed_id, operator_id)
);
```

### 9.6 `device_push_tokens`

```sql
CREATE TABLE device_push_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL,           -- customer_id или operator_id
  user_type   TEXT NOT NULL,           -- 'client'|'operator'
  token       TEXT NOT NULL,
  platform    TEXT DEFAULT 'ios',      -- 'ios'|'android'
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);
```

### 9.7 `station_bookings` (для Arena клиентов)

```sql
CREATE TABLE station_bookings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  point_id    UUID REFERENCES point_projects(id),
  station_id  TEXT,                    -- номер/ID станции
  starts_at   TIMESTAMPTZ NOT NULL,
  duration_minutes INT NOT NULL,
  status      TEXT DEFAULT 'pending',  -- pending|confirmed|active|completed|cancelled
  amount      DECIMAL(10,2),
  points_used INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 9.8 `smart_alerts`

```sql
CREATE TABLE smart_alerts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID REFERENCES companies(id),
  type        TEXT NOT NULL,   -- 'shift_not_opened'|'revenue_drop'|'client_churn'|'stock_low'
  message     TEXT NOT NULL,
  severity    TEXT DEFAULT 'warning',  -- 'info'|'warning'|'critical'
  metadata    JSONB,
  read        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 10. АРХИТЕКТУРА И СТАНДАРТЫ КОДА

### 10.1 iOS — Структура файлов

```
Orda Control/
├── Core/
│   ├── Auth/          — SessionStore, AuthService
│   ├── Security/      — AppLockManager, KeychainHelper
│   ├── Services/      — TaskSyncManager, OperatorWidgetBridge, SpotlightIndexer
│   ├── Networking/    — APIClient, APIError, GeneratedContracts
│   └── Intents/       — OrdaAppIntents (Siri)
├── Features/
│   ├── Admin/         — все admin экраны
│   ├── Analytics/     — аналитика + AI Assistant
│   ├── Auth/          — логин, регистрация
│   ├── Bookings/      — бронирования клиента
│   ├── Home/          — главная клиента + Orda Market
│   ├── Operator/      — все operator экраны
│   ├── P0/            — POS/Point/Store
│   ├── Points/        — баллы + Wallet
│   └── Support/       — поддержка
├── Models/            — DTO модели
├── Shared/
│   ├── Design/        — AppTheme, AppComponents
│   ├── UI/            — StateViews, SectionHeader
│   └── Audio/         — VoiceNoteRecorder
└── Extensions/        — Date+Orda, String+Orda etc.
```

### 10.2 Паттерны

```swift
// MVVM: каждый экран = View + ViewModel
// ViewModel: @MainActor final class + ObservableObject
// Service: protocol + implementation (для тестируемости)
// APIClient: единая точка всех запросов

// Правило: ViewModel не знает про UIKit/SwiftUI
// Правило: View не делает API вызовы напрямую
// Правило: Service не знает про ViewModel
```

### 10.3 API соглашения

```swift
// Все запросы через APIClient.shared
// Все ошибки через APIError
// Все DTO: Decodable с CodingKeys для snake_case
// Envelope: { "data": ... } или { "ok": true }

// Пагинация:
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
    var hasMore: Bool { offset + limit < total }
}
```

### 10.4 Design System

```swift
// Всё через AppTheme — никаких хардкоженных цветов
// AppTheme.Colors.* — цвета
// AppTheme.Spacing.* — отступы
// AppTheme.Typography.* — шрифты
// AppTheme.Radius.* — скругления

// Компоненты: всегда из AppComponents
// Иконки: только SF Symbols
// Анимации: withAnimation(.spring(response: 0.35, ...))
```

### 10.5 Локализация

```
Текущий язык: русский
Планируется: казахский

Все строки → через NSLocalizedString или String Catalog (iOS 17+)
Файлы: Localizable.strings (ru, kk)
Форматы дат: ru_RU локаль везде
Числа: NumberFormatter с локалью
```

---

## ИТОГОВЫЙ ЧЕКЛИСТ

### Фаза 1 (сейчас):
```
□ Widget Xcode target подключён
□ App Groups настроены
□ QR клиента содержит customer_id
□ Токены в Keychain
□ Smoke test всех ролей пройден
```

### Фаза 2 (1-2 недели):
```
□ Открытие/закрытие смены из iOS
□ Cashflow экран
□ Telegram Hub
□ AI Assistant чат
□ Arena — статус станций
□ Личная аналитика оператора
□ Рейтинг операторов
□ Дни рождения
□ Shift Swap
□ Expense Templates
```

### Фаза 3 (2-3 недели):
```
□ Apple Wallet (Orda Pass)
□ Orda Market (каталог)
□ Orda Pay (внутренний баланс + Kaspi)
□ Достижения + реферальная программа
□ Бронирование станций (Arena)
□ APNs Push Notifications
```

### Фаза 4 (3-4 недели):
```
□ Smart Notifications
□ Голосовые заметки
□ Broadcast сообщения
□ Spotlight Search
□ Siri App Intents
□ Operator Feed
```

### Фаза 5 — Electron:
```
□ Калькулятор смены улучшен
□ Штрихкод + быстрая продажа
□ Offline режим полный
□ Arena управление улучшено
□ Inventory запросы улучшены
```

### Фаза 6 — Web:
```
□ Недостающие страницы
□ Excel экспорт
□ Kanban задачи
□ Telegram бот расширен
□ Аналитика клиентской базы
```

### БД (по мере необходимости):
```
□ shift_swap_requests
□ client_achievements
□ client_referrals
□ client_balance + transactions
□ operator_feed + likes
□ device_push_tokens
□ station_bookings
□ smart_alerts
```

---

*Документ обновлять при закрытии каждого пункта.*
*Версия: 1.0 | Дата: Апрель 2026*
