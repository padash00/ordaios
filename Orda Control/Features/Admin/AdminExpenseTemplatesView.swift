import SwiftUI
import Combine

// MARK: - Models

struct ExpenseTemplate: Decodable, Identifiable {
    let id: String
    let name: String?
    let category: String?
    let defaultAmount: Double?
    let description: String?
    let isActive: Bool?

    var displayName: String { name ?? "Шаблон" }
    var active: Bool { isActive ?? true }
}

private struct TemplatesEnvelope: Decodable {
    let data: [ExpenseTemplate]?
    let templates: [ExpenseTemplate]?

    var resolved: [ExpenseTemplate] { data ?? templates ?? [] }
}

private struct TemplateActionBody: Encodable {
    let action: String
    let templateId: String?
    let name: String?
    let category: String?
    let defaultAmount: Double?
    let description: String?
}

// MARK: - ViewModel

@MainActor
final class AdminExpenseTemplatesViewModel: ObservableObject {
    @Published var templates: [ExpenseTemplate] = []
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showAddSheet = false

    // Form
    @Published var formName = ""
    @Published var formCategory = ""
    @Published var formAmount = ""
    @Published var formDescription = ""

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let envelope: TemplatesEnvelope = try await apiClient.request(ContractEndpoint.api_admin_expense_templates.get)
            templates = envelope.resolved
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func createTemplate() async {
        guard !formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            let body = TemplateActionBody(
                action: "createTemplate",
                templateId: nil,
                name: formName.trimmingCharacters(in: .whitespacesAndNewlines),
                category: formCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : formCategory,
                defaultAmount: Double(formAmount),
                description: formDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : formDescription
            )
            let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_expense_templates.post, body: body)
            successMessage = "Шаблон создан"
            resetForm()
            showAddSheet = false
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось создать шаблон"
            AppHaptics.error()
        }
    }

    func deleteTemplate(id: String) async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            let body = TemplateActionBody(action: "deleteTemplate", templateId: id, name: nil, category: nil, defaultAmount: nil, description: nil)
            let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_expense_templates.post, body: body)
            successMessage = "Шаблон удалён"
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось удалить шаблон"
            AppHaptics.error()
        }
    }

    private func resetForm() {
        formName = ""
        formCategory = ""
        formAmount = ""
        formDescription = ""
    }
}

// MARK: - View

struct AdminExpenseTemplatesView: View {
    @StateObject private var vm: AdminExpenseTemplatesViewModel
    private let categories = ["Аренда", "Зарплата", "Коммунальные", "Интернет", "Расходные материалы", "Реклама", "Прочее"]

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AdminExpenseTemplatesViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                addButton

                if vm.isLoading {
                    LoadingStateView(message: "Загрузка шаблонов…")
                } else if let err = vm.errorMessage {
                    ErrorStateView(message: err, retryAction: { Task { await vm.load() } })
                } else if vm.templates.isEmpty {
                    emptyState
                } else {
                    templatesList
                }

                if let msg = vm.successMessage {
                    resultBanner(msg, isSuccess: true)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Шаблоны расходов")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $vm.showAddSheet) {
            addTemplateSheet
        }
    }

    // MARK: Add Button

    private var addButton: some View {
        Button {
            vm.showAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Новый шаблон")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.textMuted)
            Text("Нет шаблонов расходов")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Создайте шаблоны для быстрого добавления частых расходов")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
        .appCard()
    }

    // MARK: Templates List

    private var templatesList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Шаблоны (\(vm.templates.count))", icon: "doc.fill", iconColor: AppTheme.Colors.accentBlue)

            ForEach(vm.templates) { template in
                templateRow(template)
                if template.id != vm.templates.last?.id {
                    Divider().background(AppTheme.Colors.borderSubtle)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    @ViewBuilder
    private func templateRow(_ template: ExpenseTemplate) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .fill(AppTheme.Colors.errorBg)
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.error)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayName)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    if let cat = template.category {
                        Text(cat)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let desc = template.description, !desc.isEmpty {
                        Text("•")
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        Text(desc)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let amount = template.defaultAmount, amount > 0 {
                Text(MoneyFormatter.short(amount))
                    .font(AppTheme.Typography.monoCaption)
                    .foregroundStyle(AppTheme.Colors.error)
            }

            Button {
                Task { await vm.deleteTemplate(id: template.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(vm.isActing)
        }
        .padding(.vertical, 4)
    }

    // MARK: Add Template Sheet

    private var addTemplateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Детали шаблона", icon: "doc.text", iconColor: AppTheme.Colors.accentBlue)

                        TextField("Название шаблона *", text: $vm.formName)
                            .appInputStyle()

                        TextField("Описание", text: $vm.formDescription)
                            .appInputStyle()

                        TextField("Сумма по умолчанию", text: $vm.formAmount)
                            .keyboardType(.decimalPad)
                            .appInputStyle()
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Категория", icon: "tag.fill", iconColor: AppTheme.Colors.warning)
                        Picker("Категория", selection: $vm.formCategory) {
                            Text("Без категории").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    Button {
                        Task { await vm.createTemplate() }
                    } label: {
                        HStack {
                            if vm.isActing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Создать шаблон")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.isActing || vm.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Новый шаблон")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { vm.showAddSheet = false }
                }
            }
        }
    }

    @ViewBuilder
    private func resultBanner(_ message: String, isSuccess: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Colors.success)
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.success)
            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.successBg)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.successBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }
}
