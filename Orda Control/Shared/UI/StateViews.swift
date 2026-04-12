import SwiftUI

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.Colors.purple)
            Text(message)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

struct EmptyStateView: View {
    let message: String
    var icon: String = "tray"

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.Colors.textMuted.opacity(0.5))
            Text(ServerJSONPlaintext.normalize(message))
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}

struct ErrorStateView: View {
    let message: String
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.error)

            Text(ServerJSONPlaintext.normalize(message))
                .multilineTextAlignment(.center)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.error.opacity(0.9))

            if let retryAction {
                Button("Повторить", action: retryAction)
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.error.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.error.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
    }
}
