import SwiftUI
import Charts

struct AdminContractsHubView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Header
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.purple)
                        .padding(10)
                        .background(AppTheme.Colors.purpleBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.purpleBorder, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Модули управления")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Выберите раздел для работы")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                }
                .appCard()

                // Module cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    if ModuleAccessMatrix.isVisible(.income, role: sessionStore.roleContext), capabilities.contains(.adminIncomesRead) {
                        moduleCard(title: "Доходы", icon: "arrow.up.circle.fill", color: AppTheme.Colors.success, destination: AnyView(AdminIncomesModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.expense, role: sessionStore.roleContext), capabilities.contains(.adminExpensesRead) {
                        moduleCard(title: "Расходы", icon: "arrow.down.circle.fill", color: AppTheme.Colors.error, destination: AnyView(AdminExpensesModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.shifts, role: sessionStore.roleContext), capabilities.contains(.adminShiftsRead) {
                        moduleCard(title: "Смены", icon: "clock.fill", color: AppTheme.Colors.accentBlue, destination: AnyView(AdminShiftsModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.tasks, role: sessionStore.roleContext), capabilities.contains(.adminTasksRead) {
                        moduleCard(title: "Задачи", icon: "checklist", color: AppTheme.Colors.warning, destination: AnyView(AdminTasksModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.operators, role: sessionStore.roleContext), capabilities.contains(.adminOperatorsRead) {
                        moduleCard(title: "Операторы", icon: "person.2.fill", color: AppTheme.Colors.purple, destination: AnyView(AdminOperatorsModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.clients, role: sessionStore.roleContext), capabilities.contains(.adminCustomersRead) {
                        moduleCard(title: "Клиенты", icon: "person.3.fill", color: AppTheme.Colors.info, destination: AnyView(AdminCustomersModuleView(service: service)))
                    }
                    if ModuleAccessMatrix.isVisible(.analytics, role: sessionStore.roleContext),
                       capabilities.contains(.adminReportsRead), capabilities.contains(.adminKPIRead) {
                        moduleCard(title: "Аналитика", icon: "chart.xyaxis.line", color: AppTheme.Colors.accentPrimary,
                                   destination: AnyView(AdminAnalyticsView(service: AdminAnalyticsService(apiClient: sessionStore.apiClient))))
                    }
                    if capabilities.contains(.adminInventoryRead) || capabilities.contains(.adminStoreRead) || capabilities.contains(.adminPOSRead) || capabilities.contains(.adminPointRead) {
                        moduleCard(title: "P0 операции", icon: "shippingbox.fill", color: AppTheme.Colors.cashColor, destination: AnyView(P0ModulesHubView()))
                    }
                    moduleCard(title: "Зарплата", icon: "banknote.fill", color: AppTheme.Colors.success, destination: AnyView(AdminSalaryModuleView(service: service)))
                    moduleCard(title: "P&L", icon: "chart.line.uptrend.xyaxis.circle.fill", color: AppTheme.Colors.purple, destination: AnyView(AdminProfitabilityView(service: service)))
                    moduleCard(title: "Категории", icon: "tag.fill", color: AppTheme.Colors.accentBlue, destination: AnyView(AdminCategoriesModuleView(service: service)))
                    moduleCard(title: "Устройства", icon: "desktopcomputer.and.arrow.down", color: AppTheme.Colors.accentBlue,
                               destination: AnyView(AdminPointDevicesView(service: service)))
                    moduleCard(title: "Склад", icon: "shippingbox.fill", color: AppTheme.Colors.cashColor,
                               destination: AnyView(AdminInventoryView(service: service)))
                    moduleCard(title: "KPI", icon: "chart.bar.xaxis.ascending.badge.clock", color: AppTheme.Colors.accentBlue,
                               destination: AnyView(AdminKpiDashboardView(service: service)))
                    moduleCard(title: "Отчёт", icon: "calendar.badge.clock", color: AppTheme.Colors.purple,
                               destination: AnyView(AdminMonthlyReportView(service: service)))
                    moduleCard(title: "Карьера", icon: "person.badge.star.fill", color: AppTheme.Colors.warning,
                               destination: AnyView(AdminOperatorCareerView(service: service)))
                    moduleCard(title: "Рассылка", icon: "megaphone.fill", color: AppTheme.Colors.warning,
                               destination: AnyView(AdminBroadcastView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Лента", icon: "text.bubble.fill", color: AppTheme.Colors.info,
                               destination: AnyView(AdminTeamFeedView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Кэшфлоу", icon: "arrow.left.arrow.right.circle.fill", color: AppTheme.Colors.cashColor,
                               destination: AnyView(AdminCashflowView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Telegram", icon: "paperplane.fill", color: Color(red: 0.1, green: 0.6, blue: 0.9),
                               destination: AnyView(AdminTelegramView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "AI Ассистент", icon: "brain.head.profile", color: AppTheme.Colors.purple,
                               destination: AnyView(AdminAIAssistantView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Рейтинг", icon: "trophy.fill", color: AppTheme.Colors.warning,
                               destination: AnyView(AdminRatingsView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Дни рождения", icon: "gift.fill", color: AppTheme.Colors.error,
                               destination: AnyView(AdminBirthdaysView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Шаблоны расходов", icon: "doc.fill", color: AppTheme.Colors.info,
                               destination: AnyView(AdminExpenseTemplatesView(apiClient: sessionStore.apiClient)))
                    moduleCard(title: "Настройки", icon: "gearshape.fill", color: AppTheme.Colors.textMuted, destination: AnyView(AdminSettingsView(service: service)))
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Модули")
    }

    @ViewBuilder
    private func moduleCard(title: String, icon: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(10)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(color.opacity(0.3), lineWidth: 1))
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfacePrimary.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }

    private var service: AdminContractsServicing {
        AdminContractsService(apiClient: sessionStore.apiClient)
    }
}

struct AdminIncomesModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminIncome>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var operators: [AdminOperator] = []
    @State private var companies: [AdminCompany] = []
    @State private var selectedOperatorId = ""
    @State private var selectedCompanyId = ""
    @State private var selectedDate = Date()
    @State private var shift = "day"
    @State private var zone = ""
    @State private var cashAmount = ""
    @State private var kaspiAmount = ""
    @State private var onlineAmount = ""
    @State private var cardAmount = ""
    @State private var comment = ""
    @State private var filterFromDate: Date? = nil
    @State private var filterToDate: Date? = nil
    @State private var showDateFilter = false
    @State private var searchText = ""
    @State private var sortNewestFirst = true
    @State private var page = 1
    @State private var showCreateSheet = false
    @State private var editingItem: AdminIncome? = nil
    @State private var deletingId: String? = nil
    @State private var showDeleteConfirm = false
    private let pageSize = 20

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: service.loadIncomes))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                incomesSummaryCard
                incomesControlsCard
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if filteredItems.isEmpty {
                    EmptyStateView(message: "Пока нет доходов по выбранному фильтру")
                } else {
                    incomesListCard
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        SectionHeader(title: "Новый доход", icon: "chart.bar.fill", iconColor: AppTheme.Colors.success)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ДАТА")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ТОЧКА / КОМПАНИЯ")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Компания", selection: $selectedCompanyId) {
                                Text("Выберите точку").tag("")
                                ForEach(companies) { company in
                                    Text(company.name).tag(company.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ОПЕРАТОР")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Оператор", selection: $selectedOperatorId) {
                                Text("Выберите оператора").tag("")
                                ForEach(operators.filter { $0.isActive != false }) { op in
                                    Text(op.name).tag(op.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                        Picker("Смена", selection: $shift) {
                            Text("День").tag("day")
                            Text("Ночь").tag("night")
                        }
                        .pickerStyle(.segmented)
                        TextField("Зона (опционально)", text: $zone).appInputStyle()
                        HStack {
                            TextField("Наличные", text: $cashAmount).keyboardType(.decimalPad).appInputStyle()
                            TextField("Kaspi", text: $kaspiAmount).keyboardType(.decimalPad).appInputStyle()
                        }
                        HStack {
                            TextField("Онлайн", text: $onlineAmount).keyboardType(.decimalPad).appInputStyle()
                            TextField("Карта", text: $cardAmount).keyboardType(.decimalPad).appInputStyle()
                        }
                        TextField("Комментарий", text: $comment).appInputStyle()
                        if let error = vm.errorMessage {
                            AlertBanner(message: error, style: .critical)
                        }
                        Button("Сохранить") {
                            guard validateIncomeForm() else { return }
                            Task {
                                let companyId = selectedCompanyId
                                let dateStr = isoDateString(selectedDate)
                                await vm.runWrite(
                                    action: {
                                        try await service.createIncome(.init(
                                            date: dateStr,
                                            companyId: companyId,
                                            operatorId: selectedOperatorId,
                                            shift: shift,
                                            zone: zone.nonEmpty,
                                            cashAmount: parseAmount(cashAmount),
                                            kaspiAmount: parseAmount(kaspiAmount),
                                            onlineAmount: parseAmount(onlineAmount),
                                            cardAmount: parseAmount(cardAmount),
                                            comment: comment.nonEmpty
                                        ))
                                    },
                                    successMessage: "Доход добавлен."
                                )
                                showCreateSheet = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .navigationTitle("Новый доход")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showCreateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .navigationTitle("Доходы")
        .searchable(text: $searchText, prompt: "Поиск по дате, оператору, зоне")
        .task {
            await vm.load()
            async let opsResult = try? service.loadOperators()
            async let companiesResult = try? service.loadCompanies()
            if let ops = await opsResult { operators = ops }
            if let comps = await companiesResult {
                companies = comps
                if selectedCompanyId.isEmpty { selectedCompanyId = comps.first?.id ?? "" }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                IncomeEditView(item: item, operators: operators, service: service) {
                    editingItem = nil
                    Task { await vm.load() }
                }
                .navigationTitle("Изменить доход")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { editingItem = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Удалить запись?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                guard let id = deletingId else { return }
                Task {
                    await vm.runWrite(action: { try await service.deleteIncome(id: id) }, successMessage: "Доход удалён.")
                    deletingId = nil
                }
            }
            Button("Отмена", role: .cancel) { deletingId = nil }
        } message: { Text("Это действие нельзя отменить.") }
        .alert("Инфо", isPresented: .constant(vm.infoMessage != nil), actions: {
            Button("OK") { vm.infoMessage = nil }
        }, message: { Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? "")) })
    }

    private var incomesSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка доходов", icon: "chart.pie.fill", iconColor: AppTheme.Colors.success)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ОБОРОТ", value: MoneyFormatter.detailed(totalIncome), color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "ЗАПИСЕЙ", value: "\(filteredItems.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "СРЕДНИЙ ЧЕК", value: MoneyFormatter.detailed(averageIncome), color: AppTheme.Colors.accentPrimary, bgColor: AppTheme.Colors.accentSoft, borderColor: AppTheme.Colors.accentPrimary.opacity(0.25))
                StatTile(title: "СТРАНИЦА", value: "\(min(page, totalPages))/\(totalPages)", color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder)
            }
            paymentBreakdown(title: "Наличные", value: cashIncome, color: AppTheme.Colors.cashColor)
            paymentBreakdown(title: "Kaspi", value: kaspiIncome, color: AppTheme.Colors.kaspiColor)
            paymentBreakdown(title: "Карта", value: cardIncome, color: AppTheme.Colors.cardColor)
            paymentBreakdown(title: "Онлайн", value: onlineIncome, color: AppTheme.Colors.onlineColor)
        }
        .appCard()
    }

    private var incomesControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Фильтры и действия", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            AppSearchBar(text: $searchText, placeholder: "Поиск по оператору или зоне")
            // Фильтр по дате
            if showDateFilter {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПЕРИОД").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                    HStack {
                        DatePicker("От", selection: Binding(
                            get: { filterFromDate ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())! },
                            set: { filterFromDate = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        Text("—").foregroundStyle(AppTheme.Colors.textMuted)
                        DatePicker("До", selection: Binding(
                            get: { filterToDate ?? Date() },
                            set: { filterToDate = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        Button {
                            filterFromDate = nil
                            filterToDate = nil
                            showDateFilter = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button {
                    withAnimation { showDateFilter.toggle() }
                } label: {
                    Label(showDateFilter ? "Скрыть даты" : "Фильтр по датам",
                          systemImage: "calendar.badge.clock")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(showDateFilter ? AppTheme.Colors.accentPrimary : AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Toggle("Новые", isOn: $sortNewestFirst)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .toggleStyle(.button)
                    .tint(AppTheme.Colors.accentPrimary)
            }
            HStack {
                Button("Назад") { if page > 1 { page -= 1 } }.buttonStyle(GhostButtonStyle())
                Text("Стр. \(min(page, totalPages))/\(totalPages)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Button("Вперёд") { if page < totalPages { page += 1 } }.buttonStyle(GhostButtonStyle())
            }
            Button("Добавить доход") { showCreateSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
        }
        .appCard()
    }

    private var incomesListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список доходов", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentPrimary)
            ForEach(pagedItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.date).font(AppTheme.Typography.captionBold).foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        StatusBadge(text: item.shiftLabel, style: .info)
                    }
                    DataTableRow(cells: [
                        ("Оператор", operatorName(for: item.operatorId), AppTheme.Colors.textSecondary),
                        ("Зона", item.zone ?? "—", AppTheme.Colors.textSecondary),
                        ("Итого", MoneyFormatter.short(item.total), AppTheme.Colors.success)
                    ])
                    HStack(spacing: 8) {
                        if (item.cashAmount ?? 0) > 0 { SecondaryChip(text: "Нал \(MoneyFormatter.short(item.cashAmount ?? 0))", color: AppTheme.Colors.cashColor) }
                        if (item.kaspiAmount ?? 0) > 0 { SecondaryChip(text: "Kaspi \(MoneyFormatter.short(item.kaspiAmount ?? 0))", color: AppTheme.Colors.kaspiColor) }
                        if (item.cardAmount ?? 0) > 0 { SecondaryChip(text: "Карта \(MoneyFormatter.short(item.cardAmount ?? 0))", color: AppTheme.Colors.cardColor) }
                        if (item.onlineAmount ?? 0) > 0 { SecondaryChip(text: "Онлайн \(MoneyFormatter.short(item.onlineAmount ?? 0))", color: AppTheme.Colors.onlineColor) }
                    }
                    if let c = item.comment, !c.isEmpty {
                        Text(c).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted).lineLimit(1)
                    }
                }
                .swipeActions(edge: .leading) {
                    if canWrite {
                        Button { editingItem = item; AppHaptics.medium() } label: {
                            Label("Изменить", systemImage: "pencil")
                        }.tint(AppTheme.Colors.accentBlue)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if canWrite {
                        Button(role: .destructive) {
                            deletingId = item.id; showDeleteConfirm = true; AppHaptics.heavy()
                        } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
                if item.id != pagedItems.last?.id { Divider().background(AppTheme.Colors.borderSubtle) }
            }
        }
        .appCard()
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminIncomesWrite)
    }

    private func operatorName(for id: String?) -> String {
        guard let id else { return "—" }
        return operators.first(where: { $0.id == id })?.name ?? String(id.prefix(8)) + "…"
    }

    private var filteredItems: [AdminIncome] {
        var base = vm.items
        // Текстовый поиск
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            base = base.filter {
                $0.date.lowercased().contains(q)
                    || operatorName(for: $0.operatorId).lowercased().contains(q)
                    || ($0.zone?.lowercased().contains(q) ?? false)
            }
        }
        // Фильтр по датам
        if let from = filterFromDate {
            let fromStr = isoDateString(from)
            base = base.filter { $0.date >= fromStr }
        }
        if let to = filterToDate {
            let toStr = isoDateString(to)
            base = base.filter { $0.date <= toStr }
        }
        return base.sorted { sortNewestFirst ? $0.date > $1.date : $0.date < $1.date }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize))))
    }

    private var pagedItems: [AdminIncome] {
        let safePage = min(max(1, page), totalPages)
        let start = (safePage - 1) * pageSize
        guard start < filteredItems.count else { return [] }
        let end = min(start + pageSize, filteredItems.count)
        return Array(filteredItems[start..<end])
    }

    private func parseAmount(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func itemTotal(_ item: AdminIncome) -> Double {
        let cash = item.cashAmount ?? 0
        let kaspi = item.kaspiAmount ?? 0
        let online = item.onlineAmount ?? 0
        let card = item.cardAmount ?? 0
        return cash + kaspi + online + card
    }

    private func formatMoney(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic)) + " ₸"
    }

    private var totalIncome: Double { filteredItems.reduce(0) { $0 + itemTotal($1) } }
    private var averageIncome: Double { filteredItems.isEmpty ? 0 : totalIncome / Double(filteredItems.count) }
    private var cashIncome: Double { filteredItems.reduce(0) { $0 + ($1.cashAmount ?? 0) } }
    private var kaspiIncome: Double { filteredItems.reduce(0) { $0 + ($1.kaspiAmount ?? 0) } }
    private var cardIncome: Double { filteredItems.reduce(0) { $0 + ($1.cardAmount ?? 0) } }
    private var onlineIncome: Double { filteredItems.reduce(0) { $0 + ($1.onlineAmount ?? 0) } }

    @ViewBuilder
    private func paymentBreakdown(title: String, value: Double, color: Color) -> some View {
        let pct = totalIncome > 0 ? value / totalIncome : 0
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                Text("\(MoneyFormatter.short(value)) • \(String(format: "%.0f%%", pct * 100))")
                    .font(AppTheme.Typography.monoCaption)
                    .foregroundStyle(color)
            }
            AppProgressBar(value: pct, color: color)
        }
    }

    private func validateIncomeForm() -> Bool {
        let total = parseAmount(cashAmount) + parseAmount(kaspiAmount) + parseAmount(onlineAmount) + parseAmount(cardAmount)
        if selectedOperatorId.isEmpty {
            vm.errorMessage = "Выберите оператора."
            return false
        }
        if total <= 0 {
            vm.errorMessage = "Сумма дохода должна быть больше нуля."
            return false
        }
        return true
    }
}

struct AdminExpensesModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminExpense>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var operators: [AdminOperator] = []
    @State private var companies: [AdminCompany] = []
    @State private var categories: [AdminCategory] = []
    @State private var selectedOperatorId = ""
    @State private var selectedCompanyId = ""
    @State private var selectedDate = Date()
    @State private var category = ""
    @State private var cashAmount = ""
    @State private var kaspiAmount = ""
    @State private var comment = ""
    @State private var filterFromDate: Date? = nil
    @State private var filterToDate: Date? = nil
    @State private var showDateFilter = false
    @State private var searchText = ""
    @State private var sortNewestFirst = true
    @State private var page = 1
    @State private var showCreateSheet = false
    @State private var editingItem: AdminExpense? = nil
    @State private var deletingId: String? = nil
    @State private var showDeleteConfirm = false
    private let pageSize = 20

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: service.loadExpenses))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                expensesSummaryCard
                expensesControlsCard
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if filteredItems.isEmpty {
                    EmptyStateView(message: "Пока нет расходов по выбранному фильтру")
                } else {
                    expensesListCard
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        SectionHeader(title: "Новый расход", icon: "creditcard.fill", iconColor: AppTheme.Colors.error)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ДАТА")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ТОЧКА / КОМПАНИЯ")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Компания", selection: $selectedCompanyId) {
                                Text("Выберите точку").tag("")
                                ForEach(companies) { company in
                                    Text(company.name).tag(company.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ОПЕРАТОР")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Оператор", selection: $selectedOperatorId) {
                                Text("Выберите оператора").tag("")
                                ForEach(operators.filter { $0.isActive != false }) { op in
                                    Text(op.name).tag(op.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("КАТЕГОРИЯ")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            if categories.isEmpty {
                                TextField("Категория", text: $category).appInputStyle()
                            } else {
                                Picker("Категория", selection: $category) {
                                    Text("Выберите категорию").tag("")
                                    ForEach(categories) { cat in
                                        Text(cat.name).tag(cat.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .appInputStyle()
                            }
                        }
                        HStack {
                            TextField("Наличные", text: $cashAmount).keyboardType(.decimalPad).appInputStyle()
                            TextField("Kaspi", text: $kaspiAmount).keyboardType(.decimalPad).appInputStyle()
                        }
                        TextField("Комментарий", text: $comment).appInputStyle()
                        if let error = vm.errorMessage {
                            AlertBanner(message: error, style: .critical)
                        }
                        Button("Сохранить") {
                            guard validateExpenseForm() else { return }
                            Task {
                                let dateStr = isoDateString(selectedDate)
                                await vm.runWrite(
                                    action: {
                                        try await service.createExpense(.init(
                                            date: dateStr,
                                            companyId: selectedCompanyId,
                                            operatorId: selectedOperatorId,
                                            category: category,
                                            cashAmount: parseAmount(cashAmount),
                                            kaspiAmount: parseAmount(kaspiAmount),
                                            comment: comment.nonEmpty
                                        ))
                                    },
                                    successMessage: "Расход добавлен."
                                )
                                showCreateSheet = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .navigationTitle("Новый расход")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showCreateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .navigationTitle("Расходы")
        .searchable(text: $searchText, prompt: "Поиск по дате, категории, оператору")
        .task {
            await vm.load()
            async let opsResult = try? service.loadOperators()
            async let catsResult = try? service.loadCategories()
            async let compsResult = try? service.loadCompanies()
            if let ops = await opsResult { operators = ops }
            if let cats = await catsResult { categories = cats }
            if let comps = await compsResult {
                companies = comps
                if selectedCompanyId.isEmpty { selectedCompanyId = comps.first?.id ?? "" }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ExpenseEditView(item: item, operators: operators, service: service) {
                    editingItem = nil
                    Task { await vm.load() }
                }
                .navigationTitle("Изменить расход")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { editingItem = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Удалить запись?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                guard let id = deletingId else { return }
                Task {
                    await vm.runWrite(action: { try await service.deleteExpense(id: id) }, successMessage: "Расход удалён.")
                    deletingId = nil
                }
            }
            Button("Отмена", role: .cancel) { deletingId = nil }
        } message: { Text("Это действие нельзя отменить.") }
        .alert("Инфо", isPresented: .constant(vm.infoMessage != nil), actions: {
            Button("OK") { vm.infoMessage = nil }
        }, message: { Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? "")) })
    }

    private var expensesSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка расходов", icon: "chart.bar.xaxis", iconColor: AppTheme.Colors.error)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "РАСХОД", value: MoneyFormatter.detailed(totalExpense), color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder)
                StatTile(title: "ЗАПИСЕЙ", value: "\(filteredItems.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "СРЕДНИЙ", value: MoneyFormatter.detailed(averageExpense), color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "КАТЕГОРИЙ", value: "\(Set(filteredItems.map(\.category)).count)", color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder)
            }
            Chart(expenseCategoryChartData, id: \.0) { row in
                BarMark(
                    x: .value("Категория", row.0),
                    y: .value("Сумма", row.1)
                )
                .foregroundStyle(AppTheme.Colors.error.gradient)
            }
            .frame(height: 180)
        }
        .appCard()
    }

    private var expensesControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Фильтры и действия", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            AppSearchBar(text: $searchText, placeholder: "Поиск по категории")
            if showDateFilter {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПЕРИОД").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                    HStack {
                        DatePicker("От", selection: Binding(
                            get: { filterFromDate ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())! },
                            set: { filterFromDate = $0 }
                        ), displayedComponents: .date).labelsHidden().environment(\.locale, Locale(identifier: "ru_RU"))
                        Text("—").foregroundStyle(AppTheme.Colors.textMuted)
                        DatePicker("До", selection: Binding(
                            get: { filterToDate ?? Date() },
                            set: { filterToDate = $0 }
                        ), displayedComponents: .date).labelsHidden().environment(\.locale, Locale(identifier: "ru_RU"))
                        Button { filterFromDate = nil; filterToDate = nil; showDateFilter = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.Colors.textMuted)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button { withAnimation { showDateFilter.toggle() } } label: {
                    Label(showDateFilter ? "Скрыть" : "По датам", systemImage: "calendar.badge.clock")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(showDateFilter ? AppTheme.Colors.accentPrimary : AppTheme.Colors.textSecondary)
                }.buttonStyle(.plain)
                Spacer()
                Toggle("Новые", isOn: $sortNewestFirst)
                    .font(AppTheme.Typography.caption)
                    .toggleStyle(.button)
                    .tint(AppTheme.Colors.accentPrimary)
            }
            HStack {
                Button("Назад") { if page > 1 { page -= 1 } }.buttonStyle(GhostButtonStyle())
                Text("Стр. \(min(page, totalPages))/\(totalPages)")
                    .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                Button("Вперёд") { if page < totalPages { page += 1 } }.buttonStyle(GhostButtonStyle())
            }
            Button("Добавить расход") { showCreateSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
        }
        .appCard()
    }

    private var expensesListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список расходов", icon: "list.bullet.rectangle.portrait", iconColor: AppTheme.Colors.warning)
            ForEach(pagedItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StatusBadge(text: item.categoryLabel, style: .warning)
                        Spacer()
                        Text(item.date).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    DataTableRow(cells: [
                        ("Оператор", expenseOperatorName(for: item.operatorId), AppTheme.Colors.textSecondary),
                        ("Итого", MoneyFormatter.short(item.total), AppTheme.Colors.error)
                    ])
                    HStack(spacing: 8) {
                        if (item.cashAmount ?? 0) > 0 { SecondaryChip(text: "Нал \(MoneyFormatter.short(item.cashAmount ?? 0))", color: AppTheme.Colors.cashColor) }
                        if (item.kaspiAmount ?? 0) > 0 { SecondaryChip(text: "Kaspi \(MoneyFormatter.short(item.kaspiAmount ?? 0))", color: AppTheme.Colors.kaspiColor) }
                    }
                    if let c = item.comment, !c.isEmpty {
                        Text(c).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted).lineLimit(1)
                    }
                }
                .swipeActions(edge: .leading) {
                    if canWrite {
                        Button { editingItem = item; AppHaptics.medium() } label: {
                            Label("Изменить", systemImage: "pencil")
                        }.tint(AppTheme.Colors.accentBlue)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if canWrite {
                        Button(role: .destructive) {
                            deletingId = item.id; showDeleteConfirm = true; AppHaptics.heavy()
                        } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
                if item.id != pagedItems.last?.id { Divider().background(AppTheme.Colors.borderSubtle) }
            }
        }
        .appCard()
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminExpensesWrite)
    }

    private func expenseOperatorName(for id: String?) -> String {
        guard let id else { return "—" }
        return operators.first(where: { $0.id == id })?.name ?? String(id.prefix(8)) + "…"
    }

    private var filteredItems: [AdminExpense] {
        var base = vm.items
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            base = base.filter { $0.category.lowercased().contains(q) || $0.date.lowercased().contains(q) }
        }
        if let from = filterFromDate { base = base.filter { $0.date >= isoDateString(from) } }
        if let to = filterToDate { base = base.filter { $0.date <= isoDateString(to) } }
        return base.sorted { sortNewestFirst ? $0.date > $1.date : $0.date < $1.date }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize))))
    }

    private var pagedItems: [AdminExpense] {
        let safePage = min(max(1, page), totalPages)
        let start = (safePage - 1) * pageSize
        guard start < filteredItems.count else { return [] }
        let end = min(start + pageSize, filteredItems.count)
        return Array(filteredItems[start..<end])
    }

    private func parseAmount(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func formatMoney(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic)) + " ₸"
    }

    private var totalExpense: Double { filteredItems.reduce(0) { $0 + ($1.cashAmount ?? 0) + ($1.kaspiAmount ?? 0) } }
    private var averageExpense: Double { filteredItems.isEmpty ? 0 : totalExpense / Double(filteredItems.count) }
    private var expenseCategoryChartData: [(String, Double)] {
        let grouped = Dictionary(grouping: filteredItems, by: \.category)
        var rows: [(String, Double)] = []
        rows.reserveCapacity(grouped.count)
        for (key, values) in grouped {
            let amount = values.reduce(0.0) { partial, item in
                partial + (item.cashAmount ?? 0) + (item.kaspiAmount ?? 0)
            }
            rows.append((key, amount))
        }
        return Array(rows.sorted { $0.1 > $1.1 }.prefix(8))
    }

    private func validateExpenseForm() -> Bool {
        let total = parseAmount(cashAmount) + parseAmount(kaspiAmount)
        if selectedOperatorId.isEmpty {
            vm.errorMessage = "Выберите оператора."
            return false
        }
        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            vm.errorMessage = "Укажите категорию."
            return false
        }
        if total <= 0 {
            vm.errorMessage = "Сумма расхода должна быть больше нуля."
            return false
        }
        return true
    }
}

struct AdminShiftsModuleView: View {
    @StateObject private var vm: AdminShiftsModuleViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var financeCompanies: [AdminCompany] = []
    @State private var operatorName = ""
    @State private var resolutionNote = ""
    @State private var showSaveShiftSheet = false
    @State private var shiftType = "day"

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminShiftsModuleViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                shiftsControlsCard
                shiftsStatsCard
                shiftRequestsCard
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showSaveShiftSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Новая смена", icon: "calendar.badge.plus", iconColor: AppTheme.Colors.success)
                    TextField("Оператор", text: $operatorName).appInputStyle()
                    TextField("Дата (YYYY-MM-DD)", text: $vm.weekStartISO).appInputStyle()
                    Picker("Тип смены", selection: $shiftType) {
                        Text("День").tag("day")
                        Text("Ночь").tag("night")
                    }
                    .pickerStyle(.segmented)
                    Button("Сохранить") {
                        guard canWrite else {
                            vm.errorMessage = "Нет доступа для этой роли."
                            return
                        }
                        guard !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            vm.errorMessage = "Выберите оператора."
                            return
                        }
                        let companyId = sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies) ?? ""
                        guard !companyId.isEmpty else {
                            vm.errorMessage = "Не удалось определить компанию для смены."
                            return
                        }
                        Task {
                            await vm.saveShift(payload: .init(
                                companyId: companyId,
                                date: vm.weekStartISO,
                                shiftType: shiftType,
                                operatorName: operatorName,
                                comment: "iOS saveShift"
                            ))
                            showSaveShiftSheet = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
                .navigationTitle("Новая смена")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showSaveShiftSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .navigationTitle("Смены")
        .task {
            await vm.load()
            if let list = try? await service.loadCompanies() { financeCompanies = list }
        }
    }

    @ViewBuilder
    private var shiftsControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Планирование недели", icon: "calendar", iconColor: AppTheme.Colors.accentBlue)
            TextField("Начало недели (YYYY-MM-DD)", text: $vm.weekStartISO).appInputStyle()
            TextField("Оператор", text: $operatorName).appInputStyle()
            TextField("Комментарий решения (опционально)", text: $resolutionNote).appInputStyle()
            Picker("Тип смены", selection: $shiftType) {
                Text("День").tag("day")
                Text("Ночь").tag("night")
            }
            .pickerStyle(.segmented)
            Button("Добавить смену") { showSaveShiftSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
            HStack {
                Button("Назначить неделю") {
                    guard canWrite else {
                        vm.errorMessage = "Нет доступа для этой роли."
                        return
                    }
                    let dates = (0...6).compactMap { isoDate(from: vm.weekStartISO, offsetBy: $0) }
                    let cId = sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies) ?? ""
                    guard !cId.isEmpty else {
                        vm.errorMessage = "Не удалось определить компанию."
                        return
                    }
                    Task {
                        do {
                            try await service.bulkAssignWeek(.init(
                                companyId: cId,
                                operatorName: operatorName,
                                shiftType: shiftType,
                                dates: dates
                            ))
                            await vm.load()
                        } catch {
                            vm.errorMessage = APIErrorMapper().map(error: error).errorDescription
                        }
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!canWrite)
                Button("Опубликовать неделю") {
                    guard canWrite else {
                        vm.errorMessage = "Нет доступа для этой роли."
                        return
                    }
                    let cId = sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies) ?? ""
                    guard !cId.isEmpty else {
                        vm.errorMessage = "Не удалось определить компанию."
                        return
                    }
                    Task {
                        do {
                            try await service.publishWeek(.init(companyId: cId, weekStart: vm.weekStartISO))
                            await vm.load()
                        } catch {
                            vm.errorMessage = APIErrorMapper().map(error: error).errorDescription
                        }
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!canWrite)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var shiftsStatsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Статусы недели", icon: "chart.bar.fill", iconColor: AppTheme.Colors.purple)
            if vm.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(title: "ПУБЛИКАЦИИ", value: "\(vm.workflow.publications?.count ?? 0)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                    StatTile(title: "ОТВЕТЫ", value: "\(vm.workflow.responses?.count ?? 0)", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                    StatTile(title: "ЗАПРОСЫ", value: "\(vm.workflow.requests?.count ?? 0)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var shiftRequestsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Запросы на изменения", icon: "exclamationmark.triangle.fill", iconColor: AppTheme.Colors.warning)
            if let requests = vm.workflow.requests, !requests.isEmpty {
                ForEach(Array(requests.prefix(10)), id: \.id) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(request.operatorName ?? "Оператор")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                            StatusBadge(text: request.shiftType?.uppercased() ?? "СМЕНА", style: .info)
                        }
                        DataTableRow(cells: [
                            ("Дата", request.date ?? request.weekStart ?? "—", AppTheme.Colors.textSecondary),
                            ("Статус", request.status ?? "pending", AppTheme.Colors.warning)
                        ])
                        if canWrite {
                            HStack {
                                Button("Решить") {
                                    Task { await resolveRequest(requestId: request.id, status: "resolved") }
                                }
                                .buttonStyle(GhostButtonStyle())
                                Button("Отклонить") {
                                    Task { await resolveRequest(requestId: request.id, status: "dismissed") }
                                }
                                .buttonStyle(GhostButtonStyle())
                            }
                        }
                    }
                    if request.id != requests.prefix(10).last?.id {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            } else {
                EmptyStateView(message: "Запросов на изменения нет")
            }
        }
        .appCard()
    }

    private func resolveRequest(requestId: String, status: String) async {
        do {
            try await service.resolveShiftIssue(.init(
                requestId: requestId,
                status: status,
                resolutionAction: "keep",
                replacementOperatorName: nil,
                resolutionNote: resolutionNote.nonEmpty
            ))
            await vm.load()
        } catch {
            vm.errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminShiftsWrite)
    }

    @ViewBuilder
    private func statRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value) }
    }

    private func isoDate(from base: String, offsetBy days: Int) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: base),
              let shifted = Calendar(identifier: .iso8601).date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return formatter.string(from: shifted)
    }
}

struct AdminTasksModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminTask>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var financeCompanies: [AdminCompany] = []
    @State private var operators: [AdminOperator] = []
    @State private var title = ""
    @State private var commentText = ""
    @State private var selectedPriority = "medium"
    @State private var selectedStatusFilter = "all"
    @State private var showCreateTaskSheet = false
    @State private var selectedTaskOperatorId = ""
    @State private var taskDueDate = Date()
    @State private var hasDueDate = false

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: service.loadTasks))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                tasksControlsCard
                tasksSummaryCard
                tasksListCard
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showCreateTaskSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        SectionHeader(title: "Новая задача", icon: "plus.circle.fill", iconColor: AppTheme.Colors.purple)
                        TextField("Название", text: $title).appInputStyle()
                        TextField("Описание", text: $commentText).appInputStyle()
                        Picker("Приоритет", selection: $selectedPriority) {
                            Text("Низкий").tag("low")
                            Text("Средний").tag("medium")
                            Text("Высокий").tag("high")
                        }
                        .pickerStyle(.segmented)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ОПЕРАТОР")
                                .font(AppTheme.Typography.micro).tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Оператор", selection: $selectedTaskOperatorId) {
                                Text("Не назначен").tag("")
                                ForEach(operators.filter { $0.isActive != false }) { op in
                                    Text(op.name).tag(op.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Установить срок", isOn: $hasDueDate)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            if hasDueDate {
                                DatePicker("Срок выполнения", selection: $taskDueDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .environment(\.locale, Locale(identifier: "ru_RU"))
                                    .appInputStyle()
                            }
                        }
                        Button("Сохранить") {
                            guard canWrite else {
                                vm.errorMessage = "Нет доступа для этой роли."
                                return
                            }
                            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                vm.errorMessage = "Укажите название задачи."
                                return
                            }
                            guard let companyId = sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies) else {
                                vm.errorMessage = "Не удалось определить компанию для задачи."
                                return
                            }
                            let dueDateStr: String? = hasDueDate ? {
                                let f = DateFormatter()
                                f.locale = Locale(identifier: "en_US_POSIX")
                                f.timeZone = .current
                                f.dateFormat = "yyyy-MM-dd"
                                return f.string(from: taskDueDate)
                            }() : nil
                            Task {
                                await vm.runWrite(action: {
                                    try await service.createTask(.init(
                                        title: title,
                                        description: commentText.nonEmpty,
                                        priority: selectedPriority,
                                        status: "todo",
                                        operatorId: selectedTaskOperatorId.nonEmpty,
                                        companyId: companyId,
                                        dueDate: dueDateStr,
                                        tags: []
                                    ))
                                }, successMessage: "Задача создана.")
                                showCreateTaskSheet = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .navigationTitle("Новая задача")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showCreateTaskSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .navigationTitle("Задачи")
        .task {
            await vm.load()
            if let ops = try? await service.loadOperators() { operators = ops }
            if let cos = try? await service.loadCompanies() { financeCompanies = cos }
            // Sync tasks with Calendar + Notifications + Spotlight
            await AdminTaskSyncManager.shared.requestPermissions()
            await AdminTaskSyncManager.shared.syncTasks(vm.items)
            SpotlightIndexer.shared.indexAdminTasks(vm.items)
        }
    }

    @ViewBuilder
    private var tasksControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Фильтры и действия", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            Picker("Статус", selection: $selectedStatusFilter) {
                Text("Все").tag("all")
                Text("Backlog").tag("backlog")
                Text("To do").tag("todo")
                Text("В работе").tag("in_progress")
                Text("Review").tag("review")
                Text("Done").tag("done")
            }
            .pickerStyle(.menu)
            Button("Добавить задачу") { showCreateTaskSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
            TextField("Комментарий к задаче", text: $commentText).appInputStyle()
            Button("Добавить комментарий к первой задаче") {
                guard canWrite else {
                    vm.errorMessage = "Нет доступа для этой роли."
                    return
                }
                guard let first = filteredTasks.first, let content = commentText.nonEmpty else {
                    vm.errorMessage = "Введите комментарий и загрузите задачи."
                    return
                }
                Task {
                    await vm.runWrite(action: {
                        try await service.addTaskComment(taskId: first.id, content: content)
                    }, successMessage: "Комментарий добавлен.")
                }
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(!canWrite)
        }
        .appCard()
    }

    @ViewBuilder
    private var tasksSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка задач", icon: "chart.bar.fill", iconColor: AppTheme.Colors.purple)
            if vm.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(title: "ВСЕГО", value: "\(vm.items.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                    StatTile(title: "В РАБОТЕ", value: "\(countByStatus("in_progress"))", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                    StatTile(title: "DONE", value: "\(countByStatus("done"))", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var tasksListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список задач", icon: "list.bullet.clipboard", iconColor: AppTheme.Colors.accentPrimary)
            if vm.isLoading {
                EmptyView()
            } else if vm.errorMessage != nil {
                EmptyView()
            } else if filteredTasks.isEmpty {
                EmptyStateView(message: "Нет задач по выбранному статусу")
            } else {
                ForEach(filteredTasks) { task in
                    NavigationLink(destination: AdminTaskDetailView(task: task, service: service)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let num = task.taskNumber {
                                        Text("№\(num)").font(AppTheme.Typography.micro).tracking(1).foregroundStyle(AppTheme.Colors.textMuted)
                                    }
                                    Text(task.title).font(AppTheme.Typography.headline).foregroundStyle(AppTheme.Colors.textPrimary)
                                }
                                Spacer()
                                StatusBadge(text: task.statusLabel, style: task.statusStyle)
                            }
                            if let desc = task.description, !desc.isEmpty {
                                Text(ServerJSONPlaintext.normalize(desc)).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary).lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                SecondaryChip(text: task.priorityLabel, color: priorityColor(task.priority))
                                if let due = task.dueDate {
                                    SecondaryChip(text: "До: \(due.prefix(10))", color: AppTheme.Colors.textMuted)
                                }
                                SecondaryChip(text: taskOperatorName(for: task.operatorId), color: AppTheme.Colors.info)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if canWrite {
                            Button(role: .destructive) {
                                Task { await vm.runWrite(action: { try await service.deleteTask(taskId: task.id) }, successMessage: "Задача удалена.") }
                                AppHaptics.heavy()
                            } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                    if task.id != filteredTasks.last?.id { Divider().background(AppTheme.Colors.borderSubtle) }
                }
            }
        }
        .appCard()
    }

    private func taskOperatorName(for id: String?) -> String {
        guard let id else { return "—" }
        return operators.first(where: { $0.id == id })?.name ?? String(id.prefix(8)) + "…"
    }

    private var filteredTasks: [AdminTask] {
        if selectedStatusFilter == "all" { return vm.items }
        return vm.items.filter { $0.status == selectedStatusFilter }
    }

    private func countByStatus(_ status: String) -> Int {
        vm.items.filter { $0.status == status }.count
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "backlog": return "Бэклог"
        case "todo": return "К выполнению"
        case "in_progress": return "В работе"
        case "review": return "Проверка"
        case "done": return "Готово"
        default: return status
        }
    }

    private func statusStyle(_ status: String) -> StatusBadge.Style {
        switch status {
        case "done": return .excellent
        case "in_progress": return .warning
        case "review": return .info
        case "todo", "backlog": return .neutral
        default: return .neutral
        }
    }

    private func priorityLabel(_ p: String) -> String {
        switch p {
        case "high": return "Высокий"
        case "medium": return "Средний"
        case "low": return "Низкий"
        default: return p
        }
    }

    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "high": return AppTheme.Colors.error
        case "medium": return AppTheme.Colors.warning
        case "low": return AppTheme.Colors.info
        default: return AppTheme.Colors.textSecondary
        }
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminTasksWrite)
    }
}

struct AdminOperatorsModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminOperator>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var name = ""
    @State private var selectedOperatorId = ""
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var showUpdateSheet = false

    init(service: AdminContractsServicing) {
        self.service = service
        let svc = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: { try await svc.loadOperators() }))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                operatorsControlsCard
                operatorsSummaryCard
                operatorsListCard
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Новый оператор", icon: "person.badge.plus", iconColor: AppTheme.Colors.success)
                    TextField("Имя оператора", text: $name).appInputStyle()
                    Button("Сохранить") {
                        guard canWrite else {
                            vm.errorMessage = "Нет доступа для этой роли."
                            return
                        }
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            vm.errorMessage = "Укажите имя оператора."
                            return
                        }
                        Task {
                            await vm.runWrite(action: {
                                try await service.createOperator(.init(
                                    name: name,
                                    fullName: nil,
                                    shortName: nil,
                                    position: nil,
                                    phone: nil,
                                    email: nil
                                ))
                            }, successMessage: "Оператор создан.")
                            showCreateSheet = false
                            name = ""
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
                .navigationTitle("Новый оператор")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showCreateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showUpdateSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Редактирование оператора", icon: "pencil.circle", iconColor: AppTheme.Colors.accentBlue)
                    TextField("Имя оператора", text: $name).appInputStyle()
                    Button("Сохранить") {
                        guard canWrite else {
                            vm.errorMessage = "Нет доступа для этой роли."
                            return
                        }
                        guard !selectedOperatorId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            vm.errorMessage = "Выберите оператора из списка."
                            return
                        }
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            vm.errorMessage = "Укажите имя оператора."
                            return
                        }
                        Task {
                            await vm.runWrite(action: {
                                try await service.updateOperator(
                                    operatorId: selectedOperatorId,
                                    payload: .init(
                                        name: name,
                                        fullName: nil,
                                        shortName: nil,
                                        position: nil,
                                        phone: nil,
                                        email: nil
                                    )
                                )
                            }, successMessage: "Оператор обновлен.")
                            showUpdateSheet = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
                .navigationTitle("Редактирование")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showUpdateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .navigationTitle("Операторы")
        .searchable(text: $searchText, prompt: "Поиск по имени, роли")
        .task {
            await vm.load()
            SpotlightIndexer.shared.indexOperators(vm.items)
        }
        .alert("Инфо", isPresented: .constant(vm.infoMessage != nil), actions: {
            Button("OK") { vm.infoMessage = nil }
        }, message: { Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? "")) })
    }

    @ViewBuilder
    private var operatorsControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Управление", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            AppSearchBar(text: $searchText, placeholder: "Поиск по имени, роли или ID")
            Button("Добавить оператора") { showCreateSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
            Button("Обновить выбранного оператора") { showUpdateSheet = true }
                .buttonStyle(GhostButtonStyle())
                .disabled(!canWrite || selectedOperatorId.isEmpty)
        }
        .appCard()
    }

    @ViewBuilder
    private var operatorsSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка по операторам", icon: "chart.bar.fill", iconColor: AppTheme.Colors.purple)
            if vm.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(title: "ВСЕГО", value: "\(filteredOperators.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                    StatTile(title: "АКТИВНЫЕ", value: "\(filteredOperators.filter { $0.isActive == true }.count)", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                    StatTile(title: "НЕАКТИВНЫЕ", value: "\(filteredOperators.filter { $0.isActive != true }.count)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var operatorsListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список операторов", icon: "person.2.fill", iconColor: AppTheme.Colors.accentPrimary)
            if vm.isLoading || vm.errorMessage != nil {
                EmptyView()
            } else if filteredOperators.isEmpty {
                EmptyStateView(message: "Операторы не найдены")
            } else {
                ForEach(filteredOperators) { op in
                    NavigationLink {
                        AdminOperatorProfileView(service: service, operatorId: op.id)
                    } label: {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                            Circle()
                                .fill(AppTheme.Colors.purpleBg)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(initials(op.name))
                                        .font(AppTheme.Typography.captionBold)
                                        .foregroundStyle(AppTheme.Colors.purple)
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(op.name)
                                        .font(AppTheme.Typography.headline)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Spacer()
                                    StatusBadge(text: op.isActive == true ? "Активен" : "Неактивен", style: op.isActive == true ? .excellent : .neutral)
                                }
                                HStack(spacing: 8) {
                                    SecondaryChip(text: op.role ?? "role: —", color: AppTheme.Colors.info)
                                    SecondaryChip(text: "ID: \(op.id.prefix(6))…", color: AppTheme.Colors.textSecondary)
                                }
                                if canWrite {
                                    HStack {
                                        Button(op.isActive == true ? "Деактивировать" : "Активировать") {
                                            Task {
                                                await vm.runWrite(action: {
                                                    try await service.toggleOperatorActive(
                                                        operatorId: op.id,
                                                        isActive: !(op.isActive ?? false)
                                                    )
                                                }, successMessage: "Статус оператора обновлён.")
                                            }
                                        }
                                        .buttonStyle(GhostButtonStyle())
                                        Button("Редактировать") {
                                            selectedOperatorId = op.id
                                            name = op.name
                                            showUpdateSheet = true
                                        }
                                        .buttonStyle(GhostButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canWrite {
                            Button(role: .destructive) {
                                Task { await vm.runWrite(action: { try await service.deleteOperator(operatorId: op.id) }, successMessage: "Оператор удалён.") }
                                AppHaptics.heavy()
                            } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                    if op.id != filteredOperators.last?.id { Divider().background(AppTheme.Colors.borderSubtle) }
                }
            }
        }
        .appCard()
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminOperatorsWrite)
    }

    private var filteredOperators: [AdminOperator] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.items }
        return vm.items.filter {
            $0.name.lowercased().contains(q)
                || ($0.role?.lowercased().contains(q) ?? false)
                || $0.id.lowercased().contains(q)
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct AdminOperatorProfileView: View {
    let service: AdminContractsServicing
    let operatorId: String
    @StateObject private var vm: AdminOperatorProfileViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var telegramChatId = ""

    init(service: AdminContractsServicing, operatorId: String) {
        self.service = service
        self.operatorId = operatorId
        _vm = StateObject(wrappedValue: AdminOperatorProfileViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load(operatorId: operatorId) } })
                } else if let profile = vm.profile {
                    operatorIdentityCard(profile: profile)
                    operatorProfileFieldsCard(profile: profile)
                    operatorSettingsCard
                } else {
                    EmptyStateView(message: "Пока нет данных")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Профиль оператора")
        .task {
            await vm.load(operatorId: operatorId)
            if let chat = vm.profile?.operatorItem.telegramChatId, !chat.isEmpty {
                telegramChatId = chat
            }
        }
    }

    private func operatorIdentityCard(profile: AdminOperatorProfilePayload) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Оператор", icon: "person.crop.circle", iconColor: AppTheme.Colors.info)
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Circle()
                    .fill(AppTheme.Colors.purpleBg)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials(profile.operatorItem.name))
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.purple)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.operatorItem.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        SecondaryChip(text: profile.operatorItem.role ?? "role: —", color: AppTheme.Colors.info)
                        StatusBadge(
                            text: profile.operatorItem.isActive == true ? "Активен" : "Неактивен",
                            style: profile.operatorItem.isActive == true ? .excellent : .neutral
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private func operatorProfileFieldsCard(profile: AdminOperatorProfilePayload) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Доп. поля профиля", icon: "text.book.closed.fill", iconColor: AppTheme.Colors.accentPrimary)
            if let fields = profile.profile, !fields.isEmpty {
                ForEach(fields.keys.sorted(), id: \.self) { key in
                    DataTableRow(cells: [
                        ("Поле", key, AppTheme.Colors.textSecondary),
                        ("Значение", ServerJSONPlaintext.normalize(fields[key]?.raw ?? "—"), AppTheme.Colors.textPrimary)
                    ])
                    if key != fields.keys.sorted().last {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            } else {
                EmptyStateView(message: "Дополнительные поля не заполнены")
            }
        }
        .appCard()
    }

    private var operatorSettingsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Настройки Telegram", icon: "paperplane.fill", iconColor: AppTheme.Colors.accentBlue)
            TextField("Telegram чат ID (опционально)", text: $telegramChatId).appInputStyle()
            Button("Сохранить профиль") {
                guard canWrite else {
                    vm.errorMessage = "Нет доступа для этой роли."
                    return
                }
                Task {
                    do {
                        try await service.updateOperatorProfile(.init(
                            operatorId: operatorId,
                            profile: [:],
                            photoURL: nil,
                            telegramChatId: telegramChatId.nonEmpty
                        ))
                    } catch {
                        vm.errorMessage = APIErrorMapper().map(error: error).errorDescription
                    }
                    await vm.load(operatorId: operatorId)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canWrite)
        }
        .appCard()
    }

    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminOperatorsWrite)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct AdminCustomersModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminCustomer>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var customerEmail = ""
    @State private var customerNotes = ""
    @State private var searchText = ""
    @State private var showCreateSheet = false

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: service.loadCustomers))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                customersControlsCard
                customersSummaryCard
                customersListCard
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Новый клиент", icon: "person.crop.circle.badge.plus", iconColor: AppTheme.Colors.success)
                    TextField("Имя клиента", text: $customerName).appInputStyle()
                    TextField("Телефон (опционально)", text: $customerPhone).keyboardType(.phonePad).appInputStyle()
                    TextField("Email (опционально)", text: $customerEmail).textInputAutocapitalization(.never).autocorrectionDisabled().appInputStyle()
                    TextField("Примечание", text: $customerNotes).appInputStyle()
                    Button("Сохранить") {
                        guard canWrite else {
                            vm.errorMessage = "Нет доступа для этой роли."
                            return
                        }
                        guard !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            vm.errorMessage = "Укажите имя клиента."
                            return
                        }
                        Task {
                            await vm.runWrite(action: {
                                try await service.createCustomer(.init(
                                    name: customerName,
                                    phone: customerPhone.nonEmpty,
                                    cardNumber: nil,
                                    email: customerEmail.nonEmpty,
                                    notes: customerNotes.nonEmpty,
                                    companyId: nil
                                ))
                            }, successMessage: "Клиент создан.")
                            showCreateSheet = false
                            customerName = ""
                            customerPhone = ""
                            customerEmail = ""
                            customerNotes = ""
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
                .navigationTitle("Новый клиент")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showCreateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .navigationTitle("Клиенты")
        .task { await vm.load() }
    }

    @ViewBuilder
    private var customersControlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Поиск и действия", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            AppSearchBar(text: $searchText, placeholder: "Поиск по имени, телефону, email")
            Button("Добавить клиента") { showCreateSheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canWrite)
        }
        .appCard()
    }

    @ViewBuilder
    private var customersSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка клиентов", icon: "chart.bar.fill", iconColor: AppTheme.Colors.purple)
            if vm.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(title: "КЛИЕНТОВ", value: "\(filteredCustomers.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                    StatTile(title: "ЛОЯЛЬНОСТЬ", value: "\(filteredCustomers.reduce(0) { $0 + ($1.loyaltyPoints ?? 0) })", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                    StatTile(title: "ВИЗИТОВ", value: "\(filteredCustomers.reduce(0) { $0 + ($1.visitsCount ?? 0) })", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var customersListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список клиентов", icon: "person.3.fill", iconColor: AppTheme.Colors.accentPrimary)
            if vm.isLoading || vm.errorMessage != nil {
                EmptyView()
            } else if filteredCustomers.isEmpty {
                EmptyStateView(message: "Клиенты не найдены")
            } else {
                ForEach(filteredCustomers) { customer in
                    NavigationLink {
                        AdminCustomerHistoryView(service: service, customerId: customer.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(customer.name)
                                    .font(AppTheme.Typography.headline)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Spacer()
                                StatusBadge(
                                    text: customer.isActive == false ? "Неактивен" : "Активен",
                                    style: customer.isActive == false ? .neutral : .excellent
                                )
                            }
                            DataTableRow(cells: [
                                ("Телефон", customer.phone ?? "—", AppTheme.Colors.textSecondary),
                                ("Email", customer.email ?? "—", AppTheme.Colors.textSecondary),
                                ("Трат", MoneyFormatter.short(customer.totalSpent ?? 0), AppTheme.Colors.accentPrimary)
                            ])
                            HStack(spacing: 8) {
                                SecondaryChip(text: "Баллы: \(customer.loyaltyPoints ?? 0)", color: AppTheme.Colors.purple)
                                SecondaryChip(text: "Визиты: \(customer.visitsCount ?? 0)", color: AppTheme.Colors.info)
                            }
                        }
                    }
                    if customer.id != filteredCustomers.last?.id {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }
        }
        .appCard()
    }
    
    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminCustomersWrite)
    }

    private var filteredCustomers: [AdminCustomer] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.items }
        return vm.items.filter {
            $0.name.lowercased().contains(q)
                || ($0.phone?.lowercased().contains(q) ?? false)
                || ($0.email?.lowercased().contains(q) ?? false)
        }
    }
}

struct AdminCustomerHistoryView: View {
    let service: AdminContractsServicing
    let customerId: String
    @StateObject private var vm: AdminCustomerHistoryViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    init(service: AdminContractsServicing, customerId: String) {
        self.service = service
        self.customerId = customerId
        _vm = StateObject(wrappedValue: AdminCustomerHistoryViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if !canReadHistory {
                    ErrorStateView(message: "Нет доступа для этой роли.", retryAction: nil)
                } else if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load(customerId: customerId) } })
                } else if vm.sales.isEmpty {
                    EmptyStateView(message: "История покупок пуста")
                } else {
                    customerHistorySummaryCard
                    customerSalesListCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("История клиента")
        .task {
            guard canReadHistory else { return }
            await vm.load(customerId: customerId)
        }
    }

    private var customerHistorySummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка покупок", icon: "chart.bar.fill", iconColor: AppTheme.Colors.purple)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ПОКУПОК", value: "\(vm.sales.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ОБОРОТ", value: MoneyFormatter.short(totalSpent), color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "СРЕДНИЙ", value: MoneyFormatter.short(avgSpent), color: AppTheme.Colors.accentPrimary, bgColor: AppTheme.Colors.accentSoft, borderColor: AppTheme.Colors.accentPrimary.opacity(0.25))
            }
        }
        .appCard()
    }

    private var customerSalesListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Покупки", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentBlue)
            ForEach(vm.sales) { sale in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(sale.saleDate ?? "—")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        StatusBadge(text: "SALE", style: .info)
                    }
                    DataTableRow(cells: [
                        ("Сумма", MoneyFormatter.short(sale.totalAmount ?? 0), AppTheme.Colors.success),
                        ("Скидка", MoneyFormatter.short(sale.discountAmount ?? 0), AppTheme.Colors.warning),
                        ("Создано", sale.createdAt ?? "—", AppTheme.Colors.textSecondary)
                    ])
                    HStack(spacing: 8) {
                        SecondaryChip(text: "Нал \(MoneyFormatter.short(sale.cashAmount ?? 0))", color: AppTheme.Colors.cashColor)
                        SecondaryChip(text: "Kaspi \(MoneyFormatter.short(sale.kaspiAmount ?? 0))", color: AppTheme.Colors.kaspiColor)
                    }
                    HStack(spacing: 8) {
                        SecondaryChip(text: "Карта \(MoneyFormatter.short(sale.cardAmount ?? 0))", color: AppTheme.Colors.cardColor)
                        SecondaryChip(text: "Онлайн \(MoneyFormatter.short(sale.onlineAmount ?? 0))", color: AppTheme.Colors.onlineColor)
                    }
                }
                if sale.id != vm.sales.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .appCard()
    }

    private var totalSpent: Double {
        vm.sales.reduce(0) { $0 + ($1.totalAmount ?? 0) }
    }

    private var avgSpent: Double {
        vm.sales.isEmpty ? 0 : totalSpent / Double(vm.sales.count)
    }

    private var canReadHistory: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminCustomersHistoryRead)
    }
}

private extension Date {
    static var nowISO: String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private func isoDateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Task Detail View

struct AdminTaskDetailView: View {
    let task: AdminTask
    let service: AdminContractsServicing
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var commentText = ""
    @State private var isActing = false
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Заголовок
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        if let num = task.taskNumber {
                            Text("Задача №\(num)").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Spacer()
                        StatusBadge(text: taskStatusLabel(task.status), style: taskStatusStyle(task.status))
                    }
                    Text(task.title)
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        SecondaryChip(text: taskPriorityLabel(task.priority), color: taskPriorityColor(task.priority))
                        if let due = task.dueDate {
                            SecondaryChip(text: "Дедлайн: \(due.prefix(10))", color: AppTheme.Colors.warning)
                        }
                    }
                }
                .appCard()

                // Описание
                if let desc = task.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Описание", icon: "text.alignleft", iconColor: AppTheme.Colors.accentBlue)
                        Text(ServerJSONPlaintext.normalize(desc))
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .appCard()
                }

                // Детали
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Детали", icon: "info.circle.fill", iconColor: AppTheme.Colors.purple)
                    detailRow("Статус", taskStatusLabel(task.status))
                    Divider().background(AppTheme.Colors.borderSubtle)
                    detailRow("Приоритет", taskPriorityLabel(task.priority))
                    Divider().background(AppTheme.Colors.borderSubtle)
                    detailRow("Оператор", task.operatorId != nil ? "Назначен" : "Не назначен")
                    if let due = task.dueDate {
                        Divider().background(AppTheme.Colors.borderSubtle)
                        detailRow("Дедлайн", String(due.prefix(10)))
                    }
                    if let created = task.createdAt {
                        Divider().background(AppTheme.Colors.borderSubtle)
                        detailRow("Создана", String(created.prefix(10)))
                    }
                }
                .appCard()

                // Сообщения
                if let info = infoMessage {
                    AlertBanner(message: info, style: .info)
                }
                if let error = errorMessage {
                    AlertBanner(message: error, style: .critical)
                }

                // Действия
                if canWrite {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Действия", icon: "bolt.fill", iconColor: AppTheme.Colors.accentPrimary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                            actionButton("В работу", icon: "play.circle.fill", color: AppTheme.Colors.info) {
                                await changeStatus("in_progress")
                            }
                            actionButton("На проверку", icon: "eye.circle.fill", color: AppTheme.Colors.warning) {
                                await changeStatus("review")
                            }
                            actionButton("Завершить", icon: "checkmark.circle.fill", color: AppTheme.Colors.success) {
                                await changeStatus("done")
                            }
                            actionButton("Заблокировать", icon: "xmark.octagon.fill", color: AppTheme.Colors.error) {
                                await changeStatus("blocked")
                            }
                        }
                    }
                    .appCard()

                    // Комментарий
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Добавить комментарий", icon: "bubble.left.fill", iconColor: AppTheme.Colors.accentBlue)
                        TextField("Напишите комментарий…", text: $commentText, axis: .vertical)
                            .lineLimit(3...6)
                            .appInputStyle()
                        Button("Отправить") {
                            guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task {
                                isActing = true
                                do {
                                    try await service.addTaskComment(taskId: task.id, content: commentText)
                                    infoMessage = "Комментарий добавлен."
                                    commentText = ""
                                } catch {
                                    errorMessage = APIErrorMapper().map(error: error).errorDescription
                                }
                                isActing = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isActing)
                    }
                    .appCard()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Задача")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value).font(AppTheme.Typography.captionBold).foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(AppTheme.Typography.captionBold)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(color.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }

    private func changeStatus(_ status: String) async {
        isActing = true
        do {
            try await service.changeTaskStatus(taskId: task.id, status: status)
            infoMessage = "Статус обновлён: \(taskStatusLabel(status))"
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
        isActing = false
    }

    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminTasksWrite)
    }

    private func taskStatusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "todo": return "К выполнению"
        case "in_progress": return "В работе"
        case "review": return "На проверке"
        case "done": return "Выполнено"
        case "blocked": return "Заблокировано"
        case "backlog": return "Бэклог"
        default: return status ?? "—"
        }
    }
    private func taskStatusStyle(_ status: String?) -> StatusBadge.Style {
        switch status?.lowercased() {
        case "done": return .excellent
        case "in_progress": return .info
        case "review": return .good
        case "blocked": return .critical
        default: return .neutral
        }
    }
    private func taskPriorityLabel(_ p: String?) -> String {
        switch p?.lowercased() {
        case "urgent": return "🔴 Срочно"
        case "high": return "🟠 Высокий"
        case "medium": return "🟡 Средний"
        case "low": return "🟢 Низкий"
        default: return p ?? "—"
        }
    }
    private func taskPriorityColor(_ p: String?) -> Color {
        switch p?.lowercased() {
        case "urgent", "high": return AppTheme.Colors.error
        case "medium": return AppTheme.Colors.warning
        default: return AppTheme.Colors.info
        }
    }
}

// MARK: - Settings View

struct AdminSettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing
    @State private var pointDevices: PointDevicesResponse?
    @State private var isLoadingPoints = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Точки F16
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Точки", icon: "mappin.circle.fill", iconColor: AppTheme.Colors.accentPrimary)
                    if isLoadingPoints {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Загрузка точек…")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    } else if let devices = pointDevices, !devices.projects.isEmpty {
                        ForEach(Array(devices.projects.enumerated()), id: \.element.id) { idx, project in
                            if idx > 0 { Divider().background(AppTheme.Colors.borderSubtle) }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    if let lastSeen = project.lastSeenAt {
                                        Text("Онлайн: \(String(lastSeen.prefix(10)))")
                                            .font(AppTheme.Typography.micro)
                                            .foregroundStyle(AppTheme.Colors.textMuted)
                                    }
                                }
                                Spacer()
                                StatusBadge(text: project.isActive ? "Активна" : "Откл.", style: project.isActive ? .excellent : .neutral)
                            }
                            .padding(.vertical, 2)
                        }
                        NavigationLink(destination: AdminPointDevicesView(service: service)) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.accentBlue)
                                Text("Управление устройствами")
                                    .font(AppTheme.Typography.captionBold)
                                    .foregroundStyle(AppTheme.Colors.accentBlue)
                                Spacer()
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        NavigationLink(destination: AdminPointDevicesView(service: service)) {
                            HStack {
                                Image(systemName: "desktopcomputer.and.arrow.down")
                                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                                Text("Подключить устройства точек")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .appCard()

                // Профиль пользователя
                accountSection

                // Telegram
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Telegram-бот", icon: "paperplane.fill", iconColor: AppTheme.Colors.accentBlue)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppTheme.Colors.textMuted)
                            .font(.system(size: 14))
                        Text("Для подключения Telegram-бота свяжитесь с администратором системы")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .appCard()

                // Права доступа
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Права доступа", icon: "lock.shield.fill", iconColor: AppTheme.Colors.warning)
                    permRow("Супер-администратор", sessionStore.roleContext?.isSuperAdmin == true)
                    Divider().background(AppTheme.Colors.borderSubtle)
                    permRow("Сотрудник", sessionStore.roleContext?.isStaff == true)
                    Divider().background(AppTheme.Colors.borderSubtle)
                    permRow("Оператор", sessionStore.roleContext?.isOperator == true)
                    Divider().background(AppTheme.Colors.borderSubtle)
                    permRow("Клиент", sessionStore.roleContext?.isCustomer == true)
                }
                .appCard()

                // О приложении
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "О приложении", icon: "apps.iphone", iconColor: AppTheme.Colors.textMuted)
                    settingRow("Приложение", "Orda Control", icon: "star.fill")
                    Divider().background(AppTheme.Colors.borderSubtle)
                    settingRow("Версия", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", icon: "number.circle")
                    Divider().background(AppTheme.Colors.borderSubtle)
                    settingRow("Сайт", "ordaops.kz", icon: "globe")
                }
                .appCard()
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Настройки")
        .task {
            isLoadingPoints = true
            pointDevices = try? await service.loadPointDevices()
            isLoadingPoints = false
        }
    }

    @ViewBuilder
    private func settingRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.textMuted)
                .frame(width: 20)
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func permRow(_ label: String, _ enabled: Bool) -> some View {
        HStack {
            Text(label).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            StatusBadge(text: enabled ? "Да" : "Нет", style: enabled ? .excellent : .neutral)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var accountSection: some View {
        let email = sessionStore.session?.userEmail ?? "—"
        let role = sessionStore.roleContext?.roleLabel ?? sessionStore.roleContext?.persona ?? "—"
        let path = sessionStore.roleContext?.defaultPath ?? "—"
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Аккаунт", icon: "person.crop.circle.fill", iconColor: AppTheme.Colors.purple)
            settingRow("Email", email, icon: "envelope")
            Divider().background(AppTheme.Colors.borderSubtle)
            settingRow("Роль", role, icon: "shield")
            Divider().background(AppTheme.Colors.borderSubtle)
            settingRow("Маршрут", path, icon: "arrow.right.circle")
        }
        .appCard()
    }
}

// MARK: - Salary Module View

struct AdminSalaryModuleView: View {
    @StateObject private var vm: AdminSalaryViewModel
    let service: AdminContractsServicing

    @State private var adjustmentTarget: SalaryOperatorRow?
    @State private var paymentTarget: SalaryOperatorRow?
    @State private var showRules = false

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminSalaryViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                weekNavigator
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if let board = vm.board {
                    totalsCard(board.totals)
                    if board.operators.isEmpty {
                        EmptyStateView(message: "Нет операторов за эту неделю", icon: "banknote")
                    } else {
                        ForEach(board.operators) { op in
                            SalaryOperatorCard(
                                op: op,
                                onAdjustment: { adjustmentTarget = op },
                                onPayment: { paymentTarget = op },
                                onVoidPayment: { pid in
                                    Task { await vm.voidPayment(paymentId: pid, operatorId: op.id) }
                                }
                            )
                        }
                    }
                } else {
                    EmptyStateView(message: "Выберите неделю", icon: "calendar")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Зарплата")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRules = true
                } label: {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
        .task {
            await vm.load()
            await vm.loadRules()
        }
        .onChange(of: vm.selectedWeekStart) { _, _ in Task { await vm.load() } }
        .sheet(item: $adjustmentTarget) { op in
            SalaryAdjustmentSheet(operatorName: op.name) { date, amount, kind, comment in
                Task { await vm.createAdjustment(operatorId: op.id, date: date, amount: amount, kind: kind, comment: comment) }
            }
        }
        .sheet(item: $paymentTarget) { op in
            SalaryPaymentSheet(operatorName: op.name, remaining: op.week.remainingAmount) { paymentDate, cash, kaspi, comment in
                Task { await vm.createPayment(operatorId: op.id, paymentDate: paymentDate, cashAmount: cash, kaspiAmount: kaspi, comment: comment) }
            }
        }
        .navigationDestination(isPresented: $showRules) {
            AdminSalaryRulesView(rules: vm.rules)
        }
        .alert("Готово", isPresented: .constant(vm.infoMessage != nil)) {
            Button("OK") { vm.infoMessage = nil }
        } message: { Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? "")) }
    }

    private var weekNavigator: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button { vm.shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Неделя")
                    .font(AppTheme.Typography.micro)
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Text(vm.weekLabel)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Spacer()
            Button { vm.shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func totalsCard(_ t: SalaryWeekTotals) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Итого за неделю", icon: "banknote.fill", iconColor: AppTheme.Colors.success)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "НАЧИСЛЕНО", value: MoneyFormatter.detailed(t.netAmount),
                         color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "ВЫПЛАЧЕНО", value: MoneyFormatter.detailed(t.paidAmount),
                         color: AppTheme.Colors.accentBlue, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ОСТАТОК", value: MoneyFormatter.detailed(t.remainingAmount),
                         color: t.remainingAmount > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success,
                         bgColor: t.remainingAmount > 0 ? AppTheme.Colors.warningBg : AppTheme.Colors.successBg,
                         borderColor: t.remainingAmount > 0 ? AppTheme.Colors.warningBorder : AppTheme.Colors.successBorder)
                StatTile(title: "ОПЕРАТОРОВ", value: "\(t.paidOperators)/\(t.activeOperators)",
                         color: AppTheme.Colors.accentPrimary, bgColor: AppTheme.Colors.accentSoft, borderColor: AppTheme.Colors.accentPrimary.opacity(0.25))
            }
            if t.bonusAmount > 0 || t.fineAmount > 0 {
                DataTableRow(cells: [
                    ("Бонусы", MoneyFormatter.short(t.bonusAmount), AppTheme.Colors.success),
                    ("Штрафы", MoneyFormatter.short(t.fineAmount), AppTheme.Colors.error),
                    ("Авансы", MoneyFormatter.short(t.advanceAmount), AppTheme.Colors.warning)
                ])
            }
        }
        .appCard()
    }
}

// MARK: - Operator Card

private struct SalaryOperatorCard: View {
    let op: SalaryOperatorRow
    let onAdjustment: () -> Void
    let onPayment: () -> Void
    let onVoidPayment: (String) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(op.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Нетто: \(MoneyFormatter.detailed(op.week.netAmount))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                StatusBadge(text: salaryStatusLabel(op.week.status), style: salaryStatusStyle(op.week.status))
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .padding(6)
                }
            }

            // Summary row
            DataTableRow(cells: [
                ("Валовой", MoneyFormatter.short(op.week.grossAmount), AppTheme.Colors.textSecondary),
                ("Бонус", MoneyFormatter.short(op.week.bonusAmount), AppTheme.Colors.success),
                ("Штраф", MoneyFormatter.short(op.week.fineAmount), AppTheme.Colors.error)
            ])

            // Paid / Remaining
            HStack(spacing: AppTheme.Spacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(AppTheme.Colors.success)
                    Text("Выплачено: \(MoneyFormatter.short(op.week.paidAmount))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if op.week.remainingAmount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill").font(.caption).foregroundStyle(AppTheme.Colors.warning)
                        Text("Остаток: \(MoneyFormatter.short(op.week.remainingAmount))")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                }
            }

            // Expanded: payments + adjustments info
            if expanded {
                Divider().background(AppTheme.Colors.borderSubtle)

                if !op.week.payments.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ВЫПЛАТЫ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        ForEach(op.week.payments) { payment in
                            HStack {
                                Text(formatShortDate(payment.paymentDate))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                if payment.cashAmount > 0 {
                                    Text("Нал: \(MoneyFormatter.short(payment.cashAmount))")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.success)
                                }
                                if payment.kaspiAmount > 0 {
                                    Text("Kaspi: \(MoneyFormatter.short(payment.kaspiAmount))")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.accentBlue)
                                }
                                Spacer()
                                Button {
                                    onVoidPayment(payment.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.error.opacity(0.7))
                                }
                            }
                        }
                    }
                }

                if !op.week.allocations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ПО ТОЧКАМ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        ForEach(op.week.allocations, id: \.companyId) { alloc in
                            HStack {
                                Text(alloc.companyCode ?? alloc.companyId)
                                    .font(AppTheme.Typography.captionBold)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Spacer()
                                Text(MoneyFormatter.short(alloc.netAmount))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Text(String(format: "%.0f%%", alloc.shareRatio * 100))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    onAdjustment()
                } label: {
                    Label("Корректировка", systemImage: "plus.circle")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                }
                Button {
                    onPayment()
                } label: {
                    Label("Выплатить", systemImage: "banknote")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.successBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                }
            }
        }
        .appCard()
    }

    private func salaryStatusLabel(_ s: String) -> String {
        switch s {
        case "paid": return "Выплачено"
        case "partial": return "Частично"
        default: return "Черновик"
        }
    }

    private func salaryStatusStyle(_ s: String) -> StatusBadge.Style {
        switch s {
        case "paid": return .excellent
        case "partial": return .warning
        default: return .neutral
        }
    }

    private func formatShortDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(iso.prefix(10))) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "d MMM"
        return out.string(from: d)
    }
}

// MARK: - Adjustment Sheet

private struct SalaryAdjustmentSheet: View {
    let operatorName: String
    let onSave: (String, Double, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind = "bonus"
    @State private var amount = ""
    @State private var comment = ""
    @State private var date: String = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()

    private let kinds: [(String, String, Color)] = [
        ("bonus", "Бонус", AppTheme.Colors.success),
        ("fine", "Штраф", AppTheme.Colors.error),
        ("debt", "Долг", AppTheme.Colors.warning),
        ("advance", "Аванс", AppTheme.Colors.accentBlue)
    ]

    @ViewBuilder
    private func kindButton(id: String, label: String, color: Color) -> some View {
        let isSelected = selectedKind == id
        Button { selectedKind = id } label: {
            Text(label)
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(isSelected ? color : AppTheme.Colors.textMuted)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.15) : AppTheme.Colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: operatorName, icon: "person.fill", iconColor: AppTheme.Colors.accentPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ТИП КОРРЕКТИРОВКИ").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(kinds, id: \.0) { kind in
                                kindButton(id: kind.0, label: kind.1, color: kind.2)
                            }
                        }
                    }

                    TextField("Сумма (₸)", text: $amount).keyboardType(.decimalPad).appInputStyle()
                    TextField("Дата (YYYY-MM-DD)", text: $date).appInputStyle()
                    TextField("Комментарий (опционально)", text: $comment).appInputStyle()

                    Button("Сохранить") {
                        let val = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
                        guard val > 0 else { return }
                        onSave(date, val, selectedKind, comment.isEmpty ? nil : comment)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Корректировка")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Payment Sheet

private struct SalaryPaymentSheet: View {
    let operatorName: String
    let remaining: Double
    let onSave: (String, Double?, Double?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cashAmount = ""
    @State private var kaspiAmount = ""
    @State private var comment = ""
    @State private var paymentDate: String = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: operatorName, icon: "banknote.fill", iconColor: AppTheme.Colors.success)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("К ВЫПЛАТЕ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Text(MoneyFormatter.detailed(remaining))
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(remaining > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    }
                    .appCard()

                    TextField("Дата выплаты (YYYY-MM-DD)", text: $paymentDate).appInputStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("СПОСОБ ОПЛАТЫ").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                        HStack(spacing: AppTheme.Spacing.sm) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Наличные").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                                TextField("0", text: $cashAmount).keyboardType(.decimalPad).appInputStyle()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kaspi").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                                TextField("0", text: $kaspiAmount).keyboardType(.decimalPad).appInputStyle()
                            }
                        }
                    }

                    TextField("Комментарий (опционально)", text: $comment).appInputStyle()

                    Button("Выплатить") {
                        let cash = Double(cashAmount.replacingOccurrences(of: ",", with: "."))
                        let kaspi = Double(kaspiAmount.replacingOccurrences(of: ",", with: "."))
                        guard (cash ?? 0) + (kaspi ?? 0) > 0 else { return }
                        onSave(paymentDate, cash, kaspi, comment.isEmpty ? nil : comment)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Выплата зарплаты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Salary Rules View

struct AdminSalaryRulesView: View {
    let rules: SalaryRulesBoard?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if let board = rules {
                    if board.rules.isEmpty {
                        EmptyStateView(message: "Нет настроенных правил", icon: "list.clipboard")
                    } else {
                        ForEach(board.rules) { rule in
                            ruleCard(rule)
                        }
                    }
                } else {
                    EmptyStateView(message: "Правила не загружены", icon: "list.clipboard")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Правила зарплаты")
    }

    @ViewBuilder
    private func ruleCard(_ rule: SalaryRuleItem) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.companyCode.uppercased())
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(rule.shiftType == "day" ? "Дневная смена" : "Ночная смена")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                StatusBadge(
                    text: rule.isActive ? "Активно" : "Отключено",
                    style: rule.isActive ? .excellent : .neutral
                )
            }

            DataTableRow(cells: [
                ("База/смена", MoneyFormatter.short(rule.basePerShift ?? 0), AppTheme.Colors.textSecondary),
                ("Бонус ст. оп.", MoneyFormatter.short(rule.seniorOperatorBonus ?? 0), AppTheme.Colors.success),
                ("Бонус кассира", MoneyFormatter.short(rule.seniorCashierBonus ?? 0), AppTheme.Colors.accentBlue)
            ])

            if let t1t = rule.threshold1Turnover, let t1b = rule.threshold1Bonus {
                Divider().background(AppTheme.Colors.borderSubtle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ПОРОГОВЫЕ БОНУСЫ").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                    HStack {
                        Text("≥ \(MoneyFormatter.short(t1t)) оборота")
                            .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text("+ \(MoneyFormatter.short(t1b))")
                            .font(AppTheme.Typography.captionBold).foregroundStyle(AppTheme.Colors.success)
                    }
                    if let t2t = rule.threshold2Turnover, let t2b = rule.threshold2Bonus {
                        HStack {
                            Text("≥ \(MoneyFormatter.short(t2t)) оборота")
                                .font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text("+ \(MoneyFormatter.short(t2b))")
                                .font(AppTheme.Typography.captionBold).foregroundStyle(AppTheme.Colors.success)
                        }
                    }
                }
            }
        }
        .appCard()
    }
}

// MARK: - Profitability / P&L View

struct AdminProfitabilityView: View {
    @StateObject private var vm: AdminProfitabilityViewModel

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminProfitabilityViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                periodPicker
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка P&L...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if let data = vm.data {
                    plCard(data)
                    marginCard(data)
                } else {
                    EmptyStateView(message: "Нет данных за период", icon: "chart.bar.xaxis")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("P&L / Рентабельность")
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.period) { _, _ in Task { await vm.load() } }
    }

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminProfitabilityViewModel.Period.allCases, id: \.self) { p in
                    Button(p.label) {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.period = p }
                    }
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(vm.period == p ? .white : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(vm.period == p ? AnyShapeStyle(AppTheme.Colors.purple) : AnyShapeStyle(Color(hex: 0x1F2937)))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(vm.period == p ? AppTheme.Colors.purple.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private func plCard(_ data: AdminProfitabilityData) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Отчёт о прибылях и убытках", icon: "chart.line.uptrend.xyaxis", iconColor: AppTheme.Colors.purple)

            plRow("Выручка", data.revenue, color: AppTheme.Colors.success, isBold: true)
            Divider().background(AppTheme.Colors.borderSubtle)
            plRow("Себестоимость", data.costOfGoods, color: AppTheme.Colors.error)
            Divider().background(AppTheme.Colors.borderSubtle)
            plRow("Валовая прибыль", data.grossProfit, color: AppTheme.Colors.accentBlue, isBold: true)
            Divider().background(AppTheme.Colors.borderSubtle)
            plRow("Операционные расходы", data.operatingExpenses, color: AppTheme.Colors.warning)
            Divider().background(AppTheme.Colors.borderSubtle)
            plRow("EBITDA", data.ebitda, color: AppTheme.Colors.purple, isBold: true)
            Divider().background(AppTheme.Colors.borderSubtle)
            plRow("Чистая прибыль", data.netProfit, color: (data.netProfit ?? 0) >= 0 ? AppTheme.Colors.success : AppTheme.Colors.error, isBold: true)

            if let breakdown = data.breakdown, !breakdown.isEmpty {
                Divider().background(AppTheme.Colors.borderSubtle)
                Text("ДЕТАЛИЗАЦИЯ").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
                ForEach(breakdown) { line in
                    plRow(line.label, line.amount, color: AppTheme.Colors.textSecondary)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func marginCard(_ data: AdminProfitabilityData) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Маржинальность", icon: "percent", iconColor: AppTheme.Colors.accentPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                let gm = data.grossMargin ?? 0
                let nm = data.netMargin ?? 0
                StatTile(title: "ВАЛОВАЯ МАРЖА", value: String(format: "%.1f%%", gm),
                         color: gm > 0 ? AppTheme.Colors.success : AppTheme.Colors.error,
                         bgColor: gm > 0 ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg,
                         borderColor: gm > 0 ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder)
                StatTile(title: "ЧИСТАЯ МАРЖА", value: String(format: "%.1f%%", nm),
                         color: nm > 0 ? AppTheme.Colors.accentBlue : AppTheme.Colors.error,
                         bgColor: nm > 0 ? AppTheme.Colors.infoBg : AppTheme.Colors.errorBg,
                         borderColor: nm > 0 ? AppTheme.Colors.infoBorder : AppTheme.Colors.errorBorder)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func plRow(_ label: String, _ value: Double?, color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? AppTheme.Typography.captionBold : AppTheme.Typography.caption)
                .foregroundStyle(isBold ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            Spacer()
            Text(MoneyFormatter.detailed(value ?? 0))
                .font(isBold ? AppTheme.Typography.captionBold : AppTheme.Typography.monoCaption)
                .foregroundStyle(color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Categories Module View

struct AdminCategoriesModuleView: View {
    @StateObject private var vm: AdminListModuleViewModel<AdminCategory>
    @EnvironmentObject private var sessionStore: SessionStore
    let service: AdminContractsServicing

    @State private var categoryName = ""
    @State private var accountingGroup = "operating"
    @State private var monthlyBudgetText = "0"
    @State private var showCreateSheet = false

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminListModuleViewModel(loadAction: service.loadCategories))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                summaryCard
                controlsCard
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if vm.items.isEmpty {
                    EmptyStateView(message: "Категории не заданы", icon: "tag")
                } else {
                    categoriesCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Категории")
        .task { await vm.load() }
        .sheet(isPresented: $showCreateSheet) { createSheet }
        .alert("Инфо", isPresented: .constant(vm.infoMessage != nil)) {
            Button("OK") { vm.infoMessage = nil }
        } message: { Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? "")) }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Категории", icon: "tag.fill", iconColor: AppTheme.Colors.accentPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ВСЕГО", value: "\(vm.items.count)",
                         color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "С ЛИМИТОМ", value: "\(vm.items.filter { ($0.monthlyBudget ?? 0) > 0.009 }.count)",
                         color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "ГРУПП", value: "\(Set(vm.items.compactMap { $0.accountingGroup }.filter { !$0.isEmpty }).count)",
                         color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
            }
        }
        .appCard()
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Действия", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.accentBlue)
            Button("Добавить категорию") { showCreateSheet = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .appCard()
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список категорий", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentPrimary)
            ForEach(vm.items) { cat in
                HStack(spacing: AppTheme.Spacing.sm) {
                    Circle()
                        .fill(AppTheme.Colors.accentPrimary.opacity(0.8))
                        .frame(width: 10, height: 10)
                    Text(cat.name)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    SecondaryChip(
                        text: categorySubtitle(cat),
                        color: AppTheme.Colors.textSecondary
                    )
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await vm.runWrite(action: { try await service.deleteCategory(categoryId: cat.id) }, successMessage: "Категория удалена.") }
                        AppHaptics.heavy()
                    } label: { Label("Удалить", systemImage: "trash") }
                }
                if cat.id != vm.items.last?.id { Divider().background(AppTheme.Colors.borderSubtle) }
            }
        }
        .appCard()
    }

    private var createSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionHeader(title: "Новая категория", icon: "tag.fill", iconColor: AppTheme.Colors.accentPrimary)
                TextField("Название категории", text: $categoryName).appInputStyle()
                Picker("Группа учёта", selection: $accountingGroup) {
                    Text("Операционные").tag("operating")
                    Text("ФОТ").tag("payroll")
                    Text("Налоги на ФОТ").tag("payroll_tax")
                    Text("Налог на прибыль").tag("income_tax")
                    Text("Внеоперационные").tag("non_operating")
                    Text("Аванс").tag("payroll_advance")
                }
                .pickerStyle(.menu)
                TextField("Месячный лимит (₸)", text: $monthlyBudgetText)
                    .keyboardType(.decimalPad)
                    .appInputStyle()
                if let error = vm.errorMessage {
                    AlertBanner(message: error, style: .critical)
                }
                Button("Сохранить") {
                    guard !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        vm.errorMessage = "Укажите название."
                        return
                    }
                    Task {
                        await vm.runWrite(action: {
                            try await service.createCategory(.init(
                                name: categoryName,
                                accountingGroup: accountingGroup,
                                monthlyBudget: Double(monthlyBudgetText.replacingOccurrences(of: ",", with: ".")) ?? 0
                            ))
                        }, successMessage: "Категория создана.")
                        showCreateSheet = false
                        categoryName = ""
                        monthlyBudgetText = "0"
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Новая категория")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { showCreateSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func categorySubtitle(_ cat: AdminCategory) -> String {
        if let group = cat.accountingGroup, !group.isEmpty {
            let budget = cat.monthlyBudget ?? 0
            if budget > 0.009 {
                return "\(group) · \(MoneyFormatter.short(budget))"
            }
            return group
        }
        if let t = cat.type, !t.isEmpty {
            if t == "expense" { return "Расход" }
            if t == "income" { return "Доход" }
            return t
        }
        return "—"
    }
}

// MARK: - Income Edit View
struct IncomeEditView: View {
    let item: AdminIncome
    let operators: [AdminOperator]
    let service: AdminContractsServicing
    let onDone: () -> Void

    @State private var selectedOperatorId: String
    @State private var selectedDate: Date
    @State private var shift: String
    @State private var zone: String
    @State private var cashAmount: String
    @State private var kaspiAmount: String
    @State private var onlineAmount: String
    @State private var cardAmount: String
    @State private var comment: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var financeCompanies: [AdminCompany] = []
    @EnvironmentObject private var sessionStore: SessionStore

    init(item: AdminIncome, operators: [AdminOperator], service: AdminContractsServicing, onDone: @escaping () -> Void) {
        self.item = item; self.operators = operators; self.service = service; self.onDone = onDone
        _selectedOperatorId = State(initialValue: item.operatorId ?? "")
        _selectedDate = State(initialValue: isoToDate(item.date) ?? Date())
        _shift = State(initialValue: item.shift ?? "day")
        _zone = State(initialValue: item.zone ?? "")
        _cashAmount = State(initialValue: item.cashAmount.map { "\($0)" } ?? "")
        _kaspiAmount = State(initialValue: item.kaspiAmount.map { "\($0)" } ?? "")
        _onlineAmount = State(initialValue: item.onlineAmount.map { "\($0)" } ?? "")
        _cardAmount = State(initialValue: item.cardAmount.map { "\($0)" } ?? "")
        _comment = State(initialValue: item.comment ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ru_RU")).appInputStyle()
                Picker("Смена", selection: $shift) {
                    Text("Дневная").tag("day")
                    Text("Ночная").tag("night")
                }.pickerStyle(.segmented)
                Picker("Оператор", selection: $selectedOperatorId) {
                    Text("—").tag("")
                    ForEach(operators) { op in Text(op.name).tag(op.id) }
                }.pickerStyle(.menu).appInputStyle()
                TextField("Зона", text: $zone).appInputStyle()
                TextField("Наличные", text: $cashAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Kaspi", text: $kaspiAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Карта", text: $cardAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Онлайн", text: $onlineAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Комментарий", text: $comment).appInputStyle()
                if let e = errorMessage { AlertBanner(message: e, style: .critical) }
                Button("Сохранить изменения") {
                    isLoading = true
                    Task {
                        do {
                            let companyId = item.companyId.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                                ?? sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies)
                                ?? ""
                            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                            try await service.updateIncome(id: item.id, payload: .init(
                                date: fmt.string(from: selectedDate),
                                companyId: companyId,
                                operatorId: selectedOperatorId,
                                shift: shift,
                                zone: zone.nonEmpty,
                                cashAmount: Double(cashAmount) ?? 0,
                                kaspiAmount: Double(kaspiAmount) ?? 0,
                                onlineAmount: Double(onlineAmount) ?? 0,
                                cardAmount: Double(cardAmount) ?? 0,
                                comment: comment.nonEmpty
                            ))
                            AppHaptics.success()
                            onDone()
                        } catch {
                            errorMessage = APIErrorMapper().map(error: error).errorDescription
                            AppHaptics.error()
                        }
                        isLoading = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task {
            if let list = try? await service.loadCompanies() { financeCompanies = list }
        }
    }
}

// MARK: - Expense Edit View
struct ExpenseEditView: View {
    let item: AdminExpense
    let operators: [AdminOperator]
    let service: AdminContractsServicing
    let onDone: () -> Void

    @State private var selectedOperatorId: String
    @State private var selectedDate: Date
    @State private var category: String
    @State private var cashAmount: String
    @State private var kaspiAmount: String
    @State private var comment: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var financeCompanies: [AdminCompany] = []
    @EnvironmentObject private var sessionStore: SessionStore

    init(item: AdminExpense, operators: [AdminOperator], service: AdminContractsServicing, onDone: @escaping () -> Void) {
        self.item = item; self.operators = operators; self.service = service; self.onDone = onDone
        _selectedOperatorId = State(initialValue: item.operatorId ?? "")
        _selectedDate = State(initialValue: isoToDate(item.date) ?? Date())
        _category = State(initialValue: item.category)
        _cashAmount = State(initialValue: item.cashAmount.map { "\($0)" } ?? "")
        _kaspiAmount = State(initialValue: item.kaspiAmount.map { "\($0)" } ?? "")
        _comment = State(initialValue: item.comment ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ru_RU")).appInputStyle()
                TextField("Категория", text: $category).appInputStyle()
                Picker("Оператор", selection: $selectedOperatorId) {
                    Text("—").tag("")
                    ForEach(operators) { op in Text(op.name).tag(op.id) }
                }.pickerStyle(.menu).appInputStyle()
                TextField("Наличные", text: $cashAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Kaspi", text: $kaspiAmount).keyboardType(.decimalPad).appInputStyle()
                TextField("Комментарий", text: $comment).appInputStyle()
                if let e = errorMessage { AlertBanner(message: e, style: .critical) }
                Button("Сохранить изменения") {
                    isLoading = true
                    Task {
                        do {
                            let companyId = item.companyId.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                                ?? sessionStore.roleContext?.resolvedDatabaseCompanyId(companies: financeCompanies)
                                ?? ""
                            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                            try await service.updateExpense(id: item.id, payload: .init(
                                date: fmt.string(from: selectedDate),
                                companyId: companyId,
                                operatorId: selectedOperatorId,
                                category: category,
                                cashAmount: Double(cashAmount) ?? 0,
                                kaspiAmount: Double(kaspiAmount) ?? 0,
                                comment: comment.nonEmpty
                            ))
                            AppHaptics.success()
                            onDone()
                        } catch {
                            errorMessage = APIErrorMapper().map(error: error).errorDescription
                            AppHaptics.error()
                        }
                        isLoading = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task {
            if let list = try? await service.loadCompanies() { financeCompanies = list }
        }
    }
}

private func isoToDate(_ str: String) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: str)
}
