import SwiftUI

/// Доступ к разделам веб-панели Orda Point, которых ещё нет в нативном приложении или они глубже, чем в iOS.
struct AdminWebParityHubView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Нативное приложение постепенно догоняет веб. Ниже — те же разделы на сайте: откройте ссылку в браузере и войдите тем же email и паролем (сессия приложения в Safari не передаётся).")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
            }

            Section("Обзор") {
                webLink("Главная / дашборд", path: "/platform", icon: "rectangle.3.group.fill")
                webLink("Выбор организации", path: "/select-organization", icon: "building.2.fill")
            }

            Section("Финансы и учёт") {
                webLink("Доходы", path: "/income", icon: "arrow.up.circle.fill")
                webLink("Расходы", path: "/expenses", icon: "arrow.down.circle.fill")
                webLink("Зарплата", path: "/salary", icon: "banknote.fill")
                webLink("Отчёты", path: "/reports", icon: "doc.text.fill")
                webLink("KPI", path: "/kpi", icon: "gauge.with.dots.needle.67percent")
            }

            Section("Операции") {
                webLink("Смены", path: "/shifts", icon: "clock.fill")
                webLink("Задачи", path: "/tasks", icon: "checklist")
                webLink("Операторы", path: "/operators", icon: "person.2.fill")
                webLink("Клиенты", path: "/customers", icon: "person.3.fill")
            }

            Section("Склад, POS, точка") {
                webLink("Склад / инвентарь", path: "/inventory", icon: "archivebox.fill")
                webLink("Магазин", path: "/store", icon: "cart.fill")
                webLink("POS", path: "/pos", icon: "creditcard.fill")
                webLink("Терминал точки", path: "/point", icon: "desktopcomputer")
            }

            Section("Аналитика и AI") {
                webLink("Аналитика", path: "/analytics", icon: "chart.xyaxis.line")
            }

            Section("Арена и прочее на сайте") {
                webLink("Arena (зоны, тарифы)", path: "/arena", icon: "sportscourt.fill")
                webLink("Настройки", path: "/settings", icon: "gearshape.fill")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Сайт Orda Point")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func webLink(_ title: String, path: String, icon: String) -> some View {
        Link(destination: OrdaWebsiteURL.url(path: path)) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(path)
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppTheme.Colors.surfacePrimary.opacity(0.6))
    }
}
