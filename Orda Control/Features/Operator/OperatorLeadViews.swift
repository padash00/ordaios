import SwiftUI

private struct OperatorLeadReplaceSheetItem: Identifiable {
    let id: String
}

struct OperatorLeadView: View {
    @StateObject private var vm: OperatorLeadViewModel
    @State private var replaceSheetItem: OperatorLeadReplaceSheetItem?

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorLeadViewModel(service: service))
    }

    var body: some View {
        Group {
            if vm.isLoading, vm.payload == nil {
                LoadingStateView(message: "Загрузка…")
            } else if let err = vm.errorMessage, vm.payload == nil {
                ErrorStateView(message: err) {
                    Task { await vm.load() }
                }
            } else {
                leadScroll
            }
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Ведущий")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task { await vm.load() }
        .sheet(item: $replaceSheetItem) { item in
            if let req = vm.payload?.requests?.first(where: { $0.id == item.id }) {
                OperatorLeadReplacementSheet(
                    candidates: vm.replacementCandidates(for: req),
                    onPick: { opId in
                        Task {
                            await vm.submitProposal(requestId: item.id, action: "replace", note: nil, replacementOperatorId: opId)
                            replaceSheetItem = nil
                        }
                    },
                    onCancel: { replaceSheetItem = nil }
                )
            } else {
                Text("Заявка не найдена")
                    .padding()
            }
        }
    }

    private var leadScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                if let msg = vm.infoMessage {
                    Text(msg)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let err = vm.errorMessage, vm.payload != nil {
                    Text(err)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                }

                companiesSection
                requestsSection
                tasksSection
            }
            .padding(AppTheme.Spacing.md)
        }
        .overlay {
            if vm.isLoading, vm.payload != nil {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
        }
    }

    private var companiesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Точки", icon: "mappin.and.ellipse", iconColor: AppTheme.Colors.accentPrimary)
            let list = vm.payload?.companies ?? []
            if list.isEmpty {
                Text("Нет компаний в зоне ответственности")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(list) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(c.name ?? c.code ?? "Компания")
                                .font(AppTheme.Typography.callout)
                            Spacer()
                            if let code = c.code, !code.isEmpty {
                                Text(code)
                                    .font(AppTheme.Typography.monoCaption)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                        if let pub = c.publication {
                            Text("Неделя \(pub.weekStart ?? "—") — \(pub.weekEnd ?? "—")")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        if let ws = c.weeklyStatus {
                            Text(operatorLeadWeeklyLine(ws))
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().opacity(0.15)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Заявки по сменам", icon: "exclamationmark.bubble", iconColor: AppTheme.Colors.warning)
            let list = vm.payload?.requests ?? []
            if list.isEmpty {
                Text("Нет заявок")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(list) { r in
                    OperatorLeadRequestRow(
                        request: r,
                        onKeep: {
                            Task { await vm.submitProposal(requestId: r.id, action: "keep", note: nil, replacementOperatorId: nil) }
                        },
                        onRemove: {
                            Task { await vm.submitProposal(requestId: r.id, action: "remove", note: nil, replacementOperatorId: nil) }
                        },
                        onReplace: {
                            replaceSheetItem = OperatorLeadReplaceSheetItem(id: r.id)
                        }
                    )
                    Divider().opacity(0.15)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Задачи на точках", icon: "checklist", iconColor: AppTheme.Colors.accentBlue)
            let list = vm.payload?.tasks ?? []
            if list.isEmpty {
                Text("Нет задач")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(list) { t in
                    OperatorLeadTaskRow(task: t) { status in
                        Task { await vm.updateTaskStatus(taskId: t.id, status: status, note: nil) }
                    }
                    Divider().opacity(0.15)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }
}

// MARK: - Rows

private struct OperatorLeadRequestRow: View {
    let request: OperatorLeadShiftRequest
    let onKeep: () -> Void
    let onRemove: () -> Void
    let onReplace: () -> Void

    private var canPropose: Bool {
        let st = (request.status ?? "").lowercased()
        return st == "open" || st == "awaiting_reason"
    }

    private var isProposed: Bool {
        (request.leadStatus ?? "").lowercased() == "proposed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.operatorName ?? "Оператор")
                        .font(AppTheme.Typography.callout)
                    Text("\(request.shiftDate ?? "—") · \(shiftTypeRU(request.shiftType))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                StatusBadge(text: request.status ?? "—", style: .warning)
            }
            if let co = request.companyName ?? request.companyCode {
                Text(co)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            if let reason = request.reason, !reason.isEmpty {
                Text(reason)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if canPropose, isProposed {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Оставить") { onKeep() }
                        .buttonStyle(.bordered)
                    Button("Снять") { onRemove() }
                        .buttonStyle(.bordered)
                    Button("Заменить") { onReplace() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accentPrimary)
                }
                .font(AppTheme.Typography.captionBold)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct OperatorLeadTaskRow: View {
    let task: OperatorLeadPointTask
    let onStatus: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let n = task.taskNumber {
                    Text("#\(n)")
                        .font(AppTheme.Typography.monoCaption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Text(task.title ?? "Задача")
                    .font(AppTheme.Typography.callout)
                Spacer()
                Menu {
                    Button("К выполнению") { onStatus("todo") }
                    Button("В работе") { onStatus("in_progress") }
                    Button("На проверке") { onStatus("review") }
                    Button("Готово") { onStatus("done") }
                } label: {
                    HStack(spacing: 4) {
                        Text(task.status ?? "—")
                            .font(AppTheme.Typography.caption)
                        Image(systemName: "chevron.down.circle")
                    }
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                }
            }
            if let co = task.companyName {
                Text(co)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            if let op = task.operatorName {
                Text(op)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Replacement sheet

private struct OperatorLeadReplacementSheet: View {
    let candidates: [OperatorLeadTeamAssignment]
    let onPick: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if candidates.isEmpty {
                    Text("Нет других операторов на этой точке")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    ForEach(candidates) { row in
                        Button {
                            if let oid = row.operatorId {
                                onPick(oid)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.operatorName ?? row.operatorId ?? "—")
                                    .font(AppTheme.Typography.callout)
                                if let role = row.roleInCompany, !role.isEmpty {
                                    Text(role)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.textMuted)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Замена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Formatting

private func operatorLeadWeeklyLine(_ ws: OperatorLeadWeeklyStatus) -> String {
    let state = operatorLeadWeeklyStateRU(ws.state)
    let c = ws.confirmed ?? 0
    let t = ws.total ?? 0
    let p = ws.pending ?? 0
    let i = ws.issues ?? 0
    return "\(state): подтвердили \(c) из \(t), в ожидании \(p), вопросов \(i)"
}

private func operatorLeadWeeklyStateRU(_ state: String?) -> String {
    switch state?.lowercased() {
    case "draft": return "Черновик"
    case "published": return "Опубликовано"
    case "partial": return "Частично подтверждено"
    case "confirmed": return "Все подтвердили"
    case "issues": return "Есть обращения"
    default: return state ?? "—"
    }
}

private func shiftTypeRU(_ raw: String?) -> String {
    switch raw?.lowercased() {
    case "night": return "ночная"
    case "day": return "дневная"
    default: return raw ?? "—"
    }
}
