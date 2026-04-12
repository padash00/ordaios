import SwiftUI
import Combine
import Charts

struct AdminRootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    private var isSuperAdmin: Bool {
        let persona = (sessionStore.roleContext?.persona ?? "").lowercased()
        return sessionStore.roleContext?.isSuperAdmin == true || persona == "super_admin"
    }

    var body: some View {
        if isSuperAdmin {
            SuperAdminShellView()
        } else {
            AdminShellView()
        }
    }
}

struct AdminShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @State private var selectedTab: AdminTab = .bookings

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                if capabilities.contains(.adminClientBookingsReview) {
                    AdminClientBookingsView(
                        viewModel: AdminClientBookingsViewModel(
                            service: AdminClientBookingsService(apiClient: sessionStore.apiClient),
                            canSetStatus: capabilities.contains(.adminClientBookingsSetStatus)
                        )
                    )
                } else {
                    NoPermissionInlineView()
                }
            }
            .tabItem { Label("Брони", systemImage: "calendar") }
            .tag(AdminTab.bookings)

            NavigationStack {
                if capabilities.contains(.adminClientSupportReview) {
                    AdminClientSupportView(
                        viewModel: AdminClientSupportViewModel(
                            service: AdminClientSupportService(apiClient: sessionStore.apiClient),
                            canSetStatus: capabilities.contains(.adminClientSupportSetStatus)
                        )
                    )
                } else {
                    NoPermissionInlineView()
                }
            }
            .tabItem { Label("Поддержка", systemImage: "message") }
            .tag(AdminTab.support)

            NavigationStack { ProfileRoleView() }
            .tabItem { Label("Профиль", systemImage: "person") }
            .tag(AdminTab.profile)
        }
        .onAppear {
            selectedTab = AdminTab.from(defaultPath: sessionStore.roleContext?.defaultPath)
        }
        .onChange(of: quickHub.navigationEvent) { _, new in
            guard let new else { return }
            if case .admin(let tab) = new {
                selectedTab = tab
            }
            Task { @MainActor in quickHub.clearNavigation() }
        }
        .tint(AppTheme.Colors.accentPrimary)
    }
}

// MARK: - SuperAdmin Shell
private struct SuperAdminShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @State private var selectedTab: SuperAdminTab = .dashboard

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var analyticsTabUnlocked: Bool {
        capabilities.contains(.adminReportsRead) && capabilities.contains(.adminKPIRead)
    }

    private var service: AdminContractsServicing {
        AdminContractsService(apiClient: sessionStore.apiClient)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Dashboard
            NavigationStack {
                SuperAdminDashboardView(service: service)
            }
            .tabItem { Label("Панель", systemImage: "rectangle.3.group") }
            .tag(SuperAdminTab.dashboard)

            // 2. Финансы — прямые разделы без хаба
            NavigationStack {
                SuperAdminFinanceView(service: service)
            }
            .tabItem { Label("Финансы", systemImage: "banknote") }
            .tag(SuperAdminTab.finance)

            // 3. Операции — смены, задачи, команда, P0
            NavigationStack {
                SuperAdminOperationsView(service: service)
            }
            .tabItem { Label("Операции", systemImage: "briefcase") }
            .tag(SuperAdminTab.operations)

            if analyticsTabUnlocked {
                NavigationStack {
                    AdminAnalyticsView(service: AdminAnalyticsService(apiClient: sessionStore.apiClient))
                        .navigationTitle("Аналитика")
                }
                .tabItem { Label("Аналитика", systemImage: "chart.xyaxis.line") }
                .tag(SuperAdminTab.analytics)
            }

            // 5. Ещё (профиль, настройки, точки, доступ)
            SuperAdminMoreView(service: service)
            .tabItem { Label("Ещё", systemImage: "ellipsis.circle") }
            .tag(SuperAdminTab.more)
        }
        .onAppear {
            selectedTab = superAdminInitialTab(
                defaultPath: sessionStore.roleContext?.defaultPath,
                capabilities: capabilities
            )
        }
        .onChange(of: quickHub.navigationEvent) { _, new in
            guard let new else { return }
            if case .superAdmin(let tab) = new {
                if tab == .analytics && !analyticsTabUnlocked {
                    Task { @MainActor in quickHub.clearNavigation() }
                    return
                }
                selectedTab = tab
            }
            Task { @MainActor in quickHub.clearNavigation() }
        }
        .tint(AppTheme.Colors.accentPrimary)
    }

    private func superAdminInitialTab(defaultPath: String?, capabilities: Set<AppCapability>) -> SuperAdminTab {
        var tab = SuperAdminTab.from(defaultPath: defaultPath)
        let analyticsOK = capabilities.contains(.adminReportsRead) && capabilities.contains(.adminKPIRead)
        if tab == .analytics && !analyticsOK {
            tab = .dashboard
        }
        return tab
    }
}

// MARK: - SuperAdmin Dashboard (financial, mirrors web dashboard)
private struct SuperAdminDashboardView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: AdminFinanceDashboardViewModel

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var analyticsUnlocked: Bool {
        capabilities.contains(.adminReportsRead) && capabilities.contains(.adminKPIRead)
    }

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminFinanceDashboardViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                headerCard
                periodPicker
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(AppTheme.Spacing.xl)
                        .tint(AppTheme.Colors.purple)
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else {
                    kpiRow
                    SmartAlertsCard(apiClient: sessionStore.apiClient)
                    trendChart
                    paymentBreakdown
                    expenseCategoryChart
                    quickActions
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Дашборд")
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.period) { _, _ in Task { await vm.load() } }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.purple)
                .padding(10)
                .background(AppTheme.Colors.purpleBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.purpleBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text("Финансовый дашборд")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(sessionStore.roleContext?.roleLabel ?? "Супер-администратор")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            Spacer()
            if !vm.isLoading {
                StatusBadge(text: vm.statusText, style: vm.statusStyle)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.headerGradient)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.xl).stroke(AppTheme.Colors.purpleBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }

    // MARK: - Period picker
    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminFinanceDashboardViewModel.Period.allCases, id: \.self) { p in
                    Button(p.label) {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.period = p }
                    }
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(vm.period == p ? .white : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(vm.period == p ? AnyShapeStyle(AppTheme.Colors.purple) : AnyShapeStyle(Color(hex: 0x1F2937)))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(vm.period == p ? AppTheme.Colors.purple.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                    .shadow(color: vm.period == p ? AppTheme.Colors.purple.opacity(0.25) : .clear, radius: 6, y: 2)
                }
            }
        }
    }

    // MARK: - KPI row (income / expense / profit)
    private var kpiRow: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Main metrics
            HStack(spacing: AppTheme.Spacing.xs) {
                MetricCard(label: "Доходы", value: MoneyFormatter.short(vm.totalIncome),
                           icon: "arrow.up.circle.fill", color: AppTheme.Colors.success)
                MetricCard(label: "Расходы", value: MoneyFormatter.short(vm.totalExpense),
                           icon: "arrow.down.circle.fill", color: AppTheme.Colors.error)
            }
            MetricCard(
                label: "Прибыль", value: MoneyFormatter.short(vm.profit),
                icon: "chart.line.uptrend.xyaxis",
                change: String(format: "%.1f%% маржа", vm.margin),
                changePositive: vm.profit >= 0,
                color: vm.profit >= 0 ? AppTheme.Colors.purple : AppTheme.Colors.error
            )
            // Count stats
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.xs) {
                StatTile(title: "ДОХОДЫ", value: "\(vm.incomes.count) записей",
                         color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "РАСХОДЫ", value: "\(vm.expenses.count) записей",
                         color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder)
                StatTile(title: "МАРЖА", value: String(format: "%.1f%%", vm.margin),
                         color: vm.margin > 0 ? AppTheme.Colors.purple : AppTheme.Colors.error,
                         bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder)
            }
        }
    }

    // MARK: - Trend chart (income + expense + profit by day)
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Динамика по дням", icon: "chart.xyaxis.line", iconColor: AppTheme.Colors.purple)

            let data = vm.dailyChartData
            if data.isEmpty {
                Text("Нет данных за выбранный период")
                    .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart {
                    ForEach(data) { point in
                        AreaMark(x: .value("День", point.date), y: .value("Доход", point.income))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.Colors.success.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("День", point.date), y: .value("Доход", point.income))
                            .foregroundStyle(AppTheme.Colors.success)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("День", point.date), y: .value("Расход", point.expense))
                            .foregroundStyle(AppTheme.Colors.error)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("День", point.date), y: .value("Прибыль", point.profit))
                            .foregroundStyle(AppTheme.Colors.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color(hex: 0x374151).opacity(0.5))
                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(MoneyFormatter.short(v)).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.frame(height: 220) }

                // Legend
                HStack(spacing: AppTheme.Spacing.md) {
                    legendDot("Доход", color: AppTheme.Colors.success)
                    legendDot("Расход", color: AppTheme.Colors.error)
                    legendDot("Прибыль", color: AppTheme.Colors.purple)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
        }
    }

    // MARK: - Payment breakdown
    private var paymentBreakdown: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Структура доходов по методу оплаты", icon: "chart.pie.fill", iconColor: AppTheme.Colors.accentPrimary)

            let total = vm.totalIncome
            let methods: [(String, Double, Color)] = [
                ("Наличные", vm.cashIncome, AppTheme.Colors.cashColor),
                ("Kaspi", vm.kaspiIncome, AppTheme.Colors.kaspiColor),
                ("Карта", vm.cardIncome, AppTheme.Colors.cardColor),
                ("Онлайн", vm.onlineIncome, AppTheme.Colors.onlineColor),
            ]

            if total > 0 {
                ForEach(methods, id: \.0) { method in
                    let pct = method.1 / total
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Circle().fill(method.2).frame(width: 8, height: 8)
                        Text(method.0).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 75, alignment: .leading)
                        AppProgressBar(value: pct, color: method.2)
                        Text(MoneyFormatter.short(method.1)).font(AppTheme.Typography.monoCaption).foregroundStyle(.white)
                        Text(String(format: "%.0f%%", pct * 100)).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            } else {
                Text("Нет данных").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .appCard()
    }

    // MARK: - Expense categories bar chart
    private var expenseCategoryChart: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Расходы по категориям", icon: "chart.bar.fill", iconColor: AppTheme.Colors.error)

            let cats = vm.categoryBreakdown
            if cats.isEmpty {
                Text("Нет расходов").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                Chart(cats, id: \.category) { row in
                    BarMark(x: .value("Категория", String(row.category.prefix(14))), y: .value("Сумма", row.amount))
                        .foregroundStyle(AppTheme.Colors.error.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(MoneyFormatter.short(v)).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.frame(height: 180) }
            }
        }
        .appCard()
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        let svc = AdminContractsService(apiClient: sessionStore.apiClient)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Быстрые действия", icon: "bolt.fill", iconColor: AppTheme.Colors.accentPrimary)
            NavigationLink {
                AdminModuleDirectoryView(
                    service: svc,
                    includeAccountFooter: false,
                    audience: .superAdmin,
                    catalogNavigationTitle: "Все разделы"
                )
            } label: {
                quickRow(icon: "square.grid.2x2.fill", title: "Все разделы", subtitle: "Каталог модулей и системы")
            }
            if capabilities.contains(.adminIncomesRead) {
                NavigationLink { AdminIncomesModuleView(service: svc) } label: {
                    quickRow(icon: "arrow.up.circle.fill", title: "Доходы", subtitle: "Добавить или просмотреть")
                }
            }
            if capabilities.contains(.adminExpensesRead) {
                NavigationLink { AdminExpensesModuleView(service: svc) } label: {
                    quickRow(icon: "arrow.down.circle.fill", title: "Расходы", subtitle: "Затраты и категории")
                }
            }
            if capabilities.contains(.adminShiftsRead) {
                NavigationLink { AdminShiftsModuleView(service: svc) } label: {
                    quickRow(icon: "clock.fill", title: "Смены", subtitle: "Расписание на неделю")
                }
            }
            if capabilities.contains(.adminTasksRead) {
                NavigationLink { AdminTasksModuleView(service: svc) } label: {
                    quickRow(icon: "checklist", title: "Задачи", subtitle: "Поручения и статусы")
                }
            }
            if analyticsUnlocked {
                NavigationLink { AdminAnalyticsView(service: AdminAnalyticsService(apiClient: sessionStore.apiClient)) } label: {
                    quickRow(icon: "chart.xyaxis.line", title: "Аналитика", subtitle: "KPI, прогнозы, отчёты")
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func quickRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accentPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Typography.callout).foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.Colors.textMuted)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - SuperAdmin Organizations
struct SuperAdminPointsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var locations: [POSLocation] = []
    @State private var companiesCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var activeLocationsCount: Int {
        locations.filter(\.isActiveResolved).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Summary
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(title: "ТОЧЕК", value: "\(locations.count)",
                             color: AppTheme.Colors.accentPrimary,
                             bgColor: AppTheme.Colors.accentSoft,
                             borderColor: AppTheme.Colors.accentPrimary.opacity(0.25))
                    StatTile(title: "КОМПАНИЙ", value: "\(companiesCount)",
                             color: AppTheme.Colors.info,
                             bgColor: AppTheme.Colors.infoBg,
                             borderColor: AppTheme.Colors.infoBorder)
                    StatTile(title: "АКТИВНЫХ ТОЧЕК", value: "\(activeLocationsCount)",
                             color: AppTheme.Colors.success,
                             bgColor: AppTheme.Colors.successBg,
                             borderColor: AppTheme.Colors.successBorder)
                    if locations.count > activeLocationsCount {
                        StatTile(title: "НЕАКТИВНЫХ", value: "\(locations.count - activeLocationsCount)",
                                 color: AppTheme.Colors.textMuted,
                                 bgColor: AppTheme.Colors.surfaceSecondary.opacity(0.5),
                                 borderColor: AppTheme.Colors.borderSubtle)
                    }
                }
                .appCard()

                // List
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Список точек", icon: "mappin.and.ellipse", iconColor: AppTheme.Colors.accentPrimary)

                    if isLoading {
                        LoadingStateView(message: "Загрузка...")
                    } else if let error = errorMessage {
                        ErrorStateView(message: error, retryAction: { Task { await loadLocations() } })
                    } else if locations.isEmpty {
                        EmptyStateView(message: "Точки не найдены", icon: "mappin.slash")
                    } else {
                        ForEach(locations) { loc in
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                        .fill(AppTheme.Colors.accentSoft)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loc.name)
                                        .font(AppTheme.Typography.headline)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Text("ID: \(loc.id.prefix(12))…")
                                        .font(AppTheme.Typography.micro)
                                        .foregroundStyle(AppTheme.Colors.textMuted)
                                }
                                Spacer()
                                StatusBadge(
                                    text: loc.isActiveResolved ? "Активна" : "Неактивна",
                                    style: loc.isActiveResolved ? .excellent : .neutral
                                )
                            }
                            if loc.id != locations.last?.id {
                                Divider().background(AppTheme.Colors.borderSubtle)
                            }
                        }
                    }
                }
                .appCard()
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Точки")
        .task { await loadLocations() }
        .refreshable { await loadLocations() }
    }

    private func loadLocations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let service = P0ModulesService(apiClient: sessionStore.apiClient)
            let bootstrap = try await service.fetchPOSBootstrap()
            locations = bootstrap.locations
            companiesCount = bootstrap.companies.count
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

// MARK: - SuperAdmin Access
struct SuperAdminAccessView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Роли и доступ", icon: "shield.checkered", iconColor: AppTheme.Colors.purple)
                    .padding(.horizontal, AppTheme.Spacing.md)

                let roles: [(String, Bool, String)] = [
                    ("Супер-админ", sessionStore.roleContext?.isSuperAdmin == true, "crown"),
                    ("Сотрудник", sessionStore.roleContext?.isStaff == true, "person.badge.key"),
                    ("Оператор", sessionStore.roleContext?.isOperator == true, "wrench.and.screwdriver"),
                    ("Клиент", sessionStore.roleContext?.isCustomer == true, "person"),
                ]

                ForEach(roles, id: \.0) { role in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: role.2)
                            .foregroundStyle(role.1 ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
                            .frame(width: 36, height: 36)
                            .background(role.1 ? AppTheme.Colors.successBg : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        Text(role.0)
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        StatusBadge(text: role.1 ? "Да" : "Нет", style: role.1 ? .excellent : .neutral)
                    }
                    .appCard()
                    .padding(.horizontal, AppTheme.Spacing.md)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("МАРШРУТ ПО УМОЛЧАНИЮ")
                            .font(AppTheme.Typography.micro)
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Text(sessionStore.roleContext?.defaultPath ?? "—")
                            .font(AppTheme.Typography.monoBody)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    Spacer()
                }
                .appCard()
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .navigationTitle("Доступ")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

// MARK: - SuperAdmin Finance Tab
// Прямые разделы без хаба-карточек
private struct SuperAdminFinanceView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private struct FinanceSection: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let destination: AnyView
    }

    private func financeSections() -> [FinanceSection] {
        var list: [FinanceSection] = []
        if capabilities.contains(.adminIncomesRead) {
            list.append(FinanceSection(title: "Доходы", subtitle: "История и добавление", icon: "arrow.up.circle.fill", color: AppTheme.Colors.success, destination: AnyView(AdminIncomesModuleView(service: service))))
        }
        if capabilities.contains(.adminExpensesRead) {
            list.append(FinanceSection(title: "Расходы", subtitle: "Затраты по категориям", icon: "arrow.down.circle.fill", color: AppTheme.Colors.error, destination: AnyView(AdminExpensesModuleView(service: service))))
        }
        if capabilities.contains(.adminReportsRead) {
            list.append(FinanceSection(title: "Зарплата", subtitle: "Начисления сотрудникам", icon: "banknote.fill", color: AppTheme.Colors.success, destination: AnyView(AdminSalaryModuleView(service: service))))
            list.append(FinanceSection(title: "P&L", subtitle: "Прибыль и убытки", icon: "chart.line.uptrend.xyaxis.circle.fill", color: AppTheme.Colors.purple, destination: AnyView(AdminProfitabilityView(service: service))))
        }
        if capabilities.contains(.adminIncomesRead) || capabilities.contains(.adminExpensesRead) {
            list.append(FinanceSection(title: "Категории", subtitle: "Статьи расходов и доходов", icon: "tag.fill", color: AppTheme.Colors.accentBlue, destination: AnyView(AdminCategoriesModuleView(service: service))))
        }
        return list
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AdminModuleDirectoryView(
                        service: service,
                        includeAccountFooter: false,
                        audience: .superAdmin,
                        catalogNavigationTitle: "Все разделы"
                    )
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.Colors.accentPrimary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Все разделы")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("Каталог модулей и системы")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            ForEach(financeSections()) { sec in
                NavigationLink(destination: sec.destination) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: sec.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(sec.color)
                            .frame(width: 44, height: 44)
                            .background(sec.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sec.title)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(sec.subtitle)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Финансы")
    }
}

// MARK: - SuperAdmin Operations Tab
private struct SuperAdminOperationsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var p0Unlocked: Bool {
        capabilities.contains(.adminInventoryRead) || capabilities.contains(.adminStoreRead)
            || capabilities.contains(.adminPOSRead) || capabilities.contains(.adminPointRead)
    }

    private struct OpsSection: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let destination: AnyView
    }

    private func operationsSections() -> [OpsSection] {
        var list: [OpsSection] = []
        if capabilities.contains(.adminShiftsRead) {
            list.append(OpsSection(title: "Смены", subtitle: "Расписание и назначения", icon: "clock.fill", color: AppTheme.Colors.accentBlue, destination: AnyView(AdminShiftsModuleView(service: service))))
        }
        if capabilities.contains(.adminTasksRead) {
            list.append(OpsSection(title: "Задачи", subtitle: "Поручения и статусы", icon: "checklist", color: AppTheme.Colors.warning, destination: AnyView(AdminTasksModuleView(service: service))))
        }
        if capabilities.contains(.adminOperatorsRead) {
            list.append(OpsSection(title: "Операторы", subtitle: "Сотрудники и профили", icon: "person.2.fill", color: AppTheme.Colors.purple, destination: AnyView(AdminOperatorsModuleView(service: service))))
        }
        if capabilities.contains(.adminCustomersRead) {
            list.append(OpsSection(title: "Клиенты", subtitle: "База клиентов", icon: "person.3.fill", color: AppTheme.Colors.info, destination: AnyView(AdminCustomersModuleView(service: service))))
        }
        if p0Unlocked {
            list.append(OpsSection(title: "P0 Операции", subtitle: "POS, склад, терминал", icon: "shippingbox.fill", color: AppTheme.Colors.cashColor, destination: AnyView(P0ModulesHubView())))
        }
        return list
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AdminModuleDirectoryView(
                        service: service,
                        includeAccountFooter: false,
                        audience: .superAdmin,
                        catalogNavigationTitle: "Все разделы"
                    )
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.Colors.accentPrimary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Все разделы")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("Финансы, аналитика, сервис, система")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            ForEach(operationsSections()) { sec in
                NavigationLink(destination: sec.destination) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: sec.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(sec.color)
                            .frame(width: 44, height: 44)
                            .background(sec.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sec.title)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(sec.subtitle)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Операции")
    }
}

// MARK: - SuperAdmin More Tab
private struct SuperAdminMoreView: View {
    let service: AdminContractsServicing

    var body: some View {
        AdminModuleDirectoryView(service: service, includeAccountFooter: true, audience: .superAdmin)
    }
}
