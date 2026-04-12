import SwiftUI
import Charts

private struct DailyDrilldownItem: Identifiable {
    let id: String
}

struct AdminAnalyticsView: View {
    @StateObject private var vm: AdminAnalyticsViewModel
    @State private var quickRange: String = "week"
    @State private var goalPeriod = ""
    @State private var goalIncome = ""
    @State private var goalExpense = ""
    @State private var goalNote = ""
    @State private var selectedDayForDrilldown: String?

    init(service: AdminAnalyticsServicing) {
        _vm = StateObject(wrappedValue: AdminAnalyticsViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                periodControls
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.loadAll() } })
                } else {
                    monthlyCard
                    kpiCard
                    goalsCard
                    forecastCard
                    weeklyReportCard
                    analysisCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Аналитика")
        .task { await vm.loadAll() }
        .alert("Готово", isPresented: Binding(
            get: { vm.infoMessage != nil },
            set: { if !$0 { vm.infoMessage = nil } }
        ), actions: {
            Button("OK") { vm.infoMessage = nil }
        }, message: {
            Text(ServerJSONPlaintext.normalize(vm.infoMessage ?? ""))
        })
        .sheet(item: Binding(
            get: { selectedDayForDrilldown.map(DailyDrilldownItem.init) },
            set: { selectedDayForDrilldown = $0?.id }
        )) { item in
            dailyTransactionsSheet(item.id)
        }
    }

    // MARK: - Period

    private var periodControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Период и фильтры", icon: "calendar", iconColor: AppTheme.Colors.accentPrimary)

            QuickRangePicker(
                selected: $quickRange,
                options: [
                    (key: "week", label: "Эта неделя"),
                    (key: "prev_week", label: "Прошлая"),
                    (key: "month", label: "Этот месяц")
                ]
            )
            .onChange(of: quickRange) { _, newValue in
                applyQuickRange(newValue)
            }

            labeledField("Начало месяца (ГГГГ-ММ-ДД)") {
                TextField("2025-04-01", text: $vm.period.monthStart)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .appInputStyle()
            }
            labeledField("Начало недели") {
                TextField("2025-04-07", text: $vm.period.weekStart)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .appInputStyle()
            }
            labeledField("Конец недели") {
                TextField("2025-04-13", text: $vm.period.weekEnd)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .appInputStyle()
            }
            labeledField("ID компании (необязательно)") {
                TextField("Оставьте пустым для всех", text: $vm.selectedCompanyId).appInputStyle()
            }

            if !isPeriodInputValid {
                AlertBanner(
                    message: "Проверьте формат дат: используйте ГГГГ-ММ-ДД.",
                    style: .warning
                )
            }

            Button {
                Task { await vm.loadAll() }
            } label: {
                Text("Обновить данные")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(vm.isLoading || !isPeriodInputValid)

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Предыдущая неделя") {
                    Task { await vm.switchToPreviousWeek() }
                }
                .buttonStyle(GhostButtonStyle())

                Button("Пересчитать KPI-планы") {
                    Task { await vm.generatePlans() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(vm.isActionLoading)
            }
        }
        .modifier(AppCardStyle())
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Typography.micro)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.Colors.textMuted)
            content()
        }
    }

    // MARK: - Monthly

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Месячный отчёт", icon: "doc.text.fill", iconColor: AppTheme.Colors.info)

            if let monthly = vm.monthly {
                Text("\(monthly.month).\(monthly.year)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    StatTile(
                        title: "Оборот",
                        value: MoneyFormatter.detailed(monthly.totals.total),
                        color: AppTheme.Colors.success,
                        bgColor: AppTheme.Colors.successBg,
                        borderColor: AppTheme.Colors.successBorder
                    )
                    StatTile(
                        title: "Транзакций",
                        value: "\(monthly.totals.count)",
                        color: AppTheme.Colors.accentBlue,
                        bgColor: AppTheme.Colors.infoBg,
                        borderColor: AppTheme.Colors.infoBorder
                    )
                    StatTile(
                        title: "Средний чек",
                        value: MoneyFormatter.detailed(monthly.totals.avgCheck),
                        color: AppTheme.Colors.accentPrimary,
                        bgColor: AppTheme.Colors.accentSoft,
                        borderColor: AppTheme.Colors.accentPrimary.opacity(0.25)
                    )
                    StatTile(
                        title: "Скидки",
                        value: MoneyFormatter.detailed(monthly.totals.discount),
                        color: AppTheme.Colors.warning,
                        bgColor: AppTheme.Colors.warningBg,
                        borderColor: AppTheme.Colors.warningBorder
                    )
                }

                Text("Структура оплат")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.xs)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    paymentMini(title: "Наличные", value: monthly.totals.cash, color: AppTheme.Colors.cashColor)
                    paymentMini(title: "Kaspi", value: monthly.totals.kaspi, color: AppTheme.Colors.kaspiColor)
                    paymentMini(title: "Карта", value: monthly.totals.card, color: AppTheme.Colors.cardColor)
                    paymentMini(title: "Онлайн", value: monthly.totals.online, color: AppTheme.Colors.onlineColor)
                }

                if !vm.sortedMonthlyDaily.isEmpty {
                    Text("Оборот по дням")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, AppTheme.Spacing.sm)

                    Chart(vm.sortedMonthlyDaily) { row in
                        BarMark(
                            x: .value("День", dayLabel(row.date)),
                            y: .value("Оборот", row.total)
                        )
                        .foregroundStyle(AppTheme.Colors.accentPrimary.gradient)
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
                                    Text(MoneyFormatter.short(v))
                                        .font(AppTheme.Typography.micro)
                                        .foregroundStyle(AppTheme.Colors.textMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 200)

                    Text("Drill-down по дням")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, AppTheme.Spacing.sm)

                    VStack(spacing: 0) {
                        ForEach(vm.sortedMonthlyDaily) { row in
                            HStack(spacing: AppTheme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.date)
                                        .font(AppTheme.Typography.captionBold)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Text("Транзакций: \(row.count)")
                                        .font(AppTheme.Typography.micro)
                                        .foregroundStyle(AppTheme.Colors.textMuted)
                                }
                                Spacer()
                                Text(MoneyFormatter.short(row.total))
                                    .font(AppTheme.Typography.monoCaption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Button("Транзакции") {
                                    selectedDayForDrilldown = row.date
                                    Task { await vm.loadDailyTransactions(day: row.date) }
                                }
                                .buttonStyle(GhostButtonStyle())
                            }
                            .padding(.vertical, 6)
                            if row.id != vm.sortedMonthlyDaily.last?.id {
                                Divider().background(AppTheme.Colors.borderSubtle)
                            }
                        }
                    }
                }
            } else {
                Text("Пока нет данных")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    @ViewBuilder
    private func dailyTransactionsSheet(_ day: String) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionHeader(title: "Транзакции за \(day)", icon: "list.bullet.rectangle.portrait", iconColor: AppTheme.Colors.accentBlue)
                if vm.isDayTransactionsLoading {
                    LoadingStateView(message: "Загрузка чеков...")
                } else if let error = vm.dayTransactionsError {
                    ErrorStateView(message: error) { Task { await vm.loadDailyTransactions(day: day) } }
                } else if let payload = vm.selectedDayTransactions, !payload.transactions.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(payload.transactions) { tx in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Чек #\(tx.id.suffix(6))")
                                            .font(AppTheme.Typography.captionBold)
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        Spacer()
                                        Text(MoneyFormatter.short(tx.totalAmount))
                                            .font(AppTheme.Typography.monoCaption)
                                            .foregroundStyle(AppTheme.Colors.success)
                                    }
                                    HStack(spacing: 8) {
                                        Text("Нал: \(MoneyFormatter.short(tx.cashAmount))")
                                        Text("Kaspi: \(MoneyFormatter.short(tx.kaspiAmount))")
                                        Text("Карта: \(MoneyFormatter.short(tx.cardAmount))")
                                        Text("Онлайн: \(MoneyFormatter.short(tx.onlineAmount))")
                                    }
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                                }
                                .padding(.vertical, 8)
                                if tx.id != payload.transactions.last?.id {
                                    Divider().background(AppTheme.Colors.borderSubtle)
                                }
                            }
                        }
                    }
                } else {
                    EmptyStateView(message: "Транзакций за день не найдено", icon: "tray")
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Детали дня")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { selectedDayForDrilldown = nil }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func paymentMini(title: String, value: Double, color: Color) -> some View {
        StatTile(
            title: title,
            value: MoneyFormatter.short(value),
            color: color,
            bgColor: color.opacity(0.10),
            borderColor: color.opacity(0.22)
        )
    }

    private func dayLabel(_ iso: String) -> String {
        if let last = iso.split(separator: "-").last {
            return String(last)
        }
        return iso
    }

    // MARK: - KPI

    private var kpiCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "KPI и неделя", icon: "chart.xyaxis.line", iconColor: AppTheme.Colors.accentBlue)

            if vm.kpiTrendPoints.isEmpty {
                Text("Пока нет данных по выбранной неделе")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(vm.kpiTrendPoints, id: \.0) { point in
                    AreaMark(
                        x: .value("Дата", point.0),
                        y: .value("Оборот", point.1)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.accentPrimary.opacity(0.35), AppTheme.Colors.accentPrimary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Дата", point.0),
                        y: .value("Оборот", point.1)
                    )
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
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
                                Text(MoneyFormatter.short(v))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }

            let planCount = vm.kpi?.collectivePlans.count ?? 0
            Text("Коллективных планов: \(planCount)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if let plans = vm.kpi?.collectivePlans, !plans.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(plans.prefix(6)) { plan in
                        HStack {
                            Text(plan.companyCode ?? "Все компании")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("нед: \(MoneyFormatter.short(plan.turnoverTargetWeek))")
                                    .font(AppTheme.Typography.monoCaption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Text("мес: \(MoneyFormatter.short(plan.turnoverTargetMonth))")
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                        .padding(.vertical, 4)
                        if plan.id != plans.prefix(6).last?.id {
                            Divider().background(AppTheme.Colors.borderSubtle)
                        }
                    }
                }
                .padding(.top, AppTheme.Spacing.xs)
            }

            if !vm.weekdayShareSorted.isEmpty {
                Text("Доля по дням недели")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.sm)

                Chart(vm.weekdayShareSorted, id: \.name) { row in
                    BarMark(
                        x: .value("Доля", row.share),
                        y: .value("День", row.name)
                    )
                    .foregroundStyle(AppTheme.Colors.purple.gradient)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f%%", v * 100))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .frame(height: CGFloat(min(220, max(120, vm.weekdayShareSorted.count * 28))))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    // MARK: - Goals

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Цели", icon: "target", iconColor: AppTheme.Colors.warning)

            if vm.goals.isEmpty {
                Text("Целей за период пока нет")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(vm.goals.prefix(8)) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SecondaryChip(text: goal.period, color: AppTheme.Colors.info)
                            Spacer()
                        }
                        Text("Доход: \(MoneyFormatter.detailed(goal.targetIncome ?? 0)) · Расход: \(MoneyFormatter.detailed(goal.targetExpense ?? 0))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        if let note = goal.note, !note.isEmpty {
                            Text(note)
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                    if goal.id != vm.goals.prefix(8).last?.id {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }

            Divider().padding(.vertical, AppTheme.Spacing.xs)

            SectionHeader(title: "Новая или правка цели", icon: "plus.circle", iconColor: AppTheme.Colors.success)

            labeledField("Период (ГГГГ-ММ)") {
                TextField("2025-04", text: $goalPeriod)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .appInputStyle()
            }
            labeledField("Целевой доход (₸)") {
                TextField("0", text: $goalIncome)
                    .keyboardType(.decimalPad)
                    .appInputStyle()
            }
            labeledField("Целевой расход (₸)") {
                TextField("0", text: $goalExpense)
                    .keyboardType(.decimalPad)
                    .appInputStyle()
            }
            labeledField("Комментарий") {
                TextField("Необязательно", text: $goalNote).appInputStyle()
            }

            if !isGoalInputValid {
                AlertBanner(
                    message: "Проверьте период цели (ГГГГ-ММ) и числовые значения дохода/расхода.",
                    style: .warning
                )
            }

            Button {
                let income = Double(goalIncome.replacingOccurrences(of: ",", with: ".")) ?? 0
                let expense = Double(goalExpense.replacingOccurrences(of: ",", with: ".")) ?? 0
                Task { await vm.upsertGoal(period: goalPeriod, income: income, expense: expense, note: goalNote) }
            } label: {
                Text("Сохранить цель")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(vm.isActionLoading || !isGoalInputValid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    // MARK: - AI blocks

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "AI-прогноз", icon: "sparkles", iconColor: AppTheme.Colors.purple)

            if !vm.forecastWeeklySeries.isEmpty {
                Chart {
                    ForEach(Array(vm.forecastWeeklySeries.enumerated()), id: \.offset) { _, row in
                        LineMark(
                            x: .value("Неделя", row.label),
                            y: .value("Доход", row.income)
                        )
                        .foregroundStyle(AppTheme.Colors.success)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Неделя", row.label),
                            y: .value("Расход", row.expense)
                        )
                        .foregroundStyle(AppTheme.Colors.warning)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
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
                                Text(MoneyFormatter.short(v))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                Text("Нет рядов прогноза для графика, доступен текстовый прогноз ниже.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            aiProse(vm.forecastText.isEmpty ? "Пока нет текстового прогноза." : vm.forecastText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    private var weeklyReportCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Еженедельный отчёт AI", icon: "doc.richtext", iconColor: AppTheme.Colors.accentBlue)
            aiProse(vm.weeklyReportText.isEmpty ? "Пока нет данных за выбранный интервал." : vm.weeklyReportText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "AI-анализ", icon: "brain.head.profile", iconColor: AppTheme.Colors.onlineColor)
            aiProse(vm.analysisText.isEmpty ? "Пока нет данных." : vm.analysisText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppCardStyle())
    }

    private func aiProse(_ text: String) -> some View {
        Text(ServerJSONPlaintext.normalize(text))
            .font(AppTheme.Typography.callout)
            .lineSpacing(3)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfaceSecondary.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .textSelection(.enabled)
    }

    private var isPeriodInputValid: Bool {
        isISODate(vm.period.monthStart) && isISODate(vm.period.weekStart) && isISODate(vm.period.weekEnd)
    }

    private var isGoalInputValid: Bool {
        let trimmedPeriod = goalPeriod.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isYearMonth(trimmedPeriod) else { return false }
        return parsedAmount(goalIncome) != nil && parsedAmount(goalExpense) != nil
    }

    private func parsedAmount(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func isISODate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }

    private func isYearMonth(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return false }
        return year >= 2000 && year <= 2100 && month >= 1 && month <= 12
    }

    private func applyQuickRange(_ key: String) {
        let calendar = Calendar(identifier: .iso8601)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        switch key {
        case "prev_week":
            let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) ?? prevStart
            vm.period.weekStart = formatter.string(from: prevStart)
            vm.period.weekEnd = formatter.string(from: prevEnd)
            vm.period.dateFrom = vm.period.weekStart
            vm.period.dateTo = vm.period.weekEnd
        case "month":
            vm.period.monthStart = formatter.string(from: monthStart)
            vm.period.weekStart = formatter.string(from: weekStart)
            vm.period.weekEnd = formatter.string(from: weekEnd)
            vm.period.dateFrom = vm.period.monthStart
            vm.period.dateTo = formatter.string(from: now)
        default:
            vm.period.monthStart = formatter.string(from: monthStart)
            vm.period.weekStart = formatter.string(from: weekStart)
            vm.period.weekEnd = formatter.string(from: weekEnd)
            vm.period.dateFrom = vm.period.weekStart
            vm.period.dateTo = vm.period.weekEnd
        }
    }
}
