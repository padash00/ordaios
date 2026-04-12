import SwiftUI
import PhotosUI
import UIKit

struct OperatorRootView: View {
    var body: some View {
        OperatorShellView()
    }
}

struct OperatorShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @State private var selectedTab: OperatorTab = .dashboard
    @State private var hasOperatorLeadAccess = false

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var service: OperatorServicing {
        OperatorService(apiClient: sessionStore.apiClient)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if capabilities.contains(.operatorDashboard) {
                NavigationStack {
                    OperatorDashboardView(service: service)
                }
                .tabItem { Label("Панель", systemImage: "rectangle.3.group") }
                .tag(OperatorTab.dashboard)
            }

            if capabilities.contains(.operatorTasks) {
                NavigationStack {
                    OperatorTasksView(service: service)
                }
                .tabItem { Label("Задачи", systemImage: "checklist") }
                .tag(OperatorTab.tasks)
            }

            if capabilities.contains(.operatorShifts) {
                NavigationStack {
                    OperatorShiftsView(service: service)
                }
                .tabItem { Label("Смены", systemImage: "clock.arrow.circlepath") }
                .tag(OperatorTab.shifts)
            }

            if hasOperatorLeadAccess {
                NavigationStack {
                    OperatorLeadView(service: service)
                }
                .tabItem { Label("Ведущий", systemImage: "person.badge.key") }
                .tag(OperatorTab.lead)
            }

            if capabilities.contains(.operatorSalaryRead) {
                NavigationStack {
                    OperatorSalaryView(service: service)
                }
                .tabItem { Label("Зарплата", systemImage: "banknote") }
                .tag(OperatorTab.salary)
            }

            if capabilities.contains(.operatorProfileRead) {
                NavigationStack {
                    OperatorCabinetProfileView(service: service)
                }
                .tabItem { Label("Профиль", systemImage: "person") }
                .tag(OperatorTab.profile)
            }
        }
        .task(id: sessionStore.session?.userEmail ?? "") {
            let ok = await service.hasOperatorLeadAccess()
            await MainActor.run {
                hasOperatorLeadAccess = ok
                quickHub.operatorLeadTabAvailable = ok
                let path = (sessionStore.roleContext?.defaultPath ?? "").lowercased()
                if ok, path.contains("lead") {
                    selectedTab = .lead
                }
            }
        }
        .onChange(of: hasOperatorLeadAccess) { _, ok in
            quickHub.operatorLeadTabAvailable = ok
        }
        .onAppear {
            selectedTab = OperatorTab.from(
                defaultPath: sessionStore.roleContext?.defaultPath,
                capabilities: capabilities,
                hasOperatorLeadAccess: hasOperatorLeadAccess
            )
        }
        .onChange(of: quickHub.navigationEvent) { _, new in
            guard let new else { return }
            if case .operatorRole(let tab) = new {
                if tab == .lead, !hasOperatorLeadAccess {
                    Task { @MainActor in quickHub.clearNavigation() }
                    return
                }
                selectedTab = tab
            }
            Task { @MainActor in quickHub.clearNavigation() }
        }
        .tint(AppTheme.Colors.accentPrimary)
    }
}

// MARK: - Operator Dashboard (rich)
private struct OperatorDashboardView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: OperatorOverviewViewModel
    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: OperatorOverviewViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Header
                HStack(spacing: AppTheme.Spacing.sm) {
                    // Avatar placeholder
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.Colors.accentPrimary, Color(hex: 0xF97316)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Text(initials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.bgPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.overview?.name ?? "Оператор")
                            .font(AppTheme.Typography.title)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        HStack(spacing: 6) {
                            StatusBadge(text: vm.overview?.role ?? "operator", style: .info)
                            if let short = vm.overview?.shortName {
                                Text(short)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
                .background(
                    ZStack {
                        AppTheme.Colors.headerGradient
                        Circle()
                            .fill(AppTheme.Colors.accentPrimary.opacity(0.08))
                            .frame(width: 180, height: 180)
                            .blur(radius: 50)
                            .offset(x: 120, y: -40)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.Colors.accentPrimary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(AppTheme.Spacing.xl)
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
                } else {
                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.xs) {
                        StatTile(title: "ОТКРЫТЫЕ ЗАДАЧИ", value: "\(vm.overview?.stats?.tasksOpen ?? 0)",
                                 color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                        StatTile(title: "СМЕН НА НЕДЕЛЕ", value: "\(vm.overview?.stats?.shiftsThisWeek ?? 0)",
                                 color: AppTheme.Colors.accentBlue, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                        StatTile(title: "ВЫПОЛНЕНО", value: "\(vm.overview?.stats?.tasksDone ?? 0)",
                                 color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                        StatTile(title: "РОЛЬ", value: vm.overview?.role ?? "—",
                                 color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder)
                    }

                    // Quick info
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Информация", icon: "info.circle", iconColor: AppTheme.Colors.accentBlue)
                        infoRow("Имя", vm.overview?.name ?? "—")
                        infoRow("Короткое имя", vm.overview?.shortName ?? "—")
                        infoRow("Маршрут", sessionStore.roleContext?.defaultPath ?? "—")
                    }
                    .appCard()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Панель")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Арена: `/api/point/arena` рассчитан на токен Point Terminal, не на сессию оператора.
                // Управление зонами/сессиями — с веб-панели или с привязанного терминала.
                NavigationLink(destination: OperatorMyAnalyticsView(service: service)) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    private var initials: String {
        let name = vm.overview?.shortName ?? vm.overview?.name ?? "O"
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Operator Tasks (rich)
private struct OperatorTasksView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: OperatorTasksViewModel
    @State private var commentByTaskId: [String: String] = [:]
    @State private var noteByTaskId: [String: String] = [:]
    @State private var photoPickerItemByTaskId: [String: PhotosPickerItem] = [:]
    @State private var photoDataByTaskId: [String: Data] = [:]
    @State private var photoLoadingByTaskId: [String: Bool] = [:]

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorTasksViewModel(service: service))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else if vm.items.isEmpty {
                EmptyStateView(message: "Нет задач")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(vm.items) { item in
                            taskCard(item)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        }
        .navigationTitle("Задачи")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task {
            await TaskSyncManager.shared.requestPermissions()
            await vm.load()
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func taskCard(_ item: OperatorTaskItem) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Заголовок + статус
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let num = item.taskNumber {
                        Text("№\(num)")
                            .font(AppTheme.Typography.micro)
                            .tracking(1)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Text(item.title)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Spacer(minLength: 8)
                StatusBadge(text: item.statusLabel, style: taskStatusStyle(item.status ?? ""))
            }

            // Описание
            if let desc = item.description, !desc.isEmpty {
                Text(ServerJSONPlaintext.normalize(desc))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
            }

            // Мета-информация
            HStack(spacing: 8) {
                if let p = item.priority {
                    SecondaryChip(
                        text: item.priorityLabel,
                        color: p.lowercased() == "high" || p.lowercased() == "urgent"
                            ? AppTheme.Colors.error
                            : p.lowercased() == "medium" ? AppTheme.Colors.warning : AppTheme.Colors.info
                    )
                }
                if let due = item.dueDate {
                    SecondaryChip(text: "До: \(due.prefix(10))", color: AppTheme.Colors.textMuted)
                }
                if let cnt = item.commentsCount, cnt > 0 {
                    SecondaryChip(text: "💬 \(cnt)", color: AppTheme.Colors.accentBlue)
                }
            }

            if let by = item.assignedByName {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text("Назначил: \(by)")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }

            Divider().background(AppTheme.Colors.borderSubtle)

            if canWrite {
                TextField("Комментарий к задаче", text: binding(for: item.id, storage: $commentByTaskId))
                    .appInputStyle()

                HStack(spacing: AppTheme.Spacing.sm) {
                    PhotosPicker(
                        selection: photoPickerBinding(for: item.id),
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Добавить фото", systemImage: "photo")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(AppTheme.Colors.accentBlue)
                    }
                    .buttonStyle(.plain)

                    if photoLoadingByTaskId[item.id] == true {
                        ProgressView()
                            .tint(AppTheme.Colors.accentPrimary)
                    }
                }
                .onChange(of: photoPickerItemByTaskId[item.id]) { _, newItem in
                    guard let newItem else { return }
                    Task { await loadPhoto(taskId: item.id, item: newItem) }
                }

                if let data = photoDataByTaskId[item.id], let uiImage = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        Button {
                            photoDataByTaskId[item.id] = nil
                            photoPickerItemByTaskId[item.id] = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, Color.black.opacity(0.6))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        taskActionBtn("Принять", response: "accept", item: item, color: AppTheme.Colors.success)
                        taskActionBtn("Уточнить", response: "need_info", item: item, color: AppTheme.Colors.warning)
                        taskActionBtn("Блокер", response: "blocked", item: item, color: AppTheme.Colors.error)
                        taskActionBtn("Готово", response: "complete", item: item, color: AppTheme.Colors.purple)
                    }
                }

                Button("Отправить комментарий") {
                    let text = commentByTaskId[item.id, default: ""]
                    let photoData = photoDataByTaskId[item.id]
                    let payload = composeCommentPayload(text: text, photoData: photoData)
                    guard !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    Task {
                        await vm.comment(taskId: item.id, content: payload)
                        commentByTaskId[item.id] = ""
                        photoDataByTaskId[item.id] = nil
                        photoPickerItemByTaskId[item.id] = nil
                    }
                }
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(AppTheme.Colors.accentBlue)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func taskActionBtn(_ title: String, response: String, item: OperatorTaskItem, color: Color) -> some View {
        Button {
            Task { await vm.respond(taskId: item.id, response: response, note: noteByTaskId[item.id]) }
        } label: {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.operatorTasksWrite)
    }

    private func binding(for taskId: String, storage: Binding<[String: String]>) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue[taskId, default: ""] },
            set: { storage.wrappedValue[taskId] = $0 }
        )
    }

    private func photoPickerBinding(for taskId: String) -> Binding<PhotosPickerItem?> {
        Binding(
            get: { photoPickerItemByTaskId[taskId] },
            set: { newValue in
                if let newValue {
                    photoPickerItemByTaskId[taskId] = newValue
                } else {
                    photoPickerItemByTaskId.removeValue(forKey: taskId)
                }
            }
        )
    }

    private func loadPhoto(taskId: String, item: PhotosPickerItem) async {
        photoLoadingByTaskId[taskId] = true
        defer { photoLoadingByTaskId[taskId] = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let compressed = compressImageData(data) else { return }
            photoDataByTaskId[taskId] = compressed
        } catch {
            photoDataByTaskId[taskId] = nil
        }
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.72) ?? data
    }

    private func composeCommentPayload(text: String, photoData: Data?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let photoData, !photoData.isEmpty else { return trimmed }
        let b64 = photoData.base64EncodedString()
        let imageBlock = "[photo:data:image/jpeg;base64,\(b64)]"
        if trimmed.isEmpty { return imageBlock }
        return "\(trimmed)\n\n\(imageBlock)"
    }

    private func taskStatusStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "done", "completed": return .excellent
        case "in_progress", "accepted": return .info
        case "blocked": return .critical
        case "review": return .good
        case "need_info": return .warning
        default: return .neutral
        }
    }
}

// MARK: - Operator Shifts (rich)
private struct OperatorShiftsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: OperatorShiftsViewModel
    @State private var issueReasonByShiftId: [String: String] = [:]
    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: OperatorShiftsViewModel(service: service))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await vm.load() } })
            } else if vm.items.isEmpty {
                EmptyStateView(message: "Нет смен")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(vm.items) { item in
                            shiftCard(item)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        }
        .navigationTitle("Смены")
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: OperatorShiftManagerView(service: service)) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 14))
                        Text("Смена")
                            .font(AppTheme.Typography.captionBold)
                    }
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private func shiftCard(_ item: OperatorShiftItem) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                        .fill(item.shiftType == "night" ? AppTheme.Colors.infoBg : AppTheme.Colors.warningBg.opacity(0.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.shiftType == "night" ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(item.shiftType == "night" ? AppTheme.Colors.accentBlue : AppTheme.Colors.cashColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.shiftDate?.prefix(10).description ?? "—")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(item.shiftTypeLabel)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                StatusBadge(text: item.statusLabel, style: shiftStatusStyle(item.status ?? ""))
            }

            // Доп. информация
            if let name = item.operatorName {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textMuted)
                    Text(name).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
            if let loc = item.location {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textMuted)
                    Text(loc).font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
            if let ws = item.weekStart {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10)).foregroundStyle(AppTheme.Colors.textMuted)
                    Text("Неделя с \(ws.prefix(10))").font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
            if let note = item.comment, !note.isEmpty {
                Text(note)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            if canWrite {
                Button {
                    Task { await vm.confirmWeek(responseId: item.id) }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Подтвердить")
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.success)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.successBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.small).stroke(AppTheme.Colors.successBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                TextField("Причина проблемы", text: issueBinding(for: item.id))
                    .appInputStyle()

                Button {
                    Task {
                        await vm.reportIssue(
                            responseId: item.id,
                            shiftDate: item.shiftDate ?? "",
                            shiftType: item.shiftType ?? "day",
                            reason: issueReasonByShiftId[item.id, default: ""]
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Сообщить о проблеме")
                    }
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .appCard()
    }

    private var canWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.operatorShiftsWrite)
    }

    private func issueBinding(for shiftId: String) -> Binding<String> {
        Binding(
            get: { issueReasonByShiftId[shiftId, default: ""] },
            set: { issueReasonByShiftId[shiftId] = $0 }
        )
    }

    private func shiftStatusStyle(_ status: String) -> StatusBadge.Style {
        switch status.lowercased() {
        case "confirmed": return .excellent
        case "published": return .info
        case "issue", "disputed": return .warning
        default: return .neutral
        }
    }
}
