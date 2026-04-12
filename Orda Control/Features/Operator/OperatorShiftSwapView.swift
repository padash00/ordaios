import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class OperatorShiftSwapViewModel: ObservableObject {
    @Published var incomingRequests: [ShiftSwapRequest] = []
    @Published var outgoingRequests: [ShiftSwapRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var notFound = false
    @Published var isSubmitting = false
    @Published var submitError: String? = nil
    @Published var submitSuccess = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        notFound = false
        do {
            let endpoint = ContractEndpoint.api_operator_shift_swap_requests.get
            let response: ShiftSwapListEnvelope = try await apiClient.request(endpoint)
            incomingRequests = response.incoming ?? []
            outgoingRequests = response.outgoing ?? []
        } catch let error as APIError {
            switch error {
            case .validation:
                notFound = true
                incomingRequests = []
                outgoingRequests = []
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func submitSwapRequest(shiftDate: String, shiftType: String, reason: String?) async {
        isSubmitting = true
        submitError = nil
        submitSuccess = false
        do {
            let endpoint = ContractEndpoint.api_operator_shift_swap_request.post
            let body = ShiftSwapCreatePayload(shiftDate: shiftDate, shiftType: shiftType, reason: reason?.isEmpty == true ? nil : reason)
            let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
            submitSuccess = true
            await load()
        } catch let error as APIError {
            submitError = error.localizedDescription
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }

    func acceptSwapRequest(requestId: String) async {
        do {
            let endpoint = ContractEndpoint.api_operator_shift_swap_request.patch
            let body = ShiftSwapAcceptBody(requestId: requestId, action: "accept")
            let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShiftSwapListEnvelope: Decodable {
    let incoming: [ShiftSwapRequest]?
    let outgoing: [ShiftSwapRequest]?
}

private struct ShiftSwapAcceptBody: Encodable {
    let requestId: String
    let action: String
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case action
    }
}

// MARK: - View

struct OperatorShiftSwapView: View {
    @StateObject private var vm: OperatorShiftSwapViewModel
    @State private var showCreateSheet = false

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: OperatorShiftSwapViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingStateView(message: "Загрузка...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else if vm.notFound {
                EmptyStateView(message: "Обмен сменами скоро будет доступен", icon: "arrow.left.arrow.right.circle")
            } else {
                mainContent
            }
        }
        .navigationTitle("Обмен сменами")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSwapRequestSheet(vm: vm, isPresented: $showCreateSheet)
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Incoming requests
                if !vm.incomingRequests.isEmpty {
                    incomingSection
                }

                // Outgoing requests
                if !vm.outgoingRequests.isEmpty {
                    outgoingSection
                }

                if vm.incomingRequests.isEmpty && vm.outgoingRequests.isEmpty {
                    EmptyStateView(message: "Обмен сменами скоро будет доступен", icon: "arrow.left.arrow.right.circle")
                        .frame(height: 300)
                }

                // "+ Найти замену" button
                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Найти замену")
                            .font(AppTheme.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Входящие запросы", icon: "arrow.down.circle.fill", iconColor: AppTheme.Colors.accentBlue)

            ForEach(vm.incomingRequests) { request in
                SwapRequestRow(request: request, isIncoming: true) {
                    Task { await vm.acceptSwapRequest(requestId: request.id) }
                }
            }
        }
    }

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Мои запросы", icon: "arrow.up.circle.fill", iconColor: AppTheme.Colors.warning)

            ForEach(vm.outgoingRequests) { request in
                SwapRequestRow(request: request, isIncoming: false, onAccept: nil)
            }
        }
    }
}

// MARK: - SwapRequestRow

private struct SwapRequestRow: View {
    let request: ShiftSwapRequest
    let isIncoming: Bool
    let onAccept: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.shiftDate)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(shiftTypeLabel)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                StatusBadge(text: statusLabel, style: statusStyle)
            }

            if let name = isIncoming ? request.requesterName : request.acceptorName, !name.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text(name)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            if isIncoming && request.status == "pending" {
                Button {
                    onAccept?()
                } label: {
                    Text("Взять смену")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                }
                .padding(.top, 2)
            }
        }
        .appCard()
    }

    private var shiftTypeLabel: String {
        switch request.shiftType {
        case "day": return "Дневная смена"
        case "night": return "Ночная смена"
        default: return request.shiftType
        }
    }

    private var statusLabel: String {
        switch request.status {
        case "pending": return "Ожидание"
        case "accepted": return "Принято"
        case "approved": return "Одобрено"
        case "rejected": return "Отклонено"
        default: return request.status
        }
    }

    private var statusStyle: StatusBadge.Style {
        switch request.status {
        case "approved", "accepted": return .excellent
        case "rejected": return .critical
        default: return .warning
        }
    }
}

// MARK: - CreateSwapRequestSheet

private struct CreateSwapRequestSheet: View {
    @ObservedObject var vm: OperatorShiftSwapViewModel
    @Binding var isPresented: Bool
    @State private var shiftDate = Date()
    @State private var shiftType = "day"
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Найти замену", icon: "arrow.left.arrow.right.circle.fill", iconColor: AppTheme.Colors.accentPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ДАТА СМЕНЫ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        DatePicker("", selection: $shiftDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .appInputStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ТИП СМЕНЫ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Picker("Тип смены", selection: $shiftType) {
                            Text("Дневная").tag("day")
                            Text("Ночная").tag("night")
                        }
                        .pickerStyle(.segmented)
                        .appInputStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ПРИЧИНА (НЕОБЯЗАТЕЛЬНО)")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        TextField("Укажите причину...", text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .appInputStyle()
                    }

                    if let err = vm.submitError {
                        Text(err)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    }

                    Button {
                        Task {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let dateString = formatter.string(from: shiftDate)
                            await vm.submitSwapRequest(shiftDate: dateString, shiftType: shiftType, reason: reason)
                            if vm.submitSuccess {
                                isPresented = false
                            }
                        }
                    } label: {
                        Group {
                            if vm.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Отправить запрос")
                                    .font(AppTheme.Typography.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .disabled(vm.isSubmitting)
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Запрос на обмен")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { isPresented = false }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}
