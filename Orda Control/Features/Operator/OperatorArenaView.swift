import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class OperatorArenaViewModel: ObservableObject {
    @Published var stations: [ArenaStation] = []
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedStation: ArenaStation?
    @Published var clientName = ""
    @Published var durationMinutes = 60
    @Published var showStartSheet = false

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    var freeCount: Int { stations.filter(\.isFree).count }
    var busyCount: Int { stations.filter { !$0.isFree }.count }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            stations = try await service.fetchArenaStations(pointId: nil)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func startSession() async {
        guard let station = selectedStation else { return }
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            try await service.startArenaSession(
                stationId: station.id,
                clientName: clientName.trimmingCharacters(in: .whitespacesAndNewlines),
                minutes: durationMinutes
            )
            successMessage = "Сессия запущена на \(station.displayName)"
            clientName = ""
            durationMinutes = 60
            showStartSheet = false
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось запустить сессию"
            AppHaptics.error()
        }
    }

    func stopSession(stationId: String) async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            try await service.stopArenaSession(stationId: stationId)
            successMessage = "Сессия остановлена"
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось остановить сессию"
            AppHaptics.error()
        }
    }
}

// MARK: - View

struct OperatorArenaView: View {
    @StateObject private var vm: OperatorArenaViewModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorArenaViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка арены…")
                } else if let err = vm.errorMessage {
                    ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
                } else if vm.stations.isEmpty {
                    EmptyStateView(message: "Нет станций в этой точке")
                } else {
                    summaryBar
                    stationGrid
                }

                if let msg = vm.successMessage {
                    resultBanner(msg, isSuccess: true)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Арена")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $vm.showStartSheet) {
            startSessionSheet
        }
    }

    // MARK: Summary Bar

    private var summaryBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            summaryPill(count: vm.stations.count, label: "ВСЕГО", color: AppTheme.Colors.accentBlue, bg: AppTheme.Colors.infoBg, border: AppTheme.Colors.infoBorder)
            summaryPill(count: vm.freeCount, label: "СВОБОДНО", color: AppTheme.Colors.success, bg: AppTheme.Colors.successBg, border: AppTheme.Colors.successBorder)
            summaryPill(count: vm.busyCount, label: "ЗАНЯТО", color: AppTheme.Colors.error, bg: AppTheme.Colors.errorBg, border: AppTheme.Colors.errorBorder)
        }
    }

    @ViewBuilder
    private func summaryPill(count: Int, label: String, color: Color, bg: Color, border: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(AppTheme.Typography.micro)
                .tracking(0.8)
                .foregroundStyle(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: Station Grid

    private var stationGrid: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
            ForEach(vm.stations) { station in
                stationCard(station)
            }
        }
    }

    @ViewBuilder
    private func stationCard(_ station: ArenaStation) -> some View {
        let isFree = station.isFree
        let color: Color = isFree ? AppTheme.Colors.success : AppTheme.Colors.error
        let bg: Color = isFree ? AppTheme.Colors.successBg : AppTheme.Colors.errorBg
        let border: Color = isFree ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder

        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text(station.displayName)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Circle().fill(color).frame(width: 9, height: 9)
            }

            Text(isFree ? "Свободно" : "Занято")
                .font(AppTheme.Typography.micro)
                .tracking(0.8)
                .foregroundStyle(color)

            if !isFree {
                if let client = station.clientName {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill").font(.system(size: 9)).foregroundStyle(AppTheme.Colors.textMuted)
                        Text(client).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted).lineLimit(1)
                    }
                }
                if let elapsed = station.elapsedMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "timer").font(.system(size: 9)).foregroundStyle(AppTheme.Colors.textMuted)
                        Text("\(elapsed) мин").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            }

            Spacer()

            if isFree {
                Button {
                    vm.selectedStation = station
                    vm.showStartSheet = true
                } label: {
                    Text("Запустить")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.successBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.small).stroke(AppTheme.Colors.successBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await vm.stopSession(stationId: station.id) }
                } label: {
                    Text("Стоп")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.errorBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.small).stroke(AppTheme.Colors.errorBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(vm.isActing)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .frame(minHeight: 130, alignment: .topLeading)
        .background(bg.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: Start Session Sheet

    private var startSessionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    if let station = vm.selectedStation {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.Colors.accentPrimary)
                            Text(station.displayName)
                                .font(AppTheme.Typography.title)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                        .appCard()
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Данные клиента", icon: "person.fill", iconColor: AppTheme.Colors.accentBlue)
                        TextField("Имя клиента (опционально)", text: $vm.clientName)
                            .appInputStyle()
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Длительность: \(vm.durationMinutes) мин", icon: "timer", iconColor: AppTheme.Colors.warning)
                        Slider(value: Binding(
                            get: { Double(vm.durationMinutes) },
                            set: { vm.durationMinutes = Int($0) }
                        ), in: 30...480, step: 30)
                        .tint(AppTheme.Colors.accentPrimary)

                        HStack {
                            Text("30 мин").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                            Spacer()
                            Text("8 ч").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    Button {
                        Task { await vm.startSession() }
                    } label: {
                        HStack {
                            if vm.isActing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Запустить сессию")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.isActing)

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Новая сессия")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { vm.showStartSheet = false }
                }
            }
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
