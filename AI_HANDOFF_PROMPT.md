# Orda Control iOS App — AI Handoff Prompt

You are continuing work on an iOS app called **Orda Control**. This is a native SwiftUI iOS client for a comprehensive business management web platform called **Orda Point** (f16finance). The web app is fully built and deployed at `https://www.ordaops.kz`. The iOS app connects to the same backend API.

---

## PROJECT CONTEXT

### What is Orda Point?
A multi-location business management system for Kazakhstan market. It manages:
- **Finance**: incomes, expenses, profit/loss, cashflow, profitability
- **Shifts**: day/night shift scheduling, weekly publication, operator confirmation via Telegram
- **Salary**: weekly payroll calculation (base 8000₸/shift), KPI bonuses, fines, debts
- **Tasks**: Kanban-style task management with status lifecycle
- **Operators**: workforce management, profiles, ratings, analytics
- **Inventory**: products, barcodes, stock, receipts, transfers, writeoffs, ABC analysis
- **POS**: point-of-sale, sales, returns, receipts
- **Arena**: venue zone booking with tariffs
- **Customers**: loyalty, bookings, support tickets
- **AI**: OpenAI-powered financial analysis, forecasts, weekly reports
- **Telegram**: bot notifications for shifts, tasks, reports

### Tech Stack
- **Web**: Next.js 16, React 19, TypeScript, Tailwind CSS, Radix UI/shadcn, Recharts, Supabase (PostgreSQL + Auth), OpenAI API
- **iOS**: SwiftUI, Swift Charts, MVVM, URLSession-based APIClient, Keychain for session
- **Backend**: All business logic runs through Next.js API routes at `https://www.ordaops.kz/api/*`
- **Auth**: Supabase Auth (email+password), session tokens stored in Keychain, auto-refresh on 401

### Repository Locations
- **Web source** (reference): cloned at `/tmp/f16finance` (or GitHub `https://github.com/padash00/f16finance`)
- **iOS project**: `/Users/arystanbekkeneskanov/Desktop/orda/Orda Control/`
- **Xcode project**: `Orda Control.xcodeproj`
- **Source files**: `Orda Control/Orda Control/` directory
- **Build target**: iOS 26.2+, simulator `iPhone 17 Pro` (x86_64)

### Role System (4 personas)
1. **`super_admin`** — full access to everything, can switch organizations
2. **`staff`** — sub-roles: `owner`, `manager`, `marketer`, `other` — each with different module/capability access
3. **`operator`** — shift workers: dashboard, tasks, shifts
4. **`customer`** — client-facing: home, bookings, points, support

The iOS app resolves the user's persona via `GET /api/auth/session-role` after login and routes to the correct shell (Admin/Staff/Operator/Client) with role-based tab visibility.

---

## WHAT HAS BEEN DONE (Phase 1: Design System + Shell UX Rewrite)

### 1. Design System — `Shared/Design/AppTheme.swift`
Completely rewritten to match the web app's CSS variables from `globals.css`:
- **Background colors**: `#07101A` (bgPrimary), `#0A0F18` (bgSecondary), `rgba(13,22,35,0.82)` (surfacePrimary)
- **Brand colors**: `#FFB36B` (accentPrimary/amber), `#5F8CFF` (accentBlue), `#8B5CF6` (purple)
- **Semantic colors with bg/border variants**: success (`#10B981`), warning (`#F59E0B`), error (`#EF4444`), info (`#3B82F6`), purple (`#8B5CF6`) — each has `.successBg` (10% opacity), `.successBorder` (20% opacity) etc.
- **Chart palette**: chart1-chart5 matching web `--chart-1` through `--chart-5`
- **Payment method colors**: cashColor (`#F59E0B`), kaspiColor (`#2563EB`), cardColor (`#7C3AED`), onlineColor (`#EC4899`)
- **Gradients**: `cardGradient`, `headerGradient` (purple-to-blue like web dashboard header)
- **Typography**: added `monoLarge`, `monoBody`, `monoCaption` for number displays, `micro` for uppercase labels, `captionBold`
- **New modifiers**: `GlassCardStyle` (blur + translucent), updated `AppCardStyle` with stronger shadows
- **`Color(hex:)` extension** for hex color init

### 2. UI Components — `Shared/Design/AppComponents.swift`
12 new reusable components matching web patterns:
- **`MetricCard`** — matches web's `MetricCard`: icon in colored rounded square, value in mono font, optional % change with arrow, selectable state with ring highlight
- **`StatTile`** — compact KPI tile for grids: uppercase micro title with tracking, mono value, colored bg+border (like web's "Пульс бизнеса" tiles)
- **`StatusBadge`** — pill badge with styles: `.excellent` (green), `.good` (purple), `.warning` (amber), `.critical` (red), `.neutral`, `.info`, `.custom(color:)`
- **`SectionHeader`** — icon in colored rounded square + title text (like web card headers with Lucide icons)
- **`AppProgressBar`** — thin colored bar on dark track (for payment method breakdown)
- **`QuickRangePicker`** — horizontal scrollable buttons like web's "Сегодня/Неделя/Месяц" with purple selected state
- **`SegmentedTabBar<T>`** — generic tab bar like web's "Обзор/Детали/Прогноз" tabs
- **`AlertBanner`** — warning/error banner with icon, text, action, dismiss (like web's overdue tasks banner)
- **`AppSearchBar`** — search field with magnifying glass icon and clear button
- **`DataTableRow`** — multi-column row with label/value/color for table-like layouts
- **`MoneyFormatter`** — `.short()` (тыс/млн ₸), `.detailed()` (full number ₸), `.percentChange(current:previous:)`
- **`GhostButtonStyle`** — secondary button with subtle bg and border
- Updated `PrimaryButtonStyle` with gradient (amber→orange) and shadow
- Updated `SecondaryChip`

### 3. SuperAdmin Dashboard — `AdminShellView.swift`
Completely rewritten to look like the web dashboard:
- **Header card**: gradient background (purple→blue), brain icon in purple square, title, StatusBadge showing financial status
- **Pulse card** ("Пульс бизнеса сегодня"): 6 StatTiles in 2-column grid (выручка, наличные, kaspi, карта, транзакции, онлайн) with purple glow circle effect in corner
- **Metric cards**: MetricCard for today's turnover with % change, yesterday, month
- **Trend chart**: Swift Charts `AreaMark` + `LineMark` + `PointMark` with catmullRom interpolation, gradient fill, styled axes with MoneyFormatter
- **Payment breakdown**: horizontal progress bars for each payment method (cash/kaspi/card/online) with colored dots, amounts, percentages
- **Quick actions**: navigation links with icons in colored squares, subtitles, chevrons
- **Organizations view**: cards with building icon, organization name, active badge
- **Access view**: role cards with status badges, default path in mono font
- Removed the old `SuperAdminTab.operations` tab (was duplicate of finance)
- Pull-to-refresh support

### 4. Staff Dashboard — `StaffShellView.swift`
Rewritten:
- Header with key icon, role badge (Owner/Manager/Marketer), default path
- 4 StatTiles: turnover today, transactions, month total, % change
- Trend chart with blue accent (AreaMark + LineMark)
- Navigation section with colored icon rows
- Pull-to-refresh

### 5. Operator Shell — `OperatorShellView.swift`
Rewritten:
- **Dashboard**: avatar circle with gradient and initials, name + role badge, 4 StatTiles (open tasks, shifts this week, done tasks, role), info card
- **Tasks**: card-based layout with StatusBadge per task, colored action capsule buttons (accept=green, need_info=amber, blocked=red, complete=purple), comment field
- **Shifts**: day/night icon (sun/moon), shift date, status badge, styled confirm button (green bg+border), report issue button
- Pull-to-refresh on all views

### 6. Profile — `ShellTabModels.swift`
Rewritten:
- Gradient avatar circle with initials (purple→blue gradient)
- Role label, persona badge
- Info section with SectionHeader, mono-font values
- Styled logout button (red bg+border, rectangle.portrait.and.arrow.right icon)
- NoAccessView with lock.shield icon

### 7. State Views — `Shared/UI/StateViews.swift`
Updated:
- `LoadingStateView`: large ProgressView with purple tint
- `EmptyStateView`: tray icon + message
- `ErrorStateView`: triangle icon, styled retry button with red bg+border

---

## WHAT STILL NEEDS TO BE DONE

### Phase 2: Rewrite remaining view UIs (HIGH PRIORITY)

These views exist but have basic/ugly UI. They need the same rich treatment as the dashboard:

#### 2a. `Features/Admin/AdminContractsViews.swift` (~500 lines)
This is the biggest file. Contains views for: Incomes, Expenses, Shifts, Tasks, Operators, Customers.

**What each needs:**
- **AdminIncomesModuleView**: Currently a plain List. Needs:
  - `SectionHeader` with chart icon
  - Summary MetricCards at top (total income, avg check, count)
  - `AppSearchBar` for filtering
  - Proper table rows with `DataTableRow` showing date, company, operator, amounts by payment method in colored text (cash=amber, kaspi=blue, card=purple, online=pink)
  - Payment method totals bar chart (Swift Charts `BarMark`)
  - Better create form in sheet with styled inputs
  - Keep existing pagination logic but style the controls

- **AdminExpensesModuleView**: Same pattern as incomes but for expenses:
  - Category badges with colors
  - Expense amount in red
  - Summary cards

- **AdminShiftsModuleView**: Currently basic. Needs:
  - Week picker at top
  - Shift grid/calendar view showing day/night icons
  - Publication status badges (draft/published/confirmed)
  - Issue cards with warning styling
  - Buttons for save/publish/resolve styled with component library

- **AdminTasksModuleView**: Currently a plain list. Needs:
  - Status-grouped sections or Kanban-like columns (backlog/todo/in_progress/review/done)
  - Priority badges (high=red, medium=amber, low=blue)
  - Task cards with title, assignee, due date, status actions
  - Create form with priority picker, assignee picker

- **AdminOperatorsModuleView**: Currently a list. Needs:
  - Avatar circles with initials
  - Active/inactive toggle with green/gray badge
  - Profile drill-down with NavigationLink
  - Operator stats (shifts, tasks, rating)

- **AdminCustomersModuleView**: Currently basic. Needs:
  - Customer cards with name, phone, loyalty points
  - History drill-down showing purchase list
  - Points balance display

#### 2b. `Features/Admin/AdminClientBookingsView.swift`
Admin view for managing client bookings. Needs:
- Booking cards with customer name, time range, status badge
- Status change buttons (confirm/cancel/complete)
- Date filtering

#### 2c. `Features/Admin/AdminClientSupportView.swift`
Admin view for support tickets. Needs:
- Ticket cards with priority badge, message preview
- Status change dropdown
- Severity coloring

#### 2d. `Features/Analytics/AdminAnalyticsView.swift`
Partially OK but needs polish:
- Monthly report card → make it look like web with MetricCards
- KPI chart → already has Chart but needs styled axes
- Goals card → add progress bars
- AI forecast/analysis cards → better formatting of AI text
- Period controls → use `QuickRangePicker` component

#### 2e. `Features/P0/P0Modules.swift` (~800 lines, huge file)
Contains all Store/POS/Point views. All need rich UI:
- **Store Overview**: inventory summary with MetricCards, low stock alerts
- **POS Receipts**: receipt list with amounts, payment badges
- **POS Sale form**: product picker, payment method selector
- **Point Reports**: shift reports with charts
- **Store operations** (receipts, writeoffs, revisions, movements): proper table layouts
- **Point Debts, Products**: CRUD with styled forms

#### 2f. Client views
- **`Features/Home/HomeView.swift`**: Client dashboard — needs welcome card, recent bookings, points balance
- **`Features/Bookings/BookingsView.swift`**: Booking list with status badges, time display
- **`Features/Points/PointsView.swift`**: Points balance, history, progress toward reward
- **`Features/Support/SupportView.swift`**: Ticket list with status, create form

#### 2g. Auth views
- **`Features/Auth/LoginView.swift`**: Needs gradient background like web landing, amber login button, styled inputs, Orda Control branding
- **`Features/Onboarding/RegistrationViews.swift`**: Sign up flow, email confirmation, company selection — needs polished UI

### Phase 3: Missing modules (NEW CODE needed)

These modules exist on the web but have NO iOS implementation yet:

1. **Salary module**: `GET/POST /api/admin/salary`, `/api/admin/salary-rules`
   - Weekly salary board (all operators)
   - Per-operator salary detail with 12-week history chart
   - Salary rules configuration
   - Adjustments (debts, fines, bonuses, advances)
   - Payment processing

2. **Profitability / P&L / EBITDA / Cashflow**: `/api/admin/profitability`
   - Revenue vs expense charts
   - Margin calculations
   - Kaspi commission tracking

3. **Arena module**: `/api/admin/arena`, `/api/point/arena`
   - Zone/station management
   - Tariff configuration
   - Session tracking with timer
   - Analytics

4. **Inventory catalog deep views**: `/api/admin/inventory/catalog`, `/abc`, `/forecast`
   - Full product catalog with barcode
   - ABC analysis charts
   - Stock forecast
   - Consumables tracking

5. **Operator-side views**:
   - Schedule calendar
   - Achievements/badges
   - Chat with admin
   - Salary view (operator sees their own salary)
   - Settings

6. **System views**:
   - Settings page
   - Organizational structure
   - Tax configuration
   - Telegram bot setup
   - Audit logs
   - Staff account management

---

## ARCHITECTURE GUIDE

### File structure
```
Orda Control/
├── Core/
│   ├── Auth/          — SessionStore, AuthService, BackendSessionVerifier, KeychainStorage
│   ├── Config/        — AppConfig (API URL, Supabase keys)
│   ├── Networking/    — APIClient, APIEndpoint, APIError, GeneratedContracts
│   ├── Registration/  — RegistrationService, Models
│   ├── Role/          — AppShellResolver, CapabilityMatrix, ModuleAccessMatrix
│   └── Security/      — KeychainStorage
├── Features/
│   ├── Admin/         — AdminContractsService/Views/ViewModels, Bookings, Support
│   ├── Analytics/     — AdminAnalyticsService/View/ViewModel/Models
│   ├── Auth/          — LoginView/ViewModel
│   ├── Bookings/      — Client bookings
│   ├── Home/          — Client home
│   ├── Onboarding/    — Registration flow
│   ├── Operator/      — OperatorModules (service + VMs + models)
│   ├── P0/            — P0Modules (Store, POS, Point)
│   ├── Points/        — Client loyalty points
│   └── Support/       — Client support
├── Models/            — AdminModels, ClientModels, GeneratedContractDTOs
├── Shared/
│   ├── Design/        — AppTheme, AppComponents, Haptics
│   ├── UI/            — StateViews
│   └── Utils/         — Date+Formatters
├── AdminShellView.swift      — AdminRootView, SuperAdmin dashboard
├── StaffShellView.swift      — Staff dashboard
├── OperatorShellView.swift   — Operator dashboard, tasks, shifts
├── ClientShellView.swift     — Routes to MainTabView
├── MainTabView.swift         — Client tab bar
├── AppRootView.swift         — Root router (auth → onboarding → shell)
├── ShellTabModels.swift      — Tab enums, ProfileRoleView, NoAccessView
└── Orda_ControlApp.swift     — @main entry point
```

### Key patterns
1. **MVVM**: Each feature has Service (protocol + impl) → ViewModel (@MainActor ObservableObject) → View
2. **APIClient**: Generic `request<T: Decodable>(_ endpoint:)` with auto token injection, 401 refresh, error mapping
3. **Capability-based access**: `CapabilityMatrix.capabilities(for: role) -> Set<AppCapability>` controls what UI elements are shown
4. **Module visibility**: `ModuleAccessMatrix.isVisible(.module, role:)` controls tab/section visibility
5. **Service protocols**: All services have protocols for testability (e.g., `AdminContractsServicing`, `OperatorServicing`)

### API patterns
- All endpoints are at `https://www.ordaops.kz/api/...`
- Auth header: `Bearer <supabase_access_token>`
- Response format: usually `{ ok: true, data: ... }` or `{ data: [...] }`
- POST actions use `{ action: "actionName", payload: {...} }` pattern
- Snake_case from server, decoded with `.convertFromSnakeCase`

### Design patterns to follow
When creating new views, use these components:
- Headers: `SectionHeader(title:icon:iconColor:)` 
- Cards: `.appCard()` modifier
- Stats: `StatTile(title:value:color:bgColor:borderColor:)` in `LazyVGrid`
- Metrics: `MetricCard(label:value:icon:change:changePositive:color:)`
- Status: `StatusBadge(text:style:)`
- Money: `MoneyFormatter.short()` or `.detailed()`
- Charts: Swift Charts with `AreaMark` + `LineMark`, styled axes, `AppTheme.Colors` palette
- Backgrounds: always `AppTheme.Colors.bgPrimary.ignoresSafeArea()`
- Pull-to-refresh: `.refreshable { await vm.load() }`
- Navigation: `NavigationLink` with chevron rows

### Color rules
- Positive values / success → `AppTheme.Colors.success` (green)
- Negative values / errors → `AppTheme.Colors.error` (red)
- Warnings → `AppTheme.Colors.warning` (amber)
- Info / neutral → `AppTheme.Colors.info` (blue) or `.accentBlue`
- Primary brand → `AppTheme.Colors.accentPrimary` (amber)
- Charts / highlights → `AppTheme.Colors.purple`
- Payment: cash=`.cashColor`, kaspi=`.kaspiColor`, card=`.cardColor`, online=`.onlineColor`
- Numbers always in mono font: `.monoLarge`, `.monoBody`, `.monoCaption`
- Uppercase labels: `.micro` font with `.tracking(1.5)`

---

## KNOWN ISSUES

1. **Dashboard shows zeros**: The `/api/admin/dashboard` endpoint queries `point_sales` table. If there are no sales for today, everything shows 0. This is expected behavior — not a bug. The web app has the same behavior (shows zero when no data).

2. **Build simulator**: Use `iPhone 17 Pro` destination (x86_64). The project uses iOS 26.2 SDK.

3. **Tests**: There are test files in `Orda ControlTests/` — some may need updating after the UI changes but they test ViewModels and API parity, not UI directly.

4. **The `AdminContractsViews.swift` and `P0Modules.swift` files are very large** (500-800+ lines each). When rewriting, consider splitting into separate files per view if they exceed ~400 lines.

5. **Deferred (important): task photo storage**. Current iOS operator task photo flow sends image as base64 inside comment text payload. This should be migrated to Supabase Storage (bucket + signed/public URL), with only URL/metadata stored in DB comments. Add server-side MIME/size validation and keep iOS compression before upload.

---

## BUILD & RUN

```bash
cd "/Users/arystanbekkeneskanov/Desktop/orda/Orda Control"
xcodebuild -project "Orda Control.xcodeproj" -scheme "Orda Control" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The project has NO external dependencies (no SPM, no CocoaPods). Everything is built-in (SwiftUI, Swift Charts, Foundation).
