import SwiftUI
import Charts
import Combine

// MARK: - Models

struct OperatorRating: Decodable, Identifiable {
    let id: String
    let operatorId: String?
    let operatorName: String?
    let period: String?
    let tasksCompleted: Int?
    let tasksTotal: Int?
    let shiftsCount: Int?
    let avgScore: Double?
    let rank: Int?

    var displayName: String { operatorName ?? "Оператор \(id.prefix(4))" }
    var taskRate: Double {
        guard let total = tasksTotal, total > 0, let done = tasksCompleted else { return 0 }
        return Double(done) / Double(total)
    }
}

private struct RatingsEnvelope: Decodable {
    let data: [OperatorRating]?
    let ratings: [OperatorRating]?
    let operators: [OperatorRating]?

    var resolved: [OperatorRating] { data ?? ratings ?? operators ?? [] }
}

// MARK: - ViewModel

@MainActor
final class AdminRatingsViewModel: ObservableObject {
    @Published var ratings: [OperatorRating] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod = "month"

    let periods = [("week", "Неделя"), ("month", "Месяц"), ("quarter", "Квартал")]

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let endpoint = APIEndpoint(
                path: ContractEndpoint.api_admin_ratings.rawValue,
                method: .GET,
                queryItems: [URLQueryItem(name: "period", value: selectedPeriod)]
            )
            let envelope: RatingsEnvelope = try await apiClient.request(endpoint)
            ratings = envelope.resolved.sorted { ($0.rank ?? 999) < ($1.rank ?? 999) }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - View

struct AdminRatingsView: View {
    @StateObject private var vm: AdminRatingsViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminRatingsViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                periodPicker

                if vm.isLoading {
                    LoadingStateView(message: "Загрузка рейтингов…")
                } else if let err = vm.errorMessage {
                    ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
                } else if vm.ratings.isEmpty {
                    EmptyStateView(message: "Нет данных рейтинга")
                } else {
                    podiumCard
                    ratingsList
                    performanceChart
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Рейтинг операторов")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.selectedPeriod) { _, _ in Task { await vm.load() } }
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

    // MARK: Podium

    @ViewBuilder
    private var podiumCard: some View {
        let top3 = Array(vm.ratings.prefix(3))
        if top3.count >= 2 {
            VStack(spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Топ-3", icon: "trophy.fill", iconColor: AppTheme.Colors.warning)

                HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                    if top3.count > 1 {
                        podiumItem(top3[1], place: 2, height: 80)
                    }
                    podiumItem(top3[0], place: 1, height: 110)
                    if top3.count > 2 {
                        podiumItem(top3[2], place: 3, height: 60)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .appCard()
        }
    }

    @ViewBuilder
    private func podiumItem(_ rating: OperatorRating, place: Int, height: CGFloat) -> some View {
        let medals = ["🥇", "🥈", "🥉"]
        VStack(spacing: 4) {
            Text(medals[place - 1])
                .font(.system(size: 24))
            Text(initials(rating.displayName))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(placeColor(place))
                .clipShape(Circle())
            Text(rating.displayName)
                .font(AppTheme.Typography.micro)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            if let score = rating.avgScore {
                Text(String(format: "%.1f", score))
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(placeColor(place).opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(placeColor(place).opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }

    private func placeColor(_ place: Int) -> Color {
        switch place {
        case 1: return AppTheme.Colors.warning
        case 2: return AppTheme.Colors.textMuted
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.accentBlue
        }
    }

    // MARK: Ratings List

    private var ratingsList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Полный список", icon: "list.number", iconColor: AppTheme.Colors.accentBlue)

            ForEach(Array(vm.ratings.enumerated()), id: \.element.id) { index, rating in
                ratingRow(rating, rank: index + 1)
                if index < vm.ratings.count - 1 {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    @ViewBuilder
    private func ratingRow(_ rating: OperatorRating, rank: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? AppTheme.Colors.warning : AppTheme.Colors.textMuted)
                .frame(width: 28)

            ZStack {
                Circle()
                    .fill(AppTheme.Colors.accentPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text(initials(rating.displayName))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rating.displayName)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    if let shifts = rating.shiftsCount {
                        Label("\(shifts) смен", systemImage: "clock.fill")
                            .font(AppTheme.Typography.micro)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let done = rating.tasksCompleted {
                        Label("\(done) задач", systemImage: "checkmark.circle.fill")
                            .font(AppTheme.Typography.micro)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            }

            Spacer()

            if let score = rating.avgScore {
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(score >= 4.0 ? AppTheme.Colors.success : score >= 3.0 ? AppTheme.Colors.warning : AppTheme.Colors.error)
                    Text("балл")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Performance Chart

    @ViewBuilder
    private var performanceChart: some View {
        let top5 = Array(vm.ratings.prefix(5))
        if !top5.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Процент выполнения", icon: "chart.bar.fill", iconColor: AppTheme.Colors.accentPrimary)

                Chart {
                    ForEach(top5) { r in
                        BarMark(
                            x: .value("Оператор", String(r.displayName.prefix(8))),
                            y: .value("%", r.taskRate * 100)
                        )
                        .foregroundStyle(AppTheme.Colors.accentPrimary.gradient)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 130)
                .chartYScale(domain: 0...100)
            }
            .padding(AppTheme.Spacing.md)
            .appCard()
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
