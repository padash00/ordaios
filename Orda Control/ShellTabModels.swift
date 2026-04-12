import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        NoAccessView()
    }
}

struct NoAccessView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.Colors.error.opacity(0.6))

                Text("Нет доступа для этой роли")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Обратитесь к администратору для получения доступа")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)

                Button("Выйти") {
                    Task { await sessionStore.logout() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Нет доступа")
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        }
    }
}

// MARK: - Tab Enums
enum AdminTab: Hashable {
    case bookings, support, profile

    static func from(defaultPath: String?) -> AdminTab {
        guard let defaultPath else { return .bookings }
        if defaultPath.contains("/support") || defaultPath.contains("/tickets") { return .support }
        if defaultPath.contains("/profile") { return .profile }
        return .bookings
    }
}

enum SuperAdminTab: Hashable {
    case dashboard, finance, operations, analytics, more

    static func from(defaultPath: String?) -> SuperAdminTab {
        guard let defaultPath else { return .dashboard }
        if defaultPath.contains("/income") || defaultPath.contains("/expense") || defaultPath.contains("/salary") { return .finance }
        if defaultPath.contains("/shift") || defaultPath.contains("/task") || defaultPath.contains("/operator") { return .operations }
        if defaultPath.contains("/analytics") || defaultPath.contains("/report") { return .analytics }
        if defaultPath.contains("/profile") || defaultPath.contains("/settings") { return .more }
        return .dashboard
    }
}

enum StaffTab: Hashable {
    case dashboard, finance, bookings, support, operations, profile, access

    static func from(defaultPath: String?, capabilities: Set<AppCapability>, staffRole: String) -> StaffTab {
        guard let defaultPath else { return fallback(capabilities: capabilities, staffRole: staffRole) }
        if defaultPath.contains("/dashboard") || defaultPath.contains("/platform") { return .dashboard }
        if defaultPath.contains("/finance") || defaultPath.contains("/income") || defaultPath.contains("/expense") { return .finance }
        if defaultPath.contains("/bookings") {
            return capabilities.contains(.adminClientBookingsReview) ? .bookings : fallback(capabilities: capabilities, staffRole: staffRole)
        }
        if defaultPath.contains("/support") || defaultPath.contains("/tickets") {
            return capabilities.contains(.adminClientSupportReview) ? .support : fallback(capabilities: capabilities, staffRole: staffRole)
        }
        if defaultPath.contains("/profile") { return .profile }
        if defaultPath.contains("/access") { return .access }
        if defaultPath.contains("/shifts") {
            return capabilities.contains(.adminShiftsRead) ? .operations : fallback(capabilities: capabilities, staffRole: staffRole)
        }
        return fallback(capabilities: capabilities, staffRole: staffRole)
    }

    private static func fallback(capabilities: Set<AppCapability>, staffRole: String) -> StaffTab {
        switch staffRole {
        case "owner", "manager", "marketer": return .dashboard
        default:
            if capabilities.contains(.adminClientBookingsReview) { return .bookings }
            if capabilities.contains(.adminClientSupportReview) { return .support }
            return .operations
        }
    }
}

enum ClientMainTab: Hashable {
    case home, bookings, points, support
}

enum OperatorTab: Hashable {
    case dashboard, tasks, shifts, lead, salary, profile

    static func from(
        defaultPath: String?,
        capabilities: Set<AppCapability>,
        hasOperatorLeadAccess: Bool = false
    ) -> OperatorTab {
        guard let defaultPath else { return fallback(capabilities: capabilities) }
        let path = defaultPath.lowercased()
        if path.contains("lead"), hasOperatorLeadAccess {
            return .lead
        }
        if path.contains("/salary") {
            return capabilities.contains(.operatorSalaryRead) ? .salary : fallback(capabilities: capabilities)
        }
        if path.contains("/profile") || path.contains("/settings") {
            return capabilities.contains(.operatorProfileRead) ? .profile : fallback(capabilities: capabilities)
        }
        if path.contains("/shifts") { return capabilities.contains(.operatorShifts) ? .shifts : fallback(capabilities: capabilities) }
        if path.contains("/tasks") { return capabilities.contains(.operatorTasks) ? .tasks : fallback(capabilities: capabilities) }
        if path.contains("/operator") { return capabilities.contains(.operatorDashboard) ? .dashboard : fallback(capabilities: capabilities) }
        return fallback(capabilities: capabilities)
    }

    private static func fallback(capabilities: Set<AppCapability>) -> OperatorTab {
        if capabilities.contains(.operatorDashboard) { return .dashboard }
        if capabilities.contains(.operatorTasks) { return .tasks }
        if capabilities.contains(.operatorShifts) { return .shifts }
        if capabilities.contains(.operatorSalaryRead) { return .salary }
        return .profile
    }
}

struct NoPermissionInlineView: View {
    var body: some View {
        EmptyStateView(message: "Нет доступа для этой роли", icon: "lock.shield")
    }
}

// MARK: - Profile View (rich)
struct ProfileRoleView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var lockManager: AppLockManager

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Avatar + Name
                VStack(spacing: AppTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.Colors.purple, AppTheme.Colors.accentBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)
                        Text(initials)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Text(sessionStore.roleContext?.roleLabel ?? "—")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    StatusBadge(text: sessionStore.roleContext?.persona ?? "—", style: .info)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.Colors.headerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.Colors.purpleBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

                // Details
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Информация", icon: "person.text.rectangle", iconColor: AppTheme.Colors.accentBlue)
                    profileRow("Персона", sessionStore.roleContext?.persona ?? "—")
                    profileRow("Роль", sessionStore.roleContext?.roleLabel ?? "—")
                    profileRow("Сотрудник", sessionStore.roleContext?.staffRole ?? "—")
                    profileRow("Маршрут", sessionStore.roleContext?.defaultPath ?? "—")
                }
                .appCard()

                AppLockTimeoutSettingsCard()
                    .environmentObject(lockManager)

                // Logout
                Button {
                    Task { await sessionStore.logout() }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Выйти из аккаунта")
                    }
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.errorBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                            .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Профиль")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    @ViewBuilder
    private func profileRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    private var initials: String {
        let label = sessionStore.roleContext?.roleLabel ?? sessionStore.roleContext?.persona ?? "U"
        return String(label.prefix(2)).uppercased()
    }
}
