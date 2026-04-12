import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class OrdaPayViewModel: ObservableObject {
    @Published private(set) var balance: ClientBalance?
    @Published private(set) var transactions: [ClientBalanceTransaction] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isNotAvailable = false
    @Published var showKaspiAlert = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var balanceFormatted: String {
        guard let b = balance else { return "—" }
        let currency = b.currency ?? "₸"
        return "\(Int(b.balance)) \(currency)"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        isNotAvailable = false
        defer { isLoading = false }

        do {
            async let balanceFetch: ClientBalance = apiClient.request(ContractEndpoint.api_client_balance.get)
            async let txFetch: [ClientBalanceTransaction] = apiClient.request(ContractEndpoint.api_client_balance_transactions.get)
            balance = try await balanceFetch
            transactions = (try await txFetch).sorted { $0.createdAt > $1.createdAt }
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

    func openKaspi() {
        let kaspiURL = URL(string: "kaspi://pay")!
        if UIApplication.shared.canOpenURL(kaspiURL) {
            UIApplication.shared.open(kaspiURL)
        } else {
            showKaspiAlert = true
        }
    }
}

// MARK: - Main View

struct OrdaPayView: View {
    @StateObject var viewModel: OrdaPayViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(message: "Загрузка кошелька...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.isNotAvailable {
                EmptyStateView(message: "Orda Pay пока не подключён", icon: "creditcard")
            } else {
                walletContent
            }
        }
        .navigationTitle("Orda Pay")
        .task { await viewModel.load() }
        .alert("Kaspi не установлен", isPresented: $viewModel.showKaspiAlert) {
            Button("Закрыть", role: .cancel) {}
        } message: {
            Text("Приложение Kaspi не найдено на устройстве. Пожалуйста, установите Kaspi для пополнения.")
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var walletContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                balanceCard
                topUpButton
                transactionsSection
            }
            .padding(AppTheme.Spacing.md)
        }
        .refreshable { await viewModel.load() }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var balanceCard: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Баланс")
                .font(AppTheme.Typography.micro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textMuted)

            Text(viewModel.balanceFormatted)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.purple.opacity(0.5), AppTheme.Colors.accentBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(AppTheme.Colors.purpleBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }

    private var topUpButton: some View {
        Button {
            viewModel.openKaspi()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("+ Пополнить через Kaspi")
                    .font(AppTheme.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.kaspiColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var transactionsSection: some View {
        if viewModel.transactions.isEmpty {
            EmptyStateView(message: "Транзакций пока нет", icon: "list.bullet.rectangle")
                .frame(height: 200)
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "История транзакций", icon: "clock.arrow.circlepath", iconColor: AppTheme.Colors.accentBlue)

                ForEach(viewModel.transactions) { tx in
                    TransactionRow(transaction: tx)
                    if tx.id != viewModel.transactions.last?.id {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }
            .appCard()
        }
    }
}

// MARK: - Transaction Row

private struct TransactionRow: View {
    let transaction: ClientBalanceTransaction

    var amountColor: Color {
        transaction.type == "topup" ? AppTheme.Colors.success : AppTheme.Colors.error
    }

    var amountPrefix: String {
        transaction.type == "topup" ? "+" : "−"
    }

    var formattedDate: String {
        let raw = transaction.createdAt
        // Basic ISO date display: show first 10 chars (YYYY-MM-DD)
        if raw.count >= 10 {
            let datePart = String(raw.prefix(10))
            // Convert YYYY-MM-DD to DD.MM.YYYY
            let parts = datePart.split(separator: "-")
            if parts.count == 3 {
                return "\(parts[2]).\(parts[1]).\(parts[0])"
            }
        }
        return raw
    }

    var typeLabel: String {
        switch transaction.type {
        case "topup": return "Пополнение"
        case "payment": return "Оплата"
        default: return transaction.type.capitalized
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: transaction.type == "topup" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(amountColor)
                .frame(width: 34, height: 34)
                .background(amountColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description ?? typeLabel)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(formattedDate)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            Spacer()

            Text("\(amountPrefix)\(Int(transaction.amount)) ₸")
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 4)
    }
}
