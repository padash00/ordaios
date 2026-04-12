import SwiftUI
import Charts
import VisionKit
import AVFoundation
import Vision
import UIKit

// MARK: - Salary

struct OperatorSalaryView: View {
    @StateObject private var vm: OperatorSalaryViewModel
    @State private var showExportSheet = false
    @State private var exportItems: [Any] = []
    @State private var exportErrorMessage: String?

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorSalaryViewModel(service: service))
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
                salaryContent
            }
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Зарплата")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    exportSalaryPDF()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(vm.payload?.week == nil)
            }
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
        .sheet(isPresented: $showExportSheet) {
            ActivityShareSheet(activityItems: exportItems)
        }
        .alert("Экспорт PDF", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("ОК", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var salaryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                weekPicker
                if let w = vm.payload?.week {
                    summarySection(w)
                    weeklyChartSection
                    companyBreakdownChartSection
                    if let list = w.allocations, !list.isEmpty {
                        listSection(title: "По компаниям", icon: "building.2", items: list.map { row in
                            let title = row.companyName ?? row.companyCode ?? "Компания"
                            let subtitle = row.companyCode.map { "Код: \($0)" } ?? ""
                            let value = MoneyFormatter.detailed(row.netAmount ?? 0)
                            return (title, subtitle, value)
                        })
                    }
                    if let list = w.payments, !list.isEmpty {
                        paymentSection(list)
                    }
                    if let list = w.adjustments, !list.isEmpty {
                        adjustmentSection(list)
                    }
                    if let list = w.debts, !list.isEmpty {
                        debtSection(list)
                    }
                }
                if let recent = vm.payload?.recentWeeks, !recent.isEmpty {
                    recentWeeksSection(recent)
                }
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

    private var weekPicker: some View {
        HStack {
            Button {
                Task { await vm.shiftWeek(by: -1) }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
            }
            .disabled(vm.isLoading)

            Spacer()
            VStack(spacing: 2) {
                Text("Неделя с")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Text(vm.weekStartISO)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let end = vm.payload?.week?.weekEnd {
                    Text("по \(end)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
            Spacer()

            Button {
                Task { await vm.shiftWeek(by: 1) }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
            }
            .disabled(vm.isLoading)
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Динамика по неделям", icon: "chart.bar.xaxis", iconColor: AppTheme.Colors.accentBlue)
            if vm.weeklyNetSeries.isEmpty {
                Text("Недостаточно данных для графика")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                Chart(vm.weeklyNetSeries, id: \.id) { point in
                    BarMark(
                        x: .value("Неделя", point.label),
                        y: .value("К выплате", point.amount)
                    )
                    .foregroundStyle(AppTheme.Colors.accentPrimary.gradient)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(MoneyFormatter.short(v))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var companyBreakdownChartSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Разбивка по компаниям", icon: "chart.bar.doc.horizontal", iconColor: AppTheme.Colors.purple)
            if vm.companyBreakdown.isEmpty {
                Text("Нет начислений по компаниям за выбранную неделю")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                Chart(vm.companyBreakdown, id: \.id) { row in
                    BarMark(
                        x: .value("Сумма", row.amount),
                        y: .value("Компания", row.name)
                    )
                    .foregroundStyle(AppTheme.Colors.purple.gradient)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(MoneyFormatter.short(v))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundStyle(AppTheme.Colors.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color(hex: 0x374151).opacity(0.3))
                        AxisValueLabel().font(AppTheme.Typography.micro).foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .frame(height: CGFloat(max(140, min(280, vm.companyBreakdown.count * 34))))

                Text("Всего по компаниям: \(MoneyFormatter.detailed(vm.companyBreakdownTotal))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func summarySection(_ w: OperatorSalaryWeekPayload) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Сводка", icon: "chart.bar.doc.horizontal", iconColor: AppTheme.Colors.accentPrimary)
            salaryKV("Статус", operatorSalaryWeekStatusLabel(w.status))
            salaryKV("К выплате", MoneyFormatter.detailed(w.netAmount ?? 0))
            salaryKV("Выплачено", MoneyFormatter.detailed(w.paidAmount ?? 0))
            salaryKV("Остаток", MoneyFormatter.detailed(w.remainingAmount ?? 0))
            Divider().opacity(0.3)
            salaryKV("Начислено (gross)", MoneyFormatter.detailed(w.grossAmount ?? 0))
            salaryKV("Бонус", MoneyFormatter.detailed(w.bonusAmount ?? 0))
            salaryKV("Штраф", MoneyFormatter.detailed(w.fineAmount ?? 0))
            salaryKV("Долг в расчёте", MoneyFormatter.detailed(w.debtAmount ?? 0))
            salaryKV("Аванс", MoneyFormatter.detailed(w.advanceAmount ?? 0))
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func listSection(title: String, icon: String, items: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: title, icon: icon, iconColor: AppTheme.Colors.accentBlue)
            ForEach(Array(items.enumerated()), id: \.offset) { idx, row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.0)
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text(row.2)
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                    }
                    if !row.1.isEmpty {
                        Text(row.1)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                .padding(.vertical, 4)
                if idx < items.count - 1 {
                    Divider().opacity(0.2)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func paymentSection(_ rows: [OperatorSalaryPaymentRow]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Выплаты", icon: "creditcard", iconColor: AppTheme.Colors.purple)
            ForEach(rows) { p in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(p.paymentDate ?? "—")
                            .font(AppTheme.Typography.callout)
                        Spacer()
                        Text(MoneyFormatter.detailed(p.totalAmount ?? 0))
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    if (p.cashAmount ?? 0) > 0.009 || (p.kaspiAmount ?? 0) > 0.009 {
                        Text("Наличные \(MoneyFormatter.detailed(p.cashAmount ?? 0)) · Kaspi \(MoneyFormatter.detailed(p.kaspiAmount ?? 0))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let c = p.comment, !c.isEmpty {
                        Text(c)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func adjustmentSection(_ rows: [OperatorSalaryAdjustmentRow]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Корректировки", icon: "slider.horizontal.3", iconColor: AppTheme.Colors.warning)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.date ?? "—")
                        Spacer()
                        Text(MoneyFormatter.detailed(row.amount ?? 0))
                            .font(AppTheme.Typography.monoCaption)
                    }
                    if let k = row.kind, !k.isEmpty {
                        Text(k)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let n = row.companyName, !n.isEmpty {
                        Text(n)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    if let c = row.comment, !c.isEmpty {
                        Text(c)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func debtSection(_ rows: [OperatorSalaryDebtRow]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Долги (неделя)", icon: "exclamationmark.circle", iconColor: AppTheme.Colors.error)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.date ?? "—")
                        Spacer()
                        Text(MoneyFormatter.detailed(row.amount ?? 0))
                            .font(AppTheme.Typography.monoCaption)
                    }
                    if let n = row.companyName, !n.isEmpty {
                        Text(n)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let c = row.comment, !c.isEmpty {
                        Text(c)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func recentWeeksSection(_ rows: [OperatorSalaryRecentWeek]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Недавние недели", icon: "calendar", iconColor: AppTheme.Colors.textMuted)
            ForEach(rows) { w in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.weekStart ?? "—")
                            .font(AppTheme.Typography.callout)
                        Text(operatorSalaryWeekStatusLabel(w.status))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(MoneyFormatter.detailed(w.netAmount ?? 0))
                            .font(AppTheme.Typography.monoCaption)
                        if (w.paymentsCount ?? 0) > 0 {
                            Text("Платежей: \(w.paymentsCount ?? 0)")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private func salaryKV(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.monoCaption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func exportSalaryPDF() {
        guard let payload = vm.payload else {
            exportErrorMessage = "Нет данных для экспорта."
            return
        }
        do {
            let url = try buildSalaryPDF(payload: payload, weekStart: vm.weekStartISO)
            exportItems = [url]
            showExportSheet = true
        } catch {
            exportErrorMessage = "Не удалось сформировать PDF."
        }
    }

    private func buildSalaryPDF(payload: OperatorSalaryPayload, weekStart: String) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        let week = payload.week
        var lines: [String] = []
        lines.append("Orda Control — Salary Export")
        lines.append("Week start: \(week?.weekStart ?? weekStart)")
        lines.append("Week end: \(week?.weekEnd ?? "—")")
        lines.append("")
        lines.append("Summary")
        lines.append("Status: \(operatorSalaryWeekStatusLabel(week?.status))")
        lines.append("Net: \(MoneyFormatter.detailed(week?.netAmount ?? 0))")
        lines.append("Paid: \(MoneyFormatter.detailed(week?.paidAmount ?? 0))")
        lines.append("Remaining: \(MoneyFormatter.detailed(week?.remainingAmount ?? 0))")
        lines.append("Gross: \(MoneyFormatter.detailed(week?.grossAmount ?? 0))")
        lines.append("Bonus: \(MoneyFormatter.detailed(week?.bonusAmount ?? 0))")
        lines.append("Fine: \(MoneyFormatter.detailed(week?.fineAmount ?? 0))")
        lines.append("Debt: \(MoneyFormatter.detailed(week?.debtAmount ?? 0))")
        lines.append("Advance: \(MoneyFormatter.detailed(week?.advanceAmount ?? 0))")
        lines.append("")

        if let allocations = week?.allocations, !allocations.isEmpty {
            lines.append("Company breakdown")
            for row in allocations {
                let name = row.companyName ?? row.companyCode ?? "Company"
                lines.append("• \(name): \(MoneyFormatter.detailed(row.netAmount ?? 0))")
            }
            lines.append("")
        }

        if let recent = payload.recentWeeks, !recent.isEmpty {
            lines.append("Recent weeks")
            for row in recent.prefix(8) {
                lines.append("• \(row.weekStart ?? "—"): \(MoneyFormatter.detailed(row.netAmount ?? 0))")
            }
        }

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 36
            ("Operator Salary Report" as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: titleAttrs)
            y += 30

            for line in lines {
                if y > pageRect.height - 40 {
                    ctx.beginPage()
                    y = 36
                }
                (line as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: bodyAttrs)
                y += 16
            }
        }

        let filename = "operator-salary-\(week?.weekStart ?? weekStart).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private func operatorSalaryWeekStatusLabel(_ status: String?) -> String {
    switch status?.lowercased() {
    case "paid": return "Выплачено"
    case "partial": return "Частично"
    case "draft": return "Черновик"
    default: return status ?? "—"
    }
}

// MARK: - Cabinet profile

struct OperatorCabinetProfileView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var lockManager: AppLockManager
    @StateObject private var vm: OperatorCabinetProfileViewModel
    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: OperatorCabinetProfileViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                headerCard
                if vm.isLoading, vm.payload == nil {
                    LoadingStateView(message: "Загрузка профиля…")
                        .frame(minHeight: 200)
                } else if let err = vm.errorMessage, vm.payload == nil {
                    ErrorStateView(message: err) {
                        Task { await vm.load() }
                    }
                    .frame(minHeight: 200)
                } else {
                    profileDetailsCard
                    assignmentsCard
                    leadCard
                }
                AppLockTimeoutSettingsCard()
                    .environmentObject(lockManager)
                qrLinkCard
                sessionCard
                logoutButton
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Профиль")
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
    }

    private var displayName: String {
        vm.payload?.operatorInfo?.name
            ?? vm.payload?.operatorInfo?.profile?.fullName
            ?? sessionStore.roleContext?.roleLabel
            ?? "Оператор"
    }

    private var headerCard: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Colors.purple, AppTheme.Colors.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Text(String(displayName.prefix(2)).uppercased())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(displayName)
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            if let un = vm.payload?.operatorInfo?.username, !un.isEmpty {
                Text("@\(un)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            StatusBadge(text: sessionStore.roleContext?.persona ?? "operator", style: .info)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.headerGradient)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(AppTheme.Colors.purpleBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }

    private var profileDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Анкета", icon: "person.text.rectangle", iconColor: AppTheme.Colors.accentBlue)
            if let p = vm.payload?.operatorInfo?.profile {
                profileRow("ФИО", p.fullName)
                profileRow("Должность", p.position)
                profileRow("Телефон", p.phone)
                profileRow("Email", p.email)
                profileRow("Город", p.city)
                profileRow("Дата найма", p.hireDate)
                if let about = p.about, !about.isEmpty {
                    Text(about)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            } else {
                Text("Данные профиля не заполнены")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var assignmentsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Компании", icon: "building.2", iconColor: AppTheme.Colors.accentPrimary)
            let list = vm.payload?.assignments ?? []
            if list.isEmpty {
                Text("Нет активных назначений")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(list) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(a.companyName ?? a.companyCode ?? "Компания")
                                .font(AppTheme.Typography.callout)
                            if a.isPrimary == true {
                                Text("осн.")
                                    .font(AppTheme.Typography.captionBold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.Colors.accentPrimary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        if let r = a.role, !r.isEmpty {
                            Text(r)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var leadCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Ведущий", icon: "person.badge.key", iconColor: AppTheme.Colors.warning)
            let list = vm.payload?.leadAssignments ?? []
            if list.isEmpty {
                Text("Нет назначений ведущего")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(list) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.companyName ?? a.companyCode ?? "Компания")
                            .font(AppTheme.Typography.callout)
                        if let r = a.role, !r.isEmpty {
                            Text(r)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var qrLinkCard: some View {
        NavigationLink {
            OperatorPointQRConfirmView(service: service)
        } label: {
            HStack {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Вход на кассе")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Подтвердить QR-код с терминала")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            .padding(AppTheme.Spacing.md)
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Аккаунт", icon: "key.horizontal", iconColor: AppTheme.Colors.textMuted)
            profileRow("Почта", sessionStore.session?.userEmail ?? "—")
            profileRow("Роль (сервер)", vm.payload?.operatorInfo?.authRole ?? "—")
            profileRow("Маршрут", sessionStore.roleContext?.defaultPath ?? "—")
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    private var logoutButton: some View {
        Button {
            Task { await sessionStore.logout() }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти из аккаунта")
            }
            .font(AppTheme.Typography.callout)
            .foregroundStyle(AppTheme.Colors.error)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.errorBg)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(AppTheme.Colors.errorBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profileRow(_ title: String, _ value: String?) -> some View {
        let v = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
                Text(v)
                    .font(AppTheme.Typography.monoCaption)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Point QR confirm (camera scanner)

struct OperatorPointQRConfirmView: View {
    @StateObject private var vm: OperatorPointQRConfirmViewModel
    @State private var showScanner = false
    @State private var showManual = false
    @State private var manualNonce = ""
    @State private var cameraPermissionDenied = false

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorPointQRConfirmViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Hero instruction card
                VStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.accentPrimary.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.accentPrimary)
                    }
                    Text("Вход на кассу")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Откройте терминал Orda Point, нажмите «Войти» и отсканируйте QR-код с экрана кассы.")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.lg)
                .appCard()

                // Result states
                if let success = vm.successMessage {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Успешно!")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.success)
                            Text(success)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.successBg)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.successBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }

                if let error = vm.errorMessage {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.error)
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.errorBg)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.errorBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }

                if cameraPermissionDenied {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(AppTheme.Colors.warning)
                        Text("Нет доступа к камере. Разрешите в Настройках или введите код вручную.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.warningBg)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.warningBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }

                // Primary scan button
                Button {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    switch status {
                    case .authorized:
                        cameraPermissionDenied = false
                        showScanner = true
                    case .notDetermined:
                        AVCaptureDevice.requestAccess(for: .video) { granted in
                            DispatchQueue.main.async {
                                if granted {
                                    cameraPermissionDenied = false
                                    showScanner = true
                                } else {
                                    cameraPermissionDenied = true
                                }
                            }
                        }
                    default:
                        cameraPermissionDenied = true
                    }
                } label: {
                    HStack {
                        if vm.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "camera.viewfinder")
                            Text("Сканировать QR")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(vm.isSubmitting)

                // Manual fallback
                Button {
                    showManual.toggle()
                } label: {
                    Text(showManual ? "Скрыть ручной ввод" : "Ввести код вручную")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                .buttonStyle(.plain)

                if showManual {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        TextField("Nonce из QR-кода", text: $manualNonce)
                            .appInputStyle()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            Task {
                                await vm.confirm(nonce: manualNonce)
                                if vm.successMessage != nil { manualNonce = "" }
                            }
                        } label: {
                            Text("Подтвердить")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(vm.isSubmitting || manualNonce.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Вход на кассу")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerSheet { scannedString in
                showScanner = false
                let nonce = QRScannerSheet.extractNonce(from: scannedString)
                Task { await vm.confirm(nonce: nonce) }
            } onCancel: {
                showScanner = false
            }
        }
    }
}

// MARK: - QR Scanner Sheet (DataScannerViewController wrapper)

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(onScan: onScan)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    scanOverlay
                }
                .overlay(alignment: .bottom) {
                    bottomBar
                }
        } else {
            // Fallback for simulator / unsupported device
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Text("Сканер недоступен на этом устройстве")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Закрыть", action: onCancel)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(AppTheme.Spacing.xl)
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        }
    }

    private var scanOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                }
                Spacer()
                Text("Направьте камеру на QR")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5))
                    .clipShape(Capsule())
                Spacer()
                // balance spacer
                Circle().fill(.clear).frame(width: 38, height: 38)
            }
            .padding(AppTheme.Spacing.md)
            .background(
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Corner frame indicator
            ZStack {
                // Scan frame corners
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(AppTheme.Colors.accentPrimary, lineWidth: 3)
                    .frame(width: 220, height: 220)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.Colors.accentPrimary.opacity(0.3))
                    )
            }
            .padding(.bottom, AppTheme.Spacing.lg)

            Text("QR-код с экрана терминала Orda Point")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        )
    }

    // Extract nonce from URL like https://ordaops.kz/operator/point-qr-confirm?n=abc123
    // or return the raw string if it's already a nonce
    static func extractNonce(from scanned: String) -> String {
        guard let url = URL(string: scanned),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let nonce = comps.queryItems?.first(where: { $0.name == "n" })?.value,
              !nonce.isEmpty
        else {
            return scanned // fallback: treat whole string as nonce
        }
        return nonce
    }
}

// MARK: - DataScannerViewController wrapper

@available(iOS 16.0, *)
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var scanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !scanned else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    scanned = true
                    AppHaptics.success()
                    onScan(value)
                    return
                }
            }
        }
    }
}
