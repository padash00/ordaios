import SwiftUI
import WidgetKit

// MARK: - Shared data models (copied from OperatorWidgetBridge — no import needed)

private struct OperatorWidgetTaskSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let status: String
    let dueDate: String?
}

private struct OperatorWidgetShiftSnapshot: Codable, Hashable {
    let id: String
    let shiftDate: String?
    let shiftTypeLabel: String
    let statusLabel: String
    let location: String?
}

private struct OperatorWidgetSnapshot: Codable, Hashable {
    let updatedAt: Date
    let openTasksCount: Int
    let tasks: [OperatorWidgetTaskSnapshot]
    let activeShift: OperatorWidgetShiftSnapshot?

    static let placeholder = OperatorWidgetSnapshot(
        updatedAt: Date(),
        openTasksCount: 3,
        tasks: [
            .init(id: "1", title: "Проверить остатки", status: "В работе", dueDate: "2026-04-10"),
            .init(id: "2", title: "Подтвердить смену", status: "К выполнению", dueDate: nil),
            .init(id: "3", title: "Отчёт по кассе", status: "К выполнению", dueDate: nil)
        ],
        activeShift: .init(
            id: "s1",
            shiftDate: "2026-04-10",
            shiftTypeLabel: "Дневная",
            statusLabel: "Активна",
            location: "F16 Astana"
        )
    )
}

// MARK: - Design tokens (match AppTheme without importing it)

private enum WColor {
    static let accent    = Color(red: 0.49, green: 0.44, blue: 0.97)   // #7C6FF7
    static let success   = Color(red: 0.13, green: 0.77, blue: 0.37)   // #22C460
    static let warning   = Color(red: 1.00, green: 0.62, blue: 0.04)   // #FF9E0A
    static let error     = Color(red: 1.00, green: 0.27, blue: 0.27)   // #FF4545
    static let textPrimary   = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let textSecondary = Color(red: 0.60, green: 0.60, blue: 0.67)
    static let surface   = Color(red: 0.11, green: 0.11, blue: 0.14)   // surface card
}

// MARK: - Timeline Entry

private struct OperatorEntry: TimelineEntry {
    let date: Date
    let snapshot: OperatorWidgetSnapshot
}

// MARK: - Provider

private struct OperatorProvider: TimelineProvider {
    private let appGroupSuite = "group.com.padash00.orda.client"
    private let storageKey    = "operator.widget.snapshot.v1"

    func placeholder(in context: Context) -> OperatorEntry {
        OperatorEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (OperatorEntry) -> Void) {
        completion(OperatorEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OperatorEntry>) -> Void) {
        let entry = OperatorEntry(date: Date(), snapshot: loadSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> OperatorWidgetSnapshot {
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? .standard
        guard let data    = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OperatorWidgetSnapshot.self, from: data)
        else { return .placeholder }
        return decoded
    }
}

// MARK: - Widget

struct OperatorOverviewWidget: Widget {
    let kind = "OperatorOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OperatorProvider()) { entry in
            OperatorOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Оператор Orda")
        .description("Активная смена и открытые задачи.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

private struct OperatorOverviewWidgetView: View {
    let entry: OperatorEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        default:            LargeView(entry: entry)
        }
    }
}

// MARK: Small — только смена

private struct SmallView: View {
    let entry: OperatorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(WColor.accent)
                    .frame(width: 8, height: 8)
                Text("Orda")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WColor.accent)
            }

            Spacer()

            if let shift = entry.snapshot.activeShift {
                VStack(alignment: .leading, spacing: 3) {
                    Text("◉ \(shift.shiftTypeLabel)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WColor.textPrimary)
                    Text(shift.location ?? "Точка")
                        .font(.caption2)
                        .foregroundStyle(WColor.textSecondary)
                        .lineLimit(1)
                }
            } else {
                Text("Нет смены")
                    .font(.subheadline)
                    .foregroundStyle(WColor.textSecondary)
            }

            Spacer()

            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(WColor.warning)
                Text("\(entry.snapshot.openTasksCount) задач")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WColor.warning)
            }
        }
        .padding(14)
        .containerBackground(WColor.surface, for: .widget)
    }
}

// MARK: Medium — смена + топ задачи

private struct MediumView: View {
    let entry: OperatorEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left — смена
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(WColor.accent).frame(width: 7, height: 7)
                    Text("Orda").font(.caption2.weight(.semibold)).foregroundStyle(WColor.accent)
                }

                Spacer()

                if let shift = entry.snapshot.activeShift {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("◉ Смена")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WColor.success)
                        Text(shift.shiftTypeLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(WColor.textPrimary)
                        Text(shift.location ?? "—")
                            .font(.caption2)
                            .foregroundStyle(WColor.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("○ Нет смены")
                            .font(.caption2)
                            .foregroundStyle(WColor.textSecondary)
                    }
                }

                Spacer()

                Text("Обновлено \(timeLabel(entry.snapshot.updatedAt))")
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.textSecondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            Divider().background(WColor.textSecondary.opacity(0.2))

            // Right — задачи
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Задачи")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WColor.textSecondary)
                    Spacer()
                    Text("\(entry.snapshot.openTasksCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WColor.warning)
                }

                if entry.snapshot.tasks.isEmpty {
                    Spacer()
                    Text("Нет задач")
                        .font(.caption2)
                        .foregroundStyle(WColor.textSecondary)
                    Spacer()
                } else {
                    ForEach(entry.snapshot.tasks.prefix(3)) { task in
                        HStack(alignment: .top, spacing: 4) {
                            Circle()
                                .fill(statusColor(task.status))
                                .frame(width: 5, height: 5)
                                .padding(.top, 4)
                            Text(task.title)
                                .font(.caption2)
                                .foregroundStyle(WColor.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .containerBackground(WColor.surface, for: .widget)
    }
}

// MARK: Large — полная информация

private struct LargeView: View {
    let entry: OperatorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(WColor.accent).frame(width: 8, height: 8)
                    Text("Orda Оператор")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WColor.accent)
                }
                Spacer()
                Text(timeLabel(entry.snapshot.updatedAt))
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.textSecondary.opacity(0.5))
            }
            .padding(.bottom, 10)

            // Смена
            if let shift = entry.snapshot.activeShift {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(WColor.success.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(WColor.success)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("◉ \(shift.shiftTypeLabel) · \(shift.statusLabel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WColor.success)
                        Text(shift.location ?? "Точка")
                            .font(.caption2)
                            .foregroundStyle(WColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(WColor.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 14))
                        .foregroundStyle(WColor.textSecondary)
                    Text("Смена не открыта")
                        .font(.caption)
                        .foregroundStyle(WColor.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WColor.textSecondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Задачи
            HStack {
                Text("Открытые задачи")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColor.textSecondary)
                Spacer()
                Text("\(entry.snapshot.openTasksCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WColor.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(WColor.warning.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            if entry.snapshot.tasks.isEmpty {
                Text("Нет задач")
                    .font(.caption2)
                    .foregroundStyle(WColor.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.snapshot.tasks) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(task.status))
                                .frame(width: 6, height: 6)
                            Text(task.title)
                                .font(.caption2)
                                .foregroundStyle(WColor.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let due = task.dueDate {
                                Text(shortDate(due))
                                    .font(.system(size: 9))
                                    .foregroundStyle(WColor.textSecondary.opacity(0.6))
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(WColor.surface, for: .widget)
    }
}

// MARK: - Helpers

private func statusColor(_ status: String) -> Color {
    let s = status.lowercased()
    if s.contains("работ") || s.contains("progress") { return WColor.accent }
    if s.contains("блок") || s.contains("blocked")    { return WColor.error }
    if s.contains("готов") || s.contains("done")      { return WColor.success }
    return WColor.warning
}

private func timeLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

private func shortDate(_ iso: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: String(iso.prefix(10))) else { return iso }
    let out = DateFormatter()
    out.locale = Locale(identifier: "ru_RU")
    out.dateFormat = "d MMM"
    return out.string(from: d)
}
