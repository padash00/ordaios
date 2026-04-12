import SwiftUI
import Charts
import Combine

// MARK: - Models

struct CashflowItem: Decodable, Identifiable {
    let id: String
    let date: String?
    let type: String?       // "income" | "expense"
    let category: String?
    let amount: Double?
    let description: String?
    let paymentMethod: String?

    var isIncome: Bool { (type ?? "").lowercased() == "income" }
    var displayAmount: Double { amount ?? 0 }
}

struct CashflowSummary: Decodable {
    let totalIncome: Double?
    let totalExpense: Double?
    let netCashflow: Double?
    let byCategory: [String: Double]?

    var net: Double { (totalIncome ?? 0) - (totalExpense ?? 0) }
}

private struct CashflowResponse: Decodable {
    let items: [CashflowItem]?
    let data: [CashflowItem]?
    let summary: CashflowSummary?

    var resolved: [CashflowItem] { items ?? data ?? [] }
}

// MARK: - ViewModel

@MainActor
final class AdminCashflowViewModel: ObservableObject {
    @Published var items: [CashflowItem] = []
    @Published var summary: CashflowSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod = "month"
    @Published var fromDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var toDate = Date()

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var totalIncome: Double { summary?.totalIncome ?? items.filter(\.isIncome).reduce(0) { $0 + $1.displayAmount } }
    var totalExpense: Double { summary?.totalExpense ?? items.filter { !$0.isIncome }.reduce(0) { $0 + $1.displayAmount } }
    var netFlow: Double { totalIncome - totalExpense }
    var isPositive: Bool { netFlow >= 0 }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let fromStr = f.string(from: fromDate)
            let toStr = f.string(from: toDate)
            let endpoint = APIEndpoint(
                path: ContractEndpoint.api_admin_cashflow.rawValue,
                method: .GET,
                queryItems: [
                    URLQueryItem(name: "from", value: fromStr),
                    URLQueryItem(name: "to", value: toStr)
                ]
            )
            let response: CashflowResponse = try await apiClient.request(endpoint)
            items = response.resolved
            summary = response.summary
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - View

struct AdminCashflowView: View {
    @StateObject private var vm: AdminCashflowViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminCashflowViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                periodPicker
                summaryCards
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка денежных потоков…")
                } else if let err = vm.errorMessage {
                    ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
                } else if vm.items.isEmpty {
                    EmptyStateView(message: "Нет транзакций за выбранный период")
                } else {
                    flowChart
                    itemsList
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Денежные потоки")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.fromDate) { _, _ in Task { await vm.load() } }
        .onChange(of: vm.toDate) { _, _ in Task { await vm.load() } }
    }

    // MARK: Period Picker

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Период", icon: "calendar", iconColor: AppTheme.Colors.accentBlue)
            HStack(spacing: AppTheme.Spacing.sm) {
                DatePicker("От", selection: $vm.fromDate, displayedComponents: .date)
                    .labelsHidden()
                    .appInputStyle()
                Text("—")
                    .foregroundStyle(AppTheme.Colors.textMuted)
                DatePicker("До", selection: $vm.toDate, displayedComponents: .date)
                    .labelsHidden()
                    .appInputStyle()
            }

            HStack(spacing: 6) {
                quickPeriodBtn("7д", days: -7)
                quickPeriodBtn("30д", days: -30)
                quickPeriodBtn("90д", days: -90)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    @ViewBuilder
    private func quickPeriodBtn(_ label: String, days: Int) -> some View {
        Button(label) {
            vm.fromDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
            vm.toDate = Date()
        }
        .font(AppTheme.Typography.captionBold)
        .foregroundStyle(AppTheme.Colors.accentBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.infoBg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.Colors.infoBorder, lineWidth: 1))
        .buttonStyle(.plain)
    }

    // MARK: Summary Cards

    private var summaryCards: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            summaryTile(
                title: "ДОХОДЫ",
                value: MoneyFormatter.short(vm.totalIncome),
                color: AppTheme.Colors.success,
                bg: AppTheme.Colors.successBg,
                border: AppTheme.Colors.successBorder,
                icon: "arrow.up.circle.fill"
            )
            summaryTile(
                title: "РАСХОДЫ",
                value: MoneyFormatter.short(vm.totalExpense),
                color: AppTheme.Colors.error,
                bg: AppTheme.Colors.errorBg,
                border: AppTheme.Colors.errorBorder,
                icon: "arrow.down.circle.fill"
            )
            summaryTile(
                title: "ЧИСТЫЙ",
                value: MoneyFormatter.short(abs(vm.netFlow)),
                color: vm.isPositive ? AppTheme.Colors.success : AppTheme.Colors.error,
                bg: vm.isPositive ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg,
                border: vm.isPositive ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder,
                icon: vm.isPositive ? "plus.circle.fill" : "minus.circle.fill"
            )
        }
    }

    @ViewBuilder
    private func summaryTile(title: String, value: String, color: Color, bg: Color, border: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.micro)
                .tracking(1)
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.sm)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: Flow Chart

    @ViewBuilder
    private var flowChart: some View {
        let grouped = groupedByDate()
        if !grouped.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Динамика", icon: "chart.line.uptrend.xyaxis", iconColor: AppTheme.Colors.accentPrimary)

                Chart {
                    ForEach(grouped, id: \.date) { point in
                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("Доходы", point.income)
                        )
                        .foregroundStyle(AppTheme.Colors.success)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("Расходы", point.expense)
                        )
                        .foregroundStyle(AppTheme.Colors.error)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v, format: FloatingPointFormatStyle<Double>().notation(.compactName))
                            }
                        }
                    }
                }

                HStack(spacing: AppTheme.Spacing.md) {
                    legendDot(AppTheme.Colors.success, "Доходы")
                    legendDot(AppTheme.Colors.error, "Расходы")
                }
                .font(AppTheme.Typography.caption)
            }
            .padding(AppTheme.Spacing.md)
            .appCard()
        }
    }

    @ViewBuilder
    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(AppTheme.Colors.textMuted)
        }
    }

    private struct DayPoint { let date: String; let income: Double; let expense: Double }

    private func groupedByDate() -> [DayPoint] {
        var byDate: [String: (Double, Double)] = [:]
        for item in vm.items {
            let key = String((item.date ?? "").prefix(10))
            guard !key.isEmpty else { continue }
            var (inc, exp) = byDate[key] ?? (0, 0)
            if item.isIncome { inc += item.displayAmount } else { exp += item.displayAmount }
            byDate[key] = (inc, exp)
        }
        return byDate.sorted { $0.key < $1.key }.map { DayPoint(date: $0.key, income: $0.value.0, expense: $0.value.1) }
    }

    // MARK: Items List

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Транзакции (\(vm.items.count))", icon: "list.bullet", iconColor: AppTheme.Colors.textMuted)

            ForEach(vm.items) { item in
                HStack(spacing: AppTheme.Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                            .fill(item.isIncome ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg)
                            .frame(width: 34, height: 34)
                        Image(systemName: item.isIncome ? "arrow.up" : "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.isIncome ? AppTheme.Colors.success : AppTheme.Colors.error)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category ?? (item.isIncome ? "Доход" : "Расход"))
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                                .lineLimit(1)
                        }
                        if let date = item.date {
                            Text(String(date.prefix(10)))
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }

                    Spacer()

                    Text(MoneyFormatter.short(item.displayAmount))
                        .font(AppTheme.Typography.monoCaption)
                        .foregroundStyle(item.isIncome ? AppTheme.Colors.success : AppTheme.Colors.error)
                }
                .padding(.vertical, 4)

                if item.id != vm.items.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }
}
