import SwiftUI

struct AdminClientBookingsView: View {
    @StateObject var viewModel: AdminClientBookingsViewModel
    @State private var query = ""
    @State private var statusFilter: String = "all"
    @State private var selectedBooking: AdminBooking?
    @State private var actionStatus: String = "confirmed"

    private let statusOptions: [(key: String, label: String)] = [
        ("all", "Все"), ("pending", "Ожидают"), ("confirmed", "Подтверждены"), ("cancelled", "Отменены")
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
                } else if filteredBookings.isEmpty {
                    EmptyStateView(message: "Бронирований не найдено", icon: "calendar.badge.exclamationmark")
                } else {
                    bookingsListCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Брони клиентов")
        .refreshable { await viewModel.load() }
        .task { if viewModel.bookings.isEmpty { await viewModel.load() } }
        .sheet(item: $selectedBooking) { booking in
            bookingActionSheet(booking)
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
            SectionHeader(title: "Сводка бронирований", icon: "calendar.circle.fill", iconColor: AppTheme.Colors.accentBlue)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ВСЕГО", value: "\(viewModel.bookings.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ОЖИДАЮТ", value: "\(countByStatus(["pending", "new"]))", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "ПОДТВЕРЖД.", value: "\(countByStatus(["confirmed"]))", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "ОТМЕНЕНЫ", value: "\(countByStatus(["cancelled", "rejected"]))", color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder)
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
                        .background(statusFilter == opt.key ? AnyShapeStyle(AppTheme.Colors.accentBlue) : AnyShapeStyle(Color(hex: 0x1F2937)))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(statusFilter == opt.key ? AppTheme.Colors.accentBlue.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - List
    private var bookingsListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список бронирований", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentPrimary)
            ForEach(filteredBookings) { booking in
                bookingRow(booking)
                if booking.id != filteredBookings.last?.id {
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
    private func bookingRow(_ booking: AdminBooking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.customerName ?? "Клиент")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(AppDateFormatter.dayMonthTime.string(from: booking.startsAt))
                        .font(AppTheme.Typography.monoCaption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                StatusBadge(text: statusLabel(booking.status), style: badgeStyle(booking.status))
            }
            if let notes = booking.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            if viewModel.canEditStatus {
                Button {
                    selectedBooking = booking
                    actionStatus = booking.status.lowercased() == "confirmed" ? "cancelled" : "confirmed"
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle")
                        Text("Изменить статус")
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func bookingActionSheet(_ booking: AdminBooking) -> some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    SectionHeader(title: "Изменить статус", icon: "calendar.badge.checkmark", iconColor: AppTheme.Colors.accentBlue)
                    DataTableRow(cells: [
                        ("Клиент", booking.customerName ?? "—", AppTheme.Colors.textPrimary),
                        ("Время", AppDateFormatter.dayMonthTime.string(from: booking.startsAt), AppTheme.Colors.textSecondary)
                    ])
                }
                .appCard()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Picker("Новый статус", selection: $actionStatus) {
                        Text("Подтверждено").tag("confirmed")
                        Text("Отменено").tag("cancelled")
                    }
                    .pickerStyle(.segmented)
                    Button("Сохранить") {
                        AppHaptics.selection()
                        Task {
                            await viewModel.updateStatus(bookingId: booking.id, status: actionStatus)
                            selectedBooking = nil
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .appCard()

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Бронирование")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { selectedBooking = nil }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers
    private var filteredBookings: [AdminBooking] {
        let statusFiltered: [AdminBooking]
        if statusFilter == "all" {
            statusFiltered = viewModel.bookings
        } else {
            statusFiltered = viewModel.bookings.filter { $0.status.lowercased() == statusFilter }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return statusFiltered }
        return statusFiltered.filter { ($0.customerName?.lowercased().contains(q) ?? false) }
    }

    private func countByStatus(_ statuses: [String]) -> Int {
        viewModel.bookings.filter { statuses.contains($0.status.lowercased()) }.count
    }

    private func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "confirmed", "done": return "Подтверждено"
        case "cancelled", "rejected": return "Отменено"
        case "pending", "new": return "Ожидает"
        default: return status
        }
    }

    private func badgeStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "confirmed", "done": return .excellent
        case "cancelled", "rejected": return .critical
        case "pending", "new": return .warning
        default: return .info
        }
    }
}
