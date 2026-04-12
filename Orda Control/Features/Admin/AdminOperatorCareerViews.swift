import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class AdminOperatorCareerViewModel: ObservableObject {
    @Published var operators: [AdminOperator] = []
    @Published var selectedOperator: AdminOperator?
    @Published var careerLink: OperatorCareerLink?
    @Published var isLoading = false
    @Published var isPromoting = false
    @Published var error: String?
    @Published var showPromoteSheet = false

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func loadOperators() async {
        isLoading = true
        do {
            operators = try await service.loadOperators()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectOperator(_ op: AdminOperator) async {
        selectedOperator = op
        careerLink = nil
        isLoading = true
        do {
            careerLink = try await service.loadOperatorCareer(operatorId: op.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func promote(role: String, monthlySalary: Double?) async {
        guard let op = selectedOperator else { return }
        isPromoting = true
        error = nil
        do {
            try await service.promoteOperator(operatorId: op.id, role: role, monthlySalary: monthlySalary)
            careerLink = try await service.loadOperatorCareer(operatorId: op.id)
            showPromoteSheet = false
        } catch {
            self.error = error.localizedDescription
        }
        isPromoting = false
    }
}

// MARK: - Main View

struct AdminOperatorCareerView: View {
    @StateObject private var vm: AdminOperatorCareerViewModel

    init(service: AdminContractsServicing) {
        _vm = StateObject(wrappedValue: AdminOperatorCareerViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading && vm.operators.isEmpty {
                    LoadingStateView(message: "Загрузка...")
                } else if vm.operators.isEmpty {
                    EmptyStateView(message: "Нет операторов", icon: "person.badge.star")
                } else {
                    operatorList
                    if let op = vm.selectedOperator {
                        careerCard(op: op)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Карьера операторов")
        .task { await vm.loadOperators() }
        .sheet(isPresented: $vm.showPromoteSheet) {
            if let op = vm.selectedOperator {
                PromoteOperatorSheet(operatorName: op.name) { role, salary in
                    Task { await vm.promote(role: role, monthlySalary: salary) }
                }
            }
        }
    }

    private var operatorList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Выберите оператора")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.operators) { op in
                        Button {
                            Task { await vm.selectOperator(op) }
                        } label: {
                            Text(op.shortName ?? op.name)
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(vm.selectedOperator?.id == op.id ? .white : AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(vm.selectedOperator?.id == op.id ? AppTheme.Colors.purple : AppTheme.Colors.surfacePrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func careerCard(op: AdminOperator) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(op.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if let role = op.role {
                        Text(roleLabel(role))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.purpleBg)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Button("Повысить") { vm.showPromoteSheet = true }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.purple)
            }

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let link = vm.careerLink {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Текущая роль в системе")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    careerInfoRow(label: "Роль", value: roleLabel(link.assignedRole))
                    careerInfoRow(label: "Назначен", value: formatDate(link.assignedAt))
                    careerInfoRow(label: "Обновлён", value: formatDate(link.updatedAt))
                    if let staff = link.staff {
                        if let salary = staff.monthlySalary, salary > 0 {
                            careerInfoRow(label: "Оклад", value: String(format: "%.0f ₸", salary))
                        }
                        if let email = staff.email {
                            careerInfoRow(label: "Email", value: email)
                        }
                    }
                }
            } else {
                Text("Нет карьерных данных")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            if let err = vm.error {
                Text(err).font(AppTheme.Typography.caption).foregroundStyle(.red)
            }
        }
        .appCard()
    }

    private func careerInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role.lowercased() {
        case "operator": return "Оператор"
        case "senior_operator": return "Старший оператор"
        case "cashier": return "Кассир"
        case "senior_cashier": return "Старший кассир"
        case "manager": return "Менеджер"
        case "admin": return "Администратор"
        default: return role
        }
    }

    private func formatDate(_ iso: String) -> String {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3 else { return iso }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
    }
}

// MARK: - Promote Sheet

struct PromoteOperatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let operatorName: String
    let onSave: (String, Double?) -> Void

    @State private var selectedRole = "senior_operator"
    @State private var monthlySalary = ""

    private let roles = [
        ("operator", "Оператор"),
        ("senior_operator", "Старший оператор"),
        ("cashier", "Кассир"),
        ("senior_cashier", "Старший кассир"),
        ("manager", "Менеджер")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Повышение: \(operatorName)") {
                    Picker("Новая роль", selection: $selectedRole) {
                        ForEach(roles, id: \.0) { role in
                            Text(role.1).tag(role.0)
                        }
                    }
                    TextField("Оклад (₸, необязательно)", text: $monthlySalary)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Повышение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        onSave(selectedRole, Double(monthlySalary))
                        dismiss()
                    }
                }
            }
        }
    }
}
