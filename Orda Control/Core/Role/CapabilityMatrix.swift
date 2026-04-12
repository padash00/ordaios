import Foundation

enum AppCapability: String, CaseIterable {
    case clientHome
    case clientBookings
    case clientPoints
    case clientSupport
    case adminClientBookingsReview
    case adminClientBookingsSetStatus
    case adminClientSupportReview
    case adminClientSupportSetStatus
    case operatorDashboard
    case operatorShifts
    case operatorTasks
    case operatorSalaryRead
    case operatorProfileRead
    case adminIncomesRead
    case adminIncomesWrite
    case adminExpensesRead
    case adminExpensesWrite
    case adminShiftsRead
    case adminShiftsWrite
    case adminTasksRead
    case adminTasksWrite
    case adminOperatorsRead
    case adminOperatorsWrite
    case adminCustomersRead
    case adminCustomersWrite
    case adminCustomersHistoryRead
    case adminInventoryRead
    case adminInventoryWrite
    case adminStoreRead
    case adminStoreWrite
    case adminPOSRead
    case adminPOSWrite
    case adminPointRead
    case adminPointWrite
    case adminReportsRead
    case adminKPIRead
    case adminKPIWrite
    case adminGoalsRead
    case adminGoalsWrite
    case adminForecastRead
    case adminAnalysisRead
    case operatorTasksWrite
    case operatorShiftsWrite
}

struct CapabilityMatrix {
    static func capabilities(for role: SessionRoleContext?) -> Set<AppCapability> {
        guard let role else { return [] }
        var base: Set<AppCapability> = []

        if role.isSuperAdmin {
            base = [
                .adminIncomesRead, .adminIncomesWrite,
                .adminExpensesRead, .adminExpensesWrite,
                .adminShiftsRead, .adminShiftsWrite,
                .adminTasksRead, .adminTasksWrite,
                .adminOperatorsRead, .adminOperatorsWrite,
                .adminCustomersRead, .adminCustomersWrite, .adminCustomersHistoryRead,
                .adminInventoryRead, .adminInventoryWrite,
                .adminStoreRead, .adminStoreWrite,
                .adminPOSRead, .adminPOSWrite,
                .adminPointRead, .adminPointWrite,
                .adminReportsRead, .adminKPIRead, .adminKPIWrite, .adminGoalsRead, .adminGoalsWrite,
                .adminForecastRead, .adminAnalysisRead,
                .adminClientBookingsReview,
                .adminClientBookingsSetStatus,
                .adminClientSupportReview,
                .adminClientSupportSetStatus
            ]
            return applyOverrides(base: base, role: role)
        }

        if role.isStaff {
            switch (role.staffRole ?? "").lowercased() {
            case "owner", "manager":
                base = [
                    .adminIncomesRead, .adminIncomesWrite,
                    .adminExpensesRead, .adminExpensesWrite,
                    .adminShiftsRead, .adminShiftsWrite,
                    .adminTasksRead, .adminTasksWrite,
                    .adminOperatorsRead, .adminOperatorsWrite,
                    .adminCustomersRead, .adminCustomersWrite, .adminCustomersHistoryRead,
                    .adminInventoryRead, .adminInventoryWrite,
                    .adminStoreRead, .adminStoreWrite,
                    .adminPOSRead, .adminPOSWrite,
                    .adminPointRead, .adminPointWrite,
                    .adminReportsRead, .adminKPIRead, .adminKPIWrite, .adminGoalsRead, .adminGoalsWrite,
                    .adminForecastRead, .adminAnalysisRead,
                    .adminClientBookingsReview,
                    .adminClientBookingsSetStatus,
                    .adminClientSupportReview,
                    .adminClientSupportSetStatus
                ]
            case "marketer":
                base = [
                    .adminTasksRead,
                    .adminTasksWrite,
                    .adminShiftsRead,
                    .adminClientBookingsReview,
                    .adminClientSupportReview
                ]
            default:
                base = [
                    .adminTasksRead,
                    .adminClientSupportReview
                ]
            }
            return applyOverrides(base: base, role: role)
        }

        if role.isOperator {
            base = [
                .operatorDashboard,
                .operatorShifts,
                .operatorTasks,
                .operatorTasksWrite,
                .operatorShiftsWrite,
                .operatorSalaryRead,
                .operatorProfileRead
            ]
            return applyOverrides(base: base, role: role)
        }

        if role.isCustomer {
            base = [
                .clientHome,
                .clientBookings,
                .clientPoints,
                .clientSupport
            ]
            return applyOverrides(base: base, role: role)
        }

        return applyOverrides(base: base, role: role)
    }

    private static func applyOverrides(base: Set<AppCapability>, role: SessionRoleContext) -> Set<AppCapability> {
        var result = base
        guard let overrides = role.rolePermissionOverrides else { return result }

        for item in overrides {
            if let path = item.path?.lowercased(), let enabled = item.enabled {
                applyPathOverride(path: path, enabled: enabled, result: &result)
            }

            guard let key = item.key?.lowercased(), let value = item.value?.lowercased() else { continue }
            guard key.hasPrefix("allow.") || key.hasPrefix("deny.") else { continue }

            let capabilityName = key.replacingOccurrences(of: "allow.", with: "").replacingOccurrences(of: "deny.", with: "")
            guard let cap = AppCapability(rawValue: capabilityName) else { continue }

            if key.hasPrefix("allow."), value == "true" {
                result.insert(cap)
            }
            if key.hasPrefix("deny."), value == "true" {
                result.remove(cap)
            }
        }
        return result
    }

    private static func applyPathOverride(path: String, enabled: Bool, result: inout Set<AppCapability>) {
        let mapping: [(String, [AppCapability])] = [
            ("/income", [.adminIncomesRead, .adminIncomesWrite]),
            ("/expenses", [.adminExpensesRead, .adminExpensesWrite]),
            ("/shifts", [.adminShiftsRead, .adminShiftsWrite]),
            ("/tasks", [.adminTasksRead, .adminTasksWrite]),
            ("/operators", [.adminOperatorsRead, .adminOperatorsWrite]),
            ("/customers/history", [.adminCustomersHistoryRead]),
            ("/customers", [.adminCustomersRead, .adminCustomersWrite]),
            ("/clients/bookings", [.adminClientBookingsReview, .adminClientBookingsSetStatus]),
            ("/clients/support", [.adminClientSupportReview, .adminClientSupportSetStatus]),
            ("/inventory", [.adminInventoryRead, .adminInventoryWrite, .adminStoreRead, .adminStoreWrite]),
            ("/store", [.adminStoreRead, .adminStoreWrite]),
            ("/pos", [.adminPOSRead, .adminPOSWrite]),
            ("/point", [.adminPointRead, .adminPointWrite]),
            ("/reports", [.adminReportsRead]),
            ("/kpi", [.adminKPIRead, .adminKPIWrite]),
            ("/goals", [.adminGoalsRead, .adminGoalsWrite]),
            ("/forecast", [.adminForecastRead]),
            ("/analysis", [.adminAnalysisRead]),
            ("/operator/tasks", [.operatorTasks, .operatorTasksWrite]),
            ("/operator/shifts", [.operatorShifts, .operatorShiftsWrite]),
            ("/operator/salary", [.operatorSalaryRead]),
            ("/operator/profile", [.operatorProfileRead])
        ]

        for (fragment, caps) in mapping where path.contains(fragment) {
            for capability in caps {
                if enabled {
                    result.insert(capability)
                } else {
                    result.remove(capability)
                }
            }
        }
    }
}
