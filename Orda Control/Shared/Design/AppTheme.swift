import SwiftUI

enum AppTheme {
    // MARK: - Colors (matched to web globals.css)
    enum Colors {
        // Backgrounds
        static let bgPrimary = Color(hex: 0x07101A)
        static let bgSecondary = Color(hex: 0x0A0F18)
        static let surfacePrimary = Color(red: 13/255, green: 22/255, blue: 35/255, opacity: 0.82)
        static let surfaceSecondary = Color(hex: 0x121D2C)
        static let surfaceHover = Color.white.opacity(0.04)

        // Borders
        static let borderSubtle = Color.white.opacity(0.08)
        static let borderStrong = Color.white.opacity(0.16)

        // Text
        static let textPrimary = Color(hex: 0xF4F7FB)
        static let textSecondary = Color(hex: 0x93A4BB)
        static let textMuted = Color(hex: 0x93A4BB).opacity(0.7)

        // Brand
        static let accentPrimary = Color(hex: 0xFFB36B)     // --primary amber
        static let accentBlue = Color(hex: 0x5F8CFF)        // --accent blue
        static let accentSoft = Color(hex: 0xFFB36B).opacity(0.18)

        // Semantic
        static let success = Color(hex: 0x10B981)           // emerald-500
        static let successBg = Color(hex: 0x10B981).opacity(0.10)
        static let successBorder = Color(hex: 0x10B981).opacity(0.20)

        static let warning = Color(hex: 0xF59E0B)           // amber-500
        static let warningBg = Color(hex: 0xF59E0B).opacity(0.10)
        static let warningBorder = Color(hex: 0xF59E0B).opacity(0.30)

        static let error = Color(hex: 0xEF4444)             // red-500
        static let errorBg = Color(hex: 0xEF4444).opacity(0.10)
        static let errorBorder = Color(hex: 0xEF4444).opacity(0.20)

        static let info = Color(hex: 0x3B82F6)              // blue-500
        static let infoBg = Color(hex: 0x3B82F6).opacity(0.10)
        static let infoBorder = Color(hex: 0x3B82F6).opacity(0.20)

        static let purple = Color(hex: 0x8B5CF6)            // purple-500
        static let purpleBg = Color(hex: 0x8B5CF6).opacity(0.10)
        static let purpleBorder = Color(hex: 0x8B5CF6).opacity(0.20)

        // Chart palette
        static let chart1 = Color(hex: 0xFFB36B)            // amber
        static let chart2 = Color(hex: 0x5F8CFF)            // blue
        static let chart3 = Color(hex: 0x6FE6C7)            // mint
        static let chart4 = Color(hex: 0xF38FD6)            // pink
        static let chart5 = Color(hex: 0xF15F57)            // coral

        // Payment method colors
        static let cashColor = Color(hex: 0xF59E0B)
        static let kaspiColor = Color(hex: 0x2563EB)
        static let cardColor = Color(hex: 0x7C3AED)
        static let onlineColor = Color(hex: 0xEC4899)

        // Gradient helpers
        static let cardGradient = LinearGradient(
            colors: [Color(hex: 0x0D1623).opacity(0.82), Color(hex: 0x121D2C).opacity(0.6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let headerGradient = LinearGradient(
            colors: [Color(hex: 0x581C87).opacity(0.3), Color(hex: 0x111827), Color(hex: 0x1E3A5F).opacity(0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography (Space Grotesk feel)
    enum Typography {
        static let display = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 14, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
        static let captionBold = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let micro = Font.system(size: 10, weight: .medium, design: .rounded)

        // Monospace for numbers
        static let monoLarge = Font.system(size: 28, weight: .bold, design: .monospaced)
        static let monoBody = Font.system(size: 15, weight: .medium, design: .monospaced)
        static let monoCaption = Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Card Style
struct AppCardStyle: ViewModifier {
    var padding: CGFloat = AppTheme.Spacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.Colors.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.md)
            .background(.ultraThinMaterial.opacity(0.3))
            .background(AppTheme.Colors.surfacePrimary.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardStyle())
    }
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
}
