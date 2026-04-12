import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @StateObject var viewModel: HomeViewModel

    var body: some View {
        Group {
            if clientProfile.isLoading && clientProfile.customers.isEmpty {
                LoadingStateView(message: "Загрузка профиля...")
            } else if let err = clientProfile.loadError, clientProfile.customers.isEmpty {
                ErrorStateView(message: err) { Task { await reloadAll() } }
            } else if let customer = clientProfile.selectedCustomer {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        if let notice = viewModel.loadNotice, !notice.isEmpty {
                            loadNoticeBanner(notice)
                        }
                        if clientProfile.customers.count > 1 {
                            companyPickerCard
                        }
                        welcomeCard(customer)
                        nextActionsCard(customer: customer)
                        statsGrid(customer)
                        profileCard(customer)
                        logoutButton
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .refreshable { await reloadAll() }
                .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            } else {
                EmptyStateView(message: "Нет данных\nПотяните вниз для обновления", icon: "person.crop.circle")
            }
        }
        .navigationTitle("Главная")
        .task { await reloadAll() }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var clubWebsiteURL: URL? {
        AppConfig.current.apiBaseURL
    }

    private func reloadAll() async {
        await clientProfile.refresh(apiClient: sessionStore.apiClient)
        await viewModel.load(apiClient: sessionStore.apiClient)
    }

    private func loadNoticeBanner(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.Colors.warning)
                Text(text)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Обновить") {
                Task { await reloadAll() }
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.accentPrimary)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.warning.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.warning.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    private var companyPickerCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Ваша точка / клуб", icon: "building.2.fill", iconColor: AppTheme.Colors.purple)
            Text("Брони, поддержка и станции привязаны к выбранному профилю клиента.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Picker("Профиль", selection: Binding(
                get: { clientProfile.selectedCustomerId ?? clientProfile.customers.first?.id ?? "" },
                set: { clientProfile.selectedCustomerId = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(clientProfile.customers) { row in
                    Text(profileLabel(row)).tag(row.id)
                }
            }
            .pickerStyle(.menu)
            .appInputStyle()
        }
        .appCard()
    }

    private func profileLabel(_ row: ActiveCustomer) -> String {
        if let c = row.companyId, !c.isEmpty {
            return "\(row.name) · \(c.prefix(8))…"
        }
        return row.name
    }

    // MARK: - Welcome card
    @ViewBuilder
    private func welcomeCard(_ customer: ActiveCustomer) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Colors.accentPrimary, Color(hex: 0xF97316)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Text(initials(customer.name))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.bgPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Добро пожаловать")
                    .font(AppTheme.Typography.micro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Text(customer.name)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                StatusBadge(text: "Клиент", style: .info)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.headerGradient)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.xl).stroke(AppTheme.Colors.accentPrimary.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }

    // MARK: - Stats
    @ViewBuilder
    private func statsGrid(_ customer: ActiveCustomer) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
            StatTile(
                title: "БАЛЛЫ ЛОЯЛЬНОСТИ",
                value: "\(customer.loyaltyPoints)",
                color: AppTheme.Colors.accentPrimary,
                bgColor: AppTheme.Colors.accentPrimary.opacity(0.10),
                borderColor: AppTheme.Colors.accentPrimary.opacity(0.25)
            )
            StatTile(
                title: "ВИЗИТЫ",
                value: "\(customer.visitsCount)",
                color: AppTheme.Colors.accentBlue,
                bgColor: AppTheme.Colors.accentBlue.opacity(0.10),
                borderColor: AppTheme.Colors.accentBlue.opacity(0.25)
            )
        }
    }

    // MARK: - Next actions
    @ViewBuilder
    private func nextActionsCard(customer: ActiveCustomer) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Следующие действия", icon: "bolt.fill", iconColor: AppTheme.Colors.warning)

            NavigationLink {
                StationBookingView(apiClient: sessionStore.apiClient)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.success.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Игровые станции (ПК)")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Список, мини-схема зала или сетка — выберите свободное место и время")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Divider().background(AppTheme.Colors.borderSubtle)

            if let url = clubWebsiteURL {
                Link(destination: url) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "safari")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accentBlue)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.Colors.accentBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Полная карта на сайте")
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("Откроется браузер с сайтом клуба")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }

                Divider().background(AppTheme.Colors.borderSubtle)
            }

            if let booking = viewModel.nearestBooking {
                actionRow(
                    title: "Подтвердить ближайшую бронь",
                    subtitle: AppDateFormatter.dayMonthTime.string(from: booking.startsAt),
                    icon: "calendar.badge.clock",
                    color: AppTheme.Colors.accentBlue
                ) {
                    quickHub.emit(.client(.bookings))
                }
                Divider().background(AppTheme.Colors.borderSubtle)
            }

            if let nextTier = viewModel.nextTierTitle(for: customer) {
                actionRow(
                    title: "Дойти до уровня \(nextTier)",
                    subtitle: "Осталось \(viewModel.pointsToNextTier(for: customer)) баллов",
                    icon: "star.circle.fill",
                    color: AppTheme.Colors.accentPrimary
                ) {
                    quickHub.emit(.client(.points))
                }
                Divider().background(AppTheme.Colors.borderSubtle)
            }

            actionRow(
                title: "Есть вопрос? Написать в поддержку",
                subtitle: "Обычно отвечаем в течение дня",
                icon: "message.fill",
                color: AppTheme.Colors.info
            ) {
                quickHub.emit(.client(.support))
            }

            NavigationLink {
                OrdaMarketView(viewModel: OrdaMarketViewModel(apiClient: sessionStore.apiClient))
                    .environmentObject(clientProfile)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.success.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Каталог")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Товары в приложении или витрина в браузере")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Divider().background(AppTheme.Colors.borderSubtle)

            NavigationLink {
                OrdaPayView(viewModel: OrdaPayViewModel(apiClient: sessionStore.apiClient))
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.purple)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Кошелёк")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Orda Pay — баланс и транзакции")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Divider().background(AppTheme.Colors.borderSubtle)

            NavigationLink {
                AchievementsView(viewModel: AchievementsViewModel(apiClient: sessionStore.apiClient))
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.warning)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.warning.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Достижения")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Значки, реферальная программа")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    @ViewBuilder
    private func actionRow(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.6))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile card
    @ViewBuilder
    private func profileCard(_ customer: ActiveCustomer) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Профиль", icon: "person.crop.circle.fill", iconColor: AppTheme.Colors.purple)
            profileRow("Имя", customer.name)
            Divider().background(AppTheme.Colors.borderSubtle)
            profileRow("Баллы лояльности", "\(customer.loyaltyPoints) ⭐")
            Divider().background(AppTheme.Colors.borderSubtle)
            profileRow("Количество визитов", "\(customer.visitsCount)")
            if let cid = customer.companyId, !cid.isEmpty {
                Divider().background(AppTheme.Colors.borderSubtle)
                profileRow("Компания (id)", String(cid.prefix(12)) + (cid.count > 12 ? "…" : ""))
            }
            if clientProfile.customers.count > 1 {
                Divider().background(AppTheme.Colors.borderSubtle)
                profileRow("Профилей в аккаунте", "\(clientProfile.customers.count)")
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func profileRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Logout
    private var logoutButton: some View {
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
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.errorBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
