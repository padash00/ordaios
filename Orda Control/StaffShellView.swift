import SwiftUI
import Combine
import Charts

struct StaffRootView: View {
    var body: some View {
        StaffShellView()
    }
}

struct StaffShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @State private var selectedTab: StaffTab = .dashboard

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var staffRole: String {
        (sessionStore.roleContext?.staffRole ?? "").lowercased()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if ModuleAccessMatrix.isVisible(.dashboard, role: sessionStore.roleContext) {
                NavigationStack {
                    StaffDashboardView()
                }
                .tabItem { Label("Панель", systemImage: "rectangle.3.group") }
                .tag(StaffTab.dashboard)
            }

            if ModuleAccessMatrix.isVisible(.finance, role: sessionStore.roleContext) {
                NavigationStack {
                    StaffFinanceView(service: AdminContractsService(apiClient: sessionStore.apiClient))
                }
                .tabItem { Label("Финансы", systemImage: "banknote") }
                .tag(StaffTab.finance)
            }

            if capabilities.contains(.adminClientBookingsReview) || capabilities.contains(.adminClientSupportReview) {
                NavigationStack {
                    StaffClientsView(
                        contractsService: AdminContractsService(apiClient: sessionStore.apiClient),
                        bookingsService: AdminClientBookingsService(apiClient: sessionStore.apiClient),
                        supportService: AdminClientSupportService(apiClient: sessionStore.apiClient),
                        capabilities: capabilities
                    )
                }
                .tabItem { Label("Клиенты", systemImage: "person.2") }
                .tag(StaffTab.bookings)
            }

            if capabilities.contains(.adminShiftsRead) || capabilities.contains(.adminTasksRead) || capabilities.contains(.adminOperatorsRead) || capabilities.contains(.adminPOSRead) {
                NavigationStack {
                    StaffOperationsView(service: AdminContractsService(apiClient: sessionStore.apiClient), capabilities: capabilities)
                }
                .tabItem { Label("Операции", systemImage: "briefcase") }
                .tag(StaffTab.operations)
            }

            StaffMoreTabView(
                service: AdminContractsService(apiClient: sessionStore.apiClient)
            )
            .tabItem { Label("Ещё", systemImage: "ellipsis.circle") }
            .tag(StaffTab.profile)
        }
        .onAppear {
            selectedTab = StaffTab.from(
                defaultPath: sessionStore.roleContext?.defaultPath,
                capabilities: capabilities, staffRole: staffRole
            )
        }
        .onChange(of: quickHub.navigationEvent) { _, new in
            guard let new else { return }
            if case .staff(let tab) = new {
                selectedTab = tab
            }
            Task { @MainActor in quickHub.clearNavigation() }
        }
        .tint(AppTheme.Colors.accentPrimary)
    }

    private var visibleFinanceModules: [AppModule] {
        [.income, .expense, .analytics, .payroll, .taxes]
            .filter { ModuleAccessMatrix.isVisible($0, role: sessionStore.roleContext) }
    }
}

// MARK: - Staff Dashboard (rich)
private struct StaffDashboardView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var dashboard: AdminDashboardPayload = .empty
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var staffP0Unlocked: Bool {
        capabilities.contains(.adminInventoryRead) || capabilities.contains(.adminStoreRead)
            || capabilities.contains(.adminPOSRead) || capabilities.contains(.adminPointRead)
    }

    private var staffAnalyticsUnlocked: Bool {
        capabilities.contains(.adminReportsRead) && capabilities.contains(.adminKPIRead)
    }

    /// Не запрашиваем сводку с оборотом и не показываем тренд (роли без права видеть агрегированные суммы на панели).
    private var suppressFinanceDashboardLoad: Bool {
        let r = (sessionStore.roleContext?.staffRole ?? "").lowercased()
        return r == "marketer" || r == "manager"
    }

    private var isMarketerRole: Bool {
        (sessionStore.roleContext?.staffRole ?? "").lowercased() == "marketer"
    }

    private var dashboardTitle: String {
        isMarketerRole ? "Панель маркетолога" : "Панель сотрудника"
    }

    private var dashboardFinanceHiddenMessage: String {
        if isMarketerRole {
            return "Здесь только задачи, клиенты и просмотр смен — без оборота и графиков. Детали по броням и поддержке — вкладка «Клиенты», график смен — «Операции»."
        }
        return "Сводка по выручке и тренд на этой панели скрыты для вашей роли. Откройте нужный раздел внизу или на вкладках «Финансы» / «Операции» — там доступно то, что разрешено матрицей прав."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Header
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accentBlue)
                        .padding(10)
                        .background(AppTheme.Colors.accentBlue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dashboardTitle)
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        HStack(spacing: 6) {
                            StatusBadge(text: staffRoleLabel, style: .info)
                            if let path = sessionStore.roleContext?.defaultPath {
                                Text(path)
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.Colors.headerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.Colors.accentBlue.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(AppTheme.Spacing.xl)
                } else if let error = errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await loadDashboard() } })
                } else {
                    if suppressFinanceDashboardLoad {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text(dashboardFinanceHiddenMessage)
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard()
                    } else {
                        // KPI tiles
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.xs) {
                            StatTile(title: "ОБОРОТ СЕГОДНЯ", value: MoneyFormatter.short(dashboard.today.total),
                                     color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                            StatTile(title: "ТРАНЗАКЦИЙ", value: "\(dashboard.today.count)",
                                     color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                            StatTile(title: "МЕСЯЦ", value: MoneyFormatter.short(dashboard.monthTotal),
                                     color: AppTheme.Colors.accentPrimary, bgColor: AppTheme.Colors.accentSoft, borderColor: AppTheme.Colors.accentPrimary.opacity(0.2))
                            StatTile(title: "ИЗМЕНЕНИЕ", value: changeText,
                                     color: changePositive ? AppTheme.Colors.success : AppTheme.Colors.error,
                                     bgColor: changePositive ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg,
                                     borderColor: changePositive ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder)
                        }

                        // Trend chart
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            SectionHeader(title: "Тренд за период", icon: "chart.xyaxis.line", iconColor: AppTheme.Colors.accentBlue)

                            if weekTrendData.isEmpty {
                                Text("Пока нет данных")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                                    .frame(maxWidth: .infinity, minHeight: 160)
                            } else {
                                Chart(weekTrendData, id: \.date) { point in
                                    AreaMark(
                                        x: .value("Дата", point.date),
                                        y: .value("Оборот", point.total)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.accentBlue.opacity(0.3), AppTheme.Colors.accentBlue.opacity(0.0)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Дата", point.date),
                                        y: .value("Оборот", point.total)
                                    )
                                    .foregroundStyle(AppTheme.Colors.accentBlue)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    .interpolationMethod(.catmullRom)
                                }
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
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

                    // Quick nav
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Навигация", icon: "arrow.right.circle", iconColor: AppTheme.Colors.accentPrimary)

                        NavigationLink {
                            AdminModuleDirectoryView(
                                service: AdminContractsService(apiClient: sessionStore.apiClient),
                                includeAccountFooter: false,
                                audience: .staff,
                                catalogNavigationTitle: "Разделы"
                            )
                        } label: {
                            navRow(icon: "square.grid.2x2.fill", title: "Все разделы", color: AppTheme.Colors.accentPrimary)
                        }
                        if staffP0Unlocked {
                            NavigationLink {
                                P0ModulesHubView()
                            } label: {
                                navRow(icon: "shippingbox", title: "Операции склада/POS", color: AppTheme.Colors.accentBlue)
                            }
                        }
                        if staffAnalyticsUnlocked {
                            NavigationLink {
                                AdminAnalyticsView(service: AdminAnalyticsService(apiClient: sessionStore.apiClient))
                            } label: {
                                navRow(icon: "brain.head.profile", title: "Аналитика и AI", color: AppTheme.Colors.purple)
                            }
                        }
                    }
                    .appCard()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Панель")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await loadDashboard() }
        .refreshable { await loadDashboard() }
    }

    @ViewBuilder
    private func navRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .padding(.vertical, 4)
    }

    private var weekTrendData: [(date: String, total: Double)] {
        dashboard.weekByDay.map { (date: $0.key, total: $0.value) }.sorted { $0.date < $1.date }
    }

    private var staffRoleLabel: String {
        switch (sessionStore.roleContext?.staffRole ?? "").lowercased() {
        case "owner": return "Owner"
        case "manager": return "Manager"
        case "marketer": return "Marketer"
        default: return "Staff"
        }
    }

    private var changeText: String {
        guard let p = dashboard.changePercent else { return "—" }
        return String(format: "%@%.0f%%", p >= 0 ? "+" : "", p)
    }

    private var changePositive: Bool {
        (dashboard.changePercent ?? 0) >= 0
    }

    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        if suppressFinanceDashboardLoad {
            dashboard = .empty
            return
        }
        do {
            let service = AdminContractsService(apiClient: sessionStore.apiClient)
            dashboard = try await service.loadDashboard()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Staff Finance View
private struct StaffFinanceView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AdminModuleDirectoryView(
                        service: service,
                        includeAccountFooter: false,
                        audience: .staff,
                        catalogNavigationTitle: "Разделы"
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
                            Text("Каталог модулей по вашему доступу")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminIncomesRead) {
                finRow("Доходы", sub: "История выручки", icon: "arrow.up.circle.fill", color: AppTheme.Colors.success) { AnyView(AdminIncomesModuleView(service: service)) }
            }
            if capabilities.contains(.adminExpensesRead) {
                finRow("Расходы", sub: "Затраты и категории", icon: "arrow.down.circle.fill", color: AppTheme.Colors.error) { AnyView(AdminExpensesModuleView(service: service)) }
            }
            if capabilities.contains(.adminReportsRead) {
                finRow("Зарплата", sub: "Начисления", icon: "banknote.fill", color: AppTheme.Colors.success) { AnyView(AdminSalaryModuleView(service: service)) }
                finRow("P&L", sub: "Прибыль и убытки", icon: "chart.line.uptrend.xyaxis.circle.fill", color: AppTheme.Colors.purple) { AnyView(AdminProfitabilityView(service: service)) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Финансы")
    }

    @ViewBuilder
    private func finRow(_ title: String, sub: String, icon: String, color: Color, dest: () -> AnyView) -> some View {
        NavigationLink(destination: dest()) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 44, height: 44).background(color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(sub).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                }
            }.padding(.vertical, 6)
        }
        .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
        .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
    }
}

// MARK: - Staff Clients View
private struct StaffClientsView: View {
    let contractsService: AdminContractsServicing
    let bookingsService: AdminClientBookingsServicing
    let supportService: AdminClientSupportServicing
    let capabilities: Set<AppCapability>

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AdminModuleDirectoryView(
                        service: contractsService,
                        includeAccountFooter: false,
                        audience: .staff,
                        catalogNavigationTitle: "Разделы"
                    )
                } label: {
                    rowItem("Все разделы", sub: "Каталог по вашему доступу", icon: "square.grid.2x2.fill", color: AppTheme.Colors.accentPrimary)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminClientBookingsReview) {
                NavigationLink(destination: AdminClientBookingsView(
                    viewModel: AdminClientBookingsViewModel(
                        service: bookingsService,
                        canSetStatus: capabilities.contains(.adminClientBookingsSetStatus)
                    )
                )) {
                    rowItem("Бронирования", sub: "Заявки и статусы", icon: "calendar", color: AppTheme.Colors.accentBlue)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminClientSupportReview) {
                NavigationLink(destination: AdminClientSupportView(
                    viewModel: AdminClientSupportViewModel(
                        service: supportService,
                        canSetStatus: capabilities.contains(.adminClientSupportSetStatus)
                    )
                )) {
                    rowItem("Поддержка", sub: "Обращения клиентов", icon: "message.fill", color: AppTheme.Colors.warning)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Клиенты")
    }

    @ViewBuilder
    private func rowItem(_ title: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
                .frame(width: 44, height: 44).background(color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.Colors.textPrimary)
                Text(sub).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            }
        }.padding(.vertical, 6)
    }
}

// MARK: - Staff Operations View
private struct StaffOperationsView: View {
    let service: AdminContractsServicing
    let capabilities: Set<AppCapability>

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AdminModuleDirectoryView(
                        service: service,
                        includeAccountFooter: false,
                        audience: .staff,
                        catalogNavigationTitle: "Разделы"
                    )
                } label: {
                    rowItem("Все разделы", sub: "Каталог по вашему доступу", icon: "square.grid.2x2.fill", color: AppTheme.Colors.accentPrimary)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminShiftsRead) {
                NavigationLink(destination: AdminShiftsModuleView(service: service)) {
                    rowItem("Смены", sub: "Расписание и назначения", icon: "clock.fill", color: AppTheme.Colors.accentBlue)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminTasksRead) {
                NavigationLink(destination: AdminTasksModuleView(service: service)) {
                    rowItem("Задачи", sub: "Поручения и статусы", icon: "checklist", color: AppTheme.Colors.warning)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminOperatorsRead) {
                NavigationLink(destination: AdminOperatorsModuleView(service: service)) {
                    rowItem("Операторы", sub: "Сотрудники", icon: "person.2.fill", color: AppTheme.Colors.purple)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
            }
            if capabilities.contains(.adminPOSRead) || capabilities.contains(.adminStoreRead) || capabilities.contains(.adminPointRead) {
                NavigationLink(destination: P0ModulesHubView()) {
                    rowItem("P0 Операции", sub: "POS, склад, терминал", icon: "shippingbox.fill", color: AppTheme.Colors.cashColor)
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

    @ViewBuilder
    private func rowItem(_ title: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
                .frame(width: 44, height: 44).background(color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.Colors.textPrimary)
                Text(sub).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            }
        }.padding(.vertical, 6)
    }
}

// MARK: - Staff «Ещё»: нативный каталог + профиль (как у супер-админа, с фильтром audience)

private struct StaffMoreTabView: View {
    let service: AdminContractsServicing

    var body: some View {
        AdminModuleDirectoryView(service: service, includeAccountFooter: true, audience: .staff)
    }
}
