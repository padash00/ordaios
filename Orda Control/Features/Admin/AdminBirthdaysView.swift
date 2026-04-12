import SwiftUI
import Combine

// MARK: - Models

struct StaffBirthday: Decodable, Identifiable {
    let id: String
    let name: String?
    let role: String?
    let birthDate: String?
    let daysUntil: Int?
    let age: Int?

    var displayName: String { name ?? "Сотрудник" }
    var isToday: Bool { daysUntil == 0 }
    var isThisWeek: Bool { (daysUntil ?? 999) <= 7 }

    var formattedDate: String {
        guard let raw = birthDate else { return "" }
        let parts = raw.split(separator: "-")
        guard parts.count >= 3 else { return String(raw.prefix(10)) }
        let months = ["", "янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
        let monthIdx = Int(parts[1]) ?? 0
        let month = monthIdx < months.count ? months[monthIdx] : String(parts[1])
        return "\(parts[2]) \(month)"
    }
}

private struct BirthdaysEnvelope: Decodable {
    let data: [StaffBirthday]?
    let birthdays: [StaffBirthday]?
    let upcoming: [StaffBirthday]?

    var resolved: [StaffBirthday] { data ?? birthdays ?? upcoming ?? [] }
}

// MARK: - ViewModel

@MainActor
final class AdminBirthdaysViewModel: ObservableObject {
    @Published var birthdays: [StaffBirthday] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var todayBirthdays: [StaffBirthday] { birthdays.filter(\.isToday) }
    var upcomingBirthdays: [StaffBirthday] { birthdays.filter { !$0.isToday } }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let envelope: BirthdaysEnvelope = try await apiClient.request(ContractEndpoint.api_admin_birthdays.get)
            birthdays = envelope.resolved.sorted { ($0.daysUntil ?? 999) < ($1.daysUntil ?? 999) }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - View

struct AdminBirthdaysView: View {
    @StateObject private var vm: AdminBirthdaysViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminBirthdaysViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка дней рождения…")
                } else if let err = vm.errorMessage {
                    ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
                } else if vm.birthdays.isEmpty {
                    emptyState
                } else {
                    if !vm.todayBirthdays.isEmpty {
                        todaySection
                    }
                    if !vm.upcomingBirthdays.isEmpty {
                        upcomingSection
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Дни рождения")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.warningBg)
                    .frame(width: 80, height: 80)
                Text("🎂")
                    .font(.system(size: 36))
            }
            Text("Нет предстоящих дней рождения")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Добавьте даты рождения в профили сотрудников")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
        .appCard()
    }

    // MARK: Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text("🎉")
                    .font(.system(size: 18))
                Text("Сегодня!")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.warning)
            }

            ForEach(vm.todayBirthdays) { birthday in
                birthdayCard(birthday, isToday: true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.warningBg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.xl).stroke(AppTheme.Colors.warningBorder, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }

    // MARK: Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Предстоящие", icon: "calendar.badge.clock", iconColor: AppTheme.Colors.accentBlue)

            ForEach(vm.upcomingBirthdays) { birthday in
                birthdayCard(birthday, isToday: false)
                if birthday.id != vm.upcomingBirthdays.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Birthday Card

    @ViewBuilder
    private func birthdayCard(_ birthday: StaffBirthday, isToday: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(isToday ? AppTheme.Colors.warning.opacity(0.2) : AppTheme.Colors.accentPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(isToday ? "🎂" : initials(birthday.displayName))
                    .font(isToday ? .system(size: 22) : .system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(birthday.displayName)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    if let role = birthday.role {
                        Text(role)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let age = birthday.age {
                        Text("•")
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Text("\(age) лет")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(birthday.formattedDate)
                    .font(AppTheme.Typography.monoCaption)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if isToday {
                    Text("Сегодня")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.warning)
                } else if let days = birthday.daysUntil {
                    Text("через \(days) д.")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(days <= 3 ? AppTheme.Colors.warning : AppTheme.Colors.textMuted)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Mini Birthday Widget (for dashboard injection)

struct BirthdayMiniCard: View {
    let birthdays: [StaffBirthday]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                SectionHeader(title: "Дни рождения", icon: "gift.fill", iconColor: AppTheme.Colors.warning)
                Spacer()
                Text("🎂 \(birthdays.count)")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.warning)
            }

            ForEach(birthdays.prefix(3)) { b in
                HStack(spacing: 6) {
                    Text(b.isToday ? "🎉" : "•")
                        .font(.system(size: 12))
                    Text(b.displayName)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(b.isToday ? "Сегодня" : b.daysUntil.map { "через \($0)д." } ?? "")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(b.isToday ? AppTheme.Colors.warning : AppTheme.Colors.textMuted)
                }
            }

            if birthdays.count > 3 {
                Text("и ещё \(birthdays.count - 3)…")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
    }
}
