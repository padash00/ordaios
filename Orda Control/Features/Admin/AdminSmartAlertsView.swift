import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class SmartAlertsViewModel: ObservableObject {
    @Published var alerts: [SmartAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var notFound = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        notFound = false
        do {
            let endpoint = ContractEndpoint.api_admin_smart_alerts.get
            let response: SmartAlertsEnvelope = try await apiClient.request(endpoint)
            alerts = response.alerts ?? []
        } catch let error as APIError {
            switch error {
            case .validation:
                // 404 — API not deployed yet, show nothing
                notFound = true
                alerts = []
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct SmartAlertsEnvelope: Decodable {
    let alerts: [SmartAlert]?
    let items: [SmartAlert]?
    let data: [SmartAlert]?
}

// MARK: - SmartAlertsCard (inline card for dashboard)

struct SmartAlertsCard: View {
    @StateObject private var vm: SmartAlertsViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: SmartAlertsViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                EmptyView()
            } else if vm.notFound || vm.alerts.isEmpty {
                EmptyView()
            } else {
                alertsCardContent
            }
        }
        .task { await vm.load() }
    }

    private var alertsCardContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text("⚠️")
                    .font(.system(size: 16))
                Text("Умные алерты")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(vm.alerts.count)")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.warningBg)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.Colors.warningBorder, lineWidth: 1))
            }

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(vm.alerts.prefix(5)) { alert in
                    AlertRow(alert: alert)
                }
            }
        }
        .appCard()
    }
}

private struct AlertRow: View {
    let alert: SmartAlert

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)

            Text(alert.message)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let label = alert.actionLabel {
                Text(label)
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(severityColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var severityColor: Color {
        switch alert.severity {
        case "critical": return AppTheme.Colors.error
        case "warning": return AppTheme.Colors.warning
        default: return AppTheme.Colors.info
        }
    }
}

// MARK: - AdminSmartAlertsView (full screen)

struct AdminSmartAlertsView: View {
    @StateObject private var vm: SmartAlertsViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: SmartAlertsViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingStateView(message: "Загрузка алертов...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else if vm.notFound || vm.alerts.isEmpty {
                EmptyStateView(message: "Алертов нет", icon: "bell.slash")
            } else {
                alertsList
            }
        }
        .navigationTitle("Умные алерты")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    private var alertsList: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(vm.alerts) { alert in
                    FullAlertRow(alert: alert)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

private struct FullAlertRow: View {
    let alert: SmartAlert

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(severityColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.message)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(alert.type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)

                    Text("·")
                        .foregroundStyle(AppTheme.Colors.textMuted)

                    Text(alert.severity.uppercased())
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(severityColor)
                }

                if let label = alert.actionLabel {
                    Text(label)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(severityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severityColor.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(severityColor.opacity(0.3), lineWidth: 1))
                }
            }

            Spacer()
        }
        .appCard()
    }

    private var severityColor: Color {
        switch alert.severity {
        case "critical": return AppTheme.Colors.error
        case "warning": return AppTheme.Colors.warning
        default: return AppTheme.Colors.info
        }
    }
}
