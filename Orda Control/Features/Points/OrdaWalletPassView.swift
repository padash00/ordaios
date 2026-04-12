import SwiftUI
import PassKit

// MARK: - PassKit Availability Check

struct OrdaWalletPassView: View {
    @StateObject private var vm = OrdaWalletPassViewModel()
    let customerId: String
    let customerName: String
    let points: Int
    let tierTitle: String

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                passPreviewCard
                actionsCard
                infoCard
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Apple Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .alert("Успех", isPresented: $vm.showSuccess) {
            Button("OK") {}
        } message: {
            Text("Карта добавлена в Apple Wallet!")
        }
    }

    // MARK: - Pass Preview Card

    private var passPreviewCard: some View {
        VStack(spacing: 0) {
            // Card visual
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.accentPrimary, Color(red: 0.31, green: 0.27, blue: 0.97)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: AppTheme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ORDA")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Карта лояльности")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("БАЛЛЫ")
                                .font(AppTheme.Typography.micro)
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("\(points)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("УРОВЕНЬ")
                                .font(AppTheme.Typography.micro)
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(tierTitle)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(customerName)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppTheme.Spacing.lg)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .shadow(color: AppTheme.Colors.accentPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if PKPassLibrary.isPassLibraryAvailable() {
                Button {
                    Task { await vm.addToWallet(
                        customerId: customerId,
                        customerName: customerName,
                        points: points,
                        tier: tierTitle
                    )}
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Добавить в Apple Wallet")
                                .font(AppTheme.Typography.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                .disabled(vm.isLoading)

                if vm.isPassAlreadyAdded {
                    Label("Карта уже в Wallet", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.success)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "wallet.pass")
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text("Apple Wallet недоступен на этом устройстве")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }

            // Share QR Code
            ShareLink(item: "orda://client/\(customerId)") {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Поделиться QR-кодом")
                        .font(AppTheme.Typography.headline)
                }
                .foregroundStyle(AppTheme.Colors.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.accentPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(AppTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .appCard()
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label("Как использовать", systemImage: "info.circle.fill")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            infoRow(icon: "wallet.pass", text: "Добавьте карту в Apple Wallet — она всегда под рукой")
            infoRow(icon: "iphone.radiowaves.left.and.right", text: "Покажите карту кассиру для начисления баллов")
            infoRow(icon: "star.fill", text: "Баллы обновляются автоматически после покупок")
            infoRow(icon: "qrcode.viewfinder", text: "Или используйте QR-код в разделе Баллы")
        }
        .appCard()
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.accentPrimary)
                .frame(width: 20)
            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class OrdaWalletPassViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSuccess = false
    @Published var isPassAlreadyAdded = false

    private let passTypeIdentifier = "pass.com.padash00.orda.loyalty"
    private let passLibrary = PKPassLibrary()

    init() {
        checkIfPassAdded()
    }

    func addToWallet(customerId: String, customerName: String, points: Int, tier: String) async {
        isLoading = true
        defer { isLoading = false }

        // Check if pass already exists
        checkIfPassAdded()
        if isPassAlreadyAdded { return }

        // In production: request pass from server POST /api/client/wallet-pass
        // Server generates .pkpass signed with Apple certificate
        // For now: show info that server setup is required
        error = "Для добавления в Wallet требуется настройка сертификата Pass Type ID на сервере. Обратитесь к разработчику API."
    }

    private func checkIfPassAdded() {
        if PKPassLibrary.isPassLibraryAvailable() {
            // `passes(ofType:)` API shape differs between SDKs; use all passes for stable compilation.
            let passes = passLibrary.passes()
            isPassAlreadyAdded = passes.contains {
                $0.passTypeIdentifier == passTypeIdentifier
            }
        }
    }
}

// MARK: - PKAddPassesViewController wrapper

struct AddPassView: UIViewControllerRepresentable {
    let pass: PKPass
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        let vc = PKAddPassesViewController(pass: pass)!
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            onDismiss()
        }
    }
}
