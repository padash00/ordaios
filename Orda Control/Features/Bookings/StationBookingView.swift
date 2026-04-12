import SwiftUI
import Combine

/// Онлайн-запись на игровые станции (клиентский API `api/client/stations`).
/// Подключайте только в шелле **клиента** (например с «Главной»), когда продуктово нужно;
/// в потоке **оператора** не используйте — у оператора арена/станции идут через Point Terminal и `/api/point/arena`.
// MARK: - ViewModel

@MainActor
final class StationBookingViewModel: ObservableObject {
    @Published var stations: [ClientStation] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var notFound = false
    @Published var isBooking = false
    @Published var bookingError: String? = nil
    @Published var bookingSuccess = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var freeCount: Int { stations.filter { $0.status == "free" }.count }
    var busyCount: Int { stations.filter { $0.status == "busy" || $0.status == "reserved" }.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        notFound = false
        do {
            let endpoint = ContractEndpoint.api_client_stations.get
            let response: StationListEnvelope = try await apiClient.request(endpoint)
            stations = response.stations ?? response.items ?? []
        } catch let error as APIError {
            switch error {
            case .validation:
                notFound = true
                stations = []
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func bookStation(stationId: String, durationMinutes: Int, startTime: Date, companyId: String?) async {
        isBooking = true
        bookingError = nil
        bookingSuccess = false
        do {
            let formatter = ISO8601DateFormatter()
            let timeString = formatter.string(from: startTime)
            let trimmed = companyId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cid = trimmed.isEmpty ? nil : trimmed
            let payload = StationBookingPayload(
                stationId: stationId,
                durationMinutes: durationMinutes,
                startTime: timeString,
                companyId: cid
            )
            let endpoint = ContractEndpoint.api_client_station_booking.post
            let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
            bookingSuccess = true
            await load()
        } catch let error as APIError {
            bookingError = error.localizedDescription
        } catch {
            bookingError = error.localizedDescription
        }
        isBooking = false
    }
}

private struct StationListEnvelope: Decodable {
    let stations: [ClientStation]?
    let items: [ClientStation]?
}

// MARK: - View

struct StationBookingView: View {
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @StateObject private var vm: StationBookingViewModel
    @State private var selectedStation: ClientStation? = nil
    @State private var showBookingSheet = false

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: StationBookingViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingStateView(message: "Загрузка станций...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else if vm.notFound {
                EmptyStateView(message: "Онлайн-запись недоступна", icon: "desktopcomputer")
            } else {
                mainContent
            }
        }
        .navigationTitle("Запись на станцию")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $selectedStation) { station in
            BookingSheet(station: station, vm: vm, isPresented: Binding(
                get: { selectedStation != nil },
                set: { if !$0 { selectedStation = nil } }
            ))
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Header stats
                statsHeader

                // Grid of stations
                if vm.stations.isEmpty {
                    EmptyStateView(message: "Онлайн-запись недоступна", icon: "desktopcomputer")
                        .frame(height: 200)
                } else {
                    stationsGrid
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var statsHeader: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            statPill(label: "Свободно", count: vm.freeCount, color: AppTheme.Colors.success)
            statPill(label: "Занято", count: vm.busyCount, color: AppTheme.Colors.error)
        }
        .appCard()
    }

    private func statPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var stationsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.xs), count: 4),
            spacing: AppTheme.Spacing.xs
        ) {
            ForEach(vm.stations.sorted { $0.number < $1.number }) { station in
                StationTile(station: station)
                    .onTapGesture {
                        if station.status == "free" {
                            selectedStation = station
                        }
                    }
            }
        }
    }
}

// MARK: - StationTile

private struct StationTile: View {
    let station: ClientStation

    var body: some View {
        VStack(spacing: 4) {
            Text("\(station.number)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(station.status == "free" ? .white : AppTheme.Colors.textSecondary)

            Text(statusLabel)
                .font(AppTheme.Typography.micro)
                .foregroundStyle(station.status == "free" ? .white.opacity(0.85) : AppTheme.Colors.textMuted)
                .lineLimit(1)

            if let mins = station.sessionMinutesLeft, station.status == "busy" {
                Text("\(mins)м")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.error.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var statusLabel: String {
        switch station.status {
        case "free": return "Свободна"
        case "busy": return "Занята"
        case "reserved": return "Заброн."
        default: return station.status
        }
    }

    private var backgroundColor: Color {
        switch station.status {
        case "free": return AppTheme.Colors.success.opacity(0.75)
        case "busy": return AppTheme.Colors.error.opacity(0.20)
        case "reserved": return AppTheme.Colors.warning.opacity(0.20)
        default: return AppTheme.Colors.surfaceSecondary
        }
    }

    private var borderColor: Color {
        switch station.status {
        case "free": return AppTheme.Colors.success.opacity(0.5)
        case "busy": return AppTheme.Colors.error.opacity(0.35)
        case "reserved": return AppTheme.Colors.warning.opacity(0.35)
        default: return AppTheme.Colors.borderSubtle
        }
    }
}

// MARK: - BookingSheet

private struct BookingSheet: View {
    @EnvironmentObject private var clientProfile: ClientProfileStore
    let station: ClientStation
    @ObservedObject var vm: StationBookingViewModel
    @Binding var isPresented: Bool

    @State private var durationHours = 1
    @State private var startTime = Date()

    private let durationOptions = [(1, "1 час"), (2, "2 часа"), (3, "3 часа")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(
                        title: "Станция №\(station.number)",
                        icon: "desktopcomputer",
                        iconColor: AppTheme.Colors.success
                    )

                    // Duration picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ПРОДОЛЖИТЕЛЬНОСТЬ")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Picker("Продолжительность", selection: $durationHours) {
                            ForEach(durationOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .appInputStyle()
                    }

                    // Start time
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ВРЕМЯ НАЧАЛА")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .appInputStyle()
                    }

                    if let err = vm.bookingError {
                        Text(err)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    }

                    Button {
                        Task {
                            let stationCompany = station.companyId?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let fallback = clientProfile.selectedCompanyId
                            let merged: String? = {
                                if let s = stationCompany, !s.isEmpty { return s }
                                return fallback
                            }()
                            await vm.bookStation(
                                stationId: station.id,
                                durationMinutes: durationHours * 60,
                                startTime: startTime,
                                companyId: merged
                            )
                            if vm.bookingSuccess {
                                isPresented = false
                            }
                        }
                    } label: {
                        Group {
                            if vm.isBooking {
                                ProgressView().tint(.white)
                            } else {
                                Text("Забронировать")
                                    .font(AppTheme.Typography.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .disabled(vm.isBooking)
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Бронирование")
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
