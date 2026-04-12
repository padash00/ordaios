import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class AdminPointDevicesViewModel: ObservableObject {
    @Published var response: PointDevicesResponse?
    @Published var isLoading = false
    @Published var actionLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    var projects: [PointProject] { response?.projects ?? [] }
    var companies: [PointDeviceCompany] { response?.companies ?? [] }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            response = try await service.loadPointDevices()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func toggle(project: PointProject) async {
        actionLoading = true
        defer { actionLoading = false }
        do {
            try await service.togglePointProject(projectId: project.id, isActive: !project.isActive)
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func rotateToken(projectId: String) async {
        actionLoading = true
        defer { actionLoading = false }
        do {
            try await service.rotatePointToken(projectId: projectId)
            successMessage = "Токен обновлён."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func delete(projectId: String) async {
        actionLoading = true
        defer { actionLoading = false }
        do {
            try await service.deletePointProject(projectId: projectId)
            successMessage = "Устройство удалено."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func create(name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async {
        actionLoading = true
        defer { actionLoading = false }
        do {
            try await service.createPointProject(name: name, companyIds: companyIds, flags: flags)
            successMessage = "Устройство создано."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func update(projectId: String, name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async {
        actionLoading = true
        defer { actionLoading = false }
        do {
            try await service.updatePointProject(projectId: projectId, name: name, companyIds: companyIds, flags: flags)
            successMessage = "Устройство обновлено."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }
}

// MARK: - Main View

struct AdminPointDevicesView: View {
    @StateObject private var vm: AdminPointDevicesViewModel
    @State private var showCreateSheet = false
    @State private var editTarget: PointProject?
    @State private var deleteTarget: PointProject?

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminPointDevicesViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка устройств...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else if vm.projects.isEmpty {
                    EmptyStateView(message: "Нет подключённых устройств", icon: "desktopcomputer.and.arrow.down")
                } else {
                    summaryCard
                    ForEach(vm.projects) { project in
                        PointProjectCard(
                            project: project,
                            companies: vm.companies,
                            onToggle: { Task { await vm.toggle(project: project) } },
                            onRotateToken: { Task { await vm.rotateToken(projectId: project.id) } },
                            onEdit: { editTarget = project },
                            onDelete: { deleteTarget = project }
                        )
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Устройства точек")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showCreateSheet) {
            PointProjectFormSheet(
                companies: vm.companies,
                existing: nil
            ) { name, companyIds, flags in
                Task { await vm.create(name: name, companyIds: companyIds, flags: flags) }
            }
        }
        .sheet(item: $editTarget) { project in
            PointProjectFormSheet(
                companies: vm.companies,
                existing: project
            ) { name, companyIds, flags in
                Task { await vm.update(projectId: project.id, name: name, companyIds: companyIds, flags: flags) }
            }
        }
        .alert("Удалить устройство?", isPresented: .constant(deleteTarget != nil)) {
            Button("Удалить", role: .destructive) {
                if let t = deleteTarget {
                    Task { await vm.delete(projectId: t.id) }
                }
                deleteTarget = nil
            }
            Button("Отмена", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("Устройство «\(deleteTarget?.name ?? "")» будет удалено без возможности восстановления.")
        }
        .alert("Готово", isPresented: .constant(vm.successMessage != nil)) {
            Button("OK") { vm.successMessage = nil }
        } message: { Text(ServerJSONPlaintext.normalize(vm.successMessage ?? "")) }
    }

    private var summaryCard: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            summaryTile(
                title: "ВСЕГО",
                value: "\(vm.projects.count)",
                color: AppTheme.Colors.accentPrimary
            )
            summaryTile(
                title: "АКТИВНЫХ",
                value: "\(vm.projects.filter { $0.isActive }.count)",
                color: AppTheme.Colors.success
            )
            summaryTile(
                title: "ОТКЛЮЧЕНО",
                value: "\(vm.projects.filter { !$0.isActive }.count)",
                color: AppTheme.Colors.error
            )
        }
        .appCard()
    }

    @ViewBuilder
    private func summaryTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.micro)
                .tracking(1)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Project Card

private struct PointProjectCard: View {
    let project: PointProject
    let companies: [PointDeviceCompany]
    let onToggle: () -> Void
    let onRotateToken: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var tokenVisible = false
    @State private var tokenCopied = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(project.isActive ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
                        Text(project.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    if let mode = project.mode, !mode.isEmpty, mode != "default" {
                        Text(mode.uppercased())
                            .font(AppTheme.Typography.micro)
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.accentBlue)
                    }
                }
                Spacer()
                StatusBadge(
                    text: project.isActive ? "Активно" : "Отключено",
                    style: project.isActive ? .excellent : .neutral
                )
            }

            // Assigned companies
            let assigned = assignedCompanies()
            if !assigned.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(assigned, id: \.id) { company in
                            Text(company.code?.uppercased() ?? company.name)
                                .font(AppTheme.Typography.micro)
                                .tracking(1)
                                .foregroundStyle(AppTheme.Colors.accentPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(AppTheme.Colors.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            Divider().background(AppTheme.Colors.borderSubtle)

            // Feature flags
            if let flags = project.featureFlags {
                featureFlagsRow(flags)
            }

            // Token section
            tokenSection

            // Last seen
            if let seen = project.lastSeenAt {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text("Последнее подключение: \(formatDate(seen))")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }

            Divider().background(AppTheme.Colors.borderSubtle)

            // Actions
            HStack(spacing: AppTheme.Spacing.sm) {
                actionButton("toggle", label: project.isActive ? "Откл." : "Вкл.",
                             icon: project.isActive ? "pause.circle" : "play.circle",
                             color: project.isActive ? AppTheme.Colors.warning : AppTheme.Colors.success,
                             action: onToggle)
                actionButton("edit", label: "Изменить",
                             icon: "pencil",
                             color: AppTheme.Colors.accentBlue,
                             action: onEdit)
                actionButton("delete", label: "Удалить",
                             icon: "trash",
                             color: AppTheme.Colors.error,
                             action: onDelete)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func featureFlagsRow(_ flags: PointFeatureFlags) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ФУНКЦИИ").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                flagChip("Сменный отчёт", enabled: flags.shiftReport)
                flagChip("Отчёт дохода", enabled: flags.incomeReport)
                flagChip("Долги", enabled: flags.debtReport)
                flagChip("Kaspi-сплит", enabled: flags.kaspiDailySplit)
                flagChip("Стартовая касса", enabled: flags.startCashPrompt)
                flagChip("Арена", enabled: flags.arenaEnabled)
            }
        }
    }

    @ViewBuilder
    private func flagChip(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(enabled ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
            Text(label)
                .font(AppTheme.Typography.micro)
                .foregroundStyle(enabled ? AppTheme.Colors.textSecondary : AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ТОКЕН").font(AppTheme.Typography.micro).tracking(1.2).foregroundStyle(AppTheme.Colors.textMuted)
            HStack(spacing: 8) {
                if let token = project.token {
                    Text(tokenVisible ? token : String(repeating: "•", count: 16))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        tokenVisible.toggle()
                    } label: {
                        Image(systemName: tokenVisible ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }

                    Button {
                        UIPasteboard.general.string = token
                        tokenCopied = true
                        AppHaptics.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { tokenCopied = false }
                    } label: {
                        Image(systemName: tokenCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(tokenCopied ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
                    }

                    Button {
                        onRotateToken()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                } else {
                    Text("Нет токена")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
            .padding(10)
            .background(AppTheme.Colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
    }

    @ViewBuilder
    private func actionButton(_ id: String, label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(AppTheme.Typography.captionBold)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
    }

    private func assignedCompanies() -> [PointDeviceCompany] {
        let ids = Set(project.companyAssignments.map { $0.companyId })
        return companies.filter { ids.contains($0.id) }
    }

    private func formatDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let d = f.date(from: String(iso.prefix(19))) else { return String(iso.prefix(10)) }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "d MMM, HH:mm"
        return out.string(from: d)
    }
}

// MARK: - Create / Edit Sheet

struct PointProjectFormSheet: View {
    let companies: [PointDeviceCompany]
    let existing: PointProject?
    let onSave: (String, [String], PointFeatureFlagsPayload) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedCompanyIds: Set<String>
    @State private var flags: PointFeatureFlagsPayload

    init(companies: [PointDeviceCompany], existing: PointProject?, onSave: @escaping (String, [String], PointFeatureFlagsPayload) -> Void) {
        self.companies = companies
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _selectedCompanyIds = State(initialValue: Set(existing?.companyAssignments.map { $0.companyId } ?? []))
        if let f = existing?.featureFlags {
            _flags = State(initialValue: PointFeatureFlagsPayload(
                shiftReport: f.shiftReport,
                incomeReport: f.incomeReport,
                debtReport: f.debtReport,
                kaspiDailySplit: f.kaspiDailySplit,
                startCashPrompt: f.startCashPrompt,
                arenaEnabled: f.arenaEnabled
            ))
        } else {
            _flags = State(initialValue: PointFeatureFlagsPayload())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {

                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("НАЗВАНИЕ УСТРОЙСТВА")
                            .font(AppTheme.Typography.micro).tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        TextField("Например: Касса 1, Бар, Арена", text: $name)
                            .appInputStyle()
                    }
                    .appCard()

                    // Companies
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Компании", icon: "building.2.fill", iconColor: AppTheme.Colors.accentBlue)
                        if companies.isEmpty {
                            Text("Нет доступных компаний")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        } else {
                            ForEach(companies) { company in
                                let isSelected = selectedCompanyIds.contains(company.id)
                                Button {
                                    if isSelected {
                                        selectedCompanyIds.remove(company.id)
                                    } else {
                                        selectedCompanyIds.insert(company.id)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(isSelected ? AppTheme.Colors.accentPrimary : AppTheme.Colors.textMuted)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(company.name)
                                                .font(AppTheme.Typography.body)
                                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                            if let code = company.code {
                                                Text(code.uppercased())
                                                    .font(AppTheme.Typography.micro)
                                                    .foregroundStyle(AppTheme.Colors.textMuted)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .appCard()

                    // Feature flags
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Функции", icon: "switch.2", iconColor: AppTheme.Colors.purple)
                        flagToggle("Сменный отчёт", value: $flags.shiftReport)
                        flagToggle("Отчёт по доходам", value: $flags.incomeReport)
                        flagToggle("Долги клиентов", value: $flags.debtReport)
                        flagToggle("Kaspi дневной сплит", value: $flags.kaspiDailySplit)
                        flagToggle("Стартовая касса", value: $flags.startCashPrompt)
                        flagToggle("Режим Арена", value: $flags.arenaEnabled)
                    }
                    .appCard()

                    Button(existing == nil ? "Создать устройство" : "Сохранить изменения") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(name, Array(selectedCompanyIds), flags)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Новое устройство" : "Изменить устройство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func flagToggle(_ label: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .tint(AppTheme.Colors.accentPrimary)
    }
}
