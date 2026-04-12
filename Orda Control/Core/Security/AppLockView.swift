import SwiftUI

struct AppLockView: View {
    @ObservedObject var lockManager: AppLockManager

    var body: some View {
        ZStack {
            AppTheme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()

                // Logo / Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: biometricIcon)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }

                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Orda Control")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Подтвердите личность для входа")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    Task { await lockManager.authenticate() }
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: biometricIcon)
                        Text(biometricLabel)
                    }
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                .padding(.horizontal, AppTheme.Spacing.xl)

                Spacer().frame(height: AppTheme.Spacing.xl)
            }
            .padding(AppTheme.Spacing.md)
        }
        .task { await lockManager.authenticate() }
    }

    private var biometricIcon: String {
        switch lockManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }

    private var biometricLabel: String {
        switch lockManager.biometricType {
        case .faceID: return "Войти через Face ID"
        case .touchID: return "Войти через Touch ID"
        case .none: return "Разблокировать"
        }
    }
}

struct AppLockTimeoutSettingsCard: View {
    @EnvironmentObject private var lockManager: AppLockManager

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Безопасность", icon: "lock.shield", iconColor: AppTheme.Colors.warning)
            Text("Блокировать приложение после фона")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)

            HStack {
                Text("Таймаут")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
                Menu {
                    ForEach(AppLockManager.supportedTimeoutMinutes, id: \.self) { minutes in
                        Button {
                            lockManager.setTimeoutMinutes(minutes)
                        } label: {
                            if Int(lockManager.backgroundLockTimeout / 60) == minutes {
                                Label("\(minutes) мин", systemImage: "checkmark")
                            } else {
                                Text("\(minutes) мин")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(lockManager.timeoutMinutesLabel)
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center) {
                Text(lockManager.usesCustomTimeout
                        ? "Источник: локальная настройка"
                        : "Источник: значение по умолчанию (\(lockManager.defaultTimeoutMinutesLabel))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
                if lockManager.usesCustomTimeout {
                    Button("Сбросить") {
                        lockManager.resetTimeoutToDefault()
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }
}
