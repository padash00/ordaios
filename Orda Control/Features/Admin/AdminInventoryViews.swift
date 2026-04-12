import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class AdminInventoryViewModel: ObservableObject {
    @Published var overview: InventoryOverview?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showCreateItem = false
    @Published var showCreateReceipt = false

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            overview = try await service.loadInventoryOverview()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createItem(name: String, unit: String, lowStockThreshold: Double?) async {
        let payload = InventoryItemCreatePayload(
            name: name, barcode: nil, categoryId: nil,
            salePrice: nil, defaultPurchasePrice: nil,
            unit: unit.isEmpty ? nil : unit,
            notes: nil, itemType: nil,
            lowStockThreshold: lowStockThreshold
        )
        do {
            try await service.createInventoryItem(payload)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Main View

struct AdminInventoryView: View {
    @StateObject private var vm: AdminInventoryViewModel
    let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
        _vm = StateObject(wrappedValue: AdminInventoryViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка склада...")
                } else if let err = vm.error {
                    ErrorStateView(message: err) { Task { await vm.load() } }
                } else if let overview = vm.overview {
                    inventoryContent(overview)
                } else {
                    EmptyStateView(message: "Нет данных склада", icon: "shippingbox")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Склад")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Добавить товар") { vm.showCreateItem = true }
                    Button("Приёмка товара") { vm.showCreateReceipt = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $vm.showCreateItem) {
            CreateInventoryItemSheet(service: service) { Task { await vm.load() } }
        }
        .sheet(isPresented: $vm.showCreateReceipt) {
            if let overview = vm.overview {
                CreateInventoryReceiptSheet(service: service, overview: overview) { Task { await vm.load() } }
            }
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private func inventoryContent(_ overview: InventoryOverview) -> some View {
        // Summary card
        HStack(spacing: AppTheme.Spacing.md) {
            statPill(title: "Товаров", value: "\(overview.items.count)", color: AppTheme.Colors.accentBlue)
            statPill(title: "Локаций", value: "\(overview.locations.count)", color: AppTheme.Colors.purple)
            statPill(title: "Мало", value: "\(lowStockCount(overview))", color: AppTheme.Colors.error)
        }
        .appCard()

        // Low stock alerts
        let lowItems = lowStockItems(overview)
        if !lowItems.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Label("Заканчивается на складе", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.warning)
                ForEach(lowItems, id: \.id) { item in
                    HStack {
                        Text(item.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        let qty = totalStock(for: item.id, stock: overview.stock)
                        Text(String(format: "%.1f %@", qty, item.unit ?? "шт"))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            .appCard()
        }

        // Items by location
        ForEach(overview.locations) { location in
            let locationStock = overview.stock.filter { $0.locationId == location.id }
            if !locationStock.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(location.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ForEach(locationStock) { row in
                        if let item = overview.items.first(where: { $0.id == row.itemId }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    if let cat = item.categoryId,
                                       let category = overview.categories.first(where: { $0.id == cat }) {
                                        Text(category.name)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.textMuted)
                                    }
                                }
                                Spacer()
                                let threshold = item.lowStockThreshold ?? 0
                                let isLow = threshold > 0 && row.quantity <= threshold
                                Text(String(format: "%.1f %@", row.quantity, item.unit ?? "шт"))
                                    .font(AppTheme.Typography.callout)
                                    .foregroundStyle(isLow ? AppTheme.Colors.error : AppTheme.Colors.textPrimary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .appCard()
            }
        }

        // All items list
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Все товары (\(overview.items.count))")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            ForEach(overview.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if let price = item.salePrice {
                            Text(String(format: "%.0f ₸", price))
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                    Spacer()
                    Text(item.unit ?? "шт")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.surfacePrimary)
                        .clipShape(Capsule())
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .appCard()
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func totalStock(for itemId: String, stock: [InventoryStockRow]) -> Double {
        stock.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
    }

    private func lowStockItems(_ overview: InventoryOverview) -> [InventoryItem] {
        overview.items.filter { item in
            guard let threshold = item.lowStockThreshold, threshold > 0 else { return false }
            let qty = totalStock(for: item.id, stock: overview.stock)
            return qty <= threshold
        }
    }

    private func lowStockCount(_ overview: InventoryOverview) -> Int {
        lowStockItems(overview).count
    }
}

// MARK: - Create Item Sheet

struct CreateInventoryItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let service: AdminContractsServicing
    let onDone: () -> Void

    @State private var name = ""
    @State private var unit = "шт"
    @State private var salePrice = ""
    @State private var lowStockThreshold = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Товар") {
                    TextField("Название *", text: $name)
                    TextField("Единица (шт, кг, л...)", text: $unit)
                    TextField("Цена продажи (₸)", text: $salePrice)
                        .keyboardType(.decimalPad)
                    TextField("Порог низкого запаса", text: $lowStockThreshold)
                        .keyboardType(.decimalPad)
                }
                if let err = error {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Новый товар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(name.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let threshold = Double(lowStockThreshold)
        let payload = InventoryItemCreatePayload(
            name: name, barcode: nil, categoryId: nil,
            salePrice: Double(salePrice),
            defaultPurchasePrice: nil,
            unit: unit.isEmpty ? nil : unit,
            notes: nil, itemType: nil,
            lowStockThreshold: threshold
        )
        do {
            try await service.createInventoryItem(payload)
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Create Receipt Sheet

struct CreateInventoryReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let service: AdminContractsServicing
    let overview: InventoryOverview
    let onDone: () -> Void

    @State private var selectedLocationId = ""
    @State private var selectedSupplierId = ""
    @State private var receivedDate = Date()
    @State private var invoiceNumber = ""
    @State private var comment = ""
    @State private var lines: [ReceiptLine] = []
    @State private var isSaving = false
    @State private var error: String?

    struct ReceiptLine: Identifiable {
        let id = UUID()
        var itemId: String = ""
        var quantity: String = ""
        var unitCost: String = ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Приёмка") {
                    Picker("Локация *", selection: $selectedLocationId) {
                        Text("Выбрать...").tag("")
                        ForEach(overview.locations) { loc in
                            Text(loc.name).tag(loc.id)
                        }
                    }
                    Picker("Поставщик", selection: $selectedSupplierId) {
                        Text("Без поставщика").tag("")
                        ForEach(overview.suppliers) { sup in
                            Text(sup.name).tag(sup.id)
                        }
                    }
                    DatePicker("Дата", selection: $receivedDate, displayedComponents: .date)
                    TextField("Номер накладной", text: $invoiceNumber)
                    TextField("Комментарий", text: $comment)
                }

                Section("Товары") {
                    ForEach($lines) { $line in
                        VStack(spacing: 8) {
                            Picker("Товар", selection: $line.itemId) {
                                Text("Выбрать...").tag("")
                                ForEach(overview.items) { item in
                                    Text(item.name).tag(item.id)
                                }
                            }
                            HStack {
                                TextField("Кол-во", text: $line.quantity).keyboardType(.decimalPad)
                                TextField("Цена/ед (₸)", text: $line.unitCost).keyboardType(.decimalPad)
                            }
                        }
                    }
                    Button("+ Добавить позицию") { lines.append(ReceiptLine()) }
                }

                if let err = error {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Приёмка товара")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(selectedLocationId.isEmpty || lines.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let first = overview.locations.first { selectedLocationId = first.id }
                lines = [ReceiptLine()]
            }
        }
    }

    private func save() async {
        isSaving = true
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let receiptItems = lines.compactMap { line -> InventoryReceiptLinePayload? in
            guard !line.itemId.isEmpty,
                  let qty = Double(line.quantity),
                  let cost = Double(line.unitCost) else { return nil }
            return InventoryReceiptLinePayload(itemId: line.itemId, quantity: qty, unitCost: cost, comment: nil)
        }
        guard !receiptItems.isEmpty else {
            error = "Добавьте хотя бы одну позицию"
            isSaving = false
            return
        }
        let payload = InventoryReceiptPayload(
            locationId: selectedLocationId,
            supplierId: selectedSupplierId.isEmpty ? nil : selectedSupplierId,
            receivedAt: df.string(from: receivedDate),
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            comment: comment.isEmpty ? nil : comment,
            items: receiptItems
        )
        do {
            try await service.createInventoryReceipt(payload)
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
