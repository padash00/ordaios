import SwiftUI
import Combine

// MARK: - Models

struct TelegramBotStatus: Decodable {
    let connected: Bool?
    let chatId: String?
    let botUsername: String?
    let lastPing: String?

    var isConnected: Bool { connected ?? false }
}

private struct TelegramStatusEnvelope: Decodable {
    let status: TelegramBotStatus?
    let data: TelegramBotStatus?
    let connected: Bool?
    let chatId: String?

    var resolved: TelegramBotStatus {
        if let s = status { return s }
        if let d = data { return d }
        return TelegramBotStatus(connected: connected, chatId: chatId, botUsername: nil, lastPing: nil)
    }
}

private struct TelegramSendBody: Encodable {
    let action: String
    let message: String?
    let weekStart: String?
}

// MARK: - ViewModel

@MainActor
final class AdminTelegramViewModel: ObservableObject {
    @Published var botStatus: TelegramBotStatus?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var customMessage = ""
    @Published var selectedReportType = "weekly"

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let envelope: TelegramStatusEnvelope = try await apiClient.request(ContractEndpoint.api_telegram_status.get)
            botStatus = envelope.resolved
        } catch {
            botStatus = nil
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendReport() async {
        isSending = true
        successMessage = nil
        errorMessage = nil
        defer { isSending = false }
        do {
            let body = TelegramSendBody(action: "sendReport", message: nil, weekStart: nil)
            let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_telegram_send_report.post, body: body)
            successMessage = "Отчёт отправлен в Telegram"
            AppHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось отправить отчёт"
            AppHaptics.error()
        }
    }

    func sendSalarySnapshot() async {
        isSending = true
        successMessage = nil
        errorMessage = nil
        defer { isSending = false }
        do {
            let body = TelegramSendBody(action: "salarySnapshot", message: nil, weekStart: currentWeekStart())
            let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_telegram_salary_snapshot.post, body: body)
            successMessage = "Снимок зарплаты отправлен"
            AppHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось отправить снимок"
            AppHaptics.error()
        }
    }

    func sendCustomMessage() async {
        guard !customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        successMessage = nil
        errorMessage = nil
        defer { isSending = false }
        do {
            let body = TelegramSendBody(action: "sendMessage", message: customMessage, weekStart: nil)
            let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_telegram_send.post, body: body)
            successMessage = "Сообщение отправлено"
            customMessage = ""
            AppHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось отправить сообщение"
            AppHaptics.error()
        }
    }

    private func currentWeekStart() -> String {
        let cal = Calendar(identifier: .iso8601)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return f.string(from: monday)
    }
}

// MARK: - View

struct AdminTelegramView: View {
    @StateObject private var vm: AdminTelegramViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminTelegramViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                statusCard
                actionsCard
                customMessageCard

                if let msg = vm.successMessage {
                    resultBanner(msg, isSuccess: true)
                }
                if let err = vm.errorMessage {
                    resultBanner(err, isSuccess: false)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Telegram Hub")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.loadStatus() }
        .refreshable { await vm.loadStatus() }
    }

    // MARK: Status Card

    private var statusCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(vm.botStatus?.isConnected == true ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(vm.botStatus?.isConnected == true ? AppTheme.Colors.success : AppTheme.Colors.error)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Telegram Bot")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(vm.botStatus?.isConnected == true ? AppTheme.Colors.success : AppTheme.Colors.error)
                            .frame(width: 7, height: 7)
                        if vm.isLoading {
                            Text("Проверка…").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        } else if let status = vm.botStatus {
                            Text(status.isConnected ? "Подключён" : "Отключён")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(status.isConnected ? AppTheme.Colors.success : AppTheme.Colors.error)
                        } else {
                            Text("Неизвестно").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                }
                Spacer()
                Button {
                    Task { await vm.loadStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.accentBlue)
                }
                .buttonStyle(.plain)
            }

            if let status = vm.botStatus {
                if let username = status.botUsername {
                    infoRow("Бот", "@\(username)")
                }
                if let chatId = status.chatId {
                    infoRow("Chat ID", chatId)
                }
                if let ping = status.lastPing {
                    infoRow("Последний пинг", String(ping.prefix(16)))
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Actions Card

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Быстрые действия", icon: "bolt.fill", iconColor: AppTheme.Colors.warning)

            telegramActionBtn(
                title: "Отправить недельный отчёт",
                subtitle: "Доходы, расходы, смены за текущую неделю",
                icon: "chart.bar.fill",
                color: AppTheme.Colors.accentPrimary
            ) {
                Task { await vm.sendReport() }
            }

            telegramActionBtn(
                title: "Снимок зарплаты",
                subtitle: "Текущие начисления по всем операторам",
                icon: "banknote.fill",
                color: AppTheme.Colors.success
            ) {
                Task { await vm.sendSalarySnapshot() }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Custom Message Card

    private var customMessageCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Произвольное сообщение", icon: "text.bubble.fill", iconColor: AppTheme.Colors.accentBlue)

            TextField("Текст сообщения…", text: $vm.customMessage, axis: .vertical)
                .lineLimit(3...6)
                .appInputStyle()

            Button {
                Task { await vm.sendCustomMessage() }
            } label: {
                HStack {
                    if vm.isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Отправить")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(vm.isSending || vm.customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Helpers

    @ViewBuilder
    private func telegramActionBtn(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .lineLimit(1)
                }
                Spacer()
                if vm.isSending {
                    ProgressView().tint(AppTheme.Colors.accentPrimary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(vm.isSending)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value).font(AppTheme.Typography.monoCaption).foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    @ViewBuilder
    private func resultBanner(_ message: String, isSuccess: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isSuccess ? AppTheme.Colors.success : AppTheme.Colors.error)
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isSuccess ? AppTheme.Colors.success : AppTheme.Colors.error)
            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(isSuccess ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(isSuccess ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }
}
