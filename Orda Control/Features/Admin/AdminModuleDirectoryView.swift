import SwiftUI

enum AdminDirectoryAudience {
    case superAdmin
    case staff
}

// MARK: - Catalog model

private enum AdminCatalogDestination: Hashable {
    case incomes
    case expenses
    case salary
    case salaryRules
    case profitability
    case categories
    case shifts
    case tasks
    case operators
    case customers
    case storeHub
    case analytics
    case clientBookings
    case clientSupport
    case pointsList
    case pointDevices
    case accessSummary
    case settings
    case webParityHub
    case profile
}

private struct CatalogEntry: Identifiable {
    var id: AdminCatalogDestination { destination }
    let section: String
    let destination: AdminCatalogDestination
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

/// Нативный каталог: группы, поиск; на iPad — `NavigationSplitView` + sidebar.
struct AdminModuleDirectoryView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let service: AdminContractsServicing
    var includeAccountFooter: Bool = false
    var audience: AdminDirectoryAudience = .superAdmin
    /// Заголовок навбара для списка разделов (вкладка «Ещё»).
    var catalogNavigationTitle: String = "Ещё"

    @State private var searchText = ""
    @State private var selectedDestination: AdminCatalogDestination?

    private var caps: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var isSuperAdmin: Bool {
        sessionStore.roleContext?.isSuperAdmin == true
            || (sessionStore.roleContext?.persona ?? "").lowercased() == "super_admin"
    }

    private var analyticsUnlocked: Bool {
        caps.contains(.adminReportsRead) && caps.contains(.adminKPIRead)
    }

    private var p0Unlocked: Bool {
        caps.contains(.adminInventoryRead) || caps.contains(.adminStoreRead)
            || caps.contains(.adminPOSRead) || caps.contains(.adminPointRead)
    }

    private var showPointsList: Bool {
        audience == .superAdmin || caps.contains(.adminPOSRead) || caps.contains(.adminStoreRead)
            || caps.contains(.adminPointRead)
    }

    private var showPointDevices: Bool {
        audience == .superAdmin || ModuleAccessMatrix.isVisible(.pointTerminal, role: sessionStore.roleContext)
    }

    private var showAccessSummary: Bool {
        isSuperAdmin && audience == .superAdmin
    }

    private var showSettings: Bool {
        ModuleAccessMatrix.isVisible(.settings, role: sessionStore.roleContext)
    }

    /// Разделы веб-панели: супер-админ и сотрудники (не оператор/клиент в этом шелле).
    /// Маркетологу не показываем хаб со ссылками на финансовые веб-разделы.
    private var showWebParityHub: Bool {
        let role = (sessionStore.roleContext?.staffRole ?? "").lowercased()
        if role == "marketer" { return false }
        return isSuperAdmin || sessionStore.roleContext?.isStaff == true
    }

    private var catalogEntries: [CatalogEntry] {
        var list: [CatalogEntry] = []

        if caps.contains(.adminIncomesRead) {
            list.append(CatalogEntry(section: "Деньги", destination: .incomes, title: "Доходы", subtitle: "Оборот и записи", icon: "arrow.up.circle.fill", color: AppTheme.Colors.success))
        }
        if caps.contains(.adminExpensesRead) {
            list.append(CatalogEntry(section: "Деньги", destination: .expenses, title: "Расходы", subtitle: "Статьи и списания", icon: "arrow.down.circle.fill", color: AppTheme.Colors.error))
        }
        if caps.contains(.adminReportsRead) {
            list.append(CatalogEntry(section: "Деньги", destination: .salary, title: "Зарплата", subtitle: "Недели и выплаты", icon: "banknote.fill", color: AppTheme.Colors.success))
            list.append(CatalogEntry(section: "Деньги", destination: .salaryRules, title: "Правила зарплаты", subtitle: "Ставки и бонусы", icon: "list.bullet.rectangle.fill", color: AppTheme.Colors.accentBlue))
            list.append(CatalogEntry(section: "Деньги", destination: .profitability, title: "ОПиУ и рентабельность", subtitle: "P&L за период", icon: "chart.line.uptrend.xyaxis.circle.fill", color: AppTheme.Colors.purple))
        }
        if caps.contains(.adminIncomesRead) || caps.contains(.adminExpensesRead) {
            list.append(CatalogEntry(section: "Деньги", destination: .categories, title: "Категории", subtitle: "Справочник статей", icon: "tag.fill", color: AppTheme.Colors.accentBlue))
        }

        if caps.contains(.adminShiftsRead) {
            list.append(CatalogEntry(section: "Операции", destination: .shifts, title: "Смены", subtitle: "График и публикация", icon: "clock.fill", color: AppTheme.Colors.accentBlue))
        }
        if caps.contains(.adminTasksRead) {
            list.append(CatalogEntry(section: "Операции", destination: .tasks, title: "Задачи", subtitle: "Поручения и статусы", icon: "checklist", color: AppTheme.Colors.warning))
        }
        if caps.contains(.adminOperatorsRead) {
            list.append(CatalogEntry(section: "Операции", destination: .operators, title: "Операторы", subtitle: "Команда точек", icon: "person.2.fill", color: AppTheme.Colors.purple))
        }
        if caps.contains(.adminCustomersRead) {
            list.append(CatalogEntry(section: "Операции", destination: .customers, title: "Клиенты", subtitle: "База и карточки", icon: "person.3.fill", color: AppTheme.Colors.info))
        }
        if p0Unlocked {
            list.append(CatalogEntry(section: "Операции", destination: .storeHub, title: "Склад и точка", subtitle: "POS, остатки, заявки", icon: "shippingbox.fill", color: AppTheme.Colors.cashColor))
        }

        if analyticsUnlocked {
            list.append(CatalogEntry(section: "Аналитика", destination: .analytics, title: "Аналитика", subtitle: "KPI, цели, прогноз, отчёты", icon: "chart.xyaxis.line", color: AppTheme.Colors.accentPrimary))
        }

        if caps.contains(.adminClientBookingsReview) {
            list.append(CatalogEntry(section: "Сервис", destination: .clientBookings, title: "Брони клиентов", subtitle: "Заявки и статусы", icon: "calendar", color: AppTheme.Colors.accentBlue))
        }
        if caps.contains(.adminClientSupportReview) {
            list.append(CatalogEntry(section: "Сервис", destination: .clientSupport, title: "Поддержка клиентов", subtitle: "Обращения", icon: "bubble.left.and.bubble.right.fill", color: AppTheme.Colors.warning))
        }

        if showPointsList {
            list.append(CatalogEntry(section: "Система", destination: .pointsList, title: "Точки", subtitle: "Локации из POS", icon: "mappin.and.ellipse", color: AppTheme.Colors.accentPrimary))
        }
        if showPointDevices {
            list.append(CatalogEntry(section: "Система", destination: .pointDevices, title: "Устройства точек", subtitle: "Проекты и токены", icon: "desktopcomputer.and.arrow.down", color: AppTheme.Colors.accentBlue))
        }
        if showAccessSummary {
            list.append(CatalogEntry(section: "Система", destination: .accessSummary, title: "Доступ и роли", subtitle: "Краткая сводка", icon: "shield.checkered", color: AppTheme.Colors.purple))
        }
        if showSettings {
            list.append(CatalogEntry(section: "Система", destination: .settings, title: "Настройки", subtitle: "Организация", icon: "gearshape.fill", color: AppTheme.Colors.textMuted))
        }
        if showWebParityHub {
            list.append(CatalogEntry(section: "Система", destination: .webParityHub, title: "Всё как на сайте", subtitle: "Arena, отчёты, смена компании и др.", icon: "safari.fill", color: AppTheme.Colors.accentBlue))
        }

        if includeAccountFooter {
            list.append(CatalogEntry(section: "Аккаунт", destination: .profile, title: "Профиль", subtitle: sessionStore.session?.userEmail ?? "Аккаунт", icon: "person.crop.circle.fill", color: AppTheme.Colors.accentBlue))
        }

        return list
    }

    private var filteredEntries: [CatalogEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalogEntries }
        return catalogEntries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(q)
                || entry.subtitle.localizedCaseInsensitiveContains(q)
                || entry.section.localizedCaseInsensitiveContains(q)
        }
    }

    private var groupedCatalog: [(section: String, rows: [CatalogEntry])] {
        let order = ["Деньги", "Операции", "Аналитика", "Сервис", "Система", "Аккаунт"]
        let g = Dictionary(grouping: filteredEntries, by: \.section)
        return order.compactMap { key in
            guard let rows = g[key], !rows.isEmpty else { return nil }
            return (key, rows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        }
    }

    private var useSplitView: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if useSplitView {
                splitLayout
            } else {
                phoneLayout
            }
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .onChange(of: searchText) { _, _ in
            if let s = selectedDestination, !filteredEntries.contains(where: { $0.destination == s }) {
                selectedDestination = nil
            }
        }
        .onChange(of: selectedDestination) { _, new in
            if useSplitView, new != nil {
                AppHaptics.selection()
            }
        }
    }

    /// На iPhone свой `NavigationStack` (вкладка «Ещё» без внешнего стека). На iPad — только split.
    private var phoneLayout: some View {
        NavigationStack {
            List {
                phoneCatalogSections
                if includeAccountFooter {
                    logoutSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(catalogNavigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Поиск разделов")
        }
    }

    @ViewBuilder
    private var phoneCatalogSections: some View {
        ForEach(groupedCatalog, id: \.section) { group in
            Section {
                ForEach(group.rows) { entry in
                    if entry.destination == .profile {
                        NavigationLink {
                            ProfileRoleView()
                        } label: {
                            directoryRow(title: entry.title, subtitle: entry.subtitle, icon: entry.icon, color: entry.color)
                        }
                        .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                    } else {
                        NavigationLink {
                            catalogDetail(for: entry.destination)
                        } label: {
                            directoryRow(title: entry.title, subtitle: entry.subtitle, icon: entry.icon, color: entry.color)
                        }
                        .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
                        .listRowSeparatorTint(AppTheme.Colors.borderSubtle)
                    }
                }
            } header: {
                Text(group.section)
            }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            List(selection: $selectedDestination) {
                ForEach(groupedCatalog, id: \.section) { group in
                    Section {
                        ForEach(group.rows) { entry in
                            sidebarLabeledRow(entry: entry)
                                .tag(entry.destination)
                        }
                    } header: {
                        Text(group.section)
                    }
                }
                if includeAccountFooter {
                    logoutSection
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationTitle(catalogNavigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Поиск разделов")
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            NavigationStack {
                if let d = selectedDestination {
                    catalogDetail(for: d)
                } else {
                    catalogPlaceholder
                }
            }
        }
    }

    private func sidebarLabeledRow(entry: CatalogEntry) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(entry.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        } icon: {
            Image(systemName: entry.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(entry.color)
                .frame(width: 32, height: 32)
                .background(entry.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
    }

    private var catalogPlaceholder: some View {
        ContentUnavailableView {
            Label("Разделы", systemImage: "square.grid.2x2")
        } description: {
            Text("Выберите пункт слева или найдите через поиск.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.bgPrimary)
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await sessionStore.logout() }
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(AppTheme.Colors.errorBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    Text("Выйти из аккаунта")
                        .font(AppTheme.Typography.callout)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
        }
    }

    @ViewBuilder
    private func catalogDetail(for destination: AdminCatalogDestination) -> some View {
        switch destination {
        case .incomes:
            AdminIncomesModuleView(service: service)
        case .expenses:
            AdminExpensesModuleView(service: service)
        case .salary:
            AdminSalaryModuleView(service: service)
        case .salaryRules:
            AdminSalaryRulesRouteView(service: service)
        case .profitability:
            AdminProfitabilityView(service: service)
        case .categories:
            AdminCategoriesModuleView(service: service)
        case .shifts:
            AdminShiftsModuleView(service: service)
        case .tasks:
            AdminTasksModuleView(service: service)
        case .operators:
            AdminOperatorsModuleView(service: service)
        case .customers:
            AdminCustomersModuleView(service: service)
        case .storeHub:
            P0ModulesHubView()
        case .analytics:
            AdminAnalyticsView(service: AdminAnalyticsService(apiClient: sessionStore.apiClient))
        case .clientBookings:
            AdminClientBookingsView(
                viewModel: AdminClientBookingsViewModel(
                    service: AdminClientBookingsService(apiClient: sessionStore.apiClient),
                    canSetStatus: caps.contains(.adminClientBookingsSetStatus)
                )
            )
        case .clientSupport:
            AdminClientSupportView(
                viewModel: AdminClientSupportViewModel(
                    service: AdminClientSupportService(apiClient: sessionStore.apiClient),
                    canSetStatus: caps.contains(.adminClientSupportSetStatus)
                )
            )
        case .pointsList:
            SuperAdminPointsView()
        case .pointDevices:
            AdminPointDevicesView(service: service)
        case .accessSummary:
            SuperAdminAccessView()
        case .settings:
            AdminSettingsView(service: service)
        case .webParityHub:
            AdminWebParityHubView()
        case .profile:
            ProfileRoleView()
        }
    }

    @ViewBuilder
    private func directoryRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Salary rules

private struct AdminSalaryRulesRouteView: View {
    @StateObject private var vm: AdminSalaryViewModel

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminSalaryViewModel(service: service))
    }

    var body: some View {
        AdminSalaryRulesView(rules: vm.rules)
            .navigationTitle("Правила зарплаты")
            .task { await vm.loadRules() }
    }
}
