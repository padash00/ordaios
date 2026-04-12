import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @StateObject var viewModel: SupportViewModel
    @State private var showComposer = false
    @State private var statusFilter: String = "all"

    private let statusOptions: [(key: String, label: String)] = [
        ("all", "Все"), ("new", "Новые"), ("in_progress", "В работе"), ("closed", "Закрытые")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                summaryCard
                controlsCard
                if viewModel.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(message: error) { Task { await viewModel.load() } }
                } else if filteredRequests.isEmpty {
                    EmptyStateView(message: "Обращений нет\nНапишите в поддержку", icon: "bubble.left.and.bubble.right")
                } else {
                    ticketsListCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Поддержка")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showComposer = true
                } label: {
                    Image(systemName: "square.and.pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Новое обращение")
            }
        }
        .sheet(isPresented: $showComposer) {
            SupportComposer(viewModel: viewModel)
                .environmentObject(clientProfile)
        }
        .refreshable {
            await clientProfile.refresh(apiClient: sessionStore.apiClient)
            await viewModel.load()
        }
        .task {
            await clientProfile.refresh(apiClient: sessionStore.apiClient)
            if viewModel.requests.isEmpty { await viewModel.load() }
        }
    }

    // MARK: - Summary
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Мои обращения", icon: "bubble.left.and.bubble.right.fill", iconColor: AppTheme.Colors.accentBlue)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ВСЕГО", value: "\(viewModel.requests.count)",
                         color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "НОВЫЕ", value: "\(countByStatus(["new", "pending"]))",
                         color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "В РАБОТЕ", value: "\(countByStatus(["in_progress"]))",
                         color: AppTheme.Colors.accentBlue, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ЗАКРЫТЫЕ", value: "\(countByStatus(["closed", "resolved"]))",
                         color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
            }
        }
        .appCard()
    }

    // MARK: - Controls
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusOptions, id: \.key) { opt in
                        Button(opt.label) {
                            withAnimation(.easeInOut(duration: 0.2)) { statusFilter = opt.key }
                        }
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(statusFilter == opt.key ? .white : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(statusFilter == opt.key ? AnyShapeStyle(AppTheme.Colors.accentBlue) : AnyShapeStyle(Color(hex: 0x1F2937)))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(statusFilter == opt.key ? AppTheme.Colors.accentBlue.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                    }
                }
            }
            Button {
                showComposer = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Написать в поддержку")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .appCard()
    }

    // MARK: - List
    private var ticketsListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список обращений", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentPrimary)
            ForEach(filteredRequests) { request in
                requestRow(request)
                if request.id != filteredRequests.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
            if viewModel.hasMore {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView().tint(AppTheme.Colors.accentPrimary)
                        } else {
                            Text("Показать еще")
                                .font(AppTheme.Typography.captionBold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingMore)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func requestRow(_ request: SupportRequestItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(ServerJSONPlaintext.normalize(request.message))
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                StatusBadge(text: supportStatusLabel(request.status), style: statusBadgeStyle(request.status))
            }
            HStack(spacing: 8) {
                if let priority = request.priority {
                    SecondaryChip(text: supportPriorityLabel(priority), color: priorityColor(priority))
                }
                if let cid = request.companyId, !cid.isEmpty {
                    SecondaryChip(text: "Компания \(cid.prefix(6))…", color: AppTheme.Colors.textMuted)
                }
                Text(AppDateFormatter.dateTime.string(from: request.createdAt))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    private var filteredRequests: [SupportRequestItem] {
        if statusFilter == "all" { return viewModel.requests }
        return viewModel.requests.filter {
            let s = $0.status.lowercased()
            switch statusFilter {
            case "new": return ["new", "pending"].contains(s)
            case "in_progress": return s == "in_progress"
            case "closed": return ["closed", "resolved"].contains(s)
            default: return true
            }
        }
    }

    private func countByStatus(_ statuses: [String]) -> Int {
        viewModel.requests.filter { statuses.contains($0.status.lowercased()) }.count
    }

    private func supportStatusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "new", "pending": return "Новая"
        case "in_progress": return "В работе"
        case "closed", "resolved": return "Закрыта"
        case "rejected": return "Отклонена"
        default: return status
        }
    }

    private func statusBadgeStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "closed", "resolved": return .excellent
        case "new", "pending": return .warning
        case "rejected": return .critical
        default: return .info
        }
    }

    private func supportPriorityLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "high", "urgent": return "Высокий"
        case "medium", "normal": return "Средний"
        case "low": return "Низкий"
        default: return raw
        }
    }

    private func priorityColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "high", "urgent": return AppTheme.Colors.error
        case "medium", "normal": return AppTheme.Colors.warning
        case "low": return AppTheme.Colors.info
        default: return AppTheme.Colors.textSecondary
        }
    }
}

private struct SupportComposer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @ObservedObject var viewModel: SupportViewModel
    @State private var message: String = ""

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmedMessage.isEmpty && !viewModel.isSending }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Новое обращение", icon: "bubble.left.fill", iconColor: AppTheme.Colors.accentBlue)

                    if clientProfile.customers.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("КЛУБ / ПРОФИЛЬ")
                                .font(AppTheme.Typography.micro)
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                            Picker("Профиль клиента", selection: Binding(
                                get: { clientProfile.selectedCustomerId ?? clientProfile.customers.first?.id ?? "" },
                                set: { clientProfile.selectedCustomerId = $0.isEmpty ? nil : $0 }
                            )) {
                                ForEach(clientProfile.customers) { row in
                                    Text(row.name).tag(row.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputStyle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("СООБЩЕНИЕ")
                            .font(AppTheme.Typography.micro)
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        TextField("Опишите вопрос или проблему", text: $message, axis: .vertical)
                            .lineLimit(5...12)
                            .appInputStyle()
                    }

                    if let error = viewModel.sendErrorMessage {
                        AlertBanner(message: error, style: .critical)
                    }

                    Button("Отправить") {
                        Task {
                            let success = await viewModel.send(message: message)
                            if success { dismiss() }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSend)

                    if viewModel.isSending {
                        HStack {
                            ProgressView().tint(AppTheme.Colors.accentPrimary)
                            Text("Отправка...").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                }
                .appCard()
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Написать в поддержку")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
