import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
struct OperatorShiftLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var locationText: String
        var shiftTypeText: String
    }

    var title: String
    var shiftDateText: String
}

@MainActor
final class OperatorShiftLiveActivityManager {
    static let shared = OperatorShiftLiveActivityManager()
    private init() {}

    private var currentActivity: Activity<OperatorShiftLiveActivityAttributes>?

    func sync(with shift: OperatorShiftItem?) async {
        guard let shift else {
            await endCurrent()
            return
        }

        let attrs = OperatorShiftLiveActivityAttributes(
            title: "Активная смена",
            shiftDateText: shift.shiftDate ?? "—"
        )
        let state = OperatorShiftLiveActivityAttributes.ContentState(
            statusText: shift.statusLabel,
            locationText: shift.location ?? "Точка не указана",
            shiftTypeText: shift.shiftTypeLabel
        )

        if let currentActivity {
            await currentActivity.update(ActivityContent(state: state, staleDate: nil))
            return
        }

        do {
            currentActivity = try Activity<OperatorShiftLiveActivityAttributes>.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Activity request may fail if Live Activities are unavailable/disabled.
            currentActivity = nil
        }
    }

    func endCurrent() async {
        guard let currentActivity else { return }
        let finalState = OperatorShiftLiveActivityAttributes.ContentState(
            statusText: "Смена завершена",
            locationText: "",
            shiftTypeText: ""
        )
        await currentActivity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        self.currentActivity = nil
    }
}
#else
@MainActor
final class OperatorShiftLiveActivityManager {
    static let shared = OperatorShiftLiveActivityManager()
    private init() {}

    func sync(with shift: OperatorShiftItem?) async {}
    func endCurrent() async {}
}
#endif
