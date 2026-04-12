import SwiftUI

struct ModuleCatalogView: View {
    let title: String
    let modules: [AppModule]

    var body: some View {
        List {
            if modules.isEmpty {
                EmptyStateView(message: "Пока нет данных")
            } else {
                Section(title) {
                    ForEach(modules) { module in
                        HStack {
                            Text(module.titleRU)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

struct NoBackendContractView: View {
    let moduleTitle: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text(moduleTitle)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Раздел доступен по роли. Для действий нужен backend endpoint.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.bgPrimary)
    }
}

struct RoleModulesView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        let modules = ModuleAccessMatrix.modules(for: sessionStore.roleContext).sorted { $0.rawValue < $1.rawValue }
        ModuleCatalogView(title: "Доступные разделы", modules: modules)
            .navigationTitle("Права доступа")
    }
}
