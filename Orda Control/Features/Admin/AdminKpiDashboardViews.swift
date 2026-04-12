import SwiftUI
import Charts
import Combine

// MARK: - ViewModel

@MainActor
final class AdminKpiViewModel: ObservableObject {
    @Published var data: KpiDashboardData?
    @Published var isLoading = false
    @Published var error: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let (monthStart, weekStart, weekEnd) = Self.currentPeriod()
            data = try await service.loadKpiDashboard(monthStart: monthStart, weekStart: weekStart, weekEnd: weekEnd)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private static func currentPeriod() -> (monthStart: String, weekStart: String, weekEnd: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let now = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"

        // Month start
        var monthComps = cal.dateComponents([.year, .month], from: now)
        monthComps.day = 1
        let monthStart = cal.date(from: monthComps) ?? now

        // Week start (Monday)
        let weekComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekStart = cal.date(from: weekComps) ?? now
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? now

        return (f.string(from: monthStart), f.string(from: weekStart), f.string(from: weekEnd))
    }
}

// MARK: - Main View

struct AdminKpiDashboardView: View {
    @StateObject private var vm: AdminKpiViewModel

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminKpiViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка KPI...")
                } else if let err = vm.error {
                    ErrorStateView(message: err) { Task { await vm.load() } }
                } else if let data = vm.data {
                    kpiContent(data)
                } else {
                    EmptyStateView(message: "Нет данных KPI", icon: "chart.bar.xaxis")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("KPI Dashboard")
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func kpiContent(_ data: KpiDashboardData) -> some View {
        // Week totals
        let weekTotal = data.weekRows.reduce(0) { $0 + $1.total }
        let monthTotal = data.monthRows.reduce(0) { $0 + $1.total }

        HStack(spacing: AppTheme.Spacing.md) {
            kpiPill(title: "Неделя", value: formatMoney(weekTotal), color: AppTheme.Colors.accentBlue)
            kpiPill(title: "Месяц", value: formatMoney(monthTotal), color: AppTheme.Colors.purple)
        }
        .appCard()

        // Plan fulfillment
        if !data.collectivePlans.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Планы")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                ForEach(data.collectivePlans) { plan in
                    planRow(plan: plan, weekActual: weekTotal, monthActual: monthTotal)
                }
            }
            .appCard()
        }

        // Week chart
        if !data.weekRows.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Выручка за неделю")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Chart {
                    ForEach(data.weekRows, id: \.date) { row in
                        BarMark(
                            x: .value("Дата", shortDate(row.date)),
                            y: .value("Сумма", row.total)
                        )
                        .foregroundStyle(AppTheme.Colors.accentBlue.gradient)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v >= 1_000_000 ? String(format: "%.0fМ", v/1_000_000) : v >= 1_000 ? String(format: "%.0fK", v/1_000) : String(format: "%.0f", v))
                                    .font(AppTheme.Typography.micro)
                            }
                        }
                    }
                }
            }
            .appCard()
        }

        // Month chart
        if !data.monthRows.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Выручка за месяц")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Chart {
                    ForEach(data.monthRows, id: \.date) { row in
                        BarMark(
                            x: .value("Дата", shortDate(row.date)),
                            y: .value("Сумма", row.total)
                        )
                        .foregroundStyle(AppTheme.Colors.purple.gradient)
                        .cornerRadius(2)
                    }
                }
                .frame(height: 120)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v >= 1_000_000 ? String(format: "%.0fМ", v/1_000_000) : v >= 1_000 ? String(format: "%.0fK", v/1_000) : String(format: "%.0f", v))
                                    .font(AppTheme.Typography.micro)
                            }
                        }
                    }
                }
            }
            .appCard()
        }

        // Weekday distribution
        if !data.weekdayShare.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Распределение по дням")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                let sorted = data.weekdayShare.sorted { $0.key < $1.key }
                Chart {
                    ForEach(sorted, id: \.key) { entry in
                        SectorMark(
                            angle: .value("Доля", entry.value),
                            innerRadius: .ratio(0.5)
                        )
                        .foregroundStyle(by: .value("День", weekdayName(entry.key)))
                    }
                }
                .frame(height: 160)
            }
            .appCard()
        }
    }

    private func planRow(plan: KpiPlan, weekActual: Double, monthActual: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.companyCode ?? plan.entityType)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Неделя")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    if plan.turnoverTargetWeek > 0 {
                        let pct = min(weekActual / plan.turnoverTargetWeek, 1.0)
                        ProgressView(value: pct)
                            .tint(pct >= 1.0 ? AppTheme.Colors.success : AppTheme.Colors.accentBlue)
                        Text(String(format: "%.0f / %.0f ₸", weekActual, plan.turnoverTargetWeek))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    } else {
                        Text("Нет плана").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Месяц")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    if plan.turnoverTargetMonth > 0 {
                        let pct = min(monthActual / plan.turnoverTargetMonth, 1.0)
                        ProgressView(value: pct)
                            .tint(pct >= 1.0 ? AppTheme.Colors.success : AppTheme.Colors.purple)
                        Text(String(format: "%.0f / %.0f ₸", monthActual, plan.turnoverTargetMonth))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    } else {
                        Text("Нет плана").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func kpiPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMoney(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fМ ₸", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0fK ₸", value / 1_000)
        }
        return String(format: "%.0f ₸", value)
    }

    private func shortDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3 else { return iso }
        return "\(parts[2]).\(parts[1])"
    }

    private func weekdayName(_ key: String) -> String {
        let map = ["1": "Пн","2": "Вт","3": "Ср","4": "Чт","5": "Пт","6": "Сб","7": "Вс"]
        return map[key] ?? key
    }
}
