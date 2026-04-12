import SwiftUI

struct AdminClientSupportView: View {
    @StateObject var viewModel: AdminClientSupportViewModel
    @State private var query = ""
    @State private var statusFilter: String = "all"
    @State private var selectedTicket: AdminSupportTicket?
    @State private var actionStatus: String = "in_progress"

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
                } else if filteredTickets.isEmpty {
                    EmptyStateView(message: "Тикеты не найдены", icon: "bubble.left.and.exclamationmark.bubble.right")
                } else {
                    ticketsListCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Поддержка клиентов")
        .refreshable { await viewModel.load() }
        .task { if viewModel.tickets.isEmpty { await viewModel.load() } }
        .sheet(item: $selectedTicket) { ticket in
            ticketActionSheet(ticket)
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.actionErrorMessage != nil },
            set: { if !$0 { viewModel.actionErrorMessage = nil } }
        ), actions: {
            Button("ОК") { viewModel.actionErrorMessage = nil }
        }, message: { Text(ServerJSONPlaintext.normalize(viewModel.actionErrorMessage ?? "")) })
    }

    // MARK: - Summary
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Сводка тикетов", icon: "bubble.left.and.bubble.right.fill", iconColor: AppTheme.Colors.warning)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ВСЕГО", value: "\(viewModel.tickets.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "НОВЫЕ", value: "\(countByStatus(["new", "pending"]))", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "В РАБОТЕ", value: "\(countByStatus(["in_progress"]))", color: AppTheme.Colors.accentBlue, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ЗАКРЫТЫЕ", value: "\(countByStatus(["closed", "resolved"]))", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
            }
        }
        .appCard()
    }

    // MARK: - Controls
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            AppSearchBar(text: $query, placeholder: "Поиск по клиенту...")
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
                        .background(statusFilter == opt.key ? AnyShapeStyle(AppTheme.Colors.warning) : AnyShapeStyle(Color(hex: 0x1F2937)))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(statusFilter == opt.key ? AppTheme.Colors.warning.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - List
    private var ticketsListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Обращения", icon: "list.bullet.clipboard", iconColor: AppTheme.Colors.accentPrimary)
            ForEach(filteredTickets) { ticket in
                ticketRow(ticket)
                if ticket.id != filteredTickets.last?.id {
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
                            ProgressView().tint(AppTheme.Colors.warning)
                        } else {
                            Text("Показать еще")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
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
    private func ticketRow(_ ticket: AdminSupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.customerName ?? "Клиент")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                StatusBadge(text: statusLabel(ticket.status), style: badgeStyle(ticket.status))
            }
            Text(ticket.message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                if let priority = ticket.priority {
                    SecondaryChip(text: priorityLabel(priority), color: priorityColor(priority))
                }
            }
            if viewModel.canEditStatus {
                Button {
                    selectedTicket = ticket
                    actionStatus = ticket.status.lowercased() == "closed" ? "in_progress" : "closed"
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle")
                        Text("Изменить статус")
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func ticketActionSheet(_ ticket: AdminSupportTicket) -> some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Обращение", icon: "bubble.left.fill", iconColor: AppTheme.Colors.warning)
                    DataTableRow(cells: [
                        ("Клиент", ticket.customerName ?? "—", AppTheme.Colors.textPrimary)
                    ])
                    Text(ticket.message)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, 2)
                }
                .appCard()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Picker("Новый статус", selection: $actionStatus) {
                        Text("В работе").tag("in_progress")
                        Text("Закрыто").tag("closed")
                    }
                    .pickerStyle(.segmented)
                    Button("Сохранить") {
                        AppHaptics.selection()
                        Task {
                            await viewModel.updateStatus(requestId: ticket.id, status: actionStatus)
                            selectedTicket = nil
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .appCard()

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Тикет")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { selectedTicket = nil }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers
    private var filteredTickets: [AdminSupportTicket] {
        let statusFiltered: [AdminSupportTicket]
        if statusFilter == "all" {
            statusFiltered = viewModel.tickets
        } else {
            statusFiltered = viewModel.tickets.filter { $0.status.lowercased() == statusFilter }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return statusFiltered }
        return statusFiltered.filter { ($0.customerName?.lowercased().contains(q) ?? false) || $0.message.lowercased().contains(q) }
    }

    private func countByStatus(_ statuses: [String]) -> Int {
        viewModel.tickets.filter { statuses.contains($0.status.lowercased()) }.count
    }

    private func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "closed", "resolved": return "Закрыто"
        case "new", "pending": return "Новая"
        case "in_progress": return "В работе"
        case "rejected": return "Отклонено"
        default: return status
        }
    }

    private func badgeStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "closed", "resolved": return .excellent
        case "new", "pending": return .warning
        case "rejected": return .critical
        default: return .info
        }
    }

    private func priorityLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "high": return "Высокий"
        case "medium": return "Средний"
        case "low": return "Низкий"
        default: return raw
        }
    }

    private func priorityColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "high": return AppTheme.Colors.error
        case "medium": return AppTheme.Colors.warning
        case "low": return AppTheme.Colors.info
        default: return AppTheme.Colors.textSecondary
        }
    }
}
