import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class AchievementsViewModel: ObservableObject {
    @Published private(set) var achievements: [ClientAchievement] = []
    @Published private(set) var referral: ClientReferralInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isNotAvailable = false
    @Published var selectedAchievement: ClientAchievement?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        isNotAvailable = false
        defer { isLoading = false }

        do {
            async let achievementsFetch: [ClientAchievement] = apiClient.request(ContractEndpoint.api_client_achievements.get)
            async let referralFetch: ClientReferralInfo = apiClient.request(ContractEndpoint.api_client_referral_code.get)
            achievements = try await achievementsFetch
            referral = try? await referralFetch
        } catch let err as APIError {
            if err == .forbidden || err == .unauthorized {
                errorMessage = err.errorDescription
            } else {
                isNotAvailable = true
            }
        } catch {
            isNotAvailable = true
        }
    }
}

// MARK: - Main View

struct AchievementsView: View {
    @StateObject var viewModel: AchievementsViewModel

    private let badgeColumns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(message: "Загрузка достижений...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.isNotAvailable && viewModel.achievements.isEmpty {
                EmptyStateView(message: "Достижения пока недоступны", icon: "trophy")
            } else {
                achievementsContent
            }
        }
        .navigationTitle("Достижения")
        .task { await viewModel.load() }
        .sheet(item: $viewModel.selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var achievementsContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                badgesSection
                if let referral = viewModel.referral {
                    referralSection(referral)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .refreshable { await viewModel.load() }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Мои достижения", icon: "trophy.fill", iconColor: AppTheme.Colors.warning)

            if viewModel.achievements.isEmpty {
                EmptyStateView(message: "Нет достижений", icon: "trophy")
                    .frame(height: 120)
            } else {
                LazyVGrid(columns: badgeColumns, spacing: AppTheme.Spacing.sm) {
                    ForEach(viewModel.achievements) { achievement in
                        AchievementBadge(achievement: achievement) {
                            if achievement.isUnlocked {
                                viewModel.selectedAchievement = achievement
                            }
                        }
                    }
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func referralSection(_ referral: ClientReferralInfo) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Реферальная программа", icon: "person.2.fill", iconColor: AppTheme.Colors.accentBlue)

            // Referral code display
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Ваш код")
                    .font(AppTheme.Typography.micro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textMuted)

                Text(referral.code)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accentPrimary.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(AppTheme.Colors.accentPrimary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
            .frame(maxWidth: .infinity)

            // Share button
            ShareLink(
                item: "Присоединяйся к Orda по коду: \(referral.code)",
                subject: Text("Orda — Присоединяйся!"),
                message: Text("Используй мой код \(referral.code) при регистрации в Orda!")
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Поделиться ссылкой")
                        .font(AppTheme.Typography.callout)
                }
                .foregroundStyle(AppTheme.Colors.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.infoBg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .stroke(AppTheme.Colors.infoBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            }

            // Stats
            HStack(spacing: AppTheme.Spacing.md) {
                referralStat(
                    icon: "person.badge.plus",
                    value: "\(referral.invitedCount)",
                    label: "Приглашено друзей",
                    color: AppTheme.Colors.accentBlue
                )
                Divider().frame(height: 40).background(AppTheme.Colors.borderSubtle)
                referralStat(
                    icon: "star.fill",
                    value: "+\(referral.pointsEarned)",
                    label: "Баллов заработано",
                    color: AppTheme.Colors.accentPrimary
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AppTheme.Spacing.xs)
        }
        .appCard()
    }

    @ViewBuilder
    private func referralStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(AppTheme.Typography.title3)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievement Badge

private struct AchievementBadge: View {
    let achievement: ClientAchievement
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked
                              ? AppTheme.Colors.warning.opacity(0.15)
                              : AppTheme.Colors.surfaceSecondary)
                        .frame(width: 56, height: 56)

                    if let emoji = achievement.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 26))
                            .opacity(achievement.isUnlocked ? 1.0 : 0.3)
                    } else {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(achievement.isUnlocked
                                             ? AppTheme.Colors.warning
                                             : AppTheme.Colors.textMuted.opacity(0.3))
                    }

                    if achievement.isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.success)
                            .background(Circle().fill(AppTheme.Colors.bgPrimary).padding(2))
                            .offset(x: 18, y: 18)
                    }
                }
                .frame(width: 56, height: 56)

                Text(achievement.title)
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(achievement.isUnlocked
                                     ? AppTheme.Colors.textSecondary
                                     : AppTheme.Colors.textMuted.opacity(0.5))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .disabled(!achievement.isUnlocked)
    }
}

// MARK: - Achievement Detail Sheet

private struct AchievementDetailSheet: View {
    let achievement: ClientAchievement
    @Environment(\.dismiss) private var dismiss

    var formattedDate: String? {
        guard let raw = achievement.unlockedAt, raw.count >= 10 else { return nil }
        let datePart = String(raw.prefix(10))
        let parts = datePart.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[2]).\(parts[1]).\(parts[0])"
        }
        return raw
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Badge
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.warning.opacity(0.15))
                        .frame(width: 100, height: 100)
                    if let emoji = achievement.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 52))
                    } else {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                }

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(achievement.title)
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    if let description = achievement.description {
                        Text(description)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let date = formattedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.Colors.success)
                            Text("Разблокировано \(date)")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .padding(.top, AppTheme.Spacing.xs)
                    }
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Достижение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        }
    }
}
