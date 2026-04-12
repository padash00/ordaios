import SwiftUI

// MARK: - Service

protocol AdminBroadcastServicing {
    func loadBroadcasts() async throws -> [BroadcastMessage]
    func sendBroadcast(title: String, body: String) async throws
}

final class AdminBroadcastService: AdminBroadcastServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadBroadcasts() async throws -> [BroadcastMessage] {
        let response: DataListResponse<BroadcastMessage> = try await apiClient.request(ContractEndpoint.api_admin_broadcast.get)
        return response.data
    }

    func sendBroadcast(title: String, body: String) async throws {
        let payload = BroadcastCreatePayload(title: title, body: body)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_broadcast.post, body: payload)
    }
}

// MARK: - ViewModel

@MainActor
final class AdminBroadcastViewModel: ObservableObject {
    @Published var broadcasts: [BroadcastMessage] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var composeTitle = ""
    @Published var composeBody = ""
    @Published var showCompose = false

    private let service: AdminBroadcastServicing

    init(service: AdminBroadcastServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            broadcasts = try await service.loadBroadcasts()
        } catch let error as APIError {
            // 404 = API not deployed yet — show empty state
            if error == .validation(message: "") || (error.errorDescription ?? "").contains("404") {
                broadcasts = []
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            broadcasts = []
        }
    }

    func send() async {
        guard !composeTitle.trimmingCharacters(in: .whitespaces).isEmpty,
              !composeBody.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        errorMessage = nil
        successMessage = nil
        defer { isSending = false }
        do {
            try await service.sendBroadcast(title: composeTitle, body: composeBody)
            successMessage = "Рассылка отправлена"
            composeTitle = ""
            composeBody = ""
            showCompose = false
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось отправить рассылку"
            AppHaptics.error()
        }
    }
}

// MARK: - View

struct AdminBroadcastView: View {
    let apiClient: APIClient

    @StateObject private var vm: AdminBroadcastViewModel

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _vm = StateObject(wrappedValue: AdminBroadcastViewModel(
            service: AdminBroadcastService(apiClient: apiClient)
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.bgPrimary.ignoresSafeArea()

            if vm.isLoading {
                LoadingStateView(message: "Загрузка рассылок…")
            } else if let err = vm.errorMessage, vm.broadcasts.isEmpty {
                ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
            } else if vm.broadcasts.isEmpty {
                EmptyStateView(message: "Рассылки недоступны", icon: "megaphone")
            } else {
                broadcastList
            }
        }
        .navigationTitle("Рассылка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.showCompose = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
        .sheet(isPresented: $vm.showCompose) {
            composeSheet
        }
        .task { await vm.load() }
    }

    private var broadcastList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                if let success = vm.successMessage {
                    Text(success)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.successBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                ForEach(vm.broadcasts) { broadcast in
                    broadcastCard(broadcast)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func broadcastCard(_ item: BroadcastMessage) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if let name = item.sentByName {
                        Text(name)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDate(item.sentAt))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    if let count = item.recipientCount {
                        Label("\(count)", systemImage: "person.2.fill")
                            .font(AppTheme.Typography.micro)
                            .foregroundStyle(AppTheme.Colors.accentBlue)
                    }
                }
            }

            Text(item.body)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(3)
        }
        .appCard()
    }

    private var composeSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.bgPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Заголовок")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            TextField("Введите заголовок", text: $vm.composeTitle)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .padding(AppTheme.Spacing.sm)
                                .background(AppTheme.Colors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Текст сообщения")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            TextEditor(text: $vm.composeBody)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .background(AppTheme.Colors.surfaceSecondary)
                                .frame(minHeight: 140)
                                .padding(AppTheme.Spacing.xs)
                                .background(AppTheme.Colors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
                        }

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.error)
                        }

                        Button {
                            Task { await vm.send() }
                        } label: {
                            HStack {
                                if vm.isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "megaphone.fill")
                                    Text("Отправить всем операторам")
                                }
                            }
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.Colors.warning)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                        }
                        .disabled(vm.isSending || vm.composeTitle.trimmingCharacters(in: .whitespaces).isEmpty || vm.composeBody.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity((vm.composeTitle.trimmingCharacters(in: .whitespaces).isEmpty || vm.composeBody.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1.0)
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
            .navigationTitle("Новая рассылка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { vm.showCompose = false }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            display.locale = Locale(identifier: "ru_RU")
            return display.string(from: date)
        }
        return dateStr
    }
}
