import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class OperatorShiftManagerViewModel: ObservableObject {
    @Published var currentShift: PointCurrentShift?
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Form fields
    @Published var selectedShiftType = "day"
    @Published var cashText = ""
    @Published var kaspiText = ""
    @Published var onlineText = ""
    @Published var cardText = ""
    @Published var comment = ""

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    var totalAmount: Double {
        let c = Double(cashText) ?? 0
        let k = Double(kaspiText) ?? 0
        let o = Double(onlineText) ?? 0
        let d = Double(cardText) ?? 0
        return c + k + o + d
    }

    var isPositive: Bool { totalAmount >= 0 }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            currentShift = try await service.fetchCurrentPointShift()
            if let shift = currentShift {
                cashText   = shift.cash.map   { String(format: "%.0f", $0) } ?? ""
                kaspiText  = shift.kaspi.map  { String(format: "%.0f", $0) } ?? ""
                onlineText = shift.online.map { String(format: "%.0f", $0) } ?? ""
                cardText   = shift.card.map   { String(format: "%.0f", $0) } ?? ""
                comment    = shift.comment ?? ""
                selectedShiftType = shift.shiftType ?? "day"
            }
        } catch {
            // No active shift — normal
            currentShift = nil
        }
    }

    func openShift() async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            try await service.openPointShift(shiftType: selectedShiftType, pointId: nil)
            successMessage = "Смена открыта"
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось открыть смену"
            AppHaptics.error()
        }
    }

    func closeShift(operatorId: String) async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            let today = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: Date())
            }()
            try await service.closePointShift(
                operatorId: operatorId,
                date: today,
                shiftType: selectedShiftType,
                cash: Double(cashText) ?? 0,
                kaspi: Double(kaspiText) ?? 0,
                online: Double(onlineText) ?? 0,
                card: Double(cardText) ?? 0,
                comment: comment
            )
            successMessage = "Смена закрыта"
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось закрыть смену"
            AppHaptics.error()
        }
    }
}

// MARK: - View

struct OperatorShiftManagerView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: OperatorShiftManagerViewModel
    @State private var showCloseSheet = false

    init(service: OperatorServicing) {
        _vm = StateObject(wrappedValue: OperatorShiftManagerViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка смены…")
                } else if let shift = vm.currentShift, shift.isOpen {
                    activeShiftCard(shift)
                    cashierSummaryCard(shift)
                    closeButton
                } else {
                    openShiftCard
                }

                if let msg = vm.successMessage {
                    resultBanner(msg, isSuccess: true)
                }
                if let err = vm.errorMessage {
                    resultBanner(err, isSuccess: false)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Управление сменой")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showCloseSheet) {
            closeShiftSheet
        }
    }

    // MARK: Open Shift Card

    private var openShiftCard: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accentPrimary.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                Text("Смена не открыта")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Откройте смену чтобы начать работу")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .appCard()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionHeader(title: "Тип смены", icon: "clock.fill", iconColor: AppTheme.Colors.accentPrimary)
                Picker("Тип смены", selection: $vm.selectedShiftType) {
                    Text("☀️ Дневная (08:00–20:00)").tag("day")
                    Text("🌙 Ночная (20:00–08:00)").tag("night")
                }
                .pickerStyle(.segmented)
            }
            .padding(AppTheme.Spacing.md)
            .appCard()

            Button {
                Task { await vm.openShift() }
            } label: {
                HStack {
                    if vm.isActing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.circle.fill")
                        Text("Открыть смену")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(vm.isActing)
        }
    }

    // MARK: Active Shift Card

    @ViewBuilder
    private func activeShiftCard(_ shift: PointCurrentShift) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.successBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Colors.success)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 8, height: 8)
                        Text("СМЕНА АКТИВНА")
                            .font(AppTheme.Typography.micro)
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    Text(shift.shiftType == "night" ? "🌙 Ночная смена" : "☀️ Дневная смена")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if let name = shift.pointName {
                        Text(name)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                Spacer()
            }

            if let opened = shift.openedAt {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text("Открыта: \(formatDate(opened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Spacer()
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.successBg.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Colors.successBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    // MARK: Cashier Summary

    @ViewBuilder
    private func cashierSummaryCard(_ shift: PointCurrentShift) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Итоги кассы", icon: "banknote.fill", iconColor: AppTheme.Colors.cashColor)

            let rows: [(String, Double, Color)] = [
                ("Наличные",  shift.cash   ?? 0, AppTheme.Colors.cashColor),
                ("Kaspi",     shift.kaspi  ?? 0, AppTheme.Colors.accentBlue),
                ("Online",    shift.online ?? 0, AppTheme.Colors.purple),
                ("Карта",     shift.card   ?? 0, AppTheme.Colors.info),
            ]
            ForEach(rows, id: \.0) { label, amount, color in
                if amount > 0 {
                    HStack {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(label).font(AppTheme.Typography.body).foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text(MoneyFormatter.short(amount))
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().background(AppTheme.Colors.borderSubtle)

            HStack {
                Text("ИТОГО")
                    .font(AppTheme.Typography.captionBold)
                    .tracking(1)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                Spacer()
                Text(MoneyFormatter.short(shift.total))
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .appCard()
    }

    // MARK: Close Button

    private var closeButton: some View {
        Button {
            showCloseSheet = true
        } label: {
            HStack {
                Image(systemName: "stop.circle.fill")
                Text("Закрыть смену")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .tint(AppTheme.Colors.error)
    }

    // MARK: Close Shift Sheet

    private var closeShiftSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionHeader(title: "Данные кассы", icon: "banknote.fill", iconColor: AppTheme.Colors.cashColor)
                        amountField("Наличные", text: $vm.cashText, icon: "banknote", color: AppTheme.Colors.cashColor)
                        amountField("Kaspi",    text: $vm.kaspiText, icon: "k.circle.fill", color: AppTheme.Colors.accentBlue)
                        amountField("Online",   text: $vm.onlineText, icon: "globe", color: AppTheme.Colors.purple)
                        amountField("Карта",    text: $vm.cardText, icon: "creditcard", color: AppTheme.Colors.info)
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    // Total
                    HStack {
                        Text("Итого смены")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text(MoneyFormatter.short(vm.totalAmount))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(vm.isPositive ? AppTheme.Colors.success : AppTheme.Colors.error)
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    // Comment
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Комментарий")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                        TextField("Заметки по смене...", text: $vm.comment, axis: .vertical)
                            .lineLimit(3...6)
                            .appInputStyle()
                    }
                    .padding(AppTheme.Spacing.md)
                    .appCard()

                    Button {
                        let id = sessionStore.session?.userEmail ?? ""
                        Task {
                            await vm.closeShift(operatorId: id)
                            showCloseSheet = false
                        }
                    } label: {
                        HStack {
                            if vm.isActing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Подтвердить закрытие смены")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .tint(AppTheme.Colors.error)
                    .disabled(vm.isActing)
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Закрытие смены")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { showCloseSheet = false }
                }
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func amountField(_ label: String, text: Binding<String>, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .appInputStyle()
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
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(isSuccess ? AppTheme.Colors.successBorder : AppTheme.Colors.errorBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }

    private func formatDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else { return String(iso.prefix(16)) }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "d MMM, HH:mm"
        return out.string(from: d)
    }
}
