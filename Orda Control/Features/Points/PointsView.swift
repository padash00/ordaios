import SwiftUI
import CoreImage.CIFilterBuiltins

struct PointsView: View {
    @StateObject var viewModel: PointsViewModel
    @State private var showQR = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    Task { await viewModel.load() }
                }
            } else if let summary = viewModel.summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        pointsHeroCard(summary)
                        tierCard(summary)
                        rewardsCard
                        statsRow(summary)
                        historySection
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .refreshable { await viewModel.load() }
                .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
                .sheet(isPresented: $showQR) {
                    LoyaltyQRSheet(
                        points: summary.points,
                        customerId: viewModel.primaryCustomerId,
                        tierTitle: viewModel.currentTier.title
                    )
                }
            } else {
                EmptyStateView(message: "Пока нет данных", icon: "star.circle")
            }
        }
        .navigationTitle("Баллы лояльности")
        .task {
            if viewModel.summary == nil { await viewModel.load() }
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    @ViewBuilder
    private func tierCard(_ summary: PointsSummary) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Уровень лояльности", icon: "star.circle.fill", iconColor: AppTheme.Colors.warning)
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.currentTier.title)
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                if let next = viewModel.nextTier {
                    Text("До \(next.title): \(viewModel.pointsToNextTier)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    Text("Максимальный уровень")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
            AppProgressBar(value: viewModel.tierProgress, color: AppTheme.Colors.warning)
            HStack {
                Text("Silver 0+")
                Spacer()
                Text("Gold 500+")
                Spacer()
                Text("Platinum 2000+")
            }
            .font(AppTheme.Typography.micro)
            .foregroundStyle(AppTheme.Colors.textMuted)

            if let next = viewModel.nextTier {
                Text("Осталось \(viewModel.pointsToNextTier) баллов до уровня \(next.title).")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .appCard()
    }

    // MARK: Hero card with big balance

    @ViewBuilder
    private func pointsHeroCard(_ summary: PointsSummary) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ваш баланс")
                        .font(AppTheme.Typography.micro)
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(summary.points)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                        Text("баллов")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        showQR = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.accentPrimary)
                            Text("QR карта")
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .padding(10)
                        .background(AppTheme.Colors.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    NavigationLink(destination: OrdaWalletPassView(
                        customerId: viewModel.primaryCustomerId,
                        customerName: "Клиент Orda",
                        points: summary.points,
                        tierTitle: viewModel.currentTier.title
                    )) {
                        VStack(spacing: 4) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.black)
                            Text("Wallet")
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                }
            }

            // Points worth indicator
            let worth = Double(summary.points) / 10.0
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Text("Эквивалентно ≈ \(MoneyFormatter.short(worth)) скидки")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
            }
        }
        .appCard()
    }

    // MARK: Stats row

    @ViewBuilder
    private func statsRow(_ summary: PointsSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: AppTheme.Spacing.sm), GridItem(.flexible(), spacing: AppTheme.Spacing.sm)],
            spacing: AppTheme.Spacing.sm
        ) {
            statMini(
                title: "Потрачено",
                value: MoneyFormatter.short(summary.totalSpent),
                icon: "tenge.sign.circle.fill",
                color: AppTheme.Colors.purple
            )
            statMini(
                title: "Визиты",
                value: "\(summary.visits)",
                icon: "figure.walk.circle.fill",
                color: AppTheme.Colors.accentBlue
            )
            statMini(
                title: "Заработано",
                value: "\(viewModel.totalEarned)",
                icon: "star.fill",
                color: AppTheme.Colors.warning
            )
            .gridCellColumns(2)
        }
    }

    @ViewBuilder
    private func statMini(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(AppTheme.Typography.micro)
                .tracking(0.8)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.sm)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(color.opacity(0.18), lineWidth: 1))
    }

    // MARK: Rewards
    @ViewBuilder
    private var rewardsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Что можно потратить", icon: "gift.fill", iconColor: AppTheme.Colors.accentPrimary)
            if let message = viewModel.redemptionMessage {
                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.success)
            }
            ForEach(viewModel.rewardOptions) { reward in
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reward.title)
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(reward.subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(reward.pointsCost) ⭐")
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(rewardStateText(reward))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(rewardStateColor(reward))
                        Button {
                            Task { await viewModel.redeem(reward) }
                        } label: {
                            if viewModel.redeemingRewardId == reward.id {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Обменять")
                                    .font(AppTheme.Typography.caption)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accentPrimary)
                        .disabled(!viewModel.canRedeem(reward) || viewModel.redeemingRewardId != nil)
                    }
                }
                .padding(.vertical, 4)
                if reward.id != viewModel.rewardOptions.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .appCard()
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "История операций", icon: "clock.arrow.circlepath", iconColor: AppTheme.Colors.info)

            if viewModel.history.isEmpty {
                EmptyStateView(message: "Пока нет операций", icon: "star.circle")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.history.enumerated()), id: \.element.id) { index, item in
                        historyRow(item)
                        if index < viewModel.history.count - 1 {
                            Divider().background(AppTheme.Colors.borderSubtle).padding(.leading, AppTheme.Spacing.md)
                        }
                    }
                }
                .background(AppTheme.Colors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
                if viewModel.hasMoreHistory {
                    Button {
                        Task { await viewModel.loadMoreHistory() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMoreHistory {
                                ProgressView().tint(AppTheme.Colors.accentPrimary)
                            } else {
                                Text("Показать еще операции")
                                    .font(AppTheme.Typography.captionBold)
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoadingMoreHistory)
                }
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ item: PointsHistoryItem) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.netDelta >= 0 ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg)
                    .frame(width: 36, height: 36)
                Image(systemName: item.netDelta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(item.netDelta >= 0 ? AppTheme.Colors.success : AppTheme.Colors.error)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.netDelta >= 0 ? "Начисление" : "Списание")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let total = item.totalAmount, total > 0 {
                    Text("Покупка на \(MoneyFormatter.short(total))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                if let date = item.saleDate {
                    Text(formatSaleDate(date))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                let delta = item.netDelta
                Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(delta >= 0 ? AppTheme.Colors.success : AppTheme.Colors.error)
                Text("баллов")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    private func formatSaleDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = f.date(from: String(iso.prefix(19))) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "ru_RU")
            out.dateFormat = "d MMM yyyy"
            return out.string(from: d)
        }
        return String(iso.prefix(10))
    }

    private func rewardStateText(_ reward: LoyaltyRewardOption) -> String {
        if viewModel.canRedeem(reward) { return "Доступно" }
        if !viewModel.hasTierAccess(reward.minTierKey) { return "Нужен выше tier" }
        let missing = max(0, reward.pointsCost - (viewModel.summary?.points ?? 0))
        return "Не хватает \(missing)"
    }

    private func rewardStateColor(_ reward: LoyaltyRewardOption) -> Color {
        if viewModel.canRedeem(reward) { return AppTheme.Colors.success }
        if !viewModel.hasTierAccess(reward.minTierKey) { return AppTheme.Colors.warning }
        return AppTheme.Colors.textMuted
    }
}

// MARK: - QR Sheet

struct LoyaltyQRSheet: View {
    let points: Int
    let customerId: String
    let tierTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()
                if let qrImage = generateQR(text: "orda://client/\(customerId)") {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                VStack(spacing: 6) {
                    Text("Карта лояльности")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Покажите кассиру для начисления баллов")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                    Text("ID: \(customerId)")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text("\(points) баллов")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                        .padding(.top, 4)
                    Text("Уровень: \(tierTitle)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("QR-код")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func generateQR(text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
