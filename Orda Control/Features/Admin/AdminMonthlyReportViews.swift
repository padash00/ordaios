import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class AdminMonthlyReportViewModel: ObservableObject {
    @Published var report: MonthlyReportData?
    @Published var dayTransactions: [PointTransaction] = []
    @Published var selectedDay: String?
    @Published var isLoading = false
    @Published var isDayLoading = false
    @Published var error: String?
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published var selectedCompanyId: String = ""
    @Published var companies: [AdminCompany] = []

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
        let now = Date()
        let cal = Calendar.current
        selectedYear = cal.component(.year, from: now)
        selectedMonth = cal.component(.month, from: now)
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let companiesResult = service.loadCompanies()
            async let reportResult = service.loadMonthlyReport(
                year: selectedYear,
                month: selectedMonth,
                companyId: selectedCompanyId.isEmpty ? nil : selectedCompanyId
            )
            companies = try await companiesResult
            report = try await reportResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectDay(_ day: String) async {
        selectedDay = day
        isDayLoading = true
        do {
            dayTransactions = try await service.loadDayTransactions(
                day: day,
                companyId: selectedCompanyId.isEmpty ? nil : selectedCompanyId
            )
        } catch {
            dayTransactions = []
        }
        isDayLoading = false
    }

    var monthName: String {
        let months = ["Январь","Февраль","Март","Апрель","Май","Июнь",
                      "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]
        guard selectedMonth >= 1 && selectedMonth <= 12 else { return "" }
        return months[selectedMonth - 1]
    }
}

// MARK: - Main View

struct AdminMonthlyReportView: View {
    @StateObject private var vm: AdminMonthlyReportViewModel
    @State private var showDaySheet = false

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminMonthlyReportViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                controlsCard
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка отчёта...")
                } else if let err = vm.error {
                    ErrorStateView(message: err) { Task { await vm.load() } }
                } else if let report = vm.report {
                    reportContent(report)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Месячный отчёт")
        .task { await vm.load() }
        .sheet(isPresented: $showDaySheet) {
            dayDetailSheet
        }
    }

    private var controlsCard: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Picker("Год", selection: $vm.selectedYear) {
                    ForEach((2023...Calendar.current.component(.year, from: Date())), id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

                Picker("Месяц", selection: $vm.selectedMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(monthShort(m)).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
            if !vm.companies.isEmpty {
                Picker("Точка", selection: $vm.selectedCompanyId) {
                    Text("Все точки").tag("")
                    ForEach(vm.companies) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
            Button("Загрузить") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .appCard()
    }

    @ViewBuilder
    private func reportContent(_ report: MonthlyReportData) -> some View {
        // Totals summary
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("\(vm.monthName) \(vm.selectedYear)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            let t = report.totals
            HStack(spacing: AppTheme.Spacing.md) {
                totalPill(title: "Выручка", value: formatMoney(Double(t.total)), color: AppTheme.Colors.success)
                totalPill(title: "Продаж", value: "\(t.count)", color: AppTheme.Colors.accentBlue)
                totalPill(title: "Ср. чек", value: formatMoney(Double(t.avgCheck)), color: AppTheme.Colors.purple)
            }
            Divider()
            paymentRow(label: "Наличные", amount: Double(t.cash))
            paymentRow(label: "Kaspi", amount: Double(t.kaspi))
            paymentRow(label: "Карта", amount: Double(t.card))
            paymentRow(label: "Онлайн", amount: Double(t.online))
            if t.discount > 0 {
                paymentRow(label: "Скидки", amount: Double(t.discount))
            }
        }
        .appCard()

        // Daily grid
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("По дням")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(["Пн","Вт","Ср","Чт","Пт","Сб","Вс"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                }
                ForEach(paddingDays(report), id: \.self) { _ in
                    Color.clear.frame(height: 48)
                }
                ForEach(report.daily) { row in
                    dayCell(row: row)
                }
            }
        }
        .appCard()

        // Daily table
        VStack(alignment: .leading, spacing: 4) {
            Text("Детали по дням")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.bottom, 4)
            ForEach(report.daily) { row in
                Button {
                    Task {
                        await vm.selectDay(row.date)
                        showDaySheet = true
                    }
                } label: {
                    HStack {
                        Text(dayLabel(row.date))
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatMoney(Double(row.total)))
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(row.total > 0 ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
                            Text("\(row.count) продаж")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .appCard()
    }

    private func dayCell(row: DailySaleRow) -> some View {
        let dayNum = row.date.split(separator: "-").last.map { String($0) } ?? ""
        let hasData = row.total > 0
        return VStack(spacing: 2) {
            Text(dayNum)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hasData ? AppTheme.Colors.textPrimary : AppTheme.Colors.textMuted)
            if hasData {
                Text(formatMoneyShort(Double(row.total)))
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.Colors.success)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(hasData ? AppTheme.Colors.success.opacity(0.1) : AppTheme.Colors.surfacePrimary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            if hasData {
                Task {
                    await vm.selectDay(row.date)
                    showDaySheet = true
                }
            }
        }
    }

    private var dayDetailSheet: some View {
        NavigationStack {
            Group {
                if vm.isDayLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if vm.dayTransactions.isEmpty {
                    EmptyStateView(message: "Нет транзакций", icon: "doc")
                } else {
                    List(vm.dayTransactions) { tx in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatMoney(tx.totalAmount))
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.success)
                            HStack(spacing: 12) {
                                if let c = tx.cashAmount, c > 0 { amountChip("Нал", c) }
                                if let k = tx.kaspiAmount, k > 0 { amountChip("Kaspi", k) }
                                if let ca = tx.cardAmount, ca > 0 { amountChip("Карта", ca) }
                                if let o = tx.onlineAmount, o > 0 { amountChip("Онлайн", o) }
                            }
                            Text(tx.saleDate)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(vm.selectedDay.map { dayLabel($0) } ?? "День")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { showDaySheet = false }
                }
            }
        }
    }

    private func amountChip(_ label: String, _ amount: Double) -> some View {
        Text("\(label): \(formatMoney(amount))")
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.Colors.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.Colors.surfacePrimary)
            .clipShape(Capsule())
    }

    private func totalPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func paymentRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(formatMoney(amount))
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    private func paddingDays(_ report: MonthlyReportData) -> [Int] {
        guard let firstDay = report.daily.first else { return [] }
        let parts = firstDay.date.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return [] }
        var weekday = cal.component(.weekday, from: date) - 2
        if weekday < 0 { weekday += 7 }
        return Array(0..<weekday)
    }

    private func dayLabel(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3 else { return iso }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
    }

    private func monthShort(_ m: Int) -> String {
        let months = ["Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        guard m >= 1 && m <= 12 else { return "" }
        return months[m - 1]
    }

    private func formatMoney(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fМ ₸", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.0fK ₸", v / 1_000) }
        return String(format: "%.0f ₸", v)
    }

    private func formatMoneyShort(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fМ", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.0fK", v / 1_000) }
        return String(format: "%.0f", v)
    }
}
