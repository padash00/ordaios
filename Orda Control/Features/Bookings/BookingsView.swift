import SwiftUI
import EventKit

struct BookingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @StateObject var viewModel: BookingsViewModel
    @State private var showCreateSheet = false
    @State private var statusFilter: String = "all"
    @State private var dayFilterEnabled = false
    @State private var selectedDay = Date()
    @State private var bookingToCancel: Booking?
    @State private var calendarBannerMessage: String?
    @State private var calendarBannerStyle: StatusBadge.Style = .info
    private let eventStore = EKEventStore()

    private let statusOptions: [(key: String, label: String)] = [
        ("all", "Все"), ("pending", "Ожидают"), ("confirmed", "Подтверждены"), ("cancelled", "Отменены")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if let calendarBannerMessage {
                    AlertBanner(message: calendarBannerMessage, style: calendarBannerStyle, onDismiss: {
                        self.calendarBannerMessage = nil
                    })
                }
                summaryCard
                nearestBookingCard
                repeatBookingCard
                controlsCard
                if viewModel.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(message: error) { Task { await viewModel.load() } }
                } else if filteredBookings.isEmpty {
                    EmptyStateView(message: "Нет бронирований по выбранному фильтру", icon: "calendar.badge.plus")
                } else {
                    bookingsListCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Мои брони")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Создать бронь")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateBookingSheet(viewModel: viewModel)
                .environmentObject(clientProfile)
        }
        .confirmationDialog(
            "Отменить бронирование?",
            isPresented: Binding(
                get: { bookingToCancel != nil },
                set: { if !$0 { bookingToCancel = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Отменить бронь", role: .destructive) {
                guard let booking = bookingToCancel else { return }
                Task {
                    let ok = await viewModel.cancelBooking(booking)
                    if ok { AppHaptics.success() } else { AppHaptics.error() }
                    bookingToCancel = nil
                }
            }
            Button("Закрыть", role: .cancel) { bookingToCancel = nil }
        } message: {
            Text("Можно отменить только не позднее чем за 24 часа до начала.")
        }
        .refreshable {
            await clientProfile.refresh(apiClient: sessionStore.apiClient)
            await viewModel.load()
        }
        .task {
            await clientProfile.refresh(apiClient: sessionStore.apiClient)
            if viewModel.bookings.isEmpty { await viewModel.load() }
        }
    }

    private var nearestBookingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Ближайшая бронь", icon: "calendar.badge.clock", iconColor: AppTheme.Colors.accentBlue)
            if let booking = nearestUpcomingBooking {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppDateFormatter.dayMonthTime.string(from: booking.startsAt))
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(bookingStatusLabel(booking.status))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        if let notes = booking.notes, !notes.isEmpty {
                            Text(notes)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        Task { await addBookingToCalendar(booking) }
                    } label: {
                        Label("В календарь", systemImage: "calendar.badge.plus")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.accentPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Нет предстоящих броней")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .appCard()
    }

    private var repeatBookingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Повторить прошлую бронь", icon: "arrow.clockwise.circle.fill", iconColor: AppTheme.Colors.warning)
            if let booking = viewModel.lastRepeatCandidate {
                let nextDate = viewModel.suggestedRepeatDate(for: booking)
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Предложенная дата")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Text(AppDateFormatter.dayMonthTime.string(from: nextDate))
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if let notes = booking.notes, !notes.isEmpty {
                            Text(notes)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        Task {
                            let ok = await viewModel.repeatBooking(booking)
                            if ok { AppHaptics.success() } else { AppHaptics.error() }
                        }
                    } label: {
                        if viewModel.repeatingBookingId == booking.id || (viewModel.isCreating && viewModel.repeatingBookingId != nil) {
                            ProgressView().tint(AppTheme.Colors.accentPrimary)
                        } else {
                            Label("Повторить", systemImage: "arrow.clockwise")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.accentPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.accentPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isCreating || viewModel.repeatingBookingId != nil)
                }
            } else {
                Text("Пока нет прошлых броней для повтора")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .appCard()
    }

    // MARK: - Summary
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Мои бронирования", icon: "calendar.circle.fill", iconColor: AppTheme.Colors.accentPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ВСЕГО", value: "\(viewModel.bookings.count)",
                         color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ОЖИДАЮТ", value: "\(countByStatus(["pending", "new", "requested"]))",
                         color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "ПОДТВЕРЖД.", value: "\(countByStatus(["confirmed"]))",
                         color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "ОТМЕНЕНЫ", value: "\(countByStatus(["cancelled", "rejected"]))",
                         color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder)
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
                        .background(statusFilter == opt.key ? AnyShapeStyle(AppTheme.Colors.accentPrimary) : AnyShapeStyle(Color(hex: 0x1F2937)))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(statusFilter == opt.key ? AppTheme.Colors.accentPrimary.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1))
                        .shadow(color: statusFilter == opt.key ? AppTheme.Colors.accentPrimary.opacity(0.2) : .clear, radius: 6, y: 2)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }

            Toggle(isOn: $dayFilterEnabled) {
                Text("Фильтр по дате")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            .tint(AppTheme.Colors.accentPrimary)

            if dayFilterEnabled {
                DatePicker(
                    "Дата",
                    selection: $selectedDay,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: - List
    private var bookingsListCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Список броней", icon: "list.bullet.rectangle", iconColor: AppTheme.Colors.accentBlue)
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
    private func bookingRow(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accentBlue)
                    Text(AppDateFormatter.dayMonthTime.string(from: booking.startsAt))
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Spacer()
                StatusBadge(text: bookingStatusLabel(booking.status), style: bookingBadgeStyle(booking.status))
            }
            if let notes = booking.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            if let cid = booking.companyId, !cid.isEmpty {
                Text("Компания: \(cid.prefix(8))…")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            HStack {
                if viewModel.canCancelBooking(booking) {
                    Button {
                        bookingToCancel = booking
                    } label: {
                        if viewModel.cancellingBookingId == booking.id {
                            ProgressView().tint(AppTheme.Colors.error)
                        } else {
                            Label("Отменить бронь", systemImage: "xmark.circle")
                        }
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.error)
                    .disabled(viewModel.cancellingBookingId != nil)
                } else {
                    Text("Отмена доступна за 24ч до начала")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    private var filteredBookings: [Booking] {
        var rows = viewModel.bookings
        if statusFilter != "all" {
            rows = rows.filter {
                let s = $0.status.lowercased()
                switch statusFilter {
                case "pending": return ["pending", "new", "requested"].contains(s)
                case "confirmed": return s == "confirmed"
                case "cancelled": return ["cancelled", "rejected"].contains(s)
                default: return true
                }
            }
        }
        if dayFilterEnabled {
            let cal = Calendar.current
            rows = rows.filter { cal.isDate($0.startsAt, inSameDayAs: selectedDay) }
        }
        return rows
    }

    private func countByStatus(_ statuses: [String]) -> Int {
        viewModel.bookings.filter { statuses.contains($0.status.lowercased()) }.count
    }

    private func bookingStatusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "pending", "requested", "new": return "Ожидает"
        case "confirmed": return "Подтверждено"
        case "cancelled", "rejected": return "Отменено"
        case "completed", "done": return "Завершено"
        default: return status
        }
    }

    private func bookingBadgeStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "confirmed", "completed", "done": return .excellent
        case "cancelled", "rejected": return .critical
        case "pending", "requested", "new": return .warning
        default: return .info
        }
    }

    private var nearestUpcomingBooking: Booking? {
        viewModel.bookings
            .filter {
                $0.startsAt >= Date()
                    && !["cancelled", "rejected", "completed", "done"].contains($0.status.lowercased())
            }
            .sorted { $0.startsAt < $1.startsAt }
            .first
    }

    private func addBookingToCalendar(_ booking: Booking) async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { ok, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ok)
                        }
                    }
                }
            }
            guard granted else {
                calendarBannerStyle = .warning
                calendarBannerMessage = "Нет доступа к календарю. Разрешите доступ в настройках iOS."
                return
            }

            let event = EKEvent(eventStore: eventStore)
            event.calendar = eventStore.defaultCalendarForNewEvents
            event.title = "Бронь в Orda"
            event.startDate = booking.startsAt
            event.endDate = booking.endsAt > booking.startsAt ? booking.endsAt : booking.startsAt.addingTimeInterval(60 * 60)
            event.notes = booking.notes
            try eventStore.save(event, span: .thisEvent, commit: true)

            calendarBannerStyle = .excellent
            calendarBannerMessage = "Событие добавлено в календарь."
            AppHaptics.success()
        } catch {
            calendarBannerStyle = .critical
            calendarBannerMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }
}

private struct CreateBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @ObservedObject var viewModel: BookingsViewModel
    @State private var selectedDate = Date().addingTimeInterval(3600)
    @State private var notes = ""

    private var canSubmit: Bool {
        selectedDate >= Date() && !viewModel.isCreating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(title: "Новая бронь", icon: "calendar.badge.plus", iconColor: AppTheme.Colors.accentPrimary)

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
                        Text("ДАТА И ВРЕМЯ")
                            .font(AppTheme.Typography.micro)
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        DatePicker("", selection: $selectedDate)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .labelsHidden()
                            .colorScheme(.dark)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("КОММЕНТАРИЙ")
                            .font(AppTheme.Typography.micro)
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        TextField("Комментарий (необязательно)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .appInputStyle()
                    }

                    if let error = viewModel.creationErrorMessage {
                        AlertBanner(message: error, style: .critical)
                    }

                    Button("Создать бронь") {
                        Task {
                            let success = await viewModel.createBooking(startsAt: selectedDate, notes: notes)
                            if success { dismiss() }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit)

                    if viewModel.isCreating {
                        HStack {
                            ProgressView().tint(AppTheme.Colors.accentPrimary)
                            Text("Сохранение...").font(AppTheme.Typography.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                }
                .appCard()
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Новая бронь")
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
