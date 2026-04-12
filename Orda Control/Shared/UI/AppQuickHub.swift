import SwiftUI
import Combine

// MARK: - Navigation events

enum QuickHubNavigationEvent: Equatable {
    case superAdmin(SuperAdminTab)
    case staff(StaffTab)
    case admin(AdminTab)
    case operatorRole(OperatorTab)
    case client(ClientMainTab)
}

@MainActor
final class AppQuickHubCoordinator: ObservableObject {
    @Published var isPresented = false
    @Published var navigationEvent: QuickHubNavigationEvent?
    /// Синхронизируется из `OperatorShellView` (лист хаба выше по дереву, не видит local environment).
    @Published var operatorLeadTabAvailable = false

    func openHub() {
        isPresented = true
        AppHaptics.light()
    }

    func emit(_ event: QuickHubNavigationEvent) {
        navigationEvent = event
        isPresented = false
        AppHaptics.success()
    }

    func clearNavigation() {
        navigationEvent = nil
    }
}

// MARK: - Floating button

struct AppQuickHubFloatingButton: View {
    @EnvironmentObject private var coordinator: AppQuickHubCoordinator

    var body: some View {
        Button(action: { coordinator.openHub() }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.accentPrimary, Color(hex: 0xF97316)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: AppTheme.Colors.accentPrimary.opacity(0.45), radius: 12, y: 6)

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.bgPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Быстрый переход")
        .accessibilityHint("Поиск разделов и переход по вкладкам")
        .padding(.trailing, AppTheme.Spacing.md)
        .padding(.bottom, 62)
    }
}

// MARK: - Sheet

struct AppQuickHubSheet: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var coordinator: AppQuickHubCoordinator

    @State private var query = ""

    private var caps: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var shell: AppShellType {
        sessionStore.shellType
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSearchBar(text: $query, placeholder: "Поиск раздела…")
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.sm)

                if hubItems.isEmpty {
                    EmptyStateView(message: "Нет доступных разделов для этой роли", icon: "lock.shield")
                } else if filteredGroups.isEmpty {
                    EmptyStateView(message: "Ничего не найдено", icon: "magnifyingglass")
                } else {
                    List {
                        ForEach(filteredGroups, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.rows) { row in
                                    Button(action: row.action) {
                                        hubRowLabel(row)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.Colors.bgPrimary)
            .navigationTitle("Быстрый переход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        coordinator.isPresented = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private struct HubRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let keywords: String
        let action: () -> Void
    }

    private struct HubGroup {
        let title: String
        let rows: [HubRow]
    }

    private func hubRowLabel(_ row: HubRow) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: row.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(row.color)
                .frame(width: 36, height: 36)
                .background(row.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(row.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private var hubItems: [HubGroup] {
        switch shell {
        case .admin:
            if sessionStore.roleContext?.isSuperAdmin == true
                || (sessionStore.roleContext?.persona ?? "").lowercased() == "super_admin" {
                return superAdminGroups
            }
            return adminGroups
        case .staff:
            return staffGroups
        case .operatorRole:
            return operatorGroups
        case .client:
            return clientGroups
        case .noAccess:
            return []
        }
    }

    private var filteredGroups: [HubGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return hubItems }
        return hubItems.compactMap { g in
            let rows = g.rows.filter { row in
                row.title.lowercased().contains(q)
                    || row.subtitle.lowercased().contains(q)
                    || row.keywords.lowercased().contains(q)
            }
            guard !rows.isEmpty else { return nil }
            return HubGroup(title: g.title, rows: rows)
        }
    }

    // MARK: Super Admin

    private var analyticsUnlocked: Bool {
        caps.contains(.adminReportsRead) && caps.contains(.adminKPIRead)
    }

    private var superAdminGroups: [HubGroup] {
        var rows: [HubRow] = []
        rows.append(HubRow(
            id: "sa-dash",
            title: "Панель",
            subtitle: "Дашборд и ключевые метрики",
            icon: "rectangle.3.group",
            color: AppTheme.Colors.purple,
            keywords: "дашборд главная обзор",
            action: { coordinator.emit(.superAdmin(.dashboard)) }
        ))
        rows.append(HubRow(
            id: "sa-fin",
            title: "Финансы",
            subtitle: "Доходы, расходы, зарплата",
            icon: "banknote",
            color: AppTheme.Colors.success,
            keywords: "деньги доход расход зарплата",
            action: { coordinator.emit(.superAdmin(.finance)) }
        ))
        rows.append(HubRow(
            id: "sa-ops",
            title: "Операции",
            subtitle: "Смены, задачи, команда, склад",
            icon: "briefcase",
            color: AppTheme.Colors.accentBlue,
            keywords: "смены задачи операторы склад pos",
            action: { coordinator.emit(.superAdmin(.operations)) }
        ))
        if analyticsUnlocked {
            rows.append(HubRow(
                id: "sa-an",
                title: "Аналитика",
                subtitle: "KPI, цели, отчёты",
                icon: "chart.xyaxis.line",
                color: AppTheme.Colors.accentPrimary,
                keywords: "графики kpi отчёты",
                action: { coordinator.emit(.superAdmin(.analytics)) }
            ))
        }
        rows.append(HubRow(
            id: "sa-more",
            title: "Ещё",
            subtitle: "Профиль, точки, настройки, веб-разделы",
            icon: "ellipsis.circle",
            color: AppTheme.Colors.textMuted,
            keywords: "профиль настройки точки доступ",
            action: { coordinator.emit(.superAdmin(.more)) }
        ))
        return [HubGroup(title: "Супер-админ", rows: rows)]
    }

    // MARK: Admin (брони / поддержка)

    private var adminGroups: [HubGroup] {
        var rows: [HubRow] = []
        if caps.contains(.adminClientBookingsReview) {
            rows.append(HubRow(
                id: "ad-book",
                title: "Брони",
                subtitle: "Заявки клиентов",
                icon: "calendar",
                color: AppTheme.Colors.accentBlue,
                keywords: "бронирование",
                action: { coordinator.emit(.admin(.bookings)) }
            ))
        }
        if caps.contains(.adminClientSupportReview) {
            rows.append(HubRow(
                id: "ad-sup",
                title: "Поддержка",
                subtitle: "Обращения",
                icon: "message",
                color: AppTheme.Colors.warning,
                keywords: "тикеты чат",
                action: { coordinator.emit(.admin(.support)) }
            ))
        }
        rows.append(HubRow(
            id: "ad-prof",
            title: "Профиль",
            subtitle: "Аккаунт и выход",
            icon: "person",
            color: AppTheme.Colors.accentBlue,
            keywords: "аккаунт",
            action: { coordinator.emit(.admin(.profile)) }
        ))
        return [HubGroup(title: "Админ", rows: rows)]
    }

    // MARK: Staff

    private var staffGroups: [HubGroup] {
        var rows: [HubRow] = []
        let role = sessionStore.roleContext
        if ModuleAccessMatrix.isVisible(.dashboard, role: role) {
            let staffRole = (role?.staffRole ?? "").lowercased()
            let dashSubtitle = staffRole == "marketer" || staffRole == "manager"
                ? "Обзор без сводки по деньгам"
                : "Сводка по бизнесу"
            rows.append(HubRow(
                id: "st-dash",
                title: "Панель",
                subtitle: dashSubtitle,
                icon: "rectangle.3.group",
                color: AppTheme.Colors.purple,
                keywords: "главная дашборд",
                action: { coordinator.emit(.staff(.dashboard)) }
            ))
        }
        if ModuleAccessMatrix.isVisible(.finance, role: role) {
            rows.append(HubRow(
                id: "st-fin",
                title: "Финансы",
                subtitle: "Оборот и структура",
                icon: "banknote",
                color: AppTheme.Colors.success,
                keywords: "деньги доход",
                action: { coordinator.emit(.staff(.finance)) }
            ))
        }
        if caps.contains(.adminClientBookingsReview) || caps.contains(.adminClientSupportReview) {
            rows.append(HubRow(
                id: "st-cli",
                title: "Клиенты",
                subtitle: "Брони и поддержка",
                icon: "person.2",
                color: AppTheme.Colors.info,
                keywords: "клиент бронь поддержка",
                action: { coordinator.emit(.staff(.bookings)) }
            ))
        }
        if caps.contains(.adminShiftsRead) || caps.contains(.adminTasksRead)
            || caps.contains(.adminOperatorsRead) || caps.contains(.adminPOSRead) {
            rows.append(HubRow(
                id: "st-ops",
                title: "Операции",
                subtitle: "Смены, задачи, команда",
                icon: "briefcase",
                color: AppTheme.Colors.accentBlue,
                keywords: "смены задачи операторы",
                action: { coordinator.emit(.staff(.operations)) }
            ))
        }
        rows.append(HubRow(
            id: "st-more",
            title: "Ещё",
            subtitle: "Каталог модулей и настройки",
            icon: "ellipsis.circle",
            color: AppTheme.Colors.textMuted,
            keywords: "каталог модули",
            action: { coordinator.emit(.staff(.profile)) }
        ))
        return [HubGroup(title: "Сотрудник", rows: rows)]
    }

    // MARK: Operator

    private var operatorGroups: [HubGroup] {
        var rows: [HubRow] = []
        if caps.contains(.operatorDashboard) {
            rows.append(HubRow(
                id: "op-dash",
                title: "Панель",
                subtitle: "Сводка оператора",
                icon: "rectangle.3.group",
                color: AppTheme.Colors.purple,
                keywords: "главная",
                action: { coordinator.emit(.operatorRole(.dashboard)) }
            ))
        }
        if caps.contains(.operatorTasks) {
            rows.append(HubRow(
                id: "op-task",
                title: "Задачи",
                subtitle: "Поручения",
                icon: "checklist",
                color: AppTheme.Colors.warning,
                keywords: "todo задача",
                action: { coordinator.emit(.operatorRole(.tasks)) }
            ))
        }
        if caps.contains(.operatorShifts) {
            rows.append(HubRow(
                id: "op-shift",
                title: "Смены",
                subtitle: "График и подтверждение",
                icon: "clock.arrow.circlepath",
                color: AppTheme.Colors.accentBlue,
                keywords: "график неделя",
                action: { coordinator.emit(.operatorRole(.shifts)) }
            ))
        }
        if coordinator.operatorLeadTabAvailable {
            rows.append(HubRow(
                id: "op-lead",
                title: "Ведущий",
                subtitle: "Команда и заявки по точке",
                icon: "person.badge.key",
                color: AppTheme.Colors.warning,
                keywords: "старший смена заявка",
                action: { coordinator.emit(.operatorRole(.lead)) }
            ))
        }
        if caps.contains(.operatorSalaryRead) {
            rows.append(HubRow(
                id: "op-sal",
                title: "Зарплата",
                subtitle: "Неделя и выплаты",
                icon: "banknote",
                color: AppTheme.Colors.success,
                keywords: "зарплата деньги",
                action: { coordinator.emit(.operatorRole(.salary)) }
            ))
        }
        if caps.contains(.operatorProfileRead) {
            rows.append(HubRow(
                id: "op-prof",
                title: "Профиль",
                subtitle: "Личные данные и касса",
                icon: "person",
                color: AppTheme.Colors.accentBlue,
                keywords: "аккаунт qr",
                action: { coordinator.emit(.operatorRole(.profile)) }
            ))
        }
        return [HubGroup(title: "Оператор", rows: rows)]
    }

    // MARK: Client

    private var clientGroups: [HubGroup] {
        let rows: [HubRow] = [
            HubRow(
                id: "cl-home",
                title: "Главная",
                subtitle: "Обзор и баллы",
                icon: "house",
                color: AppTheme.Colors.purple,
                keywords: "домой обзор",
                action: { coordinator.emit(.client(.home)) }
            ),
            HubRow(
                id: "cl-book",
                title: "Брони",
                subtitle: "Мои заявки",
                icon: "calendar",
                color: AppTheme.Colors.accentBlue,
                keywords: "бронь",
                action: { coordinator.emit(.client(.bookings)) }
            ),
            HubRow(
                id: "cl-pts",
                title: "Баллы",
                subtitle: "Программа лояльности",
                icon: "star.circle",
                color: AppTheme.Colors.accentPrimary,
                keywords: "бонусы",
                action: { coordinator.emit(.client(.points)) }
            ),
            HubRow(
                id: "cl-sup",
                title: "Поддержка",
                subtitle: "Обращения",
                icon: "message",
                color: AppTheme.Colors.info,
                keywords: "помощь чат",
                action: { coordinator.emit(.client(.support)) }
            ),
        ]
        return [HubGroup(title: "Клиент", rows: rows)]
    }
}
