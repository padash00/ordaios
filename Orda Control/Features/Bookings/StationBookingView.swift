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

    func load(companyId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        notFound = false
        do {
            var path = "/api/client/stations"
            let trimmed = companyId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty, let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                path += "?company_id=\(enc)"
            }
            let endpoint = APIEndpoint(path: path, method: .GET)
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

private enum StationBoardLayout: String, CaseIterable, Identifiable {
    case list = "Список"
    case grid = "Сетка"
    case map = "Схема"

    var id: String { rawValue }
}

struct StationBookingView: View {
    @EnvironmentObject private var clientProfile: ClientProfileStore
    @StateObject private var vm: StationBookingViewModel
    @State private var selectedStation: ClientStation? = nil
    @State private var showBookingSheet = false
    @State private var layout: StationBoardLayout = .list

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: StationBookingViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingStateView(message: "Загрузка станций...")
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await reloadStations() } })
            } else if vm.notFound {
                EmptyStateView(message: "Онлайн-запись недоступна", icon: "desktopcomputer")
            } else {
                mainContent
            }
        }
        .navigationTitle("Запись на станцию")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await reloadStations() }
        .refreshable { await reloadStations() }
        .onChange(of: clientProfile.selectedCustomerId) { _, _ in
            Task { await reloadStations() }
        }
        .sheet(item: $selectedStation) { station in
            BookingSheet(station: station, vm: vm, isPresented: Binding(
                get: { selectedStation != nil },
                set: { if !$0 { selectedStation = nil } }
            ))
        }
    }

    private func reloadStations() async {
        await vm.load(companyId: clientProfile.selectedCompanyId)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                introCard

                Link(destination: AppConfig.current.apiBaseURL) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Открыть сайт клуба (полная карта, если доступна)")
                            .font(AppTheme.Typography.caption)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                    .padding(AppTheme.Spacing.md)
                    .appCard()
                }

                statsHeader

                Picker("Вид", selection: $layout) {
                    ForEach(StationBoardLayout.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.xs)

                if vm.stations.isEmpty {
                    EmptyStateView(message: "Станции не настроены для вашего клуба", icon: "desktopcomputer")
                        .frame(height: 200)
                } else {
                    switch layout {
                    case .grid:
                        stationsGrid
                    case .list:
                        stationsList
                    case .map:
                        StationHallMiniMapView(stations: vm.stations.sorted { $0.number < $1.number }) { st in
                            if st.status == "free" {
                                selectedStation = st
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Что вы бронируете")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Слот на игровой станции (ПК в зале). Выберите свободную станцию, затем укажите дату и длительность сессии. Заявка уходит в клуб на подтверждение.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var stationsList: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ForEach(vm.stations.sorted { $0.number < $1.number }) { station in
                Button {
                    if station.status == "free" {
                        selectedStation = station
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stationTitle(station))
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(statusLabel(station.status))
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Spacer()
                        if station.status == "free" {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(station.status != "free")
            }
        }
    }

    private func stationTitle(_ station: ClientStation) -> String {
        if let n = station.name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(n) · №\(station.number)"
        }
        return "Станция №\(station.number)"
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "free": return "Свободна — нажмите, чтобы забронировать"
        case "busy": return "Занята"
        case "reserved": return "Забронирована"
        default: return status
        }
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

// MARK: - Mini map (grid_x / grid_y from backend)

private struct StationHallMiniMapView: View {
    let stations: [ClientStation]
    var onSelect: (ClientStation) -> Void

    private var mappable: [ClientStation] {
        stations.filter { $0.gridX != nil && $0.gridY != nil }
    }

    var body: some View {
        Group {
            if mappable.isEmpty {
                EmptyStateView(
                    message: "Координаты схемы зала ещё не заданы. Используйте список или сетку.",
                    icon: "map"
                )
                .frame(height: 160)
            } else {
                GeometryReader { geo in
                    let xs = mappable.compactMap(\.gridX)
                    let ys = mappable.compactMap(\.gridY)
                    let minX = xs.min() ?? 0
                    let maxX = xs.max() ?? 0
                    let minY = ys.min() ?? 0
                    let maxY = ys.max() ?? 0
                    let cols = max(maxX - minX + 1, 1)
                    let rows = max(maxY - minY + 1, 1)
                    let cell = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))

                    ZStack(alignment: .topLeading) {
                        ForEach(mappable) { st in
                            let gx = (st.gridX ?? 0) - minX
                            let gy = (st.gridY ?? 0) - minY
                            let free = st.status == "free"
                            Text("\(st.number)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(free ? .white : AppTheme.Colors.textSecondary)
                                .frame(width: cell * 0.92, height: cell * 0.92)
                                .background(free ? AppTheme.Colors.success.opacity(0.85) : AppTheme.Colors.error.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
                                )
                                .position(
                                    x: CGFloat(gx) * cell + cell / 2,
                                    y: CGFloat(gy) * cell + cell / 2
                                )
                                .onTapGesture {
                                    if free {
                                        onSelect(st)
                                    }
                                }
                        }
                    }
                    .frame(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell, alignment: .topLeading)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 240)
                .padding(AppTheme.Spacing.md)
                .appCard()
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

            if let n = station.name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(n)
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(station.status == "free" ? .white.opacity(0.9) : AppTheme.Colors.textMuted)
                    .lineLimit(1)
            }

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
        .frame(minHeight: 72)
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

    private var stationDisplayTitle: String {
        if let n = station.name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(n) · №\(station.number)"
        }
        return "Станция №\(station.number)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(
                        title: stationDisplayTitle,
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
