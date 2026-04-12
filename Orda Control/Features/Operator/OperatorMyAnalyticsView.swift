import SwiftUI
import Charts
import Combine

// MARK: - ViewModel

@MainActor
final class OperatorMyAnalyticsViewModel: ObservableObject {
    @Published var data: OperatorMyAnalyticsData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod = "month"

    let periods = [("week", "Неделя"), ("month", "Месяц"), ("quarter", "Квартал")]

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    var taskRate: Double {
        guard let d = data, let total = d.tasksTotal, total > 0, let done = d.tasksCompleted else { return 0 }
        return Double(done) / Double(total)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            data = try await service.fetchMyAnalytics(period: selectedPeriod)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - View

struct OperatorMyAnalyticsView: View {
    @StateObject private var vm: OperatorMyAnalyticsViewModel

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorMyAnalyticsViewModel(service: service))
    }

    var body: some View {
        scrollContent
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Мои показатели")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .onChange(of: vm.selectedPeriod) { _, _ in Task { await vm.load() } }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                periodPicker
                mainSection
            }
            .padding(AppTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private var mainSection: some View {
        if vm.isLoading {
            LoadingStateView(message: "Загрузка аналитики…")
        } else if let err = vm.errorMessage {
            ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
        } else if let data = vm.data {
            loadedContent(data: data)
        } else {
            EmptyStateView(message: "Нет данных за выбранный период")
        }
    }

    @ViewBuilder
    private func loadedContent(data: OperatorMyAnalyticsData) -> some View {
        statsGrid(data)
        rankCard(data)
        earningsChart(data)
        taskProgressCard(data)
    }

    // MARK: Period Picker

    private var periodPicker: some View {
        Picker("Период", selection: $vm.selectedPeriod) {
            ForEach(vm.periods, id: \.0) { id, label in
                Text(label).tag(id)
            }
        }
        .pickerStyle(.segmented)
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Stats Grid

    @ViewBuilder
    private func statsGrid(_ data: OperatorMyAnalyticsData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
            statTile(
                title: "ЗАДАЧ ВЫПОЛНЕНО",
                value: "\(data.tasksCompleted ?? 0)",
                subtitle: "из \(data.tasksTotal ?? 0)",
                color: AppTheme.Colors.success,
                bg: AppTheme.Colors.successBg,
                border: AppTheme.Colors.successBorder,
                icon: "checkmark.circle.fill"
            )
            statTile(
                title: "СМЕН ОТРАБОТАНО",
                value: "\(data.shiftsCount ?? 0)",
                subtitle: "за период",
                color: AppTheme.Colors.accentBlue,
                bg: AppTheme.Colors.infoBg,
                border: AppTheme.Colors.infoBorder,
                icon: "clock.fill"
            )
            statTile(
                title: "РЕЙТИНГ",
                value: data.avgRating.map { String(format: "%.1f", $0) } ?? "—",
                subtitle: "средний балл",
                color: AppTheme.Colors.warning,
                bg: AppTheme.Colors.warningBg,
                border: AppTheme.Colors.warningBorder,
                icon: "star.fill"
            )
            statTile(
                title: "ЗАРАБОТОК",
                value: MoneyFormatter.short(data.netEarnings ?? 0),
                subtitle: "за период",
                color: AppTheme.Colors.cashColor,
                bg: AppTheme.Colors.warningBg.opacity(0.5),
                border: AppTheme.Colors.warningBorder,
                icon: "banknote.fill"
            )
        }
    }

    @ViewBuilder
    private func statTile(title: String, value: String, subtitle: String, color: Color, bg: Color, border: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.micro)
                .tracking(0.8)
                .foregroundStyle(color.opacity(0.8))
            Text(subtitle)
                .font(AppTheme.Typography.micro)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .padding(AppTheme.Spacing.sm)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: Rank Card

    @ViewBuilder
    private func rankCard(_ data: OperatorMyAnalyticsData) -> some View {
        if let pos = data.rankPosition, let total = data.rankTotal {
            rankCardContent(pos: pos, total: total)
        }
    }

    private func rankProgressValue(pos: Int, total: Int) -> Double {
        guard total > 1 else { return 0 }
        return Double(total - pos) / Double(total - 1)
    }

    private func rankCardContent(pos: Int, total: Int) -> some View {
        let pct = rankProgressValue(pos: pos, total: total)
        return VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                SectionHeader(title: "Рейтинг команды", icon: "trophy.fill", iconColor: AppTheme.Colors.warning)
                Spacer()
                Text("#\(pos) из \(total)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(pos <= 3 ? AppTheme.Colors.warning : AppTheme.Colors.textPrimary)
            }

            ProgressView(value: pct)
                .tint(pos <= 3 ? AppTheme.Colors.warning : AppTheme.Colors.accentPrimary)
                .scaleEffect(y: 2)

            HStack {
                Text("Последний").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
                Text("Лучший").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Earnings Chart

    @ViewBuilder
    private func earningsChart(_ data: OperatorMyAnalyticsData) -> some View {
        if let earnings = data.weeklyEarnings, !earnings.isEmpty {
            earningsChartContent(earnings: earnings)
        }
    }

    private func earningsChartContent(earnings: [OperatorMyAnalyticsData.WeeklyEarning]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Динамика заработка", icon: "chart.bar.fill", iconColor: AppTheme.Colors.success)

            Chart {
                ForEach(earnings) { point in
                    BarMark(
                        x: .value("Неделя", String((point.weekStart ?? point.id).prefix(7))),
                        y: .value("Сумма", point.amount ?? 0)
                    )
                    .foregroundStyle(AppTheme.Colors.accentPrimary.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 140)
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
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Task Progress Card

    @ViewBuilder
    private func taskProgressCard(_ data: OperatorMyAnalyticsData) -> some View {
        let done = data.tasksCompleted ?? 0
        let total = data.tasksTotal ?? 0
        if total > 0 {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Выполнение задач", icon: "checklist", iconColor: AppTheme.Colors.accentPrimary)

                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.Colors.borderSubtle, lineWidth: 8)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: CGFloat(vm.taskRate))
                            .stroke(AppTheme.Colors.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(vm.taskRate * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.success)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(AppTheme.Colors.success).frame(width: 8, height: 8)
                            Text("Выполнено: \(done)").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        HStack {
                            Circle().fill(AppTheme.Colors.borderSubtle).frame(width: 8, height: 8)
                            Text("Всего: \(total)").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        HStack {
                            Circle().fill(AppTheme.Colors.warning).frame(width: 8, height: 8)
                            Text("Осталось: \(total - done)").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    Spacer()
                }
            }
            .padding(AppTheme.Spacing.md)
            .appCard()
        }
    }
}
