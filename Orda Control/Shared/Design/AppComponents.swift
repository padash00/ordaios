import SwiftUI
import Charts

// MARK: - Primary Button
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.Colors.bgPrimary)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.accentPrimary, Color(hex: 0xF97316)],
                    startPoint: .leading, endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .shadow(color: AppTheme.Colors.accentPrimary.opacity(0.25), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.callout)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.vertical, AppTheme.Spacing.xs)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                    .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
            )
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let style: Style

    enum Style {
        case excellent, good, warning, critical, neutral, info
        case custom(color: Color)
    }

    private var color: Color {
        switch style {
        case .excellent: return AppTheme.Colors.success
        case .good: return AppTheme.Colors.purple
        case .warning: return AppTheme.Colors.warning
        case .critical: return AppTheme.Colors.error
        case .neutral: return AppTheme.Colors.textSecondary
        case .info: return AppTheme.Colors.info
        case .custom(let c): return c
        }
    }

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .overlay(Capsule().stroke(color.opacity(0.30), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - Secondary Chip
struct SecondaryChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Metric Card (like web MetricCard)
struct MetricCard: View {
    let label: String
    let value: String
    let icon: String
    var change: String? = nil
    var changePositive: Bool = true
    var color: Color = AppTheme.Colors.purple
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text(label)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(8)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }

                Text(value)
                    .font(AppTheme.Typography.monoLarge)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let change {
                    HStack(spacing: 4) {
                        Image(systemName: changePositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(change)
                            .font(AppTheme.Typography.captionBold)
                        Text("к пред. периоду")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    .foregroundStyle(changePositive ? AppTheme.Colors.success : AppTheme.Colors.error)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfacePrimary.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(isSelected ? color.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Tile (compact version for grids)
struct StatTile: View {
    let title: String
    let value: String
    var color: Color = AppTheme.Colors.textPrimary
    var bgColor: Color = Color.white.opacity(0.04)
    var borderColor: Color = Color.white.opacity(0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Typography.micro)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.sm)
        .background(bgColor)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = AppTheme.Colors.purple
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .padding(8)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            if let trailing { trailing }
        }
    }
}

// MARK: - Progress Bar
struct AppProgressBar: View {
    let value: Double // 0..1
    var color: Color = AppTheme.Colors.purple
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(hex: 0x1F2937))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(1, max(0, value)), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Quick Range Picker (like web QuickRangeBtn)
struct QuickRangePicker: View {
    @Binding var selected: String
    let options: [(key: String, label: String)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.key) { opt in
                    Button(opt.label) {
                        withAnimation(.easeInOut(duration: 0.2)) { selected = opt.key }
                    }
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(selected == opt.key ? .white : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        selected == opt.key
                            ? AnyShapeStyle(AppTheme.Colors.purple)
                            : AnyShapeStyle(Color(hex: 0x1F2937))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(selected == opt.key ? AppTheme.Colors.purple.opacity(0.5) : AppTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .shadow(color: selected == opt.key ? AppTheme.Colors.purple.opacity(0.25) : .clear, radius: 8, y: 2)
                }
            }
        }
    }
}

// MARK: - Data Table Row
struct DataTableRow: View {
    let cells: [(label: String, value: String, color: Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.label)
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    Text(cell.value)
                        .font(AppTheme.Typography.monoCaption)
                        .foregroundStyle(cell.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - Alert Banner
struct AlertBanner: View {
    let message: String
    var style: StatusBadge.Style = .warning
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    private var color: Color {
        switch style {
        case .warning: return AppTheme.Colors.warning
        case .critical: return AppTheme.Colors.error
        case .info: return AppTheme.Colors.info
        default: return AppTheme.Colors.purple
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
            Text(ServerJSONPlaintext.normalize(message))
                .font(AppTheme.Typography.callout)
                .foregroundStyle(color.opacity(0.9))
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction)
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(color)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color.opacity(0.6))
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(color.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

// MARK: - Input
struct AppInputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(AppTheme.Spacing.sm)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

extension View {
    func appInputStyle() -> some View {
        modifier(AppInputFieldStyle())
    }
}

// MARK: - Search Bar
struct AppSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Поиск..."

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.Colors.textMuted)
            TextField(placeholder, text: $text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

// MARK: - Money Formatter
enum MoneyFormatter {
    static func short(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "%.1f млн ₸", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "%.1f тыс ₸", value / 1_000)
        }
        return value.formatted(.number.grouping(.automatic)) + " ₸"
    }

    static func detailed(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic).precision(.fractionLength(0))) + " ₸"
    }

    static func percentChange(current: Double, previous: Double) -> (text: String, positive: Bool) {
        guard previous != 0 else { return ("—", true) }
        let p = ((current - previous) / abs(previous)) * 100
        let sign = p >= 0 ? "+" : ""
        return ("\(sign)\(String(format: "%.1f", p))%", p >= 0)
    }
}

// MARK: - Segmented Tab Bar (like web Tabs)
struct SegmentedTabBar<T: Hashable>: View {
    @Binding var selected: T
    let tabs: [(key: T, label: String, icon: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = tab.key }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.label)
                            .font(AppTheme.Typography.callout)
                    }
                    .foregroundStyle(selected == tab.key ? .white : AppTheme.Colors.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selected == tab.key ? AppTheme.Colors.purple : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: 0x1F2937).opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Color(hex: 0x374151), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

