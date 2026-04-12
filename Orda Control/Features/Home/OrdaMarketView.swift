import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class OrdaMarketViewModel: ObservableObject {
    @Published private(set) var items: [ClientCatalogItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isNotAvailable = false
    /// Из ответа API (`storefront_url`); может быть пустым.
    @Published private(set) var catalogStorefrontUrl: String?
    @Published private(set) var catalogGuestMode = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var orderSuccess = false
    @Published var cartItems: [String: Int] = [:]
    @Published var showCart = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var cartItemCount: Int {
        cartItems.values.reduce(0, +)
    }

    var cartLines: [(item: ClientCatalogItem, quantity: Int)] {
        cartItems.compactMap { (itemId, qty) in
            guard let item = items.first(where: { $0.id == itemId }), qty > 0 else { return nil }
            return (item: item, quantity: qty)
        }.sorted { $0.item.name < $1.item.name }
    }

    var cartTotal: Double {
        cartLines.reduce(0) { $0 + $1.item.price * Double($1.quantity) }
    }

    var loyaltyDiscount: Double {
        cartTotal * 0.10
    }

    /// URL витрины: из API, иначе из `AppConfig.storefrontURL`, иначе база API.
    var resolvedStorefrontURL: URL? {
        let fromApi = catalogStorefrontUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromConfig = AppConfig.current.storefrontURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = !fromApi.isEmpty ? fromApi : (!fromConfig.isEmpty ? fromConfig : AppConfig.current.apiBaseURL.absoluteString)
        return URL(string: raw)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        isNotAvailable = false
        catalogStorefrontUrl = nil
        catalogGuestMode = false
        defer { isLoading = false }

        do {
            let response: ClientCatalogAPIResponse = try await apiClient.request(ContractEndpoint.api_client_catalog.get)
            items = response.items
            catalogStorefrontUrl = response.storefrontUrl
            catalogGuestMode = response.guest ?? false
            if items.isEmpty {
                isNotAvailable = true
            }
        } catch let err as APIError {
            if case .validation = err {
                isNotAvailable = true
            } else if err == .forbidden || err == .unauthorized {
                errorMessage = err.errorDescription
            } else {
                // Treat server/network errors as not available for catalog
                isNotAvailable = true
            }
        } catch {
            isNotAvailable = true
        }
    }

    func addToCart(_ item: ClientCatalogItem) {
        cartItems[item.id, default: 0] += 1
    }

    func setQuantity(itemId: String, quantity: Int) {
        if quantity <= 0 {
            cartItems.removeValue(forKey: itemId)
        } else {
            cartItems[itemId] = quantity
        }
    }

    func submitPreorder(pointId: String? = nil) async {
        guard !cartLines.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let payload = PreorderPayload(
            items: cartLines.map { PreorderLinePayload(itemId: $0.item.id, quantity: $0.quantity) },
            pointId: pointId
        )

        do {
            // POST preorder — response shape may vary; we only care about success/failure
            let _: DataListResponse<String> = try await apiClient.request(ContractEndpoint.api_client_preorder.post, body: payload)
            cartItems = [:]
            showCart = false
            orderSuccess = true
        } catch let err as APIError {
            // If decode fails but status was 2xx the APIClient throws .decodingFailed
            // Treat that as success since the request went through
            if case .decodingFailed = err {
                cartItems = [:]
                showCart = false
                orderSuccess = true
            } else {
                errorMessage = err.errorDescription
            }
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func setOrderSuccessPresented(_ presented: Bool) {
        orderSuccess = presented
    }
}

// MARK: - Main View

struct OrdaMarketView: View {
    @StateObject var viewModel: OrdaMarketViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(message: "Загрузка каталога...")
            } else if let error = viewModel.errorMessage, !viewModel.isNotAvailable {
                ErrorStateView(message: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.isNotAvailable {
                catalogUnavailableView
            } else {
                catalogContent
            }
        }
        .navigationTitle("Каталог")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                cartBarButton
            }
        }
        .sheet(isPresented: $viewModel.showCart) {
            CartSheet(viewModel: viewModel)
        }
        .alert("Заказ оформлен!", isPresented: Binding(
            get: { viewModel.orderSuccess },
            set: { viewModel.setOrderSuccessPresented($0) }
        )) {
            Button("Отлично", role: .cancel) {}
        } message: {
            Text("Ваш предзаказ принят. Мы свяжемся с вами для подтверждения.")
        }
        .task { await viewModel.load() }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }

    private var catalogUnavailableView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            EmptyStateView(
                message: viewModel.catalogGuestMode
                    ? "В приложении пока нет позиций. Откройте витрину в браузере."
                    : "Каталог пока недоступен",
                icon: "storefront"
            )
            if let url = viewModel.resolvedStorefrontURL {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Открыть витрину")
                            .font(AppTheme.Typography.callout)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                Text(url.absoluteString)
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(AppTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    private var cartBarButton: some View {
        Button {
            viewModel.showCart = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
                if viewModel.cartItemCount > 0 {
                    Text("\(viewModel.cartItemCount)")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(.black)
                        .padding(3)
                        .background(AppTheme.Colors.accentPrimary)
                        .clipShape(Circle())
                        .offset(x: 8, y: -6)
                }
            }
        }
    }

    private var catalogContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.items) { item in
                    ProductCard(item: item) {
                        viewModel.addToCart(item)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .refreshable { await viewModel.load() }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let item: ClientCatalogItem
    let onAddToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .fill(AppTheme.Colors.surfaceSecondary)
                    .frame(height: 100)
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                if let category = item.categoryName {
                    Text(category.uppercased())
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                        .tracking(0.8)
                        .lineLimit(1)
                }
                Text(item.name)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(Int(item.price)) ₸")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Colors.accentPrimary)
            }

            Button {
                onAddToCart()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("В корзину")
                        .font(AppTheme.Typography.captionBold)
                }
                .foregroundStyle(AppTheme.Colors.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }
}

// MARK: - Cart Sheet

private struct CartSheet: View {
    @ObservedObject var viewModel: OrdaMarketViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.cartLines.isEmpty {
                    EmptyStateView(message: "Корзина пуста", icon: "cart")
                } else {
                    cartContent
                }
            }
            .navigationTitle("Корзина")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        }
    }

    private var cartContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(viewModel.cartLines, id: \.item.id) { line in
                        CartLineRow(line: line) { newQty in
                            viewModel.setQuantity(itemId: line.item.id, quantity: newQty)
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }

            // Summary + order button
            VStack(spacing: AppTheme.Spacing.sm) {
                Divider().background(AppTheme.Colors.borderSubtle)

                VStack(spacing: AppTheme.Spacing.xs) {
                    summaryRow("Сумма", "\(Int(viewModel.cartTotal)) ₸", color: AppTheme.Colors.textPrimary)
                    summaryRow("Скидка лояльности (10%)", "−\(Int(viewModel.loyaltyDiscount)) ₸", color: AppTheme.Colors.success)
                    Divider().background(AppTheme.Colors.borderSubtle)
                    summaryRow("Итого", "\(Int(viewModel.cartTotal - viewModel.loyaltyDiscount)) ₸", color: AppTheme.Colors.accentPrimary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Button {
                    Task { await viewModel.submitPreorder() }
                } label: {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.black)
                        } else {
                            Text("Оформить заказ")
                                .font(AppTheme.Typography.headline)
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.surfacePrimary)
        }
    }

    @ViewBuilder
    private func summaryRow(_ title: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Cart Line Row

private struct CartLineRow: View {
    let line: (item: ClientCatalogItem, quantity: Int)
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.item.name)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(Int(line.item.price)) ₸ × \(line.quantity)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            Spacer()

            HStack(spacing: AppTheme.Spacing.xs) {
                Button {
                    onQuantityChange(line.quantity - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                .buttonStyle(.plain)

                Text("\(line.quantity)")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(minWidth: 24, alignment: .center)

                Button {
                    onQuantityChange(line.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}
