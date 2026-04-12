import Foundation

enum AppShellResolver {
    static func resolve(from context: SessionRoleContext?) -> AppShellType {
        guard let context else { return .noAccess }

        if let mappedByPath = mapByDefaultPath(context.defaultPath, context: context) {
            return mappedByPath
        }

        let persona = (context.persona ?? "").lowercased()

        if context.isSuperAdmin || persona == "super_admin" {
            return .admin
        }
        // Keep parity with web getDefaultAppPath precedence:
        // super_admin -> staff -> operator -> customer.
        if context.isStaff || persona == "staff" {
            return .staff
        }
        if context.isOperator || persona == "operator" {
            return .operatorRole
        }
        if context.isCustomer || persona == "customer" {
            return .client
        }
        return .noAccess
    }

    private static func mapByDefaultPath(_ path: String?, context: SessionRoleContext) -> AppShellType? {
        guard let path else { return nil }

        if path == "/dashboard" || path == "/welcome" || path == "/platform" || path == "/select-organization" {
            if context.isSuperAdmin || (context.persona ?? "").lowercased() == "super_admin" {
                return .admin
            }
            if context.isStaff || (context.persona ?? "").lowercased() == "staff" {
                return .staff
            }
            return nil
        }

        if path.hasPrefix("/operator") || path == "/operator-dashboard" {
            return .operatorRole
        }

        if path == "/client" || path.hasPrefix("/client/") {
            return .client
        }

        return nil
    }
}
